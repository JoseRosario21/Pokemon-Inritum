#===============================================================================
# Advanced Battle AI - Setup Move Optimization
# Smart timing for stat-boosting moves
#===============================================================================

#===============================================================================
# Setup Window Calculator
# Determines how many safe turns for setup
#===============================================================================
class Battle::AI
  # Calculate the setup window for a battler
  def calculate_full_setup_window(user, battle)
    return { turns: 0, safe: false } unless user.battler

    min_turns = 999
    max_incoming = 0

    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Calculate max damage this opponent can deal
      opp.moves.each do |move|
        next unless move && move.damagingMove?

        # Estimate damage
        damage = estimate_damage_to_user(user, opp, move)
        max_incoming = [max_incoming, damage].max
      end
    end

    return { turns: 5, safe: true } if max_incoming == 0

    # Calculate turns until KO
    turns = (user.hp.to_f / max_incoming).ceil

    # Check if we can survive to use a setup move
    can_survive = turns >= 2

    # Check for priority threats
    has_priority_threat = false
    if @memory
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        if @memory.has_shown_priority?(opp_idx)
          has_priority_threat = true
          break
        end
      end
    end

    # Priority reduces effective window if we're low HP
    if has_priority_threat && user.hp_fraction < 0.5
      turns = [turns - 1, 0].max
    end

    return {
      turns: [turns, 5].min,
      safe: can_survive && turns >= 2,
      has_priority_threat: has_priority_threat,
      max_incoming: max_incoming
    }
  end

  # Estimate damage from a specific move — delegates to shared utility
  def estimate_damage_to_user(user, attacker, move)
    return 0 unless move && move.damagingMove?
    move_data = GameData::Move.try_get(move.id)
    return 0 unless move_data
    AdvancedBattleAI.estimate_damage_battler(move_data, attacker, user.battler, @battle)
  end

  # Calculate sweep potential after setup
  def calculate_sweep_potential(user, stat_boost_stages)
    return 0 unless user.battler

    potential = 0
    boost_multiplier = get_stat_stage_multiplier(stat_boost_stages)

    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = @battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Check if we can KO after boost
      user.battler.moves.each do |move|
        next unless move && move.damagingMove?

        base_damage = estimate_damage_from_user(user, opp, move)
        boosted_damage = (base_damage * boost_multiplier).to_i

        if boosted_damage >= opp.hp
          potential += 30  # Can KO
        elsif boosted_damage >= opp.hp * 0.5
          potential += 15  # Can 2HKO
        end
      end
    end

    return potential
  end

  # Estimate damage user would deal — delegates to shared utility
  def estimate_damage_from_user(user, target, move)
    return 0 unless move && move.damagingMove?
    move_data = GameData::Move.try_get(move.id)
    return 0 unless move_data
    AdvancedBattleAI.estimate_damage_battler(move_data, user.battler, target, @battle)
  end

  # Get stat multiplier for stage
  def get_stat_stage_multiplier(stages)
    multipliers = {
      -6 => 0.25, -5 => 0.29, -4 => 0.33, -3 => 0.4, -2 => 0.5, -1 => 0.67,
      0 => 1.0, 1 => 1.5, 2 => 2.0, 3 => 2.5, 4 => 3.0, 5 => 3.5, 6 => 4.0
    }
    return multipliers[[stages, 6].min] || 1.0
  end
end

#===============================================================================
# Enhanced Setup Move Scoring
# More sophisticated setup timing
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_setup_timing,
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:setup_windows, ai.trainer)

    # Identify setup moves
    setup_patterns = [
      /RaiseUserAttack/, /RaiseUserDefense/, /RaiseUserSpAtk/,
      /RaiseUserSpDef/, /RaiseUserSpeed/, /RaiseUserMainStats/,
      /RaiseUserAtkSpAtk/, /RaiseUserAtkDef/, /RaiseUserDefSpDef/
    ]

    is_setup = setup_patterns.any? { |p| move.function_code.match?(p) }
    next score unless is_setup

    # Get setup window
    window = ai.calculate_full_setup_window(user, battle)

    if window[:safe] && window[:turns] >= 2
      # Safe setup window (reduced from SETUP_WINDOW_BONUS to avoid stacking)
      score += 15

      # Extra bonus for longer windows
      if window[:turns] >= 3
        score += 8
      end

      # Calculate sweep potential
      # Determine stages this move gives
      stages = move.function_code.match?(/\d$/) ? move.function_code[-1].to_i : 1
      sweep_potential = ai.calculate_sweep_potential(user, stages)

      if sweep_potential >= 50
        score += 15
        AdvancedBattleAI.log("High sweep potential after setup", :scoring)
      elsif sweep_potential >= 30
        score += 8
      end

    elsif window[:turns] <= 1
      # Dangerous to set up
      score += AdvancedBattleAI::SETUP_RISKY_PENALTY

      # Extra penalty if priority threat
      if window[:has_priority_threat]
        score -= 10
        AdvancedBattleAI.log("Setup risky: priority threat", :scoring)
      end
    end

    # Consider current stat stages
    current_stages = count_positive_stat_stages(ai.battlers[user.index])
    if current_stages >= 4
      # Diminishing returns
      score -= 20
      AdvancedBattleAI.log("Already heavily boosted", :scoring)
    elsif current_stages >= 2
      # Still beneficial but less so
      score -= 5
    end

    next score
  }
)

#===============================================================================
# Belly Drum Special Handling
# Only use when safe and can sweep
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("MaxUserAttackLoseHalfOfTotalHP",
  proc { |score, move, user, ai, battle|
    # Can't use if HP too low
    next Battle::AI::MOVE_USELESS_SCORE if user.hp <= user.totalhp / 2

    next score unless AdvancedBattleAI.feature_enabled?(:setup_windows, ai.trainer)

    # Calculate window
    window = ai.calculate_full_setup_window(user, battle)

    # Belly Drum is all-or-nothing
    if window[:safe] && window[:turns] >= 2
      # Check if we can actually sweep after
      sweep_potential = ai.calculate_sweep_potential(user, 6)  # Max attack

      if sweep_potential >= 60
        score = Battle::AI::MOVE_BASE_SCORE + 40
        AdvancedBattleAI.log("Belly Drum: high sweep potential", :scoring)
      elsif sweep_potential >= 40
        score = Battle::AI::MOVE_BASE_SCORE + 20
      else
        score = Battle::AI::MOVE_BASE_SCORE - 20  # Not worth it
      end
    else
      score = Battle::AI::MOVE_USELESS_SCORE  # Too risky
    end

    # Check for Sitrus Berry / healing
    if user.hasActiveItem?(:SITRUSBERRY)
      score += 20  # Berry helps recover HP loss
    end

    # Check for priority moves (important after Belly Drum)
    has_priority = user.battler.moves.any? { |m| m && m.priority > 0 && m.damagingMove? }
    if has_priority
      score += 25
      AdvancedBattleAI.log("Belly Drum + priority", :scoring)
    end

    next score
  }
)

#===============================================================================
# Shell Smash Special Handling
# Powerful but risky
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("RaiseUserAtkSpAtk2LowerUserDefSpDef1",
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:setup_windows, ai.trainer)

    window = ai.calculate_full_setup_window(user, battle)

    # Shell Smash is aggressive - need to sweep
    sweep_potential = ai.calculate_sweep_potential(user, 2)  # +2 offenses

    if window[:turns] >= 2 && sweep_potential >= 40
      score = Battle::AI::MOVE_BASE_SCORE + 35
      AdvancedBattleAI.log("Shell Smash: good sweep potential", :scoring)

      # Bonus if we have White Herb
      if user.hasActiveItem?(:WHITEHERB)
        score += 15  # Negates defense drops
      end
    elsif window[:turns] >= 1
      # Risky but might work
      score = Battle::AI::MOVE_BASE_SCORE + 10
    else
      # Too dangerous
      score = Battle::AI::MOVE_BASE_SCORE - 20
    end

    # Big penalty if already used (diminishing returns + def drops stack)
    if user.stages[:ATTACK] >= 2 || user.stages[:SPECIAL_ATTACK] >= 2
      score -= 30
    end

    next score
  }
)

#===============================================================================
# Dragon Dance / Quiver Dance Handling
# Balanced setup moves
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("RaiseUserAtkSpd1",
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:setup_windows, ai.trainer)

    window = ai.calculate_full_setup_window(user, battle)

    if window[:safe]
      score += AdvancedBattleAI::SETUP_WINDOW_BONUS

      # Dragon Dance is great for sweeping
      sweep_potential = ai.calculate_sweep_potential(user, 1)

      if sweep_potential >= 30
        score += 15
      end

      # Check Trick Room — Dragon Dance speed boost is counterproductive under TR
      trick_room_active = (battle.field.effects[PBEffects::TrickRoom] > 0 rescue false)
      if trick_room_active
        score -= 20
        AdvancedBattleAI.log("Dragon Dance: penalty under Trick Room", :scoring)
      else
        # Extra value if Speed boost makes us faster
        user_speed = user.speed * 1.5  # After DD
        will_outspeed = true
        battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
          opp = battle.battlers[opp_idx]
          next unless opp && !opp.fainted?
          if opp.speed >= user_speed
            will_outspeed = false
            break
          end
        end

        if will_outspeed && user.speed < 100  # Slow mon benefits more
          score += 10
          AdvancedBattleAI.log("Dragon Dance: Speed tier breakthrough", :scoring)
        end
      end
    else
      score -= 10
    end

    next score
  }
)

#===============================================================================
# Baton Pass Awareness
# Consider passing boosts
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_baton_pass,
  proc { |score, move, user, ai, battle|
    next score unless move.function_code == "SwitchOutUserPassOnEffects"
    next score unless AdvancedBattleAI.feature_enabled?(:setup_windows, ai.trainer)

    # Check if user has boosts worth passing
    current_stages = count_positive_stat_stages(ai.battlers[user.index])

    if current_stages >= 2
      score += 20 + (current_stages * 5)
      AdvancedBattleAI.log("Baton Pass: #{current_stages} stages to pass", :scoring)

      # Check if we have a good recipient
      party = battle.pbParty(user.index)
      has_good_recipient = false

      party.each do |pkmn|
        next unless pkmn && pkmn.able?
        # Check if it's a sweeper that would benefit
        role = ai.estimate_pokemon_role(pkmn)
        if role == Battle::AI::Roles::SWEEPER || role == Battle::AI::Roles::SETUP_SWEEPER
          has_good_recipient = true
          break
        end
      end

      if has_good_recipient
        score += 15
      end
    elsif current_stages <= 0
      # No boosts to pass
      score -= 20
    end

    # Also consider Substitute
    if user.effects[PBEffects::Substitute] > 0
      score += 15  # Pass the sub
    end

    next score
  }
)

#===============================================================================
# Substitute Timing
# Use Substitute strategically
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("UserMakesSubstitute",
  proc { |score, move, user, ai, battle|
    # Can't use if too low HP
    hp_cost = user.totalhp / 4
    next Battle::AI::MOVE_USELESS_SCORE if user.hp <= hp_cost
    next Battle::AI::MOVE_USELESS_SCORE if user.effects[PBEffects::Substitute] > 0

    next score unless AdvancedBattleAI.feature_enabled?(:setup_windows, ai.trainer)

    window = ai.calculate_full_setup_window(user, battle)

    if window[:safe] && window[:turns] >= 2
      # Substitute + setup is powerful
      if user.has_move_with_function?(/RaiseUser/)
        score += 25
        AdvancedBattleAI.log("Substitute for setup protection", :scoring)
      end
    end

    # Check for status protection
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Substitute blocks status moves
      opp.moves.each do |m|
        next unless m && m.statusMove?
        if m.function_code.match?(/Paralyze|Poison|Burn|Sleep|Confuse/)
          score += 10
          break
        end
      end
    end

    # Penalty if opponent has sound/infiltrator
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      if opp.hasActiveAbility?(:INFILTRATOR)
        score -= 15
        break
      end
      # Check for sound-based moves
      opp.moves.each do |m|
        next unless m
        if m.soundMove?
          score -= 10
          break
        end
      end
    end

    next score
  }
)
