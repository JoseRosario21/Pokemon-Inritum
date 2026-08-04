#===============================================================================
# Field Notes - Page builder
#
# Turns a GameData::FieldEffect into the ordered list of lines shown on its
# page. Returns an array of hashes:
#   { :kind => :header | :note | :flavour, :text => String }
#
# Two things here are deliberate improvements over a straight port of
# Rejuvenation's hand-written notes:
#
#  * Move multipliers are grouped. PBS lists one MoveMultiplier line per move,
#    and a field like Forest has six bug moves all sharing "The forest amplifies
#    the buzz!". Printing six identical lines is unreadable, so entries sharing
#    a multiplier and message are merged into one line naming every move.
#
#  * Nothing is authored twice. Every line is derived from the registry, so a
#    balance change in PBS is reflected in the notes with no second edit.
#===============================================================================
module FieldNotes
  module_function

  def build_page(data)
    return [] if data.nil?
    lines = []
    add_overview(lines, data)
    add_type_effects(lines, data)
    add_move_effects(lines, data)
    add_status_immunities(lines, data)
    add_special_rules(lines, data)
    add_terrain_moves(lines, data)
    add_transformations(lines, data)
    add_combos(lines, data)
    add_counters(lines, data)
    lines.push({ :kind => :note, :text => _INTL("No special rules recorded for this field.") }) if lines.length <= 1
    return lines
  end

  def header(lines, text)
    lines.push({ :kind => :header, :text => text })
  end

  def note(lines, text)
    lines.push({ :kind => :note, :text => text }) if text && !text.empty?
  end

  def flavour(lines, text)
    lines.push({ :kind => :flavour, :text => text }) if text && !text.empty?
  end

  #-----------------------------------------------------------------------------
  def add_overview(lines, data)
    header(lines, _INTL("Overview"))
    parts = []
    parts.push(data.category) if data.category && !data.category.empty?
    parts.concat(data.tags) if data.tags && !data.tags.empty?
    note(lines, parts.uniq.join(" / ")) if !parts.empty?
    if data.default_duration && data.default_duration > 0
      note(lines, _INTL("Lasts {1} turns when set by a move.", data.default_duration))
    else
      note(lines, _INTL("Remains for the whole battle."))
    end
    intro = data.get_announcement(:start)
    flavour(lines, intro) if intro && !intro.empty?
  end

  #-----------------------------------------------------------------------------
  def add_type_effects(lines, data)
    entries = data.type_multipliers
    return if entries.nil? || entries.empty?
    header(lines, _INTL("Types"))
    entries.each do |entry|
      label = describe_multiplier_target(_INTL("{1}-type moves", type_name(entry[:type])), entry)
      note(lines, label)
      flavour(lines, entry[:message]) if entry[:message] && !entry[:message].empty?
    end
  end

  #-----------------------------------------------------------------------------
  # Groups by (key, value, message) so a shared flavour line lists its moves
  # together instead of repeating.
  def add_move_effects(lines, data)
    entries = data.move_multipliers
    return if entries.nil? || entries.empty?
    header(lines, _INTL("Moves"))
    groups = {}
    order = []
    entries.each do |entry|
      key = [entry[:key], entry[:value], entry[:message].to_s]
      if !groups[key]
        groups[key] = []
        order.push(key)
      end
      groups[key].push(entry[:move])
    end
    order.each do |key|
      moves = groups[key].map { |m| move_name(m) }
      sample = { :key => key[0], :value => key[1] }
      note(lines, describe_multiplier_target(list(moves), sample))
      flavour(lines, key[2]) if !key[2].empty?
    end
  end

  # Shared phrasing for both type and move multipliers. The `key` distinguishes
  # a power boost from a raw damage/attack/defense change, and defense is
  # inverted so "+30% defense" doesn't read as if the target hits harder.
  def describe_multiplier_target(subject, entry)
    value = entry[:value].to_f
    key = entry[:key] || :power
    cond = entry[:condition]
    text = case key
           when :defense
             _INTL("{1}: {2} damage taken", subject, mult(1.0 / (value.zero? ? 1.0 : value)))
           when :attack
             _INTL("{1}: {2} attack", subject, mult(value))
           when :final_damage
             _INTL("{1}: {2} damage", subject, mult(value))
           else
             _INTL("{1}: {2} power", subject, mult(value))
           end
    text += _INTL(" (only when {1})", cond) if cond && !cond.to_s.empty?
    return text
  end

  #-----------------------------------------------------------------------------
  def add_status_immunities(lines, data)
    entries = data.status_immunities
    return if entries.nil? || entries.empty?
    header(lines, _INTL("Protection"))
    entries.each do |entry|
      text = _INTL("Pokemon cannot be affected by {1}.", status_name(entry[:status]))
      text += _INTL(" (only when {1})", entry[:condition]) if entry[:condition] && !entry[:condition].to_s.empty?
      note(lines, text)
    end
  end

  #-----------------------------------------------------------------------------
  # Effects whose first argument is a move and whose remaining arguments are
  # shared parameters. Several such entries that agree on those parameters are
  # merged into a single line, the same way move multipliers are -- five
  # consecutive "accuracy set to 85%" lines is noise, one line naming the three
  # powder moves is information.
  GROUPABLE_BY_MOVE = [
    :accuracy_set, :type_add, :type_change, :priority_boost, :effect_duration,
    :hazard_boost, :hazard_type_change, :move_boost,
    :add_burn, :add_paralysis, :add_poison, :add_freeze, :add_sleep,
    :add_status, :confusion_boost, :speed_boost_move
  ]

  def add_special_rules(lines, data)
    entries = data.effects
    return if entries.nil? || entries.empty?
    # Nature Power / Secret Power get their own section further down.
    shown = entries.reject { |e| [:nature_power_change, :nature_power_move, :secret_power_effect].include?(e[:name]) }
    return if shown.empty?
    header(lines, _INTL("Special rules"))
    seen = []
    collapse_effects(shown).each do |effect|
      text = describe_effect(effect)
      next if text.nil? || text.empty?
      next if seen.include?(text)
      seen.push(text)
      note(lines, text)
    end
  end

  # Merges groupable entries, preserving the order of first appearance so the
  # page still reads in the order the field was authored.
  def collapse_effects(entries)
    result = []
    buckets = {}
    entries.each do |effect|
      name = effect[:name]
      args = effect[:args] || []
      if !GROUPABLE_BY_MOVE.include?(name) || args.length < 1
        result.push(effect)
        next
      end
      key = [name, args[1..-1]]
      if buckets[key]
        buckets[key][:moves].push(args[0])
        next
      end
      bucket = { :name => name, :moves => [args[0]], :tail => args[1..-1] }
      buckets[key] = bucket
      result.push(bucket)
    end
    # Turn buckets back into effect hashes, wrapping multi-move ones.
    return result.map do |entry|
      next entry if !entry[:moves]
      first = (entry[:moves].length == 1) ? entry[:moves][0] : MoveGroup.new(entry[:moves])
      { :name => entry[:name], :args => [first] + entry[:tail] }
    end
  end

  #-----------------------------------------------------------------------------
  def add_terrain_moves(lines, data)
    bits = []
    bits.push(_INTL("Nature Power becomes {1}.", move_name(data.nature_power))) if data.nature_power
    camo = data.get_effect(:camouflage_type)
    bits.push(_INTL("Camouflage turns the user {1}-type.", type_name(camo[:args][0]))) if camo && camo[:args][0]
    mim = data.get_effect(:mimicry_type)
    bits.push(_INTL("Mimicry turns the user {1}-type.", type_name(mim[:args][0]))) if mim && mim[:args][0]
    bits.push(_INTL("Secret Power has a field-specific effect.")) if data.secret_power_effect && data.secret_power_effect != 0
    return if bits.empty?
    header(lines, _INTL("Terrain moves"))
    bits.each { |b| note(lines, b) }
  end

  #-----------------------------------------------------------------------------
  def add_transformations(lines, data)
    changes = data.transformations || []
    destroys = data.destroy_triggers || []
    return if changes.empty? && destroys.empty?
    header(lines, _INTL("Changing the field"))
    changes.each do |entry|
      target = entry[:new_field] ? field_display_name(entry[:new_field]) : _INTL("nothing")
      text = _INTL("{1} turns this into {2}.", move_name(entry[:trigger_move]), target)
      text += _INTL(" (only when {1})", entry[:condition]) if entry[:condition] && !entry[:condition].to_s.empty?
      note(lines, text)
      flavour(lines, entry[:message])
    end
    destroys.each do |entry|
      text = _INTL("{1} removes this field.", move_name(entry[:trigger_move]))
      text += _INTL(" (only when {1})", entry[:condition]) if entry[:condition] && !entry[:condition].to_s.empty?
      note(lines, text)
      flavour(lines, entry[:message])
    end
  end

  #-----------------------------------------------------------------------------
  def add_combos(lines, data)
    entries = data.combos
    return if entries.nil? || entries.empty?
    header(lines, _INTL("Combinations"))
    entries.each do |entry|
      moves = list(entry[:moves].map { |m| move_name(m) })
      target = entry[:result_field] ? field_display_name(entry[:result_field]) : _INTL("nothing")
      note(lines, _INTL("{1} together create {2}.", moves, target))
      flavour(lines, entry[:message])
    end
  end

  #-----------------------------------------------------------------------------
  def add_counters(lines, data)
    entries = data.counters
    return if entries.nil? || entries.empty?
    header(lines, _INTL("Build-up"))
    entries.each do |entry|
      target = entry[:result_field] ? field_display_name(entry[:result_field]) : _INTL("nothing")
      note(lines, _INTL("After {1} uses of {2}, becomes {3}.", entry[:threshold], describe_counter_trigger(entry[:trigger]), target))
      flavour(lines, entry[:message])
    end
  end

  # Counter triggers look like "type:WATER" or "move:SURF".
  def describe_counter_trigger(trigger)
    return _INTL("certain moves") if trigger.nil?
    parts = trigger.to_s.split(":")
    return _INTL("certain moves") if parts.length < 2
    case parts[0].downcase
    when "type" then return _INTL("{1}-type moves", type_name(parts[1]))
    when "move" then return move_name(parts[1])
    end
    return _INTL("certain moves")
  end

  # A field referenced by a transformation may not be defined yet.
  def field_display_name(field_id)
    data = GameData::FieldEffect.try_get(field_id) rescue nil
    return data ? data.name : pretty(field_id)
  end
end
