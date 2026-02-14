#===============================================================================
# Advanced Battle AI - Item & Ability Awareness (Phase 3)
# Choice lock exploitation, Focus Sash/Sturdy, Intimidate pivots, recovery items
#===============================================================================

#===============================================================================
# 1. Choice Lock Exploitation
# If opponent is Choice-locked into a move we resist/are immune to, stay in.
# If locked into a move that threatens us, prefer switching to a resist.
#===============================================================================

# Score bonus for staying in against a Choice-locked opponent
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_choice_exploitation,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:items, ai.trainer)
    next score unless ai.memory

    locked_move_id = ai.memory.get_choice_locked_move(target.index)
    next score unless locked_move_id

    locked_data = GameData::Move.try_get(locked_move_id)
    next score unless locked_data

    # Check how the locked move interacts with us
    type_mod = Effectiveness.calculate(locked_data.type, *user.battler.types)

    if type_mod == 0
      # We're immune to their locked move — huge advantage staying in
      score += 20
      AdvancedBattleAI.log("Choice lock: immune to #{locked_data.name}, staying in", :scoring)
    elsif Effectiveness.not_very_effective?(type_mod)
      # We resist their locked move
      score += 10
      AdvancedBattleAI.log("Choice lock: resist #{locked_data.name}", :scoring)
    elsif Effectiveness.super_effective?(type_mod)
      # Their locked move hits us hard — we want to switch (handled by ShouldSwitch below)
      score -= 10
    end

    next score
  }
)

# Switch to exploit an opponent's Choice lock
Battle::AI::Handlers::ShouldSwitch.add(:advanced_exploit_choice_lock,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:items, ai.trainer)
    next false unless ai.memory

    # Check each opponent for Choice lock
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      locked_move_id = ai.memory.get_choice_locked_move(opp_idx)
      next unless locked_move_id

      locked_data = GameData::Move.try_get(locked_move_id)
      next unless locked_data && locked_data.power > 0

      # Only switch if the locked move actually threatens us
      type_mod = Effectiveness.calculate(locked_data.type, *battler.types)
      next unless Effectiveness.super_effective?(type_mod)

      # Check if we have a reserve that's immune or resists the locked move
      reserves.each do |pkmn|
        next unless pkmn && pkmn.able?
        res_type_mod = Effectiveness.calculate(locked_data.type, *pkmn.types)
        if res_type_mod == 0 || Effectiveness.not_very_effective?(res_type_mod)
          AdvancedBattleAI.log("Switch to exploit Choice lock: #{pkmn.name} resists #{locked_data.name}", :decisions)
          next true
        end
      end
    end

    next false
  }
)

# Don't switch out if opponent is Choice-locked into something we resist
Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_resist_choice_lock,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:items, ai.trainer)
    next false unless ai.memory

    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      locked_move_id = ai.memory.get_choice_locked_move(opp_idx)
      next unless locked_move_id

      locked_data = GameData::Move.try_get(locked_move_id)
      next unless locked_data

      type_mod = Effectiveness.calculate(locked_data.type, *battler.types)
      if type_mod == 0
        AdvancedBattleAI.log("Don't switch: immune to Choice-locked #{locked_data.name}", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# 2. Focus Sash / Sturdy Awareness
# Don't waste strong moves on full-HP targets with Sash/Sturdy.
# Prefer chip damage, multi-hit, or priority to break Sash first.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_sash_sturdy_awareness,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:items, ai.trainer)
    next score unless ai.memory

    target_battler = target.battler

    # Only relevant at full HP (Sash/Sturdy require full HP)
    next score unless target_battler.hp == target_battler.totalhp

    # Check if entry hazards are on their side (breaks Sash on entry)
    opp_side = target_battler.pbOwnSide
    has_hazards = opp_side.effects[PBEffects::StealthRock] ||
                  (opp_side.effects[PBEffects::Spikes] || 0) > 0
    next score if has_hazards  # Sash already broken by hazards

    # Check if target has known/predicted Sash or Sturdy
    known_item = ai.memory.get_known_item(target.index)
    known_ability = ai.memory.get_known_ability(target.index)
    predicted_item = ai.memory.predict_item(target_battler) if ai.trainer.skill >= 80

    has_sash = known_item == :FOCUSSASH || predicted_item == :FOCUSSASH
    has_sturdy = known_ability == :STURDY ||
                 (ai.memory.predict_ability(target_battler) == :STURDY && ai.trainer.skill >= 80)

    # If Sash was already consumed, no adjustment needed
    has_sash = false if ai.memory.item_consumed?(target.index)

    next score unless has_sash || has_sturdy

    # Multi-hit moves bypass Sash/Sturdy
    multi_hit_functions = [
      "HitTwoToFiveTimes",          # Bullet Seed, Icicle Spear, etc.
      "HitTwoToFiveTimesOrThreeForAshGreninja",
      "HitThreeTimesAlwaysCriticalHit",  # Surging Strikes
      "HitTwoTimes",                # Double Hit, Dragon Darts
      "HitThreeTimesDoubleDamageIfTargetPoisoned"  # Triple Axel-ish
    ]
    if multi_hit_functions.include?(move.function_code)
      score += 20
      AdvancedBattleAI.log("Multi-hit move vs Sash/Sturdy", :scoring)
      next score
    end

    # Fake Out is great for breaking Sash
    if move.function_code == "FlinchTargetFailsIfNotUserFirstTurn"
      score += 20
      AdvancedBattleAI.log("Fake Out vs Sash/Sturdy", :scoring)
      next score
    end

    # Mold Breaker abilities ignore Sturdy
    mold_breaker_abilities = [:MOLDBREAKER, :TERAVOLT, :TURBOBLAZE]
    if has_sturdy && !has_sash
      user_ability = user.battler.ability_id rescue nil
      if mold_breaker_abilities.include?(user_ability)
        next score  # No penalty, we ignore Sturdy
      end
    end

    # Penalize strong moves that would waste their power leaving target at 1 HP
    if move.damagingMove? && move.move.power >= 80
      score -= 15
      AdvancedBattleAI.log("Penalize strong move vs Sash/Sturdy (wasted power)", :scoring)
    end

    # Bonus for weak chip moves or priority (to break Sash then KO)
    if move.damagingMove? && move.move.power > 0 && move.move.power <= 60
      score += 8
    end

    # Bonus for hazard-setting moves (breaks Sash for next switch-in)
    hazard_functions = [
      "AddStealthRocksToFoeSide", "AddSpikesToFoeSide",
      "AddToxicSpikesToFoeSide", "AddStickyWebToFoeSide"
    ]
    if hazard_functions.include?(move.function_code)
      score += 10
      AdvancedBattleAI.log("Hazard move bonus: breaks Sash on future entry", :scoring)
    end

    next score
  }
)

#===============================================================================
# 3. Intimidate Pivot Handler
# Switch in Intimidate users against physical attackers strategically
#===============================================================================
Battle::AI::Handlers::ShouldSwitch.add(:advanced_intimidate_pivot,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:items, ai.trainer)

    # Don't switch if we have boosts or are trapped
    next false if should_avoid_switching?(battler, ai)

    # Only switch if we have decent HP
    next false if battler.hp < battler.totalhp * 0.5

    # Don't switch if we can KO
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

    # Check if current opponent is a physical attacker threatening us
    physical_threat = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      # Physical attacker check: Atk > SpAtk * 1.3
      next unless opp.attack > opp.spatk * 1.3

      # Check if they're dealing significant physical damage to us
      opp_best_phys = 0
      opp.moves.each do |m|
        next unless m && m.damagingMove?
        move_data = GameData::Move.try_get(m.id)
        next unless move_data && move_data.category == 0  # Physical
        dmg = estimate_switch_damage(move_data, opp, battler)
        opp_best_phys = dmg if dmg > opp_best_phys
      end

      if opp_best_phys > battler.totalhp * 0.3
        physical_threat = true
        break
      end
    end
    next false unless physical_threat

    # Check if we have an Intimidate user in reserves
    reserves.each do |pkmn|
      next unless pkmn && pkmn.able?

      species_data = pkmn.species_data rescue nil
      next unless species_data

      abilities = (species_data.abilities || []) + (species_data.hidden_abilities || [])
      next unless abilities.include?(:INTIMIDATE)

      # Check opponent doesn't have Defiant/Competitive
      safe_to_intimidate = true
      battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        opp_ability = nil
        if ai.memory
          opp_ability = ai.memory.get_known_ability(opp_idx)
          opp_ability ||= ai.memory.predict_ability(opp)
        end
        if [:DEFIANT, :COMPETITIVE].include?(opp_ability)
          safe_to_intimidate = false
          break
        end
      end

      if safe_to_intimidate
        AdvancedBattleAI.log("Intimidate pivot: switching to #{pkmn.name} vs physical threat", :decisions)
        next true
      end
    end

    next false
  }
)

#===============================================================================
# 4. Recovery Item Awareness
# Factor opponent's passive recovery into scoring.
# Bonus for Knock Off, prefer moves that outpace recovery.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_recovery_item_awareness,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:items, ai.trainer)
    next score unless ai.memory

    target_battler = target.battler

    # Check if target has Leftovers/Black Sludge
    known_item = ai.memory.get_known_item(target.index)
    predicted_item = nil
    predicted_item = ai.memory.predict_item(target_battler) if ai.trainer.skill >= 80

    recovery_items = [:LEFTOVERS, :BLACKSLUDGE]
    has_recovery = recovery_items.include?(known_item) || recovery_items.include?(predicted_item)

    next score unless has_recovery

    # Knock Off removes their recovery item
    if move.function_code == "RemoveTargetItem"
      score += 15
      AdvancedBattleAI.log("Knock Off bonus: removes recovery item", :scoring)
      next score
    end

    # Trick/Switcheroo can swap items
    if move.function_code == "UserTargetSwapItems"
      score += 10
      AdvancedBattleAI.log("Trick/Switcheroo bonus vs recovery item", :scoring)
      next score
    end

    # Bonus for strong attacks that outpace recovery (Leftovers heals 1/16 = 6.25%)
    if move.damagingMove? && move.move.power > 0
      # Estimate damage fraction using shared utility
      move_data = GameData::Move.try_get(move.id)
      est_dmg = move_data ? AdvancedBattleAI.estimate_damage_battler(move_data, user.battler, target_battler, battle) : 0

      dmg_fraction = est_dmg.to_f / target_battler.totalhp

      if dmg_fraction > 0.12
        # Move outpaces recovery meaningfully
        score += 8
      elsif dmg_fraction <= 0.0625 && dmg_fraction > 0
        # Move barely outpaces or loses to recovery — deprioritize
        score -= 5
        AdvancedBattleAI.log("Weak move vs Leftovers holder — recovery outpaces", :scoring)
      end
    end

    next score
  }
)

