#===============================================================================
# Advanced Battle AI - Enhanced Switching Logic
# Role-based switching and strategic decisions
#===============================================================================

#===============================================================================
# Helper function to count positive stat stages
#===============================================================================
def count_positive_stat_stages(ai_battler)
  return 0 unless ai_battler && ai_battler.battler
  count = 0
  [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |stat|
    stage = ai_battler.stages[stat] || 0
    count += stage if stage > 0
  end
  return count
end

#===============================================================================
# Helper to check if battler should avoid switching
#===============================================================================
def should_avoid_switching?(battler, ai)
  return true unless battler && ai

  ai_battler = ai.battlers[battler.index]
  return false unless ai_battler

  # Don't switch if we have significant stat boosts
  if count_positive_stat_stages(ai_battler) >= 2
    AdvancedBattleAI.log("Avoiding switch: has +2 or more stat boosts", :decisions)
    return true
  end

  # Don't switch if trapped (can't switch anyway, but check for logic)
  if battler.effects[PBEffects::Trapping] > 0 ||
     battler.effects[PBEffects::MeanLook] > 0 ||
     battler.effects[PBEffects::JawLock] > 0
    return true
  end

  # Don't switch if we have a powerful setup opportunity
  # (e.g., opponent is at low HP and we can finish them)

  return false
end

#===============================================================================
# Role-Based Switching Handler
# Switch if current role is no longer useful for the matchup
# Now with proper safeguards
#===============================================================================
Battle::AI::Handlers::ShouldSwitch.add(:advanced_role_mismatch,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
    next false unless ai.battlers[battler.index]

    # === SAFEGUARDS ===
    # Don't switch if we have stat boosts
    next false if should_avoid_switching?(battler, ai)

    # Don't switch if HP is low (might as well stay in)
    next false if battler.hp < battler.totalhp * 0.3

    # Don't switch if HP is high and we can still contribute
    # Only consider switching at medium HP (30-70%)
    next false if battler.hp > battler.totalhp * 0.7

    user_role = ai.battlers[battler.index].detected_role

    # Check if our role is mismatched against current opponents
    case user_role
    when Battle::AI::Roles::PHYSICAL_WALL
      # Physical wall vs all special attackers = bad
      all_special = true
      battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        # Use a meaningful threshold - SpAtk must be notably higher
        if opp.spatk < opp.attack * 1.3
          all_special = false
          break
        end
      end
      if all_special
        # Additional check: do we have a special wall to switch to?
        has_better_option = reserves.any? do |pkmn|
          next false unless pkmn && pkmn.able?
          role = ai.estimate_pokemon_role(pkmn)
          role == Battle::AI::Roles::SPECIAL_WALL || role == Battle::AI::Roles::MIXED_WALL
        end
        if has_better_option
          AdvancedBattleAI.log("Role mismatch: Physical wall vs special attackers, have SpD wall", :decisions)
          next true
        end
      end

    when Battle::AI::Roles::SPECIAL_WALL
      # Special wall vs all physical attackers = bad
      all_physical = true
      battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        if opp.attack < opp.spatk * 1.3
          all_physical = false
          break
        end
      end
      if all_physical
        # Additional check: do we have a physical wall to switch to?
        has_better_option = reserves.any? do |pkmn|
          next false unless pkmn && pkmn.able?
          role = ai.estimate_pokemon_role(pkmn)
          role == Battle::AI::Roles::PHYSICAL_WALL || role == Battle::AI::Roles::MIXED_WALL
        end
        if has_better_option
          AdvancedBattleAI.log("Role mismatch: Special wall vs physical attackers, have Def wall", :decisions)
          next true
        end
      end

    when Battle::AI::Roles::HAZARD_SETTER
      # Hazard setter when all hazards already up = job done
      side = battler.pbOpposingSide
      # Check what hazards this Pokemon can set
      can_set_sr = battler.moves.any? { |m| m && m.function_code == "AddStealthRocksToFoeSide" }
      can_set_spikes = battler.moves.any? { |m| m && m.function_code == "AddSpikesToFoeSide" }
      can_set_tspikes = battler.moves.any? { |m| m && m.function_code == "AddToxicSpikesToFoeSide" }

      sr_done = !can_set_sr || side.effects[PBEffects::StealthRock]
      spikes_done = !can_set_spikes || (side.effects[PBEffects::Spikes] || 0) >= 3
      tspikes_done = !can_set_tspikes || (side.effects[PBEffects::ToxicSpikes] || 0) >= 2

      hazards_maxed = sr_done && spikes_done && tspikes_done
      if hazards_maxed && battler.hp < battler.totalhp * 0.5
        AdvancedBattleAI.log("Hazard setter job done, medium HP", :decisions)
        next true
      end

    when Battle::AI::Roles::SCREEN_SETTER
      # Screen setter when screens are up and low HP
      side = battler.pbOwnSide
      screens_up = side.effects[PBEffects::Reflect] > 0 ||
                   side.effects[PBEffects::LightScreen] > 0 ||
                   side.effects[PBEffects::AuroraVeil] > 0
      if screens_up && battler.hp < battler.totalhp * 0.5
        AdvancedBattleAI.log("Screen setter job done, medium HP", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# Pivot Move Preference Handler
# Prefer using pivot moves over hard switching
#===============================================================================
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_prefer_pivot,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)

    # Check if battler has a pivot move
    pivot_move = nil
    battler.moves.each do |m|
      next unless m
      pivot_functions = [
        "SwitchOutUserDamagingMove",   # U-turn, Volt Switch
        "SwitchOutUserStatusMove"       # Parting Shot, Teleport
      ]
      if pivot_functions.include?(m.function_code)
        pivot_move = m
        break
      end
    end

    next false unless pivot_move

    # Check if pivot would work (not immune)
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # For damaging pivots, check type effectiveness
      if pivot_move.function_code == "SwitchOutUserDamagingMove"
        type_mod = Effectiveness.calculate(pivot_move.type, *opp.types)
        if type_mod > 0
          AdvancedBattleAI.log("Prefer pivot move (#{pivot_move.name}) over hard switch", :decisions)
          next true
        end
      else
        # Status pivots always work (Parting Shot, Teleport)
        AdvancedBattleAI.log("Prefer status pivot move over hard switch", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# Sacrifice Awareness Handler
# Allow strategic sacrifices to enable setup
#===============================================================================
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_sacrifice_play,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:sacrifice, ai.trainer)
    next false unless ai.battlers[battler.index]

    # Don't sacrifice important roles
    if ai.battlers[battler.index].should_preserve?
      next false
    end

    # Check if sacrificing would let a sweeper come in safely
    if ai.battlers[battler.index].can_sacrifice?
      # Only consider sacrifice if we're very low HP
      if battler.hp < battler.totalhp * 0.2
        # Look for setup sweeper in reserves
        reserves.each do |pkmn|
          next unless pkmn && pkmn.able?
          role = ai.estimate_pokemon_role(pkmn)
          if role == Battle::AI::Roles::SETUP_SWEEPER
            AdvancedBattleAI.log("Allowing sacrifice to bring in sweeper", :decisions)
            next true
          end
        end
      end
    end

    next false
  }
)

#===============================================================================
# Sweeper Preservation Handler
# Avoid switching out sweepers that are set up
#===============================================================================
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_preserve_sweeper,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
    next false unless ai.battlers[battler.index]

    # Only applies if we're not the last Pokemon
    remaining = reserves.count { |p| p && p.able? }
    next false if remaining <= 1

    # Check if current battler is a sweeper with boosts
    ai_battler = ai.battlers[battler.index]
    if ai_battler.detected_role == Battle::AI::Roles::SWEEPER ||
       ai_battler.detected_role == Battle::AI::Roles::SETUP_SWEEPER
      # Don't switch out a sweeper that's set up
      boost_count = count_positive_stat_stages(ai_battler)
      if boost_count >= 2
        AdvancedBattleAI.log("Preserve boosted sweeper (+#{boost_count} stages)", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# Type Advantage Switching Handler
# Switch when at severe type disadvantage - with safeguards
#===============================================================================
Battle::AI::Handlers::ShouldSwitch.add(:advanced_type_disadvantage,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
    next false unless ai.trainer.high_skill?

    # === SAFEGUARDS ===
    next false if should_avoid_switching?(battler, ai)

    # Only switch if we have decent HP (switching at low HP is usually bad)
    next false if battler.hp < battler.totalhp * 0.4

    # Check if we're at severe type disadvantage against all opponents
    dominated = true
    our_best_effective_power = 0

    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Check our best move against this opponent
      battler.moves.each do |m|
        next unless m && m.damagingMove?
        type_mod = Effectiveness.calculate(m.type, *opp.types)
        effective_power = m.power * type_mod / 100.0
        our_best_effective_power = [our_best_effective_power, effective_power].max
      end

      # If we can deal decent effective damage, not dominated
      if our_best_effective_power >= 50
        dominated = false
        break
      end

      # Check if opponent can threaten us
      opponent_threatens = false
      opp.moves.each do |m|
        next unless m && m.damagingMove?
        type_mod = Effectiveness.calculate(m.type, *battler.types)
        if Effectiveness.super_effective?(type_mod) && m.power >= 60
          opponent_threatens = true
          break
        end
      end

      # If they don't threaten us, we're not dominated
      unless opponent_threatens
        dominated = false
        break
      end
    end

    if dominated
      # Check if we have a significantly better option
      best_reserve_score = 0
      reserves.each do |pkmn|
        next unless pkmn && pkmn.able?

        reserve_score = 0
        battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
          opp = battle.battlers[opp_idx]
          next unless opp && !opp.fainted?

          # Check type matchup - how well does reserve handle opponent?
          opp.moves.each do |m|
            next unless m && m.damagingMove?
            type_mod = Effectiveness.calculate(m.type, *pkmn.types)
            if Effectiveness.not_very_effective?(type_mod)
              reserve_score += 20
            elsif type_mod == 0
              reserve_score += 40  # Immunity is great
            elsif Effectiveness.super_effective?(type_mod)
              reserve_score -= 15
            end
          end
        end

        best_reserve_score = [best_reserve_score, reserve_score].max
      end

      # Only switch if reserve is significantly better (score threshold)
      if best_reserve_score >= 30
        AdvancedBattleAI.log("Switching: dominated by matchup, better option available", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# Enhanced Replacement Pokemon Rating
# Considers roles and memory when choosing replacement
#===============================================================================
class Battle::AI
  alias advanced_ai_rate_replacement rate_replacement_pokemon if method_defined?(:rate_replacement_pokemon)

  def rate_replacement_pokemon(idxBattler, pkmn, party_index)
    # Call original if it exists
    score = 100
    if self.class.method_defined?(:advanced_ai_rate_replacement)
      score = advanced_ai_rate_replacement(idxBattler, pkmn, party_index)
    end

    return score unless AdvancedBattleAI.feature_enabled?(:roles, @trainer)

    # Get opponent info
    opponents = @battle.pbGetOpposingIndicesInOrder(idxBattler)

    # Role-based scoring
    estimated_role = estimate_pokemon_role(pkmn)

    case estimated_role
    when Battle::AI::Roles::HAZARD_SETTER
      # Bonus if opponent's side doesn't have hazards
      side = @battle.sides[idxBattler % 2 == 0 ? 1 : 0]
      unless side.effects[PBEffects::StealthRock]
        score += 15
      end

    when Battle::AI::Roles::HAZARD_REMOVER
      # Bonus if our side has hazards
      side = @battle.sides[idxBattler % 2]
      hazard_count = 0
      hazard_count += 1 if side.effects[PBEffects::StealthRock]
      hazard_count += (side.effects[PBEffects::Spikes] || 0)
      hazard_count += (side.effects[PBEffects::ToxicSpikes] || 0)
      hazard_count += 1 if side.effects[PBEffects::StickyWeb]
      score += hazard_count * 10

    when Battle::AI::Roles::SWEEPER, Battle::AI::Roles::SETUP_SWEEPER
      # Sweepers are better late game
      remaining_opponents = opponents.count do |i|
        b = @battle.battlers[i]
        b && !b.fainted?
      end
      if remaining_opponents <= 2
        score += 15
      elsif remaining_opponents >= 4
        score -= 10  # Penalty for bringing in sweeper too early
      end

    when Battle::AI::Roles::CLERIC
      # Bonus if team has status
      party = @battle.pbParty(idxBattler)
      status_count = party.count { |p| p && p.able? && p.status != :NONE }
      score += status_count * 10
    end

    # Type matchup scoring with memory
    if @memory
      opponents.each do |opp_idx|
        opp = @battle.battlers[opp_idx]
        next unless opp && !opp.fainted?

        # Check known moves for dangerous ones
        known_moves = @memory.get_known_moves(opp_idx)
        known_moves.each do |move_id|
          move_data = GameData::Move.try_get(move_id)
          next unless move_data && move_data.power > 0

          type_mod = Effectiveness.calculate(move_data.type, *pkmn.types)
          if Effectiveness.super_effective?(type_mod)
            score -= 15
          elsif Effectiveness.not_very_effective?(type_mod)
            score += 10
          elsif type_mod == 0
            score += 25  # Immunity
          end
        end
      end
    end

    return score
  end
end

#===============================================================================
# Counter Switch Handler - More Conservative
# Switch to counter opponent's known moveset
#===============================================================================
Battle::AI::Handlers::ShouldSwitch.add(:advanced_counter_switch,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:memory, ai.trainer)
    next false unless ai.memory

    # === SAFEGUARDS ===
    next false if should_avoid_switching?(battler, ai)

    # Only consider if we have decent HP
    next false if battler.hp < battler.totalhp * 0.5

    # Check if opponent has shown moves that hard counter us
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      known_moves = ai.memory.get_known_moves(opp_idx)
      next if known_moves.empty?

      # Check if any known move is 4x super effective or STAB super effective
      critical_threat = known_moves.any? do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next false unless move_data && move_data.power >= 70
        type_mod = Effectiveness.calculate(move_data.type, *battler.types)
        # 4x super effective is a critical threat
        type_mod >= Effectiveness::SUPER_EFFECTIVE_MULTIPLIER * 2
      end

      if critical_threat
        # Check if we have an immune or resistant option
        reserves.each do |pkmn|
          next unless pkmn && pkmn.able?

          # Check if this reserve handles the threat
          handles_threat = known_moves.all? do |move_id|
            move_data = GameData::Move.try_get(move_id)
            next true unless move_data && move_data.power >= 70
            type_mod = Effectiveness.calculate(move_data.type, *pkmn.types)
            # Reserve should resist or be immune
            !Effectiveness.super_effective?(type_mod)
          end

          if handles_threat
            AdvancedBattleAI.log("Counter switch: 4x weakness, have resistant option", :decisions)
            next true
          end
        end
      end
    end

    next false
  }
)
