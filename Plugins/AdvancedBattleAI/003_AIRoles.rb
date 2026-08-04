#===============================================================================
# Advanced Battle AI - Pokemon Role System
# Classifies Pokemon into strategic roles to influence AI decisions
#===============================================================================
module Battle::AI::Roles
  # Role definitions with their characteristics
  SWEEPER = :sweeper           # Fast offensive Pokemon
  PHYSICAL_WALL = :phys_wall   # High Defense tank
  SPECIAL_WALL = :spec_wall    # High Sp.Def tank
  MIXED_WALL = :mixed_wall     # Balanced defensive
  CLERIC = :cleric             # Healing/status support
  HAZARD_SETTER = :hazard_set  # Entry hazard focus
  HAZARD_REMOVER = :hazard_rem # Defog/Rapid Spin
  PIVOT = :pivot               # U-turn/Volt Switch users
  SETUP_SWEEPER = :setup_sweep # Needs setup to sweep
  REVENGE_KILLER = :revenge    # Priority/scarf users
  STALLBREAKER = :stallbreak   # Taunt/status offense
  WEATHER_SETTER = :weather    # Auto-weather abilities
  SCREEN_SETTER = :screens     # Light Screen/Reflect
  UTILITY = :utility           # General support

  # Role priorities for switching decisions (higher = switch in earlier)
  ROLE_SWITCH_PRIORITY = {
    HAZARD_SETTER => 90,   # Lead with hazards
    SCREEN_SETTER => 85,   # Set up screens early
    WEATHER_SETTER => 80,  # Establish weather
    PIVOT => 70,           # Safe switch-ins
    PHYSICAL_WALL => 60,   # Tank hits
    SPECIAL_WALL => 60,
    MIXED_WALL => 55,
    CLERIC => 50,          # Keep team healthy
    STALLBREAKER => 45,
    SETUP_SWEEPER => 40,   # Save for late game setup
    HAZARD_REMOVER => 35,  # Remove when needed
    REVENGE_KILLER => 30,  # Clean up weakened foes
    SWEEPER => 20,         # Preserve for sweeping
    UTILITY => 50
  }

  # Roles that should avoid early sacrifice
  PRESERVE_ROLES = [SWEEPER, SETUP_SWEEPER, REVENGE_KILLER, CLERIC]

  # Roles that can be sacrificed for advantage
  EXPENDABLE_ROLES = [HAZARD_SETTER, SCREEN_SETTER, PIVOT, UTILITY]
end

#===============================================================================
# Role Detection for Battlers
#===============================================================================
class Battle::AI::AIBattler
  attr_reader :detected_role
  attr_reader :secondary_roles

  #-----------------------------------------------------------------------------
  # Initialize role detection
  #-----------------------------------------------------------------------------
  alias advanced_ai_roles_init initialize
  def initialize(ai, battler_index)
    advanced_ai_roles_init(ai, battler_index)
    @detected_role = nil
    @secondary_roles = []
    detect_role if @battler
  end

  #-----------------------------------------------------------------------------
  # Detect the primary role of this Pokemon
  #-----------------------------------------------------------------------------
  def detect_role
    return unless @battler
    @secondary_roles = []

    # Check for role-defining abilities first
    role = detect_role_from_ability
    if role
      @detected_role = role
      detect_secondary_roles
      log_detected_role
      return
    end

    # Check for role-defining moves
    role = detect_role_from_moves
    if role
      @detected_role = role
      detect_secondary_roles
      log_detected_role
      return
    end

    # Fall back to stat-based role detection
    @detected_role = detect_role_from_stats
    detect_secondary_roles
    log_detected_role
  end

  # Logs the detected role to Data/debuglog.txt (when battle logging is on)
  # so role classification is visible alongside the rest of the turn-by-turn
  # AI decision trace, not just in the player-only pbAdvancedAITestRoles screen.
  def log_detected_role
    return unless @battler
    label = role_to_string(@detected_role)
    if @secondary_roles && !@secondary_roles.empty?
      secondary = @secondary_roles.map { |r| role_to_string(r) }.join(", ")
      label += " (secondary: #{secondary})"
    end
    PBDebug.log("[AI] #{@battler.pbThis} (#{index}) role: #{label}")
  end

  #-----------------------------------------------------------------------------
  # Detect role from ability
  #-----------------------------------------------------------------------------
  def detect_role_from_ability
    return nil unless @battler.ability

    ability_id = @battler.ability_id

    # A Pokemon carrying an explicit screen move is a screen setter first,
    # even if it also has an incidentally-weather-setting ability (e.g. Snow
    # Warning enabling its own Aurora Veil) - the move choice is the more
    # deliberate signal, and it should take priority over the generic
    # weather-setter classification below.
    return Battle::AI::Roles::SCREEN_SETTER if @battler.moves.compact.any? { |m| is_screen_move?(m) }

    # Weather setters
    weather_abilities = [:DROUGHT, :DRIZZLE, :SANDSTREAM, :SNOWWARNING, :DESOLATELAND, :PRIMORDIALSEA, :DELTASTREAM]
    return Battle::AI::Roles::WEATHER_SETTER if weather_abilities.include?(ability_id)

    # Intimidate/defensive abilities suggest wall
    defensive_abilities = [:INTIMIDATE, :UNAWARE, :MARVELSCALE, :MULTISCALE, :REGENERATOR]
    if defensive_abilities.include?(ability_id)
      return detect_wall_type
    end

    # Speed boosting abilities suggest sweeper
    speed_abilities = [:SPEEDBOOST, :SWIFTSWIM, :CHLOROPHYLL, :SANDRUSH, :SLUSHRUSH]
    return Battle::AI::Roles::SWEEPER if speed_abilities.include?(ability_id)

    # Priority abilities suggest revenge killer
    priority_abilities = [:GALEWINGS, :PRANKSTER, :TRIAGE]
    return Battle::AI::Roles::REVENGE_KILLER if priority_abilities.include?(ability_id)

    return nil
  end

  #-----------------------------------------------------------------------------
  # Detect role from moveset
  #-----------------------------------------------------------------------------
  def detect_role_from_moves
    moves = @battler.moves.compact

    # Check for hazard setter
    hazard_moves = moves.select { |m| is_hazard_move?(m) }
    if hazard_moves.length >= 1
      @secondary_roles.push(Battle::AI::Roles::HAZARD_SETTER)
    end

    # Check for hazard remover
    removal_moves = moves.select { |m| is_removal_move?(m) }
    if removal_moves.length >= 1
      @secondary_roles.push(Battle::AI::Roles::HAZARD_REMOVER)
    end

    # Check for pivot
    pivot_moves = moves.select { |m| is_pivot_move?(m) }
    if pivot_moves.length >= 1
      @secondary_roles.push(Battle::AI::Roles::PIVOT)
      # If has both pivot and hazards, probably a lead
      return Battle::AI::Roles::HAZARD_SETTER if hazard_moves.length >= 1
    end

    # Check for setup sweeper
    setup_moves = moves.select { |m| is_setup_move?(m) }
    if setup_moves.length >= 1
      @secondary_roles.push(Battle::AI::Roles::SETUP_SWEEPER)
    end

    # Check for screens
    screen_moves = moves.select { |m| is_screen_move?(m) }
    if screen_moves.length >= 1
      return Battle::AI::Roles::SCREEN_SETTER
    end

    # Check for cleric
    cleric_moves = moves.select { |m| is_cleric_move?(m) }
    if cleric_moves.length >= 1
      return Battle::AI::Roles::CLERIC
    end

    # Check for stallbreaker (Taunt + offensive)
    has_taunt = moves.any? { |m| m.function_code == "DisableTargetStatusMoves" }
    has_offensive = moves.any? { |m| m.category != 2 && m.power > 0 }
    if has_taunt && has_offensive
      return Battle::AI::Roles::STALLBREAKER
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Detect role from stats
  #-----------------------------------------------------------------------------
  def detect_role_from_stats
    stats = {
      hp: @battler.totalhp,
      atk: @battler.attack,
      def: @battler.defense,
      spa: @battler.spatk,
      spd: @battler.spdef,
      spe: @battler.speed
    }

    # Calculate offensive vs defensive ratio
    offensive = [stats[:atk], stats[:spa]].max
    defensive = stats[:def] + stats[:spd]
    offensive_ratio = offensive.to_f / (defensive / 2.0)

    # Check for sweeper (high offensive, good speed)
    if offensive_ratio >= AdvancedBattleAI::SWEEPER_OFFENSIVE_RATIO && stats[:spe] >= 80
      return Battle::AI::Roles::SWEEPER
    end

    # Check for wall
    if offensive_ratio <= (1.0 / AdvancedBattleAI::WALL_DEFENSIVE_RATIO)
      return detect_wall_type
    end

    # Check for setup sweeper (good offensive but slow)
    if offensive >= 100 && stats[:spe] < 70
      return Battle::AI::Roles::SETUP_SWEEPER
    end

    # Default to utility
    return Battle::AI::Roles::UTILITY
  end

  #-----------------------------------------------------------------------------
  # Determine wall type
  #-----------------------------------------------------------------------------
  def detect_wall_type
    def_stat = @battler.defense
    spd_stat = @battler.spdef

    if def_stat >= spd_stat * 1.3
      return Battle::AI::Roles::PHYSICAL_WALL
    elsif spd_stat >= def_stat * 1.3
      return Battle::AI::Roles::SPECIAL_WALL
    else
      return Battle::AI::Roles::MIXED_WALL
    end
  end

  #-----------------------------------------------------------------------------
  # Detect secondary roles
  #-----------------------------------------------------------------------------
  def detect_secondary_roles
    return unless @battler
    moves = @battler.moves.compact

    # Already added some in detect_role_from_moves, check for more
    unless @secondary_roles.include?(Battle::AI::Roles::HAZARD_SETTER)
      if moves.any? { |m| is_hazard_move?(m) }
        @secondary_roles.push(Battle::AI::Roles::HAZARD_SETTER)
      end
    end

    unless @secondary_roles.include?(Battle::AI::Roles::HAZARD_REMOVER)
      if moves.any? { |m| is_removal_move?(m) }
        @secondary_roles.push(Battle::AI::Roles::HAZARD_REMOVER)
      end
    end

    unless @secondary_roles.include?(Battle::AI::Roles::PIVOT)
      if moves.any? { |m| is_pivot_move?(m) }
        @secondary_roles.push(Battle::AI::Roles::PIVOT)
      end
    end

    # Check for revenge killer (priority moves)
    if moves.any? { |m| m.priority > 0 && m.power > 0 }
      @secondary_roles.push(Battle::AI::Roles::REVENGE_KILLER) unless @secondary_roles.include?(Battle::AI::Roles::REVENGE_KILLER)
    end
  end

  #-----------------------------------------------------------------------------
  # Move classification helpers
  #-----------------------------------------------------------------------------
  def is_hazard_move?(move)
    hazard_functions = [
      "AddSpikesToFoeSide",
      "AddToxicSpikesToFoeSide",
      "AddStealthRocksToFoeSide",
      "AddStickyWebToFoeSide"
    ]
    return hazard_functions.include?(move.function_code)
  end

  def is_removal_move?(move)
    removal_functions = [
      "RemoveUserBindingAndEntryHazards",  # Rapid Spin
      "LowerTargetEvasion1RemoveSideEffects" # Defog
    ]
    return removal_functions.include?(move.function_code)
  end

  def is_pivot_move?(move)
    pivot_functions = [
      "SwitchOutUserDamagingMove",  # U-turn, Volt Switch, Flip Turn
      "SwitchOutUserStatusMove",     # Teleport, Parting Shot
      "SwitchOutUserPassOnEffects"   # Baton Pass
    ]
    return pivot_functions.include?(move.function_code)
  end

  def is_setup_move?(move)
    setup_functions = [
      "RaiseUserAttack1", "RaiseUserAttack2", "RaiseUserAttack3",
      "RaiseUserDefense1", "RaiseUserDefense2", "RaiseUserDefense3",
      "RaiseUserSpAtk1", "RaiseUserSpAtk2", "RaiseUserSpAtk3",
      "RaiseUserSpDef1", "RaiseUserSpDef2", "RaiseUserSpDef3",
      "RaiseUserSpeed1", "RaiseUserSpeed2", "RaiseUserSpeed3",
      "RaiseUserAtkSpAtk1", "RaiseUserAtkDef1", "RaiseUserAtkSpd1",
      "RaiseUserDefSpDef1", "RaiseUserMainStats1",
      "MaxUserAttackLoseHalfOfTotalHP",  # Belly Drum
      "RaiseUserAtkSpAtk1Or2InSun"       # Growth
    ]
    return setup_functions.include?(move.function_code)
  end

  def is_screen_move?(move)
    screen_functions = [
      "StartWeakenPhysicalDamageAgainstUserSide",  # Reflect
      "StartWeakenSpecialDamageAgainstUserSide",   # Light Screen
      "StartWeakenDamageAgainstUserSideIfHail"     # Aurora Veil
    ]
    return screen_functions.include?(move.function_code)
  end

  def is_cleric_move?(move)
    cleric_functions = [
      "CureUserPartyStatus",     # Aromatherapy, Heal Bell
      "HealUserPositionNextTurn", # Wish
      "HealAllyOrUser"           # Pollen Puff (healing ally)
    ]
    return cleric_functions.include?(move.function_code)
  end

  #-----------------------------------------------------------------------------
  # Role utility methods
  #-----------------------------------------------------------------------------

  # Check if this role should be preserved (not sacrificed)
  def should_preserve?
    return Battle::AI::Roles::PRESERVE_ROLES.include?(@detected_role)
  end

  # Check if this role can be sacrificed for advantage
  def can_sacrifice?
    return Battle::AI::Roles::EXPENDABLE_ROLES.include?(@detected_role)
  end

  # Get switch priority for this role
  def role_switch_priority
    return Battle::AI::Roles::ROLE_SWITCH_PRIORITY[@detected_role] || 50
  end

  # Check if this Pokemon has a specific role (primary or secondary)
  def has_role?(role)
    return true if @detected_role == role
    return @secondary_roles.include?(role)
  end

  # Refresh role detection (call when moveset/ability changes)
  def refresh_role
    detect_role
  end
end

#===============================================================================
# Helper methods for AI to query roles
#===============================================================================
class Battle::AI
  # Get the role of a battler by index
  def get_role(battler_index)
    return nil unless @battlers[battler_index]
    return @battlers[battler_index].detected_role
  end

  # Get battlers with a specific role on a side
  def get_battlers_with_role(side, role)
    result = []
    @battlers.each_with_index do |b, i|
      next unless b && @battle.battlers[i]
      next unless @battle.opposes?(i) == (side == 1)
      result.push(b) if b.has_role?(role)
    end
    return result
  end

  # Check if the team has a specific role covered
  def team_has_role?(side, role)
    return !get_battlers_with_role(side, role).empty?
  end

  # Get the best Pokemon to switch to based on role priorities
  def get_best_switch_for_role(party, needed_role)
    best = nil
    best_priority = -1

    party.each_with_index do |pkmn, i|
      next unless pkmn && pkmn.able?
      next if @battle.pbFindBattler(i, @user.side)

      # Create temporary AIBattler to analyze
      temp_battler = create_temp_ai_battler(pkmn)
      next unless temp_battler

      if temp_battler.has_role?(needed_role)
        priority = temp_battler.role_switch_priority
        if priority > best_priority
          best = i
          best_priority = priority
        end
      end
    end

    return best
  end

  # Helper to create temporary AI battler mock for party Pokemon.
  # Returns a lightweight object with has_role? and role_switch_priority methods.
  # Only used by get_best_switch_for_role.
  def create_temp_ai_battler(pkmn)
    return nil unless pkmn
    role = estimate_pokemon_role(pkmn)
    priority = Battle::AI::Roles::ROLE_SWITCH_PRIORITY[role] || 50
    mock = Object.new
    mock.define_singleton_method(:has_role?) { |r| role == r }
    mock.define_singleton_method(:role_switch_priority) { priority }
    return mock
  end

  # Estimate role for a party Pokemon without a battler
  def estimate_pokemon_role(pkmn)
    return nil unless pkmn

    # Check moves for role indicators
    pkmn.moves.each do |move|
      next unless move
      move_data = GameData::Move.try_get(move.id)
      next unless move_data

      # Hazard setter
      if ["AddSpikesToFoeSide", "AddToxicSpikesToFoeSide", "AddStealthRocksToFoeSide"].include?(move_data.function_code)
        return Battle::AI::Roles::HAZARD_SETTER
      end

      # Pivot
      if ["SwitchOutUserDamagingMove", "SwitchOutUserStatusMove"].include?(move_data.function_code)
        return Battle::AI::Roles::PIVOT
      end
    end

    # Fall back to stat-based
    stats = pkmn.baseStats
    offensive = [stats[:ATTACK], stats[:SPECIAL_ATTACK]].max
    defensive = stats[:DEFENSE] + stats[:SPECIAL_DEFENSE]

    if offensive > defensive * 0.7
      return Battle::AI::Roles::SWEEPER
    else
      return Battle::AI::Roles::UTILITY
    end
  end
end

#===============================================================================
# Screen Setter Lead Priority
# A Pokemon built for the Screen Setter role (has Reflect/Light Screen/Aurora
# Veil in its moveset) should strongly prefer opening with its screen rather
# than attacking or setting up - UNLESS it can secure a kill this turn, in
# which case ending a Pokemon outright is worth more than a screen.
#
# This wraps the base engine's existing screen-move scoring (which already
# handles HP-awareness, foe-type matching, and Light Clay) rather than
# replacing it, so that logic stays intact and this only adds the
# role/kill-awareness layer on top.
#===============================================================================
["StartWeakenPhysicalDamageAgainstUserSide",
 "StartWeakenSpecialDamageAgainstUserSide",
 "StartWeakenDamageAgainstUserSideIfHail"].each do |screen_function_code|
  original_screen_handler = Battle::AI::Handlers::MoveEffectScore[screen_function_code]
  next unless original_screen_handler

  Battle::AI::Handlers::MoveEffectScore.add(screen_function_code,
    proc { |score, move, user, ai, battle|
      score = original_screen_handler.call(score, move, user, ai, battle)
      next score unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
      next score unless user.has_role?(Battle::AI::Roles::SCREEN_SETTER)

      # Don't boost the screen if this Pokemon can already secure a kill this
      # turn - ending a Pokemon outright is worth more than banking a screen.
      # Simplification: only checks this Pokemon's own moves, not whether a
      # partner could clean up a second target next turn with no reprisal -
      # that fuller doubles-coordination case isn't modeled here.
      can_secure_kill = false
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        user.battler.moves.each do |m|
          next unless m && m.damagingMove?
          move_data = GameData::Move.try_get(m.id)
          next unless move_data && move_data.power > 0
          est_dmg = AdvancedBattleAI.estimate_damage_battler(move_data, user.battler, opp, battle)
          if est_dmg >= opp.hp
            can_secure_kill = true
            break
          end
        end
        break if can_secure_kill
      end
      next score if can_secure_kill

      # No kill available - this Pokemon's job right now is to screen for the
      # team. Bigger bonus as the opening lead, and again if Light Clay makes
      # the screen last long enough to matter.
      lead_bonus = 30
      lead_bonus += 15 if user.battler.turnCount == 0
      lead_bonus += 10 if user.has_active_item?(:LIGHTCLAY)
      score += lead_bonus
      AdvancedBattleAI.log("Screen Setter: no kill available, prioritizing support role (+#{lead_bonus})", :scoring)

      next score
    }
  )
end
