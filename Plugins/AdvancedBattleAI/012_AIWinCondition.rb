#===============================================================================
# Advanced Battle AI - Win Condition Identification
# Identifies how the AI can win and plays toward that goal
#===============================================================================

module AdvancedBattleAI
  # Win condition types
  module WinCondition
    SWEEP = :sweep           # One Pokemon can sweep if set up
    STALL = :stall           # Outlast with hazards/recovery/toxic
    MOMENTUM = :momentum     # Keep switch advantage with pivots
    WALLBREAK = :wallbreak   # Break walls first, then sweep
    OFFENSIVE = :offensive   # Raw offensive pressure
    UNKNOWN = :unknown       # Couldn't determine
  end
end

#===============================================================================
# Win Condition Analyzer
# Analyzes team composition and battle state to determine win condition
#===============================================================================
class Battle::AI
  attr_reader :win_condition
  attr_reader :win_condition_pokemon  # Index of Pokemon that enables the win

  #-----------------------------------------------------------------------------
  # Initialize win condition analysis
  #-----------------------------------------------------------------------------
  alias advanced_ai_wincond_initialize initialize
  def initialize(battle)
    advanced_ai_wincond_initialize(battle)
    @win_condition = AdvancedBattleAI::WinCondition::UNKNOWN
    @win_condition_pokemon = nil
    @win_condition_analyzed = false
  end

  #-----------------------------------------------------------------------------
  # Analyze win condition (called once per battle, early on)
  #-----------------------------------------------------------------------------
  def analyze_win_condition
    return if @win_condition_analyzed
    return unless AdvancedBattleAI.feature_enabled?(:win_condition, @trainer)

    @win_condition_analyzed = true

    # Get AI side — find the first non-player battler's side
    ai_battler_index = nil
    @battle.battlers.each do |b|
      next unless b && !b.fainted? && !b.pbOwnedByPlayer?
      ai_battler_index = b.index
      break
    end
    ai_battler_index ||= 1

    # Get our party
    our_party = @battle.pbParty(ai_battler_index)
    return unless our_party && our_party.length > 0

    # Analyze team composition
    team_analysis = analyze_team_composition(our_party)

    # Determine primary win condition
    @win_condition = determine_win_condition(team_analysis)
    @win_condition_pokemon = find_win_condition_pokemon(our_party, team_analysis)

    AdvancedBattleAI.log("Win condition: #{@win_condition}, key Pokemon: #{@win_condition_pokemon}", :decisions)
  end

  #-----------------------------------------------------------------------------
  # Analyze team composition
  #-----------------------------------------------------------------------------
  def analyze_team_composition(party)
    analysis = {
      sweepers: [],
      walls: [],
      setup_sweepers: [],
      pivots: [],
      hazard_setters: [],
      clerics: [],
      stallbreakers: [],
      total_recovery: 0,
      total_priority: 0,
      total_setup: 0,
      total_hazards: 0,
      average_speed: 0,
      speed_control: false  # Tailwind, Sticky Web, Thunder Wave, etc.
    }

    total_speed = 0
    party.each_with_index do |pkmn, idx|
      next unless pkmn && pkmn.able?

      # Classify Pokemon
      role = classify_pokemon_role(pkmn)
      case role
      when :sweeper
        analysis[:sweepers].push(idx)
      when :setup_sweeper
        analysis[:setup_sweepers].push(idx)
        analysis[:total_setup] += 1
      when :physical_wall, :special_wall, :mixed_wall
        analysis[:walls].push(idx)
      when :pivot
        analysis[:pivots].push(idx)
      when :hazard_setter
        analysis[:hazard_setters].push(idx)
      when :cleric
        analysis[:clerics].push(idx)
      when :stallbreaker
        analysis[:stallbreakers].push(idx)
      end

      # Count move types
      pkmn.moves.each do |move|
        next unless move
        move_data = GameData::Move.try_get(move.id)
        next unless move_data

        # Recovery moves
        if is_recovery_move?(move_data)
          analysis[:total_recovery] += 1
        end

        # Priority moves
        if move_data.priority > 0 && move_data.power > 0
          analysis[:total_priority] += 1
        end

        # Setup moves
        if is_setup_move?(move_data)
          analysis[:total_setup] += 1
        end

        # Hazard moves
        if is_hazard_move?(move_data)
          analysis[:total_hazards] += 1
        end

        # Speed control
        if is_speed_control_move?(move_data)
          analysis[:speed_control] = true
        end
      end

      total_speed += pkmn.speed
    end

    able_count = party.count { |p| p && p.able? }
    analysis[:average_speed] = able_count > 0 ? total_speed / able_count : 0

    return analysis
  end

  #-----------------------------------------------------------------------------
  # Determine win condition from team analysis
  #-----------------------------------------------------------------------------
  def determine_win_condition(analysis)
    # Stall: Multiple walls + recovery + hazards
    if analysis[:walls].length >= 2 && analysis[:total_recovery] >= 2 && analysis[:total_hazards] >= 1
      return AdvancedBattleAI::WinCondition::STALL
    end

    # Sweep: Has setup sweeper + support (screens, hazards, speed control)
    if analysis[:setup_sweepers].length >= 1
      has_support = analysis[:hazard_setters].length >= 1 || analysis[:speed_control]
      if has_support
        return AdvancedBattleAI::WinCondition::SWEEP
      end
    end

    # Momentum: Multiple pivots
    if analysis[:pivots].length >= 2
      return AdvancedBattleAI::WinCondition::MOMENTUM
    end

    # Wallbreak: Has stallbreakers + sweepers
    if analysis[:stallbreakers].length >= 1 && analysis[:sweepers].length >= 1
      return AdvancedBattleAI::WinCondition::WALLBREAK
    end

    # Offensive: Fast team with priority
    if analysis[:average_speed] >= 90 || analysis[:total_priority] >= 2
      return AdvancedBattleAI::WinCondition::OFFENSIVE
    end

    # Default based on what we have most of
    if analysis[:setup_sweepers].length >= 1
      return AdvancedBattleAI::WinCondition::SWEEP
    elsif analysis[:walls].length >= 2
      return AdvancedBattleAI::WinCondition::STALL
    else
      return AdvancedBattleAI::WinCondition::OFFENSIVE
    end
  end

  #-----------------------------------------------------------------------------
  # Find the key Pokemon that enables the win condition
  #-----------------------------------------------------------------------------
  def find_win_condition_pokemon(party, analysis)
    case @win_condition
    when AdvancedBattleAI::WinCondition::SWEEP
      # The setup sweeper is key
      return analysis[:setup_sweepers].first if analysis[:setup_sweepers].length > 0
      return analysis[:sweepers].first if analysis[:sweepers].length > 0

    when AdvancedBattleAI::WinCondition::STALL
      # The Pokemon with most recovery/longevity is key
      best_idx = nil
      best_score = 0
      party.each_with_index do |pkmn, idx|
        next unless pkmn && pkmn.able?
        score = 0
        pkmn.moves.each do |move|
          next unless move
          move_data = GameData::Move.try_get(move.id)
          next unless move_data
          score += 20 if is_recovery_move?(move_data)
          score += 10 if is_status_move?(move_data)
        end
        # Bulk matters for stall
        score += (pkmn.defense + pkmn.spdef) / 20
        if score > best_score
          best_score = score
          best_idx = idx
        end
      end
      return best_idx

    when AdvancedBattleAI::WinCondition::MOMENTUM
      # The best pivot is key
      return analysis[:pivots].first if analysis[:pivots].length > 0

    when AdvancedBattleAI::WinCondition::WALLBREAK
      # The stallbreaker is key for breaking, then the sweeper for cleaning
      return analysis[:stallbreakers].first if analysis[:stallbreakers].length > 0
      return analysis[:sweepers].first if analysis[:sweepers].length > 0

    when AdvancedBattleAI::WinCondition::OFFENSIVE
      # The fastest/strongest Pokemon is key
      best_idx = nil
      best_power = 0
      party.each_with_index do |pkmn, idx|
        next unless pkmn && pkmn.able?
        power = [pkmn.attack, pkmn.spatk].max + pkmn.speed
        if power > best_power
          best_power = power
          best_idx = idx
        end
      end
      return best_idx
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Check if a Pokemon can sweep remaining opponents
  #-----------------------------------------------------------------------------
  def can_pokemon_sweep?(pkmn, opponents)
    return false unless pkmn && pkmn.able?

    # Check if this Pokemon can KO all remaining opponents
    opponents.each do |opp_idx|
      opp = @battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Check if we have a move that can deal significant damage
      can_threaten = false
      pkmn.moves.each do |move|
        next unless move
        move_data = GameData::Move.try_get(move.id)
        next unless move_data && move_data.power > 0

        type_mod = Effectiveness.calculate(move_data.type, *opp.types)
        effective_power = move_data.power * type_mod / 100.0

        # STAB bonus
        if pkmn.types.include?(move_data.type)
          effective_power *= 1.5
        end

        # Can threaten if effective power is decent
        if effective_power >= 60
          can_threaten = true
          break
        end
      end

      return false unless can_threaten
    end

    return true
  end

  #-----------------------------------------------------------------------------
  # Update win condition mid-battle (when Pokemon faint)
  #-----------------------------------------------------------------------------
  def update_win_condition
    return unless @win_condition_analyzed

    # Check if our win condition Pokemon fainted
    if @win_condition_pokemon
      ai_idx = nil
      @battle.battlers.each { |b| next unless b && !b.fainted? && !b.pbOwnedByPlayer?; ai_idx = b.index; break }
      ai_idx ||= 1
      our_party = @battle.pbParty(ai_idx)
      if our_party && our_party[@win_condition_pokemon]
        pkmn = our_party[@win_condition_pokemon]
        if !pkmn.able?
          # Win condition Pokemon fainted - need to re-evaluate
          AdvancedBattleAI.log("Win condition Pokemon fainted, re-analyzing", :decisions)
          @win_condition_analyzed = false
          analyze_win_condition
        end
      end
    end

    # Check if we can now sweep (opponent weakened)
    opponents = @battle.pbGetOpposingIndicesInOrder(0)
    remaining_opponents = opponents.count { |i| @battle.battlers[i] && !@battle.battlers[i].fainted? }

    if remaining_opponents <= 2
      # Late game - check if any Pokemon can clean up
      ai_idx = nil
      @battle.battlers.each { |b| next unless b && !b.fainted? && !b.pbOwnedByPlayer?; ai_idx = b.index; break }
      ai_idx ||= 1
      our_party = @battle.pbParty(ai_idx)
      our_party.each_with_index do |pkmn, idx|
        next unless pkmn && pkmn.able?
        if can_pokemon_sweep?(pkmn, opponents)
          @win_condition = AdvancedBattleAI::WinCondition::SWEEP
          @win_condition_pokemon = idx
          AdvancedBattleAI.log("Late game: #{pkmn.name} can sweep", :decisions)
          break
        end
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Helper: Classify Pokemon role (simplified version for party analysis)
  #-----------------------------------------------------------------------------
  def classify_pokemon_role(pkmn)
    return :unknown unless pkmn

    # Check moves first
    has_setup = false
    has_pivot = false
    has_hazards = false
    has_recovery = false
    has_stallbreak = false  # Taunt, Trick, etc.

    pkmn.moves.each do |move|
      next unless move
      move_data = GameData::Move.try_get(move.id)
      next unless move_data

      has_setup = true if is_setup_move?(move_data)
      has_pivot = true if is_pivot_move?(move_data)
      has_hazards = true if is_hazard_move?(move_data)
      has_recovery = true if is_recovery_move?(move_data)
      has_stallbreak = true if is_stallbreak_move?(move_data)
    end

    # Stat-based classification (thresholds aligned with 003_AIRoles.rb)
    offensive = [pkmn.attack, pkmn.spatk].max
    defensive = (pkmn.defense + pkmn.spdef) / 2
    speed = pkmn.speed

    # Check ability for role hints
    pkmn_ability = pkmn.ability_id rescue nil

    # Setup sweeper
    if has_setup && offensive >= 80
      return :setup_sweeper
    end

    # Pivot
    if has_pivot
      return :pivot
    end

    # Hazard setter
    if has_hazards
      return :hazard_setter
    end

    # Stallbreaker
    if has_stallbreak && offensive >= 80
      return :stallbreaker
    end

    # Walls (aligned with 003: def > off * 1.3, Intimidate users lean wall-ish)
    wall_threshold = 1.3
    wall_threshold = 1.1 if pkmn_ability == :INTIMIDATE
    if defensive >= offensive * wall_threshold
      if pkmn.defense > pkmn.spdef * 1.3
        return :physical_wall
      elsif pkmn.spdef > pkmn.defense * 1.3
        return :special_wall
      else
        return :mixed_wall
      end
    end

    # Cleric
    if has_recovery && defensive >= 80
      return :cleric
    end

    # Sweeper (aligned: off >= 90, speed >= 75)
    if offensive >= 90 && speed >= 75
      return :sweeper
    end

    return :utility
  end

  #-----------------------------------------------------------------------------
  # Move classification helpers
  #-----------------------------------------------------------------------------
  def is_setup_move?(move_data)
    setup_functions = [
      "RaiseUserAttack1", "RaiseUserAttack2", "RaiseUserAttack3",
      "RaiseUserDefense1", "RaiseUserDefense2",
      "RaiseUserSpAtk1", "RaiseUserSpAtk2", "RaiseUserSpAtk3",
      "RaiseUserSpDef1", "RaiseUserSpDef2",
      "RaiseUserSpeed1", "RaiseUserSpeed2",
      "RaiseUserAtkSpAtk1", "RaiseUserAtkDef1", "RaiseUserDefSpDef1",
      "RaiseUserMainStats1", "MaxUserAttackLoseHalfOfTotalHP",
      "RaiseUserAtkSpAtk1Or2InSun", "RaiseUserAtk1Spd2",
      "StartRaiseUserAtk1", "RaiseUserAtkSpd1"
    ]
    return setup_functions.include?(move_data.function_code)
  end

  def is_pivot_move?(move_data)
    pivot_functions = [
      "SwitchOutUserDamagingMove",  # U-turn, Volt Switch, Flip Turn
      "SwitchOutUserStatusMove",     # Teleport, Parting Shot
      "SwitchOutUserPassOnEffects"   # Baton Pass
    ]
    return pivot_functions.include?(move_data.function_code)
  end

  def is_hazard_move?(move_data)
    hazard_functions = [
      "AddSpikesToFoeSide", "AddToxicSpikesToFoeSide",
      "AddStealthRocksToFoeSide", "AddStickyWebToFoeSide"
    ]
    return hazard_functions.include?(move_data.function_code)
  end

  def is_recovery_move?(move_data)
    recovery_functions = [
      "HealUserHalfOfTotalHP", "HealUserHalfOfTotalHPLoseFlyingTypeThisTurn",
      "HealUserDependingOnWeather", "HealUserFullyAndFallAsleep",
      "HealUserPositionNextTurn", "HealUserByTargetAttackLowerTargetAttack1"
    ]
    return recovery_functions.include?(move_data.function_code)
  end

  def is_status_move?(move_data)
    return move_data.category == 2  # Status category
  end

  def is_speed_control_move?(move_data)
    speed_control_functions = [
      "StartUserSideDoubleSpeed",     # Tailwind
      "AddStickyWebToFoeSide",        # Sticky Web
      "LowerTargetSpeed1",            # Electroweb, Icy Wind
      "LowerTargetSpeed2",
      "ParalyzeTarget",               # Thunder Wave, Stun Spore
      "StartSlowerBattlersActFirst"   # Trick Room
    ]
    return speed_control_functions.include?(move_data.function_code)
  end

  def is_stallbreak_move?(move_data)
    stallbreak_functions = [
      "DisableTargetStatusMoves",      # Taunt
      "DisableTargetUsingSameMoveConsecutively",  # Torment
      "UserTargetSwapItems",           # Trick, Switcheroo
      "UserTakesTargetItem",           # Thief, Covet
      "DisableTargetHealingMoves"      # Heal Block
    ]
    return stallbreak_functions.include?(move_data.function_code)
  end
end

#===============================================================================
# Win Condition Score Modifiers
# Adjust move scoring based on win condition
#===============================================================================

#-------------------------------------------------------------------------------
# Preserve win condition Pokemon
#-------------------------------------------------------------------------------
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_preserve_win_condition,
  proc { |battler, reserves, ai, battle|
    next false unless ai.win_condition_pokemon

    # Check if this battler is our win condition Pokemon
    # battler is an AIBattler wrapper, need .battler to get the actual Battler
    party_idx = battler.battler.pokemonIndex rescue nil
    next false unless party_idx

    if party_idx == ai.win_condition_pokemon
      # Don't switch out the win condition unless critically low
      if battler.hp > battler.totalhp * 0.25
        AdvancedBattleAI.log("Preserving win condition Pokemon", :decisions)
        next true
      end
    end

    next false
  }
)

#-------------------------------------------------------------------------------
# Prioritize setup for sweep win condition
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_win_condition_setup,
  proc { |score, move, user, ai, battle|
    # Analyze win condition if not done yet
    ai.analyze_win_condition if ai.respond_to?(:analyze_win_condition)

    next score unless ai.win_condition == AdvancedBattleAI::WinCondition::SWEEP

    # Check if this is our win condition Pokemon
    party_idx = user.battler.pokemonIndex rescue nil
    next score unless party_idx && party_idx == ai.win_condition_pokemon

    # Boost setup moves for the win condition Pokemon
    move_data = GameData::Move.try_get(move.id) rescue nil
    if move_data && ai.is_setup_move?(move_data)
      # Only boost if we don't have boosts yet
      current_boosts = (user.stages[:ATTACK] || 0) + (user.stages[:SPECIAL_ATTACK] || 0) rescue 0
      if current_boosts < 2
        score += 25
        AdvancedBattleAI.log("Win condition: boosting setup for sweeper", :scoring)
      end
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Prioritize hazards for stall win condition
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_win_condition_stall,
  proc { |score, move, user, ai, battle|
    ai.analyze_win_condition if ai.respond_to?(:analyze_win_condition)

    next score unless ai.win_condition == AdvancedBattleAI::WinCondition::STALL

    move_data = GameData::Move.try_get(move.id) rescue nil
    next score unless move_data

    # Boost hazards
    if ai.is_hazard_move?(move_data)
      score += 15
      AdvancedBattleAI.log("Win condition: boosting hazards for stall", :scoring)
    end

    # Boost recovery
    if ai.is_recovery_move?(move_data)
      score += 10
      AdvancedBattleAI.log("Win condition: boosting recovery for stall", :scoring)
    end

    # Boost status moves (Toxic, Will-o-Wisp)
    if move_data.function_code == "PoisonTarget" ||
       move_data.function_code == "BadlyPoisonTarget" ||
       move_data.function_code == "BurnTarget"
      score += 15
      AdvancedBattleAI.log("Win condition: boosting status for stall", :scoring)
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Prioritize pivot moves for momentum win condition
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_win_condition_momentum,
  proc { |score, move, user, ai, battle|
    ai.analyze_win_condition if ai.respond_to?(:analyze_win_condition)

    next score unless ai.win_condition == AdvancedBattleAI::WinCondition::MOMENTUM

    move_data = GameData::Move.try_get(move.id) rescue nil
    next score unless move_data

    # Boost pivot moves
    if ai.is_pivot_move?(move_data)
      # Check if we have a good switch target
      reserves = battle.pbParty(user.index)
      has_good_switch = reserves.any? { |p| p && p.able? && p != user.battler.pokemon }
      if has_good_switch
        score += 20
        AdvancedBattleAI.log("Win condition: boosting pivot for momentum", :scoring)
      end
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Prioritize wallbreaking for wallbreak win condition
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_win_condition_wallbreak,
  proc { |score, move, user, target, ai, battle|
    ai.analyze_win_condition if ai.respond_to?(:analyze_win_condition)

    next score unless ai.win_condition == AdvancedBattleAI::WinCondition::WALLBREAK

    # Check if target is a wall (high defenses, low offense)
    target_offensive = [target.attack, target.spatk].max
    target_defensive = (target.defense + target.spdef) / 2

    if target_defensive > target_offensive * 1.2
      # Target is a wall - prioritize breaking it
      if move.damagingMove?
        # Boost super effective moves against walls
        type_mod = Effectiveness.calculate(move.type, *target.types)
        if Effectiveness.super_effective?(type_mod)
          score += 20
          AdvancedBattleAI.log("Win condition: boosting wallbreaking move", :scoring)
        end
      end

      # Boost Taunt against walls
      move_data = GameData::Move.try_get(move.id)
      if move_data && ai.is_stallbreak_move?(move_data)
        score += 25
        AdvancedBattleAI.log("Win condition: boosting Taunt vs wall", :scoring)
      end
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Win condition is analyzed lazily when handlers call ai.analyze_win_condition
# No need for method aliasing - the handlers trigger analysis when needed
#-------------------------------------------------------------------------------
