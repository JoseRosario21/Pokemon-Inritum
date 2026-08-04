#===============================================================================
# Advanced Battle AI - Settings
# Configure which features are enabled and skill thresholds
#===============================================================================
module AdvancedBattleAI
  #-----------------------------------------------------------------------------
  # Feature Toggles - Set to false to disable specific features
  #-----------------------------------------------------------------------------

  # Track opponent's revealed moves, abilities, and items for smarter predictions
  ENABLE_MOVE_MEMORY = true

  # Consider partner abilities in doubles (Flash Fire, Volt Absorb, etc.)
  ENABLE_TEAM_SYNERGY = true

  # Smart hazard layering and removal decisions
  ENABLE_ADVANCED_HAZARDS = true

  # Calculate turns until OHKO to decide setup vs attack
  ENABLE_SETUP_WINDOWS = true

  # Role-based switching decisions (SWEEPER, WALL, CLERIC, etc.)
  # Safeguards: KO checks, speed checks, turn count, hazard cost, replacement quality
  ENABLE_ROLE_SWITCHING = true

  # Advanced double battle tactics (focus fire, partner protection)
  ENABLE_DOUBLES_COORDINATION = true

  # Perish Song awareness, sacrifice plays, knowing when to let Pokemon faint
  ENABLE_SACRIFICE_AWARENESS = true

  # Adjust scoring for Field Effect plugin terrain/fields (requires Field Effect plugin)
  ENABLE_FIELD_INTEGRATION = true

  # Item & ability awareness (Choice lock exploitation, Sash/Sturdy, Intimidate, recovery items)
  ENABLE_ITEM_AWARENESS = true

  # Win condition identification - AI identifies how to win and plays toward it
  ENABLE_WIN_CONDITION = true

  # Move prediction - AI predicts what opponent will do and plays around it
  ENABLE_MOVE_PREDICTION = true

  #-----------------------------------------------------------------------------
  # Skill Thresholds - Minimum skill level for features to activate
  # Default Essentials skill ranges: 0=Wild, 1-31=Basic, 32-47=Medium, 48-99=High, 100+=Best
  #-----------------------------------------------------------------------------

  # Minimum skill to enable any advanced features (below this = default AI)
  SKILL_THRESHOLD_BASIC = 48

  # Skill level for move memory and basic prediction
  SKILL_THRESHOLD_MEMORY = 48

  # Skill level for role-based decisions
  SKILL_THRESHOLD_ROLES = 60

  # Skill level for setup window calculations
  SKILL_THRESHOLD_SETUP = 60

  # Skill level for double battle coordination
  SKILL_THRESHOLD_DOUBLES = 80

  # Skill level for item & ability awareness
  SKILL_THRESHOLD_ITEMS = 60

  # Skill level for all features (sacrifice plays, full prediction)
  SKILL_THRESHOLD_FULL = 100

  #-----------------------------------------------------------------------------
  # Score Modifiers - Adjust how much each feature affects move scoring
  #-----------------------------------------------------------------------------

  # Multiplier for moves that benefit from known opponent weaknesses
  MEMORY_PREDICTION_BONUS = 1.2

  # Score bonus for setup moves when setup window exists
  SETUP_WINDOW_BONUS = 20

  # Score penalty for setup moves when no safe window
  SETUP_RISKY_PENALTY = -15

  # Score bonus for focusing down a single target in doubles
  DOUBLES_FOCUS_FIRE_BONUS = 15

  # Score bonus for moves that activate partner's beneficial ability
  PARTNER_SYNERGY_BONUS = 25

  # Score bonus for pivot moves when switching is beneficial
  PIVOT_MOVE_BONUS = 20

  # Score threshold for hazard moves (only use if above this)
  HAZARD_SCORE_THRESHOLD = 80

  #-----------------------------------------------------------------------------
  # Role Detection Settings
  #-----------------------------------------------------------------------------

  # Stat ratio threshold for classifying as SWEEPER (Attack+SpAtk vs Defense+SpDef)
  SWEEPER_OFFENSIVE_RATIO = 1.3

  # Stat ratio threshold for classifying as WALL
  WALL_DEFENSIVE_RATIO = 1.3

  # Speed threshold percentile for SWEEPER classification (0.0-1.0)
  SWEEPER_SPEED_PERCENTILE = 0.6

  #-----------------------------------------------------------------------------
  # Score Modifiers (centralized for tuning)
  #-----------------------------------------------------------------------------
  SCORE_MINOR_BONUS    = 8
  SCORE_SMALL_BONUS    = 10
  SCORE_MEDIUM_BONUS   = 15
  SCORE_LARGE_BONUS    = 20
  SCORE_MAJOR_BONUS    = 25
  SCORE_MINOR_PENALTY  = -8
  SCORE_SMALL_PENALTY  = -10
  SCORE_MEDIUM_PENALTY = -15
  SCORE_LARGE_PENALTY  = -20
  SCORE_MAJOR_PENALTY  = -25

  #-----------------------------------------------------------------------------
  # Debug Settings
  #-----------------------------------------------------------------------------

  # Log AI decisions to console (for debugging)
  DEBUG_LOG_DECISIONS = true

  # Log memory updates to console
  DEBUG_LOG_MEMORY = false

  # Log scoring breakdowns to console
  DEBUG_LOG_SCORING = false
end

#===============================================================================
# New AI Skill Flags
# These can be added to trainer types in PBS to enable specific features
#===============================================================================
# AdvancedAI       - Enables all advanced AI features regardless of skill level
# MemorizeMoves    - Enables move memory system
# CoordinateDoubles - Enables double battle coordination
# SetupSmart       - Enables setup window calculations
# RoleAware        - Enables role-based switching
# SacrificeAware   - Enables sacrifice play awareness
# HazardSmart      - Enables advanced hazard management
# FieldAware       - Enables field effect integration
# WinConditionAware - Enables win condition identification and strategy
# PredictMoves     - Enables move prediction system
# ItemAware        - Enables item & ability awareness (Choice, Sash, Intimidate, recovery)

#===============================================================================
# Utility methods for checking if features are enabled
#===============================================================================
module AdvancedBattleAI
  module_function

  # Check if a feature is enabled for a given AI trainer
  def feature_enabled?(feature, ai_trainer)
    return false unless ai_trainer
    skill = ai_trainer.skill

    # Check for AdvancedAI flag which enables everything
    return true if ai_trainer.has_skill_flag?("AdvancedAI")

    case feature
    when :memory
      return false unless ENABLE_MOVE_MEMORY
      return true if ai_trainer.has_skill_flag?("MemorizeMoves")
      return skill >= SKILL_THRESHOLD_MEMORY

    when :team_synergy
      return false unless ENABLE_TEAM_SYNERGY
      return skill >= SKILL_THRESHOLD_DOUBLES

    when :hazards
      return false unless ENABLE_ADVANCED_HAZARDS
      return true if ai_trainer.has_skill_flag?("HazardSmart")
      return skill >= SKILL_THRESHOLD_BASIC

    when :setup_windows
      return false unless ENABLE_SETUP_WINDOWS
      return true if ai_trainer.has_skill_flag?("SetupSmart")
      return skill >= SKILL_THRESHOLD_SETUP

    when :roles
      return false unless ENABLE_ROLE_SWITCHING
      return true if ai_trainer.has_skill_flag?("RoleAware")
      return skill >= SKILL_THRESHOLD_ROLES

    when :doubles
      return false unless ENABLE_DOUBLES_COORDINATION
      return true if ai_trainer.has_skill_flag?("CoordinateDoubles")
      return skill >= SKILL_THRESHOLD_DOUBLES

    when :sacrifice
      return false unless ENABLE_SACRIFICE_AWARENESS
      return true if ai_trainer.has_skill_flag?("SacrificeAware")
      return skill >= SKILL_THRESHOLD_FULL

    when :field
      return false unless ENABLE_FIELD_INTEGRATION
      return true if ai_trainer.has_skill_flag?("FieldAware")
      return skill >= SKILL_THRESHOLD_BASIC

    when :win_condition
      return false unless ENABLE_WIN_CONDITION
      return true if ai_trainer.has_skill_flag?("WinConditionAware")
      return skill >= SKILL_THRESHOLD_SETUP

    when :move_prediction
      return false unless ENABLE_MOVE_PREDICTION
      return true if ai_trainer.has_skill_flag?("PredictMoves")
      return skill >= SKILL_THRESHOLD_FULL  # High skill requirement for prediction

    when :items
      return false unless ENABLE_ITEM_AWARENESS
      return true if ai_trainer.has_skill_flag?("ItemAware")
      return skill >= SKILL_THRESHOLD_ITEMS
    end

    return false
  end

  # Check if any advanced feature is enabled for this trainer
  def any_feature_enabled?(ai_trainer)
    return false unless ai_trainer
    return true if ai_trainer.has_skill_flag?("AdvancedAI")
    return ai_trainer.skill >= SKILL_THRESHOLD_BASIC
  end

  # Debug logging helper
  def log(message, category = :general)
    return unless $DEBUG
    case category
    when :decisions
      return unless DEBUG_LOG_DECISIONS
    when :memory
      return unless DEBUG_LOG_MEMORY
    when :scoring
      return unless DEBUG_LOG_SCORING
    end
    echoln "[AdvancedAI] #{message}"
  end

  #---------------------------------------------------------------------------
  # Shared Damage Estimation Utility
  # Core formula used by all damage estimation call sites.
  # Options hash supports :weather, :ability, :item, :adaptability, :move_flags
  #
  # This is intentionally a separate, simplified formula from the base AI's
  # Battle::AI::AIMove#rough_damage (Data/Scripts/011_Battle/005_AI/011_AIMove.rb)
  # rather than a duplicate of it - the two exist for different, non-overlapping
  # jobs:
  #   - rough_damage is bound to the single Battle::AI::AIMove instance's
  #     current (ai.user, ai.target, ai.move), set via ai.move.set_up(move).
  #     It's comprehensive (full ability/item/weather/terrain/field/screens/
  #     crit/badge/burn handling via the real damage-calc hook registry) but
  #     can only ever evaluate that one current combination - it can't safely
  #     be repointed at an arbitrary battler pair mid-scoring.
  #   - estimate_damage/_battler/_party take explicit battler or Pokemon
  #     arguments, so they can evaluate ANY pairing - switch-in candidates,
  #     an opponent's hypothetical move against the user, a benched party
  #     Pokemon with no live Battler at all (_party). That flexibility is
  #     why they use a simplified formula instead of the real hook registry.
  #
  # When a handler already has ai.move available for the AI's own current
  # (user, move, target), prefer ai.move.rough_damage over these - it's both
  # more accurate and already set up. Reach for estimate_damage_battler/
  # _party only when evaluating a battler pair outside that current context.
  #---------------------------------------------------------------------------

  # Core formula: stat-based, no battler objects required
  def estimate_damage(atk_stat, def_stat, level, base_power, move_type, move_category,
                      attacker_types, defender_types, options = {})
    return 0 if base_power <= 0 || def_stat <= 0
    base_power = 60 if base_power == 1  # Variable power moves

    damage = ((2 * level / 5.0 + 2) * base_power * atk_stat / def_stat / 50.0 + 2).floor

    # STAB
    stab = attacker_types.include?(move_type) ? 1.5 : 1.0
    # Adaptability makes STAB 2.0x
    if options[:ability] == :ADAPTABILITY && stab > 1.0
      stab = 2.0
    end
    damage = (damage * stab).floor

    # Type effectiveness
    type_mod = Effectiveness.calculate(move_type, *defender_types)
    damage = (damage * type_mod / Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER).floor

    # Weather modifiers
    weather = options[:weather]
    if weather
      case weather
      when :Sun, :HarshSun
        damage = (damage * 1.5).floor if move_type == :FIRE
        damage = (damage * 0.5).floor if move_type == :WATER
      when :Rain, :HeavyRain
        damage = (damage * 1.5).floor if move_type == :WATER
        damage = (damage * 0.5).floor if move_type == :FIRE
      end
    end

    # Ability modifiers
    ability = options[:ability]
    if ability
      case ability
      when :HUGEPOWER, :PUREPOWER
        damage = (damage * 2.0).floor if move_category == 0  # Physical
      when :TECHNICIAN
        damage = (damage * 1.5).floor if base_power <= 60
      when :STRONGJAW
        damage = (damage * 1.5).floor if options[:move_flags] && options[:move_flags][:biting]
      when :TOUGHCLAWS
        damage = (damage * 1.33).floor if options[:move_flags] && options[:move_flags][:contact]
      when :SHEERFORCE
        damage = (damage * 1.3).floor if options[:move_flags] && options[:move_flags][:secondary_effect]
      end
    end

    # Item modifiers
    item = options[:item]
    if item
      case item
      when :CHOICEBAND
        damage = (damage * 1.5).floor if move_category == 0  # Physical
      when :CHOICESPECS
        damage = (damage * 1.5).floor if move_category == 1  # Special
      when :LIFEORB
        damage = (damage * 1.3).floor
      end
    end

    return damage
  end

  # Entry point for in-battle battler objects
  def estimate_damage_battler(move_data, attacker_battler, defender_battler, battle = nil)
    return 0 unless move_data && move_data.power > 0

    if move_data.category == 0  # Physical
      atk = attacker_battler.attack
      dfn = defender_battler.defense
    else  # Special
      atk = attacker_battler.spatk
      dfn = defender_battler.spdef
    end

    options = {}

    # Weather
    if battle && battle.field && battle.field.weather
      options[:weather] = battle.field.weather
    end

    # Ability
    ability_id = attacker_battler.ability_id rescue nil
    options[:ability] = ability_id if ability_id

    # Item
    item_id = attacker_battler.item_id rescue nil
    options[:item] = item_id if item_id

    # Move flags
    move_flags = {}
    if move_data.respond_to?(:flags)
      flags = move_data.flags
      move_flags[:contact] = flags.include?("Contact") if flags
      move_flags[:biting] = flags.include?("Bite") if flags
    end
    # Check for secondary effect (addlEffect > 0)
    if move_data.respond_to?(:addlEffect)
      move_flags[:secondary_effect] = (move_data.addlEffect || 0) > 0
    end
    options[:move_flags] = move_flags

    attacker_types = attacker_battler.types rescue [:NORMAL]
    defender_types = defender_battler.types rescue [:NORMAL]

    return estimate_damage(
      atk, dfn, attacker_battler.level, move_data.power, move_data.type,
      move_data.category, attacker_types, defender_types, options
    )
  end

  # Entry point for party Pokemon objects (used by team preview, switching)
  def estimate_damage_party(move_data, attacker_pkmn, defender_pkmn)
    return 0 unless move_data && move_data.power > 0

    if move_data.category == 0  # Physical
      atk = attacker_pkmn.attack
      dfn = defender_pkmn.defense
    else  # Special
      atk = attacker_pkmn.spatk
      dfn = defender_pkmn.spdef
    end
    dfn = [dfn, 1].max

    options = {}

    # Ability from party Pokemon
    ability_id = attacker_pkmn.ability_id rescue nil
    options[:ability] = ability_id if ability_id

    # Item from party Pokemon
    item_id = attacker_pkmn.item_id rescue nil
    options[:item] = item_id if item_id

    # Move flags
    move_flags = {}
    if move_data.respond_to?(:flags)
      flags = move_data.flags
      move_flags[:contact] = flags.include?("Contact") if flags
      move_flags[:biting] = flags.include?("Bite") if flags
    end
    if move_data.respond_to?(:addlEffect)
      move_flags[:secondary_effect] = (move_data.addlEffect || 0) > 0
    end
    options[:move_flags] = move_flags

    attacker_types = attacker_pkmn.types rescue [:NORMAL]
    defender_types = defender_pkmn.types rescue [:NORMAL]

    return estimate_damage(
      atk, dfn, attacker_pkmn.level, move_data.power, move_data.type,
      move_data.category, attacker_types, defender_types, options
    )
  end

  #---------------------------------------------------------------------------
  # Module-level utility methods (moved from global scope)
  #---------------------------------------------------------------------------

  def count_positive_stat_stages(ai_battler)
    return 0 unless ai_battler && ai_battler.battler
    count = 0
    [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
      stage = ai_battler.stages[stat] || 0
      count += stage if stage > 0
    end
    return count
  end

  def should_avoid_switching?(battler, ai)
    return true unless battler && ai
    ai_battler = ai.battlers[battler.index]
    return false unless ai_battler
    # Don't switch if we have significant stat boosts
    if count_positive_stat_stages(ai_battler) >= 2
      log("Avoiding switch: has +2 or more stat boosts", :decisions)
      return true
    end
    # Don't switch if trapped
    if battler.effects[PBEffects::Trapping] > 0 ||
       battler.effects[PBEffects::MeanLook] > 0 ||
       battler.effects[PBEffects::JawLock] > 0
      return true
    end
    return false
  end

  def best_move_damage(battler, opponent)
    best = 0
    battler.moves.each do |m|
      next unless m && m.damagingMove?
      move_data = GameData::Move.try_get(m.id)
      next unless move_data
      dmg = estimate_damage_battler(move_data, battler, opponent)
      best = dmg if dmg > best
    end
    return best
  end

  def calculate_stealth_rock_value(user, ai, battle)
    return 0 unless ai
    total_value = 0
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      next if opp.hasActiveAbility?(:MAGICGUARD)
      next if opp.hasActiveItem?(:HEAVYDUTYBOOTS)
      type_mod = Effectiveness.calculate(:ROCK, *opp.types)
      damage_fraction = type_mod / 8.0
      if damage_fraction >= 0.5
        total_value += 30
      elsif damage_fraction >= 0.25
        total_value += 20
      elsif damage_fraction >= 0.125
        total_value += 10
      else
        total_value += 3
      end
    end
    remaining = count_opponent_remaining_pokemon(user, battle) - battle.pbGetOpposingIndicesInOrder(user.index).length
    total_value += remaining * 12
    return total_value
  end

  def count_opponent_remaining_pokemon(user, battle)
    count = 0
    if battle.opponent
      battle.opponent.each do |trainer|
        trainer.party.each { |p| count += 1 if p && p.able? }
      end
    end
    return [count, 6].min
  end

  def count_grounded_opponents(user, ai, battle)
    count = 0
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      next if opp.airborne?
      count += 1
    end
    return count
  end

  def calculate_hazard_entry_damage_fraction(pkmn, side)
    return 0.0 unless pkmn && side
    if pkmn.respond_to?(:hasActiveItem?)
      return 0.0 if pkmn.hasActiveItem?(:HEAVYDUTYBOOTS)
    elsif pkmn.respond_to?(:item)
      return 0.0 if pkmn.item == :HEAVYDUTYBOOTS
    end
    if pkmn.respond_to?(:hasActiveAbility?)
      return 0.0 if pkmn.hasActiveAbility?(:MAGICGUARD)
    elsif pkmn.respond_to?(:ability)
      return 0.0 if pkmn.ability == :MAGICGUARD
    end
    fraction = 0.0
    types = pkmn.types
    if side.effects[PBEffects::StealthRock]
      type_mod = Effectiveness.calculate(:ROCK, *types)
      fraction += type_mod / (Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER * 8.0)
    end
    spikes = side.effects[PBEffects::Spikes] || 0
    if spikes > 0
      is_flying = types.include?(:FLYING)
      has_levitate = false
      if pkmn.respond_to?(:hasActiveAbility?)
        has_levitate = pkmn.hasActiveAbility?(:LEVITATE)
      elsif pkmn.respond_to?(:ability)
        has_levitate = pkmn.ability == :LEVITATE
      end
      unless is_flying || has_levitate
        case spikes
        when 1 then fraction += 1.0 / 8.0
        when 2 then fraction += 1.0 / 6.0
        else        fraction += 1.0 / 4.0
        end
      end
    end
    return fraction
  end

  def count_remaining_pokemon(battle, battler_index)
    party = battle.pbParty(battler_index)
    return 0 unless party
    party.count { |p| p && p.able? }
  end
end
