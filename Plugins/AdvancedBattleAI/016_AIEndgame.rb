#===============================================================================
# Advanced Battle AI - Endgame & Clutch Plays (Phase 5)
# Adjusts scoring based on remaining Pokemon count and desperate situations
#===============================================================================

# Global wrapper — delegates to AdvancedBattleAI module method
def count_remaining_pokemon(battle, battler_index)
  AdvancedBattleAI.count_remaining_pokemon(battle, battler_index)
end

#===============================================================================
# 5.1 & 5.2 Endgame State Machine + Revenge Kill / Cleaner Logic
# Adjusts move scoring based on how many Pokemon remain on each side.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_endgame,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:win_condition, ai.trainer)

    our_remaining = count_remaining_pokemon(battle, user.index)
    opp_remaining = count_remaining_pokemon(battle, target.index)

    next score if our_remaining > 3 && opp_remaining > 3  # Not endgame yet

    # Estimate if this move can KO the target
    can_ko = false
    if move.damagingMove?
      move_data = GameData::Move.try_get(move.id)
      if move_data
        damage = AdvancedBattleAI.estimate_damage_battler(move_data, user.battler, target.battler, battle)
        can_ko = damage >= target.hp
      end
    end

    is_setup = move.function_code.match?(/RaiseUser|MaxUserAttack/) rescue false
    is_status = move.statusMove? rescue false
    is_priority = (move.move.priority > 0 && move.damagingMove?) rescue false
    is_hazard = ["AddStealthRocksToFoeSide", "AddSpikesToFoeSide",
                 "AddToxicSpikesToFoeSide", "AddStickyWebToFoeSide"].include?(move.function_code)
    user_faster = user.faster_than?(target) rescue false

    #---------------------------------------------------------------------------
    # Find highest effective power among user's moves (for 1v1 best-move bonus)
    #---------------------------------------------------------------------------
    best_effective_power = 0
    this_effective_power = 0
    if move.damagingMove?
      target_types = target.battler.types rescue [:NORMAL]
      user.battler.moves.each do |m|
        next unless m && (m.damagingMove? rescue false)
        m_power = m.power rescue 0
        next if m_power == 0
        m_type_mod = Effectiveness.calculate(m.type, *target_types) rescue 1.0
        m_stab = (user.battler.pbHasType?(m.type) rescue false) ? 1.5 : 1.0
        eff = m_power * m_stab * m_type_mod
        best_effective_power = eff if eff > best_effective_power
        this_effective_power = eff if m.id == move.move.id
      end
    end

    #---------------------------------------------------------------------------
    # Late Game: <= 3 Pokemon per side
    #---------------------------------------------------------------------------
    if our_remaining <= 3 || opp_remaining <= 3
      # KO moves finish the game faster
      if can_ko
        score += 15
        AdvancedBattleAI.log("Endgame: KO move bonus (late game)", :scoring)
      end

      # Don't set up if we only have 1 Pokemon left (too risky)
      if is_setup && our_remaining == 1
        score -= 10
        AdvancedBattleAI.log("Endgame: setup penalty (last Pokemon)", :scoring)
      end

      # Priority when low HP
      if is_priority && user.hp_fraction < 0.5
        score += 10
        AdvancedBattleAI.log("Endgame: priority bonus (low HP, late game)", :scoring)
      end
    end

    #---------------------------------------------------------------------------
    # Endgame: <= 2 Pokemon per side
    #---------------------------------------------------------------------------
    if our_remaining <= 2 || opp_remaining <= 2
      # Stronger KO bonus
      if can_ko
        score += 20
        AdvancedBattleAI.log("Endgame: KO move bonus (endgame)", :scoring)
      end

      # Priority KO against faster targets
      if is_priority && can_ko && !user_faster
        score += 15
        AdvancedBattleAI.log("Endgame: priority KO vs faster target", :scoring)
      end

      # No more switches coming — hazards are wasteful
      if is_hazard
        score -= 15
        AdvancedBattleAI.log("Endgame: hazard penalty (few Pokemon left)", :scoring)
      end

      # If target is low, just KO them instead of using status
      if is_status && target.hp_fraction < 0.4
        score -= 10
        AdvancedBattleAI.log("Endgame: status penalty (target low HP)", :scoring)
      end
    end

    #---------------------------------------------------------------------------
    # Last Pokemon: 1v1
    #---------------------------------------------------------------------------
    if our_remaining == 1 && opp_remaining == 1
      # Heavily favor the highest-damage move
      if move.damagingMove? && best_effective_power > 0 && this_effective_power >= best_effective_power * 0.95
        score += 25
        AdvancedBattleAI.log("Endgame: best damage move bonus (1v1)", :scoring)
      end

      # Penalize non-damaging, non-setup moves (no point switching or setting hazards)
      if !move.damagingMove? && !is_setup
        score -= 20
        AdvancedBattleAI.log("Endgame: non-damaging penalty (1v1)", :scoring)
      end

      # Setup only if outspeeding AND healthy
      if is_setup
        if user_faster && user.hp_fraction > 0.6
          score += 15
          AdvancedBattleAI.log("Endgame: safe setup bonus (1v1, fast + healthy)", :scoring)
        else
          score -= 15
          AdvancedBattleAI.log("Endgame: risky setup penalty (1v1)", :scoring)
        end
      end

      # Priority KO when slower
      if is_priority && can_ko && !user_faster
        score += 20
        AdvancedBattleAI.log("Endgame: priority KO bonus (1v1, slower)", :scoring)
      end
    end

    #---------------------------------------------------------------------------
    # 5.2 Revenge Kill / Cleaner Logic
    # When our Pokemon just switched in (turnCount == 0), prioritize KOs
    #---------------------------------------------------------------------------
    if user.battler.turnCount == 0
      if is_priority && can_ko
        score += 15
        AdvancedBattleAI.log("Revenge kill: priority KO on entry", :scoring)
      elsif user_faster && can_ko
        score += 10
        AdvancedBattleAI.log("Cleaner: outspeed KO on entry", :scoring)
      end
    end

    next score
  }
)

#===============================================================================
# 5.3 Desperate Plays
# When losing badly, slightly favor hax moves (crits, flinch, freeze/para)
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_desperate_plays,
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:win_condition, ai.trainer)

    our_remaining = count_remaining_pokemon(battle, user.index)

    # Determine opponent remaining — check opposing side
    opp_remaining = 0
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp_party_count = count_remaining_pokemon(battle, opp_idx)
      opp_remaining = opp_party_count if opp_party_count > opp_remaining
    end

    # Only activate when losing (fewer Pokemon than opponent)
    next score unless our_remaining < opp_remaining

    AdvancedBattleAI.log("Desperate plays active (#{our_remaining} vs #{opp_remaining})", :scoring)

    # High crit ratio moves — check the move flag
    move_obj = move.move rescue nil
    if move_obj
      is_high_crit = (move_obj.highCriticalRate? rescue false)
      if is_high_crit && move.damagingMove?
        score += 10
        AdvancedBattleAI.log("Desperate: high crit move bonus", :scoring)
      end
    end

    # Flinch moves if we're faster
    flinch_functions = [
      "FlinchTarget", "FlinchTargetDoublePowerIfTargetInSky",
      "HitTwoTimesFlinchTarget", "TwoTurnAttackFlinchTarget",
      "ParalyzeFlinchTarget", "BurnFlinchTarget", "FreezeFlinchTarget"
    ]
    if flinch_functions.include?(move.function_code) && move.damagingMove?
      # Check if we're faster than at least one opponent
      is_faster_than_any = false
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        opp_ai = ai.battlers[opp_idx]
        next unless opp_ai && !opp_ai.battler.fainted?
        if user.faster_than?(opp_ai)
          is_faster_than_any = true
          break
        end
      end
      if is_faster_than_any
        score += 8
        AdvancedBattleAI.log("Desperate: flinch move bonus (faster)", :scoring)
      end
    end

    # Moves with secondary freeze or paralysis chance
    if move.damagingMove? && move_obj
      addl_effect = move_obj.addlEffect rescue 0
      if addl_effect > 0
        # Check function code for freeze/paralysis secondary effects
        freeze_para_functions = [
          "FreezeTarget", "ParalyzeTarget",
          "FreezeFlinchTarget", "ParalyzeFlinchTarget"
        ]
        if freeze_para_functions.include?(move.function_code)
          score += 5
          AdvancedBattleAI.log("Desperate: freeze/para chance bonus", :scoring)
        end
      end
    end

    next score
  }
)

#===============================================================================
# Log that Endgame & Clutch Plays loaded
#===============================================================================
AdvancedBattleAI.log("Endgame & Clutch Plays (Phase 5) loaded", :general)
