#===============================================================================
# Field Notes - Effect descriptions
#
# Translates a raw `Effect = ...` entry from PBS/field_effects.txt into a
# sentence a player can read. The Field Effect plugin's own library stores only
# a category and a proc per effect, with no human-readable text, so this table
# is the missing half.
#
# Every entry is a lambda taking the effect's args array and returning a String.
# Anything not listed falls back to a generic rendering, which means a new
# effect added to the library later shows up as readable-ish text instead of
# breaking the page. Keeping the fallback honest is why this file never raises.
#===============================================================================
module FieldNotes
  module_function

  #-----------------------------------------------------------------------------
  # Name lookups. All tolerate unknown ids and fall back to a tidied raw symbol,
  # so a typo in PBS shows as "Sleeppowder" rather than crashing the screen.
  #-----------------------------------------------------------------------------
  def pretty(sym)
    return "" if sym.nil?
    return sym.to_s.capitalize.gsub("_", " ")
  end

  # Lets several effect entries that differ only in their move collapse into one
  # line. Wrapping the ids means the description lambdas need no special casing:
  # they call move_name as usual and get "A, B and C" back.
  class MoveGroup
    attr_reader :ids
    def initialize(ids)
      @ids = ids
    end
  end

  def move_name(id)
    return list(id.ids.map { |i| move_name(i) }) if id.is_a?(MoveGroup)
    data = GameData::Move.try_get(id.to_s.to_sym) rescue nil
    return data ? data.name : pretty(id)
  end

  def type_name(id)
    data = GameData::Type.try_get(id.to_s.to_sym) rescue nil
    return data ? data.name : pretty(id)
  end

  def ability_name(id)
    data = GameData::Ability.try_get(id.to_s.to_sym) rescue nil
    return data ? data.name : pretty(id)
  end

  def item_name(id)
    data = GameData::Item.try_get(id.to_s.to_sym) rescue nil
    return data ? data.name : pretty(id)
  end

  def species_name(id)
    data = GameData::Species.try_get(id.to_s.to_sym) rescue nil
    return data ? data.name : pretty(id)
  end

  def stat_name(id)
    data = GameData::Stat.try_get(id.to_s.to_sym) rescue nil
    return data ? data.name : pretty(id)
  end

  def status_name(id)
    case id.to_s.upcase
    when "SLEEP"     then return _INTL("sleep")
    when "POISON"    then return _INTL("poison")
    when "BURN"      then return _INTL("burn")
    when "PARALYSIS" then return _INTL("paralysis")
    when "FROZEN", "FREEZE" then return _INTL("freezing")
    when "CONFUSION" then return _INTL("confusion")
    end
    return pretty(id).downcase
  end

  # Joins a list of names with commas and a final "and".
  def list(names)
    names = names.compact.reject { |n| n.to_s.empty? }
    return "" if names.empty?
    return names[0] if names.length == 1
    return _INTL("{1} and {2}", names[0..-2].join(", "), names[-1])
  end

  # Formats a multiplier as a signed percentage, which reads far better than a
  # bare "x1.3" when scanning a long list.
  def mult(value)
    value = value.to_f
    return _INTL("no change") if value == 1.0
    pct = ((value - 1.0) * 100).round
    return (pct > 0) ? _INTL("+{1}%", pct) : _INTL("{1}%", pct)
  end

  def stages(value)
    value = value.to_i
    return _INTL("{1} stage(s)", value) if value.abs != 1
    return (value > 0) ? _INTL("1 stage") : _INTL("-1 stage")
  end

  def fraction(denominator)
    d = denominator.to_i
    return "" if d <= 0
    return _INTL("1/{1} max HP", d)
  end

  # Args that resolve to real moves, used by the many effects whose whole
  # argument list is just "these moves".
  def move_list(args)
    moves = args.select { |a| GameData::Move.try_get(a.to_s.to_sym) rescue false }
    moves = args if moves.empty?   # tolerate ids the registry doesn't know
    return list(moves.map { |m| move_name(m) })
  end

  #-----------------------------------------------------------------------------
  # The table. Keys match the names registered in Battle::FieldEffectsLibrary.
  #-----------------------------------------------------------------------------
  EFFECT_TEXT = {
    # --- Power -------------------------------------------------------------
    :move_boost         => ->(a) { _INTL("{1}: {2} power", FieldNotes.move_name(a[0]), FieldNotes.mult(a[1])) },
    :flag_boost         => ->(a) { _INTL("{1} moves: {2} power", FieldNotes.pretty(a[0]), FieldNotes.mult(a[1])) },
    :stab_field_boost   => ->(a) { _INTL("{1}-type users: {2} power", FieldNotes.type_name(a[0]), FieldNotes.mult(a[1])) },
    :echo_boost         => ->(a) { _INTL("Repeating the same move: {1} power each time", FieldNotes.mult(a[0])) },
    :pulse_boost        => ->(a) { _INTL("Pulse and aura moves: {1} power", FieldNotes.mult(a[0])) },
    :aura_boost         => ->(a) { _INTL("Aura moves: {1} power", FieldNotes.mult(a[0])) },
    :sound_boost        => ->(a) { _INTL("Sound moves: {1} power", FieldNotes.mult(a[0])) },
    :contact_boost      => ->(a) { _INTL("Contact moves: {1} power", FieldNotes.mult(a[0])) },
    :explosion_boost    => ->(a) { _INTL("Explosion moves: {1} power", FieldNotes.mult(a[0])) },

    # --- Typing ------------------------------------------------------------
    :type_add           => ->(a) { _INTL("{1} also counts as {2}-type", FieldNotes.move_name(a[0]), FieldNotes.type_name(a[1])) },
    :type_change        => ->(a) { _INTL("{1} becomes {2}-type", FieldNotes.move_name(a[0]), FieldNotes.type_name(a[1])) },
    :type_convert       => ->(a) { _INTL("All {1}-type moves become {2}-type", FieldNotes.type_name(a[0]), FieldNotes.type_name(a[1])) },
    :camouflage_type    => ->(a) { _INTL("Camouflage turns the user {1}-type", FieldNotes.type_name(a[0])) },
    :mimicry_type       => ->(a) { _INTL("Mimicry turns the user {1}-type", FieldNotes.type_name(a[0])) },
    :weather_ball_type  => ->(a) { _INTL("Weather Ball becomes {1}-type", FieldNotes.type_name(a[0])) },
    :terrain_pulse_type => ->(a) { _INTL("Terrain Pulse becomes {1}-type", FieldNotes.type_name(a[0])) },

    # --- Accuracy ----------------------------------------------------------
    :accuracy_set        => ->(a) { _INTL("{1}: accuracy set to {2}%", FieldNotes.move_name(a[0]), a[1]) },
    :accuracy_type_boost => ->(a) { _INTL("{1}-type moves: {2} accuracy", FieldNotes.type_name(a[0]), FieldNotes.mult(a[1])) },
    :accuracy_penalty    => ->(a) { _INTL("All moves: {1} accuracy", FieldNotes.mult(a[0])) },
    :always_hit          => ->(a) { _INTL("{1}: cannot miss", FieldNotes.move_list(a)) },
    :type_evasion        => ->(a) { _INTL("{1}-type Pokemon: {2} evasion", FieldNotes.type_name(a[0]), FieldNotes.mult(a[1])) },

    # --- Charging / targeting ----------------------------------------------
    :no_charge     => ->(a) { _INTL("{1}: no charging turn", FieldNotes.move_list(a)) },
    :force_charge  => ->(a) { _INTL("{1}: requires a charging turn", FieldNotes.move_list(a)) },
    :target_all    => ->(a) { _INTL("{1}: expanded to hit all opponents", FieldNotes.move_list(a)) },

    # --- Durations ---------------------------------------------------------
    :binding_boost       => ->(a) { _INTL("{1}: longer binding duration", FieldNotes.move_list(a)) },
    :effect_chance_boost => ->(a) { _INTL("{1}: doubled secondary effect chance", FieldNotes.move_list(a)) },
    :effect_duration     => ->(a) { _INTL("{1} lasts {2} turns", FieldNotes.move_name(a[0]), a[1]) },
    :terrain_extend      => ->(a) { _INTL("Terrain moves last {1} turns longer", a[0]) },

    # --- Healing -----------------------------------------------------------
    :heal_boost       => ->(a) { _INTL("{1}: increased healing", FieldNotes.move_list(a)) },
    :heal_reduce      => ->(a) { _INTL("{1}: reduced healing", FieldNotes.move_list(a)) },
    :ingrain_boost    => ->(_a) { _INTL("Ingrain restores more HP") },
    :aqua_ring_boost  => ->(_a) { _INTL("Aqua Ring restores more HP") },
    :leech_seed_boost => ->(_a) { _INTL("Leech Seed drains more HP") },

    # --- Stat changes from moves -------------------------------------------
    :speed_boost_move => ->(a) { _INTL("{1} also raises the user's Speed by {2}", FieldNotes.move_name(a[0]), FieldNotes.stages(a[1])) },
    :stat_boost_move  => ->(a) { _INTL("{1} also raises the user's {2} by {3}", FieldNotes.move_name(a[0]), FieldNotes.stat_name(a[1]), FieldNotes.stages(a[2])) },

    # --- Status ------------------------------------------------------------
    :add_status      => ->(a) { _INTL("{1}: can inflict {2} ({3}%)", FieldNotes.move_name(a[0]), FieldNotes.status_name(a[1]), a[2] || 30) },
    :add_burn        => ->(a) { _INTL("{1}: can inflict burn ({2}%)", FieldNotes.move_name(a[0]), a[1] || 30) },
    :add_paralysis   => ->(a) { _INTL("{1}: can inflict paralysis ({2}%)", FieldNotes.move_name(a[0]), a[1] || 30) },
    :add_poison      => ->(a) { _INTL("{1}: can inflict poison ({2}%)", FieldNotes.move_name(a[0]), a[1] || 30) },
    :add_freeze      => ->(a) { _INTL("{1}: can freeze ({2}%)", FieldNotes.move_name(a[0]), a[1] || 30) },
    :add_sleep       => ->(a) { _INTL("{1}: can induce sleep ({2}%)", FieldNotes.move_name(a[0]), a[1] || 30) },
    :flinch_boost    => ->(a) { _INTL("{1}: raised flinch chance", FieldNotes.move_list(a)) },
    :confusion_boost => ->(a) { _INTL("{1}: raised confusion chance", FieldNotes.move_list(a)) },
    :contact_status  => ->(a) { _INTL("Contact moves can inflict {1} ({2}%)", FieldNotes.status_name(a[0]), a[1] || 30) },

    # --- Crits -------------------------------------------------------------
    :crit_boost      => ->(a) { _INTL("{1}: raised critical hit rate", FieldNotes.move_list(a)) },
    :crit_type_boost => ->(a) { _INTL("{1}-type moves: +{2} critical hit stage", FieldNotes.type_name(a[0]), a[1] || 1) },
    :always_crit     => ->(a) { _INTL("{1}: always a critical hit", FieldNotes.move_list(a)) },

    # --- Recoil ------------------------------------------------------------
    :recoil_reduce => ->(a) { _INTL("Recoil damage reduced to {1}x", a[0]) },
    :recoil_boost  => ->(a) { _INTL("Recoil damage increased to {1}x", a[0]) },
    :no_recoil     => ->(a) { _INTL("{1}: no recoil", FieldNotes.move_list(a)) },

    # --- Priority / speed ---------------------------------------------------
    :priority_boost    => ->(a) { _INTL("{1}: +{2} priority", FieldNotes.move_name(a[0]), a[1] || 1) },
    :block_priority    => ->(_a) { _INTL("Increased-priority moves are blocked") },
    :speed_double      => ->(a) { _INTL("{1}-type Pokemon have doubled Speed", FieldNotes.type_name(a[0])) },
    :speed_halve       => ->(a) { _INTL("{1}-type Pokemon have halved Speed", FieldNotes.type_name(a[0])) },
    :speed_boost_entry => ->(a) { _INTL("{1}-type Pokemon gain {2} Speed on entry", FieldNotes.type_name(a[0]), FieldNotes.stages(a[1])) },

    # --- End of turn --------------------------------------------------------
    :end_turn_damage => ->(a) { _INTL("Every turn: {1} damage", FieldNotes.fraction(a[0])) },
    :end_turn_heal   => ->(a) { _INTL("Every turn: restores {1}", FieldNotes.fraction(a[0])) },
    :end_turn_status => ->(a) { _INTL("Every turn: {1}% chance of {2}", a[1] || 10, FieldNotes.status_name(a[0])) },

    # --- On entry -----------------------------------------------------------
    :entry_stat_boost => ->(a) { _INTL("{1}-type Pokemon gain {2} {3} on entry", FieldNotes.type_name(a[0]), FieldNotes.stages(a[2]), FieldNotes.stat_name(a[1])) },
    :entry_status     => ->(a) { _INTL("{1}-type Pokemon inflict {2} on entry", FieldNotes.type_name(a[1]), FieldNotes.status_name(a[0])) },

    # --- Battle start -------------------------------------------------------
    :begin_stat_boost        => ->(a) { _INTL("At battle start, everyone gains {1} {2}", FieldNotes.stages(a[1]), FieldNotes.stat_name(a[0])) },
    :begin_random_stat_boost => ->(a) { _INTL("At battle start, everyone gains {1} in a random stat", FieldNotes.stages(a[0])) },
    :begin_type_stat_boost   => ->(a) { _INTL("At battle start, {1}-type Pokemon gain {2} {3}", FieldNotes.type_name(a[0]), FieldNotes.stages(a[2]), FieldNotes.stat_name(a[1])) },

    # --- Hazards ------------------------------------------------------------
    :hazard_boost       => ->(a) { _INTL("{1}: {2} damage", FieldNotes.move_name(a[0]), FieldNotes.mult(a[1])) },
    :hazard_type_change => ->(a) { _INTL("{1} becomes {2}-type", FieldNotes.move_name(a[0]), FieldNotes.type_name(a[1])) },
    :hazard_immune      => ->(a) { _INTL("{1}: no effect here", FieldNotes.move_list(a)) },

    # --- Abilities / items --------------------------------------------------
    :grant_ability    => ->(a) { _INTL("Every Pokemon acts as if it had {1}", FieldNotes.ability_name(a[0])) },
    :suppress_ability => ->(a) { _INTL("{1} is suppressed", FieldNotes.ability_name(a[0])) },
    :ability_boost    => ->(a) { _INTL("{1}: {2} effect", FieldNotes.ability_name(a[0]), FieldNotes.mult(a[1])) },
    :item_boost       => ->(a) { _INTL("{1}: {2} effect", FieldNotes.item_name(a[0]), FieldNotes.mult(a[1])) },
    :item_block       => ->(a) { _INTL("{1} has no effect here", FieldNotes.item_name(a[0])) },

    # --- Failure / protection -----------------------------------------------
    :move_block        => ->(a) { _INTL("{1}: cannot be used here", FieldNotes.move_list(a)) },
    :type_block        => ->(a) { _INTL("{1}-type moves: fail here", FieldNotes.type_name(a[0])) },
    :move_immune       => ->(a) { _INTL("{1}: no effect here", FieldNotes.move_list(a)) },
    :damage_reduce     => ->(a) { _INTL("{1}-type damage taken: {2}", FieldNotes.type_name(a[0]), FieldNotes.mult(a[1])) },
    :explosion_protect => ->(_a) { _INTL("Explosion moves fail here") },
    :sound_block       => ->(_a) { _INTL("Sound moves are blocked") },
    :stat_block        => ->(_a) { _INTL("Stat changes are prevented") },
    :stat_protect      => ->(_a) { _INTL("Stats cannot be lowered by opponents") },

    # --- Gravity ------------------------------------------------------------
    :ground_flying => ->(_a) { _INTL("Flying-types and Levitate are grounded") },
    :no_jump       => ->(_a) { _INTL("Jumping moves cannot be used") },

    # --- Weather ------------------------------------------------------------
    :weather_boost => ->(a) { _INTL("In {1}, {2}-type moves: {3} power", FieldNotes.pretty(a[0]), FieldNotes.type_name(a[1]), FieldNotes.mult(a[2])) },
    :set_weather   => ->(a) { _INTL("Sets {1} when the field appears", FieldNotes.pretty(a[0])) },

    # --- Seeds --------------------------------------------------------------
    :activate_seed => ->(a) { _INTL("{1} activates here, raising {2} by {3}", FieldNotes.item_name(a[0]), FieldNotes.stat_name(a[1]), FieldNotes.stages(a[2])) },
    :terrain_seed  => ->(a) { _INTL("{1} activates here, raising {2} by {3}", FieldNotes.item_name(a[0]), FieldNotes.stat_name(a[1]), FieldNotes.stages(a[2])) },

    # --- Misc ---------------------------------------------------------------
    :nature_power_change => ->(a) { _INTL("Nature Power becomes {1}", FieldNotes.move_name(a[0])) },
    :nature_power_move   => ->(a) { _INTL("Nature Power becomes {1}", FieldNotes.move_name(a[0])) },
    :secret_power_effect => ->(_a) { _INTL("Secret Power has a field-specific effect") },
    :weight_modify       => ->(a) { _INTL("Weight counts as {1}x for weight-based moves", a[0]) },
    :contact_damage      => ->(a) { _INTL("Making contact costs the attacker {1}", FieldNotes.fraction(a[0])) },
    :form_change         => ->(a) { _INTL("{1} changes form here", FieldNotes.species_name(a[0])) },
    :type_stat_boost     => ->(a) { _INTL("{1}-type Pokemon: {2} {3}", FieldNotes.type_name(a[0]), FieldNotes.stages(a[2]), FieldNotes.stat_name(a[1])) },
    :pledge_effect       => ->(a) { _INTL("Pledge combination active: {1}", FieldNotes.pretty(a[0])) }
  }

  #-----------------------------------------------------------------------------
  # Renders one effect entry. Never raises: a bad lambda or unexpected args
  # degrades to the generic form rather than blanking the page.
  #-----------------------------------------------------------------------------
  def describe_effect(effect)
    return nil if effect.nil? || effect[:name].nil?
    lambda_for = EFFECT_TEXT[effect[:name]]
    args = effect[:args] || []
    if lambda_for
      begin
        text = lambda_for.call(args)
        return text if text && !text.empty?
      rescue StandardError
        # fall through to the generic form
      end
    end
    return generic_effect_text(effect[:name], args)
  end

  # Fallback for effects with no entry above. Reads as e.g.
  # "Special rule: super bounce (SPLASH, 2)".
  def generic_effect_text(name, args)
    label = name.to_s.tr("_", " ")
    return _INTL("Special rule: {1}", label) if args.nil? || args.empty?
    shown = args.reject { |a| a.to_s.length > 24 }   # drop embedded messages
    return _INTL("Special rule: {1}", label) if shown.empty?
    return _INTL("Special rule: {1} ({2})", label, shown.join(", "))
  end
end
