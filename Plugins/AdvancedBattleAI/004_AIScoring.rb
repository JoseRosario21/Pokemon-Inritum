#===============================================================================
# Advanced Battle AI - Enhanced Move Scoring
# Adds new handlers for smarter move selection
#===============================================================================

#===============================================================================
# CRITICAL: Best Damage Move Handler
# This handler ALWAYS runs for skilled trainers and heavily favors the
# move with the highest effective damage (considering STAB and type effectiveness)
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_best_damage_move,
  proc { |score, move, user, target, ai, battle|
    # Only for skilled trainers
    next score unless ai.trainer && ai.trainer.skill >= 48
    next score unless move.damagingMove?

    # Get target types safely
    target_types = []
    if target.battler && target.battler.types
      target_types = target.battler.types
    elsif target.respond_to?(:types) && target.types
      target_types = target.types
    else
      target_types = [:NORMAL]
    end

    # Calculate this move's effective damage
    move_type = move.type rescue :NORMAL
    move_power = (move.move.power rescue 0) || 0
    next score if move_power == 0

    type_mod = Effectiveness.calculate(move_type, *target_types) rescue 1.0
    has_stab = (user.battler.pbHasType?(move_type) rescue false)
    effective_power = move_power * (has_stab ? 1.5 : 1.0) * type_mod

    # Find the best move available
    best_power = 0
    user.battler.moves.each do |m|
      next unless m
      next unless (m.damagingMove? rescue false)
      m_power = (m.power rescue 0) || 0
      next if m_power == 0
      m_type_mod = Effectiveness.calculate(m.type, *target_types) rescue 1.0
      m_stab = (user.battler.pbHasType?(m.type) rescue false)
      m_eff = m_power * (m_stab ? 1.5 : 1.0) * m_type_mod
      best_power = m_eff if m_eff > best_power
    end

    # Apply bonuses/penalties based on comparison
    if best_power > 0 && effective_power > 0
      ratio = effective_power / best_power
      old_score = score
      if ratio >= 0.95
        # This IS the best move - big bonus!
        score += 40
      elsif ratio >= 0.7
        # Decent - no change
      elsif ratio >= 0.5
        # Significantly worse - moderate penalty
        score -= 30
      else
        # Much worse - heavy penalty
        score -= 60
      end
      if score != old_score
        PBDebug.log_score_change(score - old_score,
          "effective power vs best available move (ratio #{(ratio * 100).round}%)")
      end
    end

    # Super effective bonus
    if Effectiveness.super_effective?(type_mod)
      old_score = score
      score += 25
      PBDebug.log_score_change(score - old_score, "advanced: super effective")
    end

    # STAB bonus
    if has_stab
      old_score = score
      score += 15
      PBDebug.log_score_change(score - old_score, "advanced: STAB")
    end

    next score
  }
)

#===============================================================================
# Memory-Based Prediction Handler
# Adjusts score based on known opponent moves and abilities
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_memory_prediction,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:memory, ai.trainer)
    next score unless ai.memory

    # Get known information about target
    known_moves = ai.memory.get_known_moves(target.index)
    known_ability = ai.memory.get_known_ability(target.index)

    # Bonus for moves that exploit known weaknesses
    if known_ability
      ability_data = GameData::Ability.try_get(known_ability)
      if ability_data
        # Bonus for Mold Breaker-like abilities against known defensive abilities
        mold_breaker_functions = ["IgnoreTargetAbility", "UserMakeContactIgnoreTargetAbility"]
        if mold_breaker_functions.include?(move.function_code)
          defensive_abilities = [:STURDY, :MULTISCALE, :SHADOWSHIELD, :DISGUISE, :ICEFACE]
          if defensive_abilities.include?(known_ability)
            score += 15
            AdvancedBattleAI.log("Mold Breaker bonus vs #{known_ability}", :scoring)
          end
        end

        # Penalty for status moves against Magic Bounce
        if move.statusMove? && known_ability == :MAGICBOUNCE
          score -= 30
          AdvancedBattleAI.log("Magic Bounce penalty for status move", :scoring)
        end

        # Bonus for Ground moves against known Levitate (if we have Gravity/Mold Breaker)
        if move.type == :GROUND && known_ability == :LEVITATE
          if user.has_move_with_function?("StartGravity") || user.has_active_ability?(:MOLDBREAKER)
            score += 10
            AdvancedBattleAI.log("Ground move bypasses known Levitate", :scoring)
          end
        end
      end
    end

    # Predict likely switches if target is low HP and we've seen other Pokemon
    if target.hp_fraction < 0.3 && ai.memory.estimate_remaining_pokemon(target.side) > 0
      # Prefer moves with good coverage
      if move.damagingMove?
        score += 5  # Small bonus for attacking a likely switching target
        AdvancedBattleAI.log("Pressure a likely-switching low HP target", :scoring)
      end
    end

    # Penalty for predictable moves if opponent has shown counters
    if known_moves.length > 0
      # Check if opponent has shown priority moves - be careful with setup
      if ai.memory.has_shown_priority?(target.index)
        if user.has_role?(Battle::AI::Roles::SETUP_SWEEPER)
          if move.function_code.include?("RaiseUser")
            score -= 10  # Risky to set up against priority users
            AdvancedBattleAI.log("Setup penalty vs priority user", :scoring)
          end
        end
      end

      # Check if opponent has shown recovery - boost our pressure
      if ai.memory.has_shown_recovery?(target.index)
        # Prefer strong attacks over chip damage
        if move.damagingMove? && move.move.power >= 80
          score += 8
          AdvancedBattleAI.log("Strong attack vs known recovery user", :scoring)
        end
        # Boost Taunt
        if move.function_code == "DisableTargetStatusMoves"
          score += 15
          AdvancedBattleAI.log("Taunt bonus vs recovery user", :scoring)
        end
      end
    end

    next score
  }
)

# Type Coverage Handler removed - functionality merged into :advanced_best_damage_move

#===============================================================================
# Doubles Focus Fire Handler
# Encourages focusing damage on one target in doubles
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_doubles_focus_fire,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)
    next score unless move.damagingMove?

    # Get the partner's target if we can
    partner_index = battle.pbGetOpposingIndicesInOrder(user.index).find do |i|
      battle.battlers[i] && battle.battlers[i].index != target.index
    end

    # If target is already low, prioritize finishing them
    if target.hp_fraction < 0.4
      score += AdvancedBattleAI::DOUBLES_FOCUS_FIRE_BONUS
      AdvancedBattleAI.log("Focus fire bonus on low HP target", :scoring)
    end

    # If we can KO, strongly prefer this target
    if ai.move && move.damagingMove?
      ai.move.set_up(move.move) if move.respond_to?(:move)
      damage = ai.move.rough_damage
      if damage >= target.hp
        score += 25  # Strong bonus for confirmed KO
        AdvancedBattleAI.log("KO confirmation bonus", :scoring)
      end
    end

    next score
  }
)

#===============================================================================
# Priority Move Handler
# Smarter priority move usage - only valuable in specific situations
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_priority_usage,
  proc { |score, move, user, target, ai, battle|
    next score unless move.move.priority > 0
    next score unless move.damagingMove?

    dominated_by_other_move = false

    # Check type effectiveness of this priority move
    priority_type_mod = Effectiveness.calculate(move.type, *target.types)

    # Check if user has a better move (higher power + better type effectiveness)
    user.battler.moves.each do |m|
      next unless m && m.damagingMove? && m.id != move.move.id
      other_type_mod = Effectiveness.calculate(m.type, *target.battler.types)

      # Another move is "better" if it's super effective when priority isn't,
      # or has significantly higher power with same/better effectiveness
      if Effectiveness.super_effective?(other_type_mod) && !Effectiveness.super_effective?(priority_type_mod)
        dominated_by_other_move = true
        break
      end
      if other_type_mod >= priority_type_mod && m.power >= move.move.power * 1.5
        dominated_by_other_move = true
        break
      end
    end

    # If we have clearly better options, penalize priority move
    if dominated_by_other_move
      score -= 15
      AdvancedBattleAI.log("Priority penalty: better moves available", :scoring)
    end

    # Only give priority bonus in specific survival scenarios
    if !user.faster_than?(target)
      # Significant bonus ONLY if user is at risk of being KO'd
      if user.hp_fraction < 0.35
        score += 15
        AdvancedBattleAI.log("Priority bonus (low HP, might die)", :scoring)
      elsif user.hp_fraction < 0.5
        score += 5  # Small bonus when moderately low
        AdvancedBattleAI.log("Priority bonus (moderately low HP)", :scoring)
      end
      # No bonus just for being slower - that's not smart play
    end

    # Big bonus if this priority move can secure a KO on a faster threat
    if ai.move
      ai.move.set_up(move.move) if move.respond_to?(:move)
      damage = ai.move.rough_damage
      if damage >= target.hp && !user.faster_than?(target)
        score += 25
        AdvancedBattleAI.log("Priority KO bonus", :scoring)
      end
    end

    # Penalty if target has Quick Guard in doubles
    if battle.doubleBattle? && ai.memory
      partner_idx = user.index.even? ? user.index + 1 : user.index - 1
      if battle.battlers[partner_idx] && ai.memory.knows_move_with_function?(partner_idx, "ProtectUserSideFromPriorityMoves")
        score -= 10
        AdvancedBattleAI.log("Priority penalty: target's side has Quick Guard", :scoring)
      end
    end

    next score
  }
)

#===============================================================================
# Setup vs Attack Decision Handler
# Helps AI decide when to use setup moves vs attacking
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_setup_decision,
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:setup_windows, ai.trainer)

    # Check if this is a setup move
    is_setup = move.function_code.match?(/RaiseUser|MaxUserAttack/)
    next score unless is_setup

    # Calculate setup window (turns until KO)
    setup_window = calculate_setup_window(user, ai, battle)

    if setup_window >= 2
      # Safe to set up
      score += AdvancedBattleAI::SETUP_WINDOW_BONUS
      AdvancedBattleAI.log("Setup window bonus (#{setup_window} turns)", :scoring)

      # Extra bonus if we have multiple setup turns
      if setup_window >= 3
        score += 10
        AdvancedBattleAI.log("Setup window: extra-long window", :scoring)
      end
    elsif setup_window <= 1
      # Risky to set up
      score += AdvancedBattleAI::SETUP_RISKY_PENALTY
      AdvancedBattleAI.log("Setup risky penalty (#{setup_window} turns)", :scoring)
    end

    # Consider current stat stages
    stat_stages = count_positive_stat_stages(user)
    if stat_stages >= 4
      # Already heavily boosted, prefer attacking
      score -= 15
      AdvancedBattleAI.log("Already boosted, prefer attacking", :scoring)
    end

    next score
  }
)

#===============================================================================
# Protect/Detect Usage Handler
# Smarter protect usage in doubles and singles
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_protect_usage,
  proc { |score, move, user, ai, battle|
    protect_functions = [
      "ProtectUser", "ProtectUserFromTargetingMovesSpikyShield",
      "ProtectUserBanefulBunker", "ProtectUserFromDamagingMovesKingsShield",
      "ProtectUserFromTargetingMovesSilkTrap", "ProtectUserFromTargetingMovesBurningBulwark"
    ]
    next score unless protect_functions.include?(move.function_code)

    # Count consecutive protect uses
    consecutive_protects = user.effects[PBEffects::ProtectRate] || 0

    # Penalty for consecutive protects based on failure chance
    # ProtectRate: 1 = 100%, 2 = 50%, 4 = 25%, etc.
    # Keep penalty small - ability-specific logic will decide if it's worth the risk
    # Pokemon with end-of-turn abilities (Speed Boost, etc.) may want to risk it
    if consecutive_protects >= 4
      # 25% or less success - moderate penalty
      score -= 20
      AdvancedBattleAI.log("Consecutive protect penalty (low success chance)", :scoring)
    elsif consecutive_protects >= 2
      # 50% success - small penalty
      score -= 5
      AdvancedBattleAI.log("Consecutive protect penalty (moderate success chance)", :scoring)
    end

    # In doubles, check if partner is using spread move
    if battle.doubleBattle?
      partner_idx = user.index.even? ? user.index + 1 : user.index - 1
      partner = battle.battlers[partner_idx]
      if partner && partner.fainted? == false
        # Check if partner might use Earthquake/Surf
        partner_ai = ai.battlers[partner_idx]
        if partner_ai
          partner_ai.battler.moves.each do |m|
            next unless m
            if m.target == :AllNonUsers || m.target == :AllBattlers
              score += 20  # Protect from ally spread move
              AdvancedBattleAI.log("Protect from ally spread move", :scoring)
              break
            end
          end
        end
      end
    end

    # ==========================================================================
    # Ability Activation Protect - Strategic Protect for ability synergy
    # Only apply these bonuses if Protect hasn't been used recently (won't fail)
    # ==========================================================================

    # Calculate success chance multiplier for ability bonuses
    # ProtectRate: 1 = 100%, 2 = 50%, 4 = 25%, 8 = 12.5%
    # Use slightly higher multipliers than raw probability because
    # the strategic value of abilities like Speed Boost is worth the risk
    success_multiplier = 1.0
    if consecutive_protects >= 8
      success_multiplier = 0.0  # Complete failure chance, no bonus
    elsif consecutive_protects >= 4
      success_multiplier = 0.2  # 25% success, but still worth considering
    elsif consecutive_protects >= 2
      success_multiplier = 0.8   # 50% success is decent odds for valuable effects
    end

    # Apply ability bonuses scaled by success chance
    if success_multiplier > 0

      # Speed Boost - Protect guarantees safe +1 Speed
      if user.has_active_ability?(:SPEEDBOOST)
        # Check if we're slower than the fastest opponent
        # Use faster_than? which accounts for stat stages, abilities, items, Trick Room, etc.
        dominated_by_speed = false
        battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
          opp_pokemon = ai.battlers[opp_idx]
          next unless opp_pokemon && !opp_pokemon.battler.fainted?
          if opp_pokemon.faster_than?(user)
            dominated_by_speed = true
            break
          end
        end

        # If we're slower, Protect is valuable to gain Speed Boost
        # Bonus scales based on how much speed we still need
        # Needs to beat: best move (+40) + STAB (+15) + super effective (+25) + predicted damage (+30) = +110
        # Also scaled by success_multiplier for consecutive Protects
        if dominated_by_speed
          current_speed_stages = user.stages[:SPEED] || 0
          base_bonus = 0
          if current_speed_stages < 2
            # Still slow - really want that speed boost
            base_bonus = 40
          elsif current_speed_stages < 4
            # Getting faster but could use more
            base_bonus = 30
          else
            # Already very boosted, less urgent but still useful
            base_bonus = 15
          end

          # Scale bonus by success chance, cap at +40
          actual_bonus = [(base_bonus * success_multiplier).to_i, 40].min
          score += actual_bonus
          AdvancedBattleAI.log("Speed Boost Protect (stages=#{current_speed_stages}, success=#{(success_multiplier * 100).to_i}%)", :scoring)
        end
      end

      # Toxic Orb activation - Protect to safely activate poison-based abilities
      if user.has_active_item?(:TOXICORB) && user.status == :NONE
        # Toxic Boost, Poison Heal, Guts, Quick Feet, Marvel Scale all benefit
        if user.has_active_ability?(:TOXICBOOST) || user.has_active_ability?(:POISONHEAL) ||
           user.has_active_ability?(:GUTS) || user.has_active_ability?(:QUICKFEET) ||
           user.has_active_ability?(:MARVELSCALE)
          # Only on first turn - after that orb should be active
          if user.turnCount == 0
            score += 40
            AdvancedBattleAI.log("Toxic Orb activation Protect (first turn)", :scoring)
          end
        end
      end

      # Flame Orb activation - Protect to safely activate burn-based abilities
      if user.has_active_item?(:FLAMEORB) && user.status == :NONE
        # Guts, Quick Feet, Marvel Scale, Flare Boost benefit
        if user.has_active_ability?(:GUTS) || user.has_active_ability?(:QUICKFEET) ||
           user.has_active_ability?(:MARVELSCALE) || user.has_active_ability?(:FLAREBOOST)
          # Only on first turn - after that orb should be active
          if user.turnCount == 0
            score += 40
            AdvancedBattleAI.log("Flame Orb activation Protect (first turn)", :scoring)
          end
        end
      end

      # Moody - Protect for free stat changes (less valuable than other abilities)
      if user.has_active_ability?(:MOODY)
        score += 10
        AdvancedBattleAI.log("Moody Protect", :scoring)
      end

    end

    # ==========================================================================
    # Protect when expecting to be KO'd
    # ==========================================================================
    if user.hp_fraction < 0.25
      # Check if opponent has KO threat
      all_targets = battle.pbGetOpposingIndicesInOrder(user.index)
      all_targets.each do |target_idx|
        target = battle.battlers[target_idx]
        next unless target && !target.fainted?
        if ai.battlers[target_idx] && ai.battlers[target_idx].faster_than?(user)
          score += 10
          AdvancedBattleAI.log("Protect: expecting to be KO'd by a faster foe", :scoring)
          break
        end
      end
    end

    next score
  }
)

#===============================================================================
# Helper Functions
#===============================================================================

# Calculate how many turns until user is KO'd
def calculate_setup_window(user, ai, battle)
  return 3 unless ai.trainer && ai.trainer.high_skill?

  max_incoming_damage = 0

  # Check all opponents
  battle.pbGetOpposingIndicesInOrder(user.index).each do |target_idx|
    target = battle.battlers[target_idx]
    next unless target && !target.fainted?

    target_ai = ai.battlers[target_idx]
    next unless target_ai

    # Estimate max damage target can deal using shared utility
    target.moves.each do |move|
      next unless move && move.damagingMove?
      move_data = GameData::Move.try_get(move.id)
      next unless move_data
      estimated = AdvancedBattleAI.estimate_damage_battler(move_data, target, user.battler, battle)
      max_incoming_damage = [max_incoming_damage, estimated].max
    end
  end

  return 3 if max_incoming_damage == 0

  # Calculate turns to live
  turns = (user.hp.to_f / max_incoming_damage).ceil
  return [turns, 5].min  # Cap at 5 turns
end

