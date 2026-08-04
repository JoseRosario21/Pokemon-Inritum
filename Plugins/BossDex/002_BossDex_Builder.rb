#===============================================================================
# Boss Dex - Page builder
#
# Turns a BossBattle::BOSS_DATA entry into the lines shown on its page, as
#   { :kind => :header | :note | :flavour, :text => String }
#
# Text is plain here; the UI applies colour and indent per kind, which is what
# lets long lines be wrapped without ever splitting a formatting tag.
#
# How much is shown depends on progress: an encountered boss gives away only
# what you saw walking in, a defeated one gives the full breakdown.
#===============================================================================
module BossDex
  module_function

  def name_of(boss_id)
    data = data_for(boss_id)
    return "???" if !data
    return data[:name] if data[:name] && !data[:name].empty?
    species = GameData::Species.try_get(data[:species]) rescue nil
    return species ? species.name : boss_id.to_s
  end

  def species_name(id)
    data = GameData::Species.try_get(id) rescue nil
    return data ? data.name : pretty(id)
  end

  def move_name(id)
    data = GameData::Move.try_get(id) rescue nil
    return data ? data.name : pretty(id)
  end

  def ability_name(id)
    data = GameData::Ability.try_get(id) rescue nil
    return data ? data.name : pretty(id)
  end

  def item_name(id)
    data = GameData::Item.try_get(id) rescue nil
    return data ? data.name : pretty(id)
  end

  def type_name(id)
    data = GameData::Type.try_get(id) rescue nil
    return data ? data.name : pretty(id)
  end

  def stat_name(id)
    data = GameData::Stat.try_get(id) rescue nil
    return data ? data.name : pretty(id)
  end

  def pretty(sym)
    return "" if sym.nil?
    return sym.to_s.split("_").map { |w| w.capitalize }.join(" ")
  end

  def list(names)
    names = names.compact.reject { |n| n.to_s.empty? }
    return "" if names.empty?
    return names[0] if names.length == 1
    return _INTL("{1} and {2}", names[0..-2].join(", "), names[-1])
  end

  def header(lines, text);  lines.push({ :kind => :header,  :text => text }); end
  def note(lines, text);    lines.push({ :kind => :note,    :text => text }) if text && !text.to_s.empty?; end
  def subnote(lines, text); lines.push({ :kind => :subnote, :text => text }) if text && !text.to_s.empty?; end
  def flavour(lines, text); lines.push({ :kind => :flavour, :text => text }) if text && !text.to_s.empty?; end

  # Boss messages are authored with {1} standing in for the boss's name, so they
  # read correctly in battle. Substituting "it" instead turns "{1}'s seal
  # shatters" into "it's seal shatters", which reads as "it is".
  def fill_name(text, boss_id)
    return nil if text.nil?
    return text.to_s.gsub("{1}", name_of(boss_id))
  end

  #-----------------------------------------------------------------------------
  def build_page(boss_id)
    data = data_for(boss_id)
    return [{ :kind => :note, :text => _INTL("No data.") }] if !data
    lines = []
    add_profile(lines, boss_id, data)
    if defeated?(boss_id)
      add_loadout(lines, data)
      add_shields(lines, data, boss_id)
      add_charge_attack(lines, data, boss_id)
    else
      header(lines, _INTL("Record"))
      note(lines, _INTL("Defeat this opponent to complete its entry."))
    end
    return lines
  end

  def add_profile(lines, boss_id, data)
    header(lines, _INTL("Profile"))
    note(lines, _INTL("Species: {1}", species_name(data[:species])))
    note(lines, _INTL("Level: {1}", data[:level])) if data[:level]
    if data[:shield_count] && data[:shield_count] > 0
      note(lines, _INTL("Shields: {1}", data[:shield_count]))
    end
    note(lines, _INTL("Can be caught.")) if data[:catchable]
    flavour(lines, data[:entry_text])
  end

  def add_loadout(lines, data)
    header(lines, _INTL("Loadout"))
    note(lines, _INTL("Ability: {1}", ability_name(data[:ability]))) if data[:ability]
    note(lines, _INTL("Held item: {1}", item_name(data[:item])))     if data[:item]
    note(lines, _INTL("Nature: {1}", pretty(data[:nature])))         if data[:nature]
    if data[:moves] && !data[:moves].empty?
      note(lines, _INTL("Moves: {1}", list(data[:moves].map { |m| move_name(m) })))
    end
  end

  #-----------------------------------------------------------------------------
  # Shields are the interesting part of a boss, so each break gets its own
  # block describing exactly what changes.
  def add_shields(lines, data, boss_id)
    breaks = data[:on_break]
    return if breaks.nil? || breaks.empty?
    header(lines, _INTL("Shield phases"))
    breaks.keys.sort.reverse.each do |shield|
      entry = breaks[shield]
      next if !entry
      note(lines, _INTL("Breaking shield {1}:", shield))
      # Sub-items get their own kind so the UI indents them under the shield
      # they belong to -- a leading two spaces would be eaten by word wrap.
      describe_break(entry).each { |text| subnote(lines, text) }
      flavour(lines, fill_name(entry[:message], boss_id))
    end
  end

  def describe_break(entry)
    out = []
    out.push(_INTL("Becomes {1}-type", list(entry[:type_change].map { |t| type_name(t) }))) if entry[:type_change]
    out.push(_INTL("Ability becomes {1}", ability_name(entry[:ability])))                   if entry[:ability]
    out.push(_INTL("Changes form"))                                                          if entry[:form_change]
    out.push(_INTL("Switches to {1}", list(entry[:moves].map { |m| move_name(m) })))         if entry[:moves]
    if entry[:stat_changes].is_a?(Hash)
      parts = entry[:stat_changes].map do |stat, amount|
        _INTL("{1} {2}", stat_name(stat), sprintf("%+d", amount))
      end
      out.push(_INTL("Stats: {1}", parts.join(", ")))
    end
    out.push(_INTL("Resets stat changes"))                                if entry[:stat_reset]
    out.push(_INTL("Cures its status condition"))                         if entry[:status_cure]
    out.push(_INTL("Summons {1}", weather_label(entry[:weather])))        if entry[:weather]
    if entry[:ally_call].is_a?(Hash)
      out.push(_INTL("Calls in an ally: {1}", species_name(entry[:ally_call][:species])))
    end
    return out
  end

  def weather_label(sym)
    case sym.to_s.downcase
    when "sun"       then return _INTL("harsh sunlight")
    when "rain"      then return _INTL("rain")
    when "sandstorm" then return _INTL("a sandstorm")
    when "hail"      then return _INTL("hail")
    when "snow"      then return _INTL("snow")
    end
    return pretty(sym)
  end

  #-----------------------------------------------------------------------------
  def add_charge_attack(lines, data, boss_id)
    charge = data[:charge_attack]
    return if !charge.is_a?(Hash)
    header(lines, _INTL("Charge attack"))
    note(lines, _INTL("Uses {1} every {2} rounds.",
                      move_name(charge[:move]), charge[:interval] || 3))
    flavour(lines, fill_name(charge[:warning], boss_id))
  end
end
