#===============================================================================
# Advanced Battle AI - Strategic Status Targeting
# Makes AI choose the RIGHT target for each status move based on role/threat
#===============================================================================

# Function code groups for status moves
PARALYSIS_FUNCTION_CODES = [
  "ParalyzeTarget", "ParalyzeTargetIfNotTypeImmune",
  "ParalyzeTargetAlwaysHitsInRainHitsTargetInSky", "ParalyzeFlinchTarget"
]
BURN_FUNCTION_CODES = [
  "BurnTarget", "BurnFlinchTarget"
]
POISON_FUNCTION_CODES = [
  "PoisonTarget", "BadPoisonTarget", "PoisonTargetLowerTargetSpeed1"
]
SLEEP_FUNCTION_CODES = [
  "SleepTarget", "SleepTargetIfUserDarkrai",
  "SleepTargetChangeUserMeloettaForm", "SleepTargetNextTurn"
]

ALL_STATUS_FUNCTION_CODES = PARALYSIS_FUNCTION_CODES + BURN_FUNCTION_CODES +
                            POISON_FUNCTION_CODES + SLEEP_FUNCTION_CODES

# Physical setup function codes (for burn targeting)
PHYSICAL_SETUP_FUNCTIONS = [
  "RaiseUserAttack1", "RaiseUserAttack2", "RaiseUserAttack3",
  "MaxUserAttackLoseHalfOfTotalHP",  # Belly Drum
  "RaiseUserAtkDef1", "RaiseUserAtkSpd1", "RaiseUserAtkSpAtk1"
]

#===============================================================================
# Handler 1: Strategic Status Targeting
# Adds role-aware bonuses/penalties for status moves
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_status_targeting,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
    func = move.function_code
    next score unless ALL_STATUS_FUNCTION_CODES.include?(func)

    target_role = target.detected_role rescue nil

    #---------------------------------------------------------------------------
    # Paralysis targeting
    #---------------------------------------------------------------------------
    if PARALYSIS_FUNCTION_CODES.include?(func)
      # +20 if target is a sweeper (shutting down speed advantage is huge)
      if target_role == Battle::AI::Roles::SWEEPER ||
         target_role == Battle::AI::Roles::SETUP_SWEEPER
        score += AdvancedBattleAI::SCORE_LARGE_BONUS
        AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_LARGE_BONUS} paralyze sweeper (#{target_role})", :scoring)
      end

      # +10 if target outspeeds our entire remaining team
      if ai.memory && ai.memory.target_is_fast_threat?(target, ai, battle)
        score += AdvancedBattleAI::SCORE_SMALL_BONUS
        AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_SMALL_BONUS} paralyze fast threat (outspeeds team)", :scoring)
      end

      # -10 if target is a wall/staller (paralysis barely matters)
      if target_role == Battle::AI::Roles::PHYSICAL_WALL ||
         target_role == Battle::AI::Roles::SPECIAL_WALL ||
         target_role == Battle::AI::Roles::MIXED_WALL
        score += AdvancedBattleAI::SCORE_SMALL_PENALTY
        AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_SMALL_PENALTY} paralyze wall (low value)", :scoring)
      end

      # -10 if target is already slow (base speed < 60)
      base_speed = target.battler.pokemon.baseStats[:SPEED] rescue 0
      if base_speed > 0 && base_speed < 60
        score += AdvancedBattleAI::SCORE_SMALL_PENALTY
        AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_SMALL_PENALTY} paralyze slow target (base speed #{base_speed})", :scoring)
      end
    end

    #---------------------------------------------------------------------------
    # Burn targeting
    #---------------------------------------------------------------------------
    if BURN_FUNCTION_CODES.include?(func)
      t_atk = target.attack rescue 0
      t_spatk = target.spatk rescue 0

      # +20 if target is a pure physical attacker (Atk > SpAtk * 1.5)
      if t_atk > 0 && t_spatk > 0 && t_atk > t_spatk * 1.5
        score += AdvancedBattleAI::SCORE_LARGE_BONUS
        AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_LARGE_BONUS} burn physical attacker (Atk #{t_atk} >> SpAtk #{t_spatk})", :scoring)
      end

      # +10 if target has known physical setup moves
      if ai.memory
        if ai.memory.knows_move_with_function?(target.index, *PHYSICAL_SETUP_FUNCTIONS)
          score += AdvancedBattleAI::SCORE_SMALL_BONUS
          AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_SMALL_BONUS} burn physical setup user", :scoring)
        end
      end

      # -15 if target is a special attacker (SpAtk > Atk * 1.5)
      if t_atk > 0 && t_spatk > 0 && t_spatk > t_atk * 1.5
        score += AdvancedBattleAI::SCORE_MEDIUM_PENALTY
        AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_MEDIUM_PENALTY} burn special attacker (SpAtk #{t_spatk} >> Atk #{t_atk})", :scoring)
      end

      # -10 if target has Guts or Flare Boost (reinforce base AI penalty)
      if target.has_active_ability?(:GUTS) || target.has_active_ability?(:FLAREBOOST)
        score += AdvancedBattleAI::SCORE_SMALL_PENALTY
        AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_SMALL_PENALTY} burn Guts/Flare Boost user", :scoring)
      end
    end

    #---------------------------------------------------------------------------
    # Toxic/Poison targeting
    #---------------------------------------------------------------------------
    if POISON_FUNCTION_CODES.include?(func)
      # +15 if target has recovery (known Leftovers or recovery moves)
      has_recovery = false
      if ai.memory
        known_item = ai.memory.get_known_item(target.index)
        has_recovery = true if known_item == :LEFTOVERS || known_item == :BLACKSLUDGE
        has_recovery = true if ai.memory.has_shown_recovery?(target.index)
      end
      if has_recovery
        score += AdvancedBattleAI::SCORE_MEDIUM_BONUS
        AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_MEDIUM_BONUS} toxic recovery user", :scoring)
      end

      # +15 if target is a wall
      if target_role == Battle::AI::Roles::PHYSICAL_WALL ||
         target_role == Battle::AI::Roles::SPECIAL_WALL ||
         target_role == Battle::AI::Roles::MIXED_WALL
        score += AdvancedBattleAI::SCORE_MEDIUM_BONUS
        AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_MEDIUM_BONUS} toxic wall (#{target_role})", :scoring)
      end

      # +10 if target has high HP (Toxic scales better vs bulk)
      base_hp = target.battler.pokemon.baseStats[:HP] rescue 0
      if base_hp >= 100
        score += AdvancedBattleAI::SCORE_SMALL_BONUS
        AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_SMALL_BONUS} toxic high HP target (base HP #{base_hp})", :scoring)
      end

      # -10 if target is a sweeper at high HP (they'll KO us before Toxic matters)
      if (target_role == Battle::AI::Roles::SWEEPER ||
          target_role == Battle::AI::Roles::SETUP_SWEEPER) &&
         target.hp_fraction > 0.8
        score += AdvancedBattleAI::SCORE_SMALL_PENALTY
        AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_SMALL_PENALTY} toxic sweeper at high HP", :scoring)
      end

      # -15 if target has Poison Heal (reinforce base AI penalty)
      if target.has_active_ability?(:POISONHEAL)
        score += AdvancedBattleAI::SCORE_MEDIUM_PENALTY
        AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_MEDIUM_PENALTY} toxic Poison Heal user", :scoring)
      end
    end

    #---------------------------------------------------------------------------
    # General status priority (applies to all status moves above)
    #---------------------------------------------------------------------------

    # +10 if target is the opponent's likely win condition
    ai.analyze_win_condition if ai.respond_to?(:analyze_win_condition)
    if ai.win_condition_pokemon
      if (target_role == Battle::AI::Roles::SWEEPER ||
          target_role == Battle::AI::Roles::SETUP_SWEEPER) &&
         target.hp_fraction > 0.6
        score += AdvancedBattleAI::SCORE_SMALL_BONUS
        AdvancedBattleAI.log("+#{AdvancedBattleAI::SCORE_SMALL_BONUS} status opponent's likely win condition", :scoring)
      end
    end

    # -8 if opponent has few Pokemon left and target is low HP (just KO instead)
    remaining = AdvancedBattleAI.count_remaining_pokemon(battle, target.index)
    if remaining <= 2 && target.hp_fraction < 0.4
      score += AdvancedBattleAI::SCORE_MINOR_PENALTY
      AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_MINOR_PENALTY} status low HP target with few remaining", :scoring)
    end

    next score
  }
)

#===============================================================================
# Handler 2: Don't Waste Status Turns
# Discourages using status moves when they won't be effective
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_status_dont_waste,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
    next score unless move.statusMove?
    func = move.function_code
    next score unless ALL_STATUS_FUNCTION_CODES.include?(func)

    # -15 if target already has a status condition
    if target.battler.status != :NONE
      score -= 15
      AdvancedBattleAI.log("-15 target already statused (#{target.battler.status})", :scoring)
    end

    # -10 if target has Substitute up
    if target.effects[PBEffects::Substitute] > 0
      score -= 10
      AdvancedBattleAI.log("-10 target behind Substitute", :scoring)
    end

    # -8 if we can KO the target this turn (attacking > statusing a dying target)
    best_damage = AdvancedBattleAI.best_move_damage(user.battler, target.battler)
    if best_damage >= target.hp
      score += AdvancedBattleAI::SCORE_MINOR_PENALTY
      AdvancedBattleAI.log("#{AdvancedBattleAI::SCORE_MINOR_PENALTY} can KO target this turn", :scoring)
    end

    next score
  }
)
