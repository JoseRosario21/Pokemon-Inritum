#===============================================================================
# Advanced Battle AI - Enhanced Switching Logic
# Role-based switching and strategic decisions
#===============================================================================

# Global wrappers — delegate to AdvancedBattleAI module methods
def count_positive_stat_stages(ai_battler)
  AdvancedBattleAI.count_positive_stat_stages(ai_battler)
end

def should_avoid_switching?(battler, ai)
  AdvancedBattleAI.should_avoid_switching?(battler, ai)
end

def estimate_switch_damage(move_data, attacker, defender, battle = nil)
  AdvancedBattleAI.estimate_damage_battler(move_data, attacker, defender, battle)
end

def best_move_damage(battler, opponent)
  AdvancedBattleAI.best_move_damage(battler, opponent)
end

def calculate_hazard_entry_damage_fraction(pkmn, side)
  AdvancedBattleAI.calculate_hazard_entry_damage_fraction(pkmn, side)
end

#===============================================================================
# Role-Based Switching Handler
# Switch if current role is no longer useful for the matchup
# Conservative approach: many safeguards to prevent excessive switching
#===============================================================================
Battle::AI::Handlers::ShouldSwitch.add(:advanced_role_mismatch,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
    next false unless ai.battlers[battler.index]

    # === SAFEGUARDS ===
    # Don't switch if we have stat boosts
    next false if should_avoid_switching?(battler, ai)

    # Don't switch on turn 1-2 — give the Pokemon a chance to contribute
    next false if battler.turnCount < 2

    # Only consider switching at 40-60% HP (tighter window)
    hp_ratio = battler.hp.to_f / battler.totalhp
    next false if hp_ratio < 0.4 || hp_ratio > 0.6

    # Don't switch if we can KO any opponent this turn
    can_ko = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      dmg = best_move_damage(battler, opp)
      if dmg >= opp.hp
        can_ko = true
        break
      end
    end
    next false if can_ko

    # Don't switch if we outspeed and can deal > 50% of any opponent's HP
    dealing_good_damage = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      ai_user = ai.battlers[battler.index]
      ai_opp = ai.battlers[opp_idx]
      if ai_user && ai_opp && ai_user.faster_than?(ai_opp)
        dmg = AdvancedBattleAI.best_move_damage(battler, opp)
        if dmg > opp.totalhp * 0.5
          AdvancedBattleAI.log("Role mismatch skipped: outspeed and deal >50%", :decisions)
          dealing_good_damage = true
          break
        end
      end
    end
    next false if dealing_good_damage

    # Check entry hazard cost: don't switch if hazards on our side are heavy
    our_side = battler.pbOwnSide
    hazard_fraction = calculate_hazard_entry_damage_fraction(battler, our_side)
    next false if hazard_fraction >= 0.25

    user_role = ai.battlers[battler.index].detected_role

    # Check if our role is mismatched against current opponents
    case user_role
    when Battle::AI::Roles::PHYSICAL_WALL
      # Physical wall vs all special attackers = bad
      all_special = true
      battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        # Require SpAtk to be clearly dominant (1.5x instead of 1.3x)
        if opp.spatk < opp.attack * 1.5
          all_special = false
          break
        end
      end
      if all_special
        # Replacement must BOTH resist the threat AND threaten back
        has_better_option = reserves.any? do |pkmn|
          next false unless pkmn && pkmn.able?
          role = ai.estimate_pokemon_role(pkmn)
          next false unless role == Battle::AI::Roles::SPECIAL_WALL || role == Battle::AI::Roles::MIXED_WALL

          # Check replacement can threaten at least one opponent
          threatens_back = false
          battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
            opp = battle.battlers[opp_idx]
            next unless opp && !opp.fainted?
            pkmn.moves.each do |m|
              next unless m
              move_data = GameData::Move.try_get(m.id)
              next unless move_data && move_data.power > 0
              type_mod = Effectiveness.calculate(move_data.type, *opp.types)
              if Effectiveness.super_effective?(type_mod)
                threatens_back = true
                break
              end
            end
            break if threatens_back
          end
          next threatens_back
        end
        if has_better_option
          AdvancedBattleAI.log("Role mismatch: Physical wall vs special attackers, have threatening SpD wall", :decisions)
          next true
        end
      end

    when Battle::AI::Roles::SPECIAL_WALL
      # Special wall vs all physical attackers = bad
      all_physical = true
      battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        # Require Atk to be clearly dominant (1.5x instead of 1.3x)
        if opp.attack < opp.spatk * 1.5
          all_physical = false
          break
        end
      end
      if all_physical
        # Replacement must BOTH resist the threat AND threaten back
        has_better_option = reserves.any? do |pkmn|
          next false unless pkmn && pkmn.able?
          role = ai.estimate_pokemon_role(pkmn)
          next false unless role == Battle::AI::Roles::PHYSICAL_WALL || role == Battle::AI::Roles::MIXED_WALL

          threatens_back = false
          battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
            opp = battle.battlers[opp_idx]
            next unless opp && !opp.fainted?
            pkmn.moves.each do |m|
              next unless m
              move_data = GameData::Move.try_get(m.id)
              next unless move_data && move_data.power > 0
              type_mod = Effectiveness.calculate(move_data.type, *opp.types)
              if Effectiveness.super_effective?(type_mod)
                threatens_back = true
                break
              end
            end
            break if threatens_back
          end
          next threatens_back
        end
        if has_better_option
          AdvancedBattleAI.log("Role mismatch: Special wall vs physical attackers, have threatening Def wall", :decisions)
          next true
        end
      end

    when Battle::AI::Roles::HAZARD_SETTER
      # Hazard setter when all hazards already up = job done
      side = battler.pbOpposingSide
      can_set_sr = battler.moves.any? { |m| m && m.function_code == "AddStealthRocksToFoeSide" }
      can_set_spikes = battler.moves.any? { |m| m && m.function_code == "AddSpikesToFoeSide" }
      can_set_tspikes = battler.moves.any? { |m| m && m.function_code == "AddToxicSpikesToFoeSide" }

      sr_done = !can_set_sr || side.effects[PBEffects::StealthRock]
      spikes_done = !can_set_spikes || (side.effects[PBEffects::Spikes] || 0) >= 3
      tspikes_done = !can_set_tspikes || (side.effects[PBEffects::ToxicSpikes] || 0) >= 2

      hazards_maxed = sr_done && spikes_done && tspikes_done
      if hazards_maxed
        # Only switch if a replacement has a meaningfully better matchup
        has_better_matchup = reserves.any? do |pkmn|
          next false unless pkmn && pkmn.able?
          score = 0
          battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
            opp = battle.battlers[opp_idx]
            next unless opp && !opp.fainted?
            pkmn.moves.each do |m|
              next unless m
              move_data = GameData::Move.try_get(m.id)
              next unless move_data && move_data.power > 0
              type_mod = Effectiveness.calculate(move_data.type, *opp.types)
              score += 15 if Effectiveness.super_effective?(type_mod)
            end
          end
          next score >= 15
        end
        if has_better_matchup
          AdvancedBattleAI.log("Hazard setter job done, replacement has better matchup", :decisions)
          next true
        end
      end

    when Battle::AI::Roles::SCREEN_SETTER
      # Screen setter when screens are up
      side = battler.pbOwnSide
      screens_up = side.effects[PBEffects::Reflect] > 0 ||
                   side.effects[PBEffects::LightScreen] > 0 ||
                   side.effects[PBEffects::AuroraVeil] > 0
      if screens_up
        # Only switch if a replacement has a better matchup
        has_better_matchup = reserves.any? do |pkmn|
          next false unless pkmn && pkmn.able?
          score = 0
          battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
            opp = battle.battlers[opp_idx]
            next unless opp && !opp.fainted?
            pkmn.moves.each do |m|
              next unless m
              move_data = GameData::Move.try_get(m.id)
              next unless move_data && move_data.power > 0
              type_mod = Effectiveness.calculate(move_data.type, *opp.types)
              score += 15 if Effectiveness.super_effective?(type_mod)
            end
          end
          next score >= 15
        end
        if has_better_matchup
          AdvancedBattleAI.log("Screen setter job done, replacement has better matchup", :decisions)
          next true
        end
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
    pivot_works = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # For damaging pivots, check type effectiveness
      if pivot_move.function_code == "SwitchOutUserDamagingMove"
        type_mod = Effectiveness.calculate(pivot_move.type, *opp.types)
        if type_mod > 0
          AdvancedBattleAI.log("Prefer pivot move (#{pivot_move.name}) over hard switch", :decisions)
          pivot_works = true
          break
        end
      else
        # Status pivots always work (Parting Shot, Teleport)
        AdvancedBattleAI.log("Prefer status pivot move over hard switch", :decisions)
        pivot_works = true
        break
      end
    end

    next pivot_works
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
        has_sweeper = reserves.any? do |pkmn|
          next false unless pkmn && pkmn.able?
          role = ai.estimate_pokemon_role(pkmn)
          role == Battle::AI::Roles::SETUP_SWEEPER
        end
        if has_sweeper
          AdvancedBattleAI.log("Allowing sacrifice to bring in sweeper", :decisions)
          next true
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
# Uses actual damage estimation instead of raw type*power
#===============================================================================
Battle::AI::Handlers::ShouldSwitch.add(:advanced_type_disadvantage,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)
    next false unless ai.trainer.high_skill?

    # === SAFEGUARDS ===
    next false if should_avoid_switching?(battler, ai)

    # Only switch if we have decent HP (switching at low HP is usually bad)
    next false if battler.hp < battler.totalhp * 0.4

    # Don't switch if we can KO any opponent this turn
    can_ko_any = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      dmg = best_move_damage(battler, opp)
      if dmg >= opp.hp
        can_ko_any = true
        break
      end
      # Also check: if we outspeed and deal > 50%, don't switch
      ai_us = ai.battlers[battler.index]
      ai_them = ai.battlers[opp_idx]
      if ai_us && ai_them && ai_us.faster_than?(ai_them) && dmg > opp.totalhp * 0.5
        can_ko_any = true
        break
      end
    end
    next false if can_ko_any

    # Check if we're truly dominated using actual damage estimation
    dominated = true
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Check our best actual damage against this opponent
      our_best_dmg = best_move_damage(battler, opp)

      # If we can deal > 33% of their HP, we're contributing meaningfully
      if our_best_dmg > opp.totalhp * 0.33
        dominated = false
        break
      end

      # Check if opponent can actually KO us in 1-2 turns (actual damage)
      opp_best_dmg = best_move_damage(opp, battler)

      # If opponent can't 2HKO us, we're not truly dominated
      if opp_best_dmg * 2 < battler.hp
        dominated = false
        break
      end
    end

    if dominated
      # Factor entry hazard cost into switch decision
      our_side = battler.pbOwnSide
      hazard_penalty = calculate_hazard_entry_damage_fraction(battler, our_side)
      # If re-entry would cost > 25% HP, heavily penalize switching
      hazard_cost_high = hazard_penalty >= 0.25

      # Check if we have a significantly better option
      best_reserve_score = 0
      reserves.each do |pkmn|
        next unless pkmn && pkmn.able?

        reserve_score = 0

        # Subtract entry hazard cost for the replacement
        replacement_hazard = calculate_hazard_entry_damage_fraction(pkmn, our_side)
        reserve_score -= (replacement_hazard * 100).to_i

        battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
          opp = battle.battlers[opp_idx]
          next unless opp && !opp.fainted?

          # Defensive: how well does reserve handle opponent's attacks?
          opp.moves.each do |m|
            next unless m && m.damagingMove?
            type_mod = Effectiveness.calculate(m.type, *pkmn.types)
            if type_mod == 0
              reserve_score += 40  # Immunity
            elsif Effectiveness.not_very_effective?(type_mod)
              reserve_score += 20
            elsif Effectiveness.super_effective?(type_mod)
              reserve_score -= 15
            end
          end

          # Offensive: can replacement threaten back?
          pkmn.moves.each do |m|
            next unless m
            move_data = GameData::Move.try_get(m.id)
            next unless move_data && move_data.power > 0
            type_mod = Effectiveness.calculate(move_data.type, *opp.types)
            if Effectiveness.super_effective?(type_mod)
              # Extra credit for STAB SE
              if pkmn.types.include?(move_data.type)
                reserve_score += 25
              else
                reserve_score += 15
              end
            end
          end
        end

        best_reserve_score = [best_reserve_score, reserve_score].max
      end

      # Require clearly better option (raised from 30 to 50)
      # If hazard cost is high, require even more advantage
      threshold = hazard_cost_high ? 70 : 50
      if best_reserve_score >= threshold
        AdvancedBattleAI.log("Switching: dominated by matchup (score #{best_reserve_score} >= #{threshold}), better option available", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# Enhanced Replacement Pokemon Rating
# Multi-category scoring inspired by Rejuvenation's 8-category system:
#   Defensive, Offensive, Speed, Entry Hazards, Role, Memory
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

    opponents = @battle.pbGetOpposingIndicesInOrder(idxBattler)

    #---------------------------------------------------------------------------
    # 1. Defensive score: Can it survive the opponent's likely next attack?
    #---------------------------------------------------------------------------
    opponents.each do |opp_idx|
      opp = @battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Estimate best damage opponent deals to this replacement
      opp_best_dmg = 0
      opp.moves.each do |m|
        next unless m && m.damagingMove?
        move_data = GameData::Move.try_get(m.id)
        next unless move_data
        # Simplified damage calc against party pkmn
        base_power = move_data.power
        base_power = 60 if base_power == 1
        if move_data.category == 0
          atk = opp.attack
          dfn = pkmn.baseStats[:DEFENSE] * pkmn.level / 50.0
        else
          atk = opp.spatk
          dfn = pkmn.baseStats[:SPECIAL_DEFENSE] * pkmn.level / 50.0
        end
        dfn = [dfn, 1].max
        dmg = ((2 * opp.level / 5.0 + 2) * base_power * atk / dfn / 50.0 + 2).floor
        # STAB
        dmg = (dmg * 1.5).floor if opp.types.include?(move_data.type)
        # Type effectiveness
        type_mod = Effectiveness.calculate(move_data.type, *pkmn.types)
        dmg = (dmg * type_mod / Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER).floor
        opp_best_dmg = dmg if dmg > opp_best_dmg
      end

      if pkmn.totalhp > 0
        dmg_fraction = opp_best_dmg.to_f / pkmn.totalhp
        if dmg_fraction < 0.25
          score += 50  # Tanks the hit very well
        elsif dmg_fraction < 0.50
          score += 30  # Survives comfortably
        elsif dmg_fraction >= 1.0
          score -= 30  # Gets OHKOed — bad switch-in
        elsif dmg_fraction >= 0.75
          score -= 15  # Takes heavy damage
        end
      end
    end

    #---------------------------------------------------------------------------
    # 2. Offensive score: Can it threaten the opponent?
    #---------------------------------------------------------------------------
    opponents.each do |opp_idx|
      opp = @battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      pkmn.moves.each do |m|
        next unless m
        move_data = GameData::Move.try_get(m.id)
        next unless move_data && move_data.power > 0
        type_mod = Effectiveness.calculate(move_data.type, *opp.types)
        if Effectiveness.super_effective?(type_mod)
          if pkmn.types.include?(move_data.type)
            score += 30  # SE STAB — strong threat
          else
            score += 15  # SE non-STAB
          end
          break  # Only count best offensive matchup per opponent
        end
      end
    end

    #---------------------------------------------------------------------------
    # 3. Speed factor: Faster replacements are more valuable offensively
    #---------------------------------------------------------------------------
    opponents.each do |opp_idx|
      opp = @battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      pkmn_speed = pkmn.baseStats[:SPEED] * pkmn.level / 50.0
      if pkmn_speed > opp.speed
        score += 10  # Outspeeds — can act first
      elsif pkmn_speed < opp.speed * 0.5
        score -= 5   # Much slower — risky
      end
    end

    #---------------------------------------------------------------------------
    # 4. Entry hazard penalty: Subtract proportional HP loss from hazards
    #---------------------------------------------------------------------------
    our_side = @battle.sides[idxBattler % 2]
    hazard_fraction = calculate_hazard_entry_damage_fraction(pkmn, our_side)
    score -= (hazard_fraction * 120).to_i  # e.g., 50% SR damage = -60

    #---------------------------------------------------------------------------
    # 5. Role relevance (kept from original, slightly adjusted)
    #---------------------------------------------------------------------------
    estimated_role = estimate_pokemon_role(pkmn)

    case estimated_role
    when Battle::AI::Roles::HAZARD_SETTER
      side = @battle.sides[idxBattler % 2 == 0 ? 1 : 0]
      score += 15 unless side.effects[PBEffects::StealthRock]

    when Battle::AI::Roles::HAZARD_REMOVER
      side = @battle.sides[idxBattler % 2]
      hazard_count = 0
      hazard_count += 1 if side.effects[PBEffects::StealthRock]
      hazard_count += (side.effects[PBEffects::Spikes] || 0)
      hazard_count += (side.effects[PBEffects::ToxicSpikes] || 0)
      hazard_count += 1 if side.effects[PBEffects::StickyWeb]
      score += hazard_count * 10

    when Battle::AI::Roles::SWEEPER, Battle::AI::Roles::SETUP_SWEEPER
      remaining_opponents = opponents.count do |i|
        b = @battle.battlers[i]
        b && !b.fainted?
      end
      score += 15 if remaining_opponents <= 2
      score -= 10 if remaining_opponents >= 4

    when Battle::AI::Roles::CLERIC
      party = @battle.pbParty(idxBattler)
      status_count = party.count { |p| p && p.able? && p.status != :NONE }
      score += status_count * 10
    end

    #---------------------------------------------------------------------------
    # 6. Intimidate switching bonus/penalty
    #---------------------------------------------------------------------------
    if AdvancedBattleAI.feature_enabled?(:items, @trainer)
      pkmn_abilities = []
      species_data = pkmn.species_data rescue nil
      if species_data
        pkmn_abilities = (species_data.abilities || []) + (species_data.hidden_abilities || [])
      end

      if pkmn_abilities.include?(:INTIMIDATE)
        opponents.each do |opp_idx|
          opp = @battle.battlers[opp_idx]
          next unless opp && !opp.fainted?

          # Bonus if opponent is primarily physical
          if opp.attack > opp.spatk * 1.3
            # Check if opponent has Defiant/Competitive (avoid triggering)
            opp_ability = nil
            if @memory
              opp_ability = @memory.get_known_ability(opp_idx)
              opp_ability ||= @memory.predict_ability(opp)
            end

            if [:DEFIANT, :COMPETITIVE].include?(opp_ability)
              score -= 30
              AdvancedBattleAI.log("Intimidate penalty: opponent has #{opp_ability}", :decisions)
            else
              score += 25
              AdvancedBattleAI.log("Intimidate bonus vs physical attacker", :decisions)
            end
          end
        end
      end
    end

    #---------------------------------------------------------------------------
    # 7. Memory integration: Check known moves for dangerous ones
    #---------------------------------------------------------------------------
    if @memory
      opponents.each do |opp_idx|
        opp = @battle.battlers[opp_idx]
        next unless opp && !opp.fainted?

        known_moves = @memory.get_known_moves(opp_idx)
        known_moves.each do |move_id|
          move_data = GameData::Move.try_get(move_id)
          next unless move_data && move_data.power > 0

          type_mod = Effectiveness.calculate(move_data.type, *pkmn.types)
          if type_mod == 0
            score += 25  # Immunity to a known move
          elsif Effectiveness.not_very_effective?(type_mod)
            score += 10
          elsif Effectiveness.super_effective?(type_mod)
            score -= 15
          end
        end

        # Use damage history to estimate threat when moves aren't fully known
        if known_moves.length < 2
          [:PHYSICAL, :SPECIAL].each do |dmg_type|
            hist_damage = @memory.estimate_damage_from_history(opp_idx, idxBattler, dmg_type)
            next unless hist_damage && hist_damage > 0
            dmg_fraction = hist_damage.to_f / pkmn.totalhp
            if dmg_fraction >= 0.5
              score -= 10  # Opponent dealt heavy damage of this type
            end
          end
        end
      end
    end

    AdvancedBattleAI.log("Replacement #{pkmn.name}: score #{score}", :decisions)
    return score
  end
end

#===============================================================================
# "Can KO This Turn" ShouldNotSwitch Handler
# If we can KO the opponent (outspeed + KO or priority + KO), don't switch.
# If opponent is very low HP (<30%), strongly discourage switching.
#===============================================================================
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_can_ko_opponent,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)

    dominated_by_ko = false

    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      best_dmg = 0
      has_priority_ko = false

      battler.moves.each do |m|
        next unless m && m.damagingMove?
        move_data = GameData::Move.try_get(m.id)
        next unless move_data

        dmg = estimate_switch_damage(move_data, battler, opp)

        # Check priority moves separately
        if move_data.priority > 0 && dmg >= opp.hp
          has_priority_ko = true
        end

        best_dmg = dmg if dmg > best_dmg
      end

      # Priority KO — never switch
      if has_priority_ko
        AdvancedBattleAI.log("Don't switch: priority move can KO #{opp.name}", :decisions)
        dominated_by_ko = true
        break
      end

      # We outspeed and can KO — never switch
      ai_us = ai.battlers[battler.index]
      ai_them = ai.battlers[opp_idx]
      if ai_us && ai_them && ai_us.faster_than?(ai_them) && best_dmg >= opp.hp
        AdvancedBattleAI.log("Don't switch: outspeed and can KO #{opp.name}", :decisions)
        dominated_by_ko = true
        break
      end

      # Opponent is at very low HP — heavily discourage switching
      if opp.hp < opp.totalhp * 0.3 && best_dmg > 0
        AdvancedBattleAI.log("Don't switch: #{opp.name} at <30% HP and we have damaging moves", :decisions)
        dominated_by_ko = true
        break
      end
    end

    next dominated_by_ko
  }
)

#===============================================================================
# Entry Hazard Cost ShouldNotSwitch Handler
# Discourage switching when hazards on our side would punish re-entry later.
# This considers the CURRENT battler's future re-entry cost.
#===============================================================================
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_entry_hazard_cost,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)

    our_side = battler.pbOwnSide
    hazard_fraction = calculate_hazard_entry_damage_fraction(battler, our_side)

    # No hazards or immune to them — no reason to block switch
    next false if hazard_fraction <= 0

    # If hazard damage would KO us on re-entry, strongly discourage switching
    future_hp = battler.hp - (battler.totalhp * hazard_fraction).to_i
    if future_hp <= 0
      AdvancedBattleAI.log("Don't switch: hazards would KO #{battler.name} on re-entry", :decisions)
      next true
    end

    # If hazard damage > 25% of our total HP, discourage switching
    if hazard_fraction >= 0.25
      AdvancedBattleAI.log("Don't switch: hazards deal #{(hazard_fraction * 100).to_i}% to #{battler.name} on re-entry", :decisions)
      next true
    end

    next false
  }
)

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
    should_switch = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      break if should_switch
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
            should_switch = true
            break
          end
        end
      end
    end

    next should_switch
  }
)

#===============================================================================
# Perish Song Awareness — Switch out when Perish count reaches 1
#===============================================================================
Battle::AI::Handlers::ShouldSwitch.add(:advanced_perish_song_escape,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:sacrifice, ai.trainer)

    # If Perish Song count is at 1, we faint next turn — switch out
    perish_count = battler.effects[PBEffects::PerishSong] rescue 0
    if perish_count == 1 && reserves.any? { |p| p && p.able? }
      AdvancedBattleAI.log("Perish Song: switching out at count 1", :decisions)
      next true
    end

    next false
  }
)

#===============================================================================
# Perish Song Awareness — Don't switch if opponent is about to perish
#===============================================================================
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_perish_song_stay,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:sacrifice, ai.trainer)

    our_perish = battler.effects[PBEffects::PerishSong] rescue 0
    # If we're not under Perish Song, check if opponent is
    if our_perish == 0
      opponent_perishing = false
      battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        opp_perish = opp.effects[PBEffects::PerishSong] rescue 0
        if opp_perish > 0 && opp_perish <= 2
          AdvancedBattleAI.log("Perish Song: staying in, opponent perishes in #{opp_perish} turns", :decisions)
          opponent_perishing = true
          break
        end
      end
      next true if opponent_perishing
    end

    next false
  }
)

#===============================================================================
# No-Threat Anti-Loop Handler
# If every opponent has no damaging moves (or all known moves are status),
# there is zero reason to switch — just stay in and attack/stall.
# Also prevents switching loops when the AI keeps flip-flopping.
#===============================================================================
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_no_threat_anti_loop,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)

    # Check if ANY opponent can deal damage to us
    any_threat = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # If we know all 4 moves and none are damaging, opponent is no threat
      known_moves = ai.memory ? ai.memory.get_known_moves(opp_idx) : []
      if known_moves.length >= 4
        has_damage = known_moves.any? do |move_id|
          md = GameData::Move.try_get(move_id)
          md && md.power > 0
        end
        next unless has_damage  # This opponent is harmless, check next
      end

      # If we don't know all moves, check the ones we do know + assume unknown could be damaging
      if known_moves.length < 4
        # Check the opponent's actual moveset if it's an AI trainer Pokemon (AI knows its own)
        if !opp.pbOwnedByPlayer?
          has_damage = opp.moves.any? { |m| m && m.damagingMove? }
          next unless has_damage
        else
          # Player Pokemon — we don't know all moves, assume could be a threat
          any_threat = true
          break
        end
      end

      any_threat = true
      break
    end

    unless any_threat
      AdvancedBattleAI.log("Don't switch: no opponent can deal damage", :decisions)
      next true
    end

    # Anti-loop: if we just switched in last turn, don't switch again
    if battler.turnCount <= 1
      switch_count = ai.memory ? ai.memory.get_switch_count(battler.index) : 0
      if switch_count >= 2
        AdvancedBattleAI.log("Don't switch: anti-loop (switched #{switch_count} times, just arrived)", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# Perish Song Move Scoring — Boost if opponent is trapped/last Pokemon
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_perish_song_usage,
  proc { |score, move, user, ai, battle|
    next score unless move.function_code == "StartPerishCountsForAllBattlers"
    next score unless AdvancedBattleAI.feature_enabled?(:sacrifice, ai.trainer)

    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Already under Perish Song — don't use again
      if (opp.effects[PBEffects::PerishSong] rescue 0) > 0
        score -= 30
        next
      end

      # Opponent is trapped (Mean Look, etc.) — Perish Song is very strong
      is_trapped = (opp.effects[PBEffects::Trapping] > 0 ||
                    opp.effects[PBEffects::MeanLook] > 0 ||
                    opp.effects[PBEffects::JawLock] > 0) rescue false
      if is_trapped
        score += AdvancedBattleAI::SCORE_MAJOR_BONUS
        AdvancedBattleAI.log("Perish Song: bonus vs trapped opponent", :scoring)
      end

      # Opponent is last Pokemon — can't switch out
      opp_remaining = AdvancedBattleAI.count_remaining_pokemon(battle, opp_idx)
      if opp_remaining == 1
        score += AdvancedBattleAI::SCORE_MAJOR_BONUS
        AdvancedBattleAI.log("Perish Song: bonus vs last opponent Pokemon", :scoring)
      end
    end

    next score
  }
)
