#===============================================================================
# Advanced Battle AI - Double Battle Coordination
# Partner synergy, threat assessment, and coordinated targeting
#===============================================================================

#===============================================================================
# Partner Synergy Detection
# Detects beneficial ability interactions for doubles
#===============================================================================
module AdvancedBattleAI
  # Abilities that benefit from being hit by specific types
  ABSORPTION_ABILITIES = {
    :FLASHFIRE      => :FIRE,
    :VOLTABSORB     => :ELECTRIC,
    :LIGHTNINGROD   => :ELECTRIC,
    :MOTORDRIVE     => :ELECTRIC,
    :WATERABSORB    => :WATER,
    :STORMDRAIN     => :WATER,
    :DRYSKIN        => :WATER,
    :SAPSIPPER      => :GRASS,
    :EARTHEATER     => :GROUND
  }

  # Abilities that are immune to specific types
  IMMUNITY_ABILITIES = {
    :LEVITATE       => :GROUND,
    :FLASHFIRE      => :FIRE,
    :HEATPROOF      => :FIRE,  # Partial
    :WATERABSORB    => :WATER,
    :DRYSKIN        => :WATER,
    :VOLTABSORB     => :ELECTRIC,
    :MOTORDRIVE     => :ELECTRIC,
    :LIGHTNINGROD   => :ELECTRIC,
    :SAPSIPPER      => :GRASS,
    :SOUNDPROOF     => :SOUND,  # Sound-based moves
    :BULLETPROOF    => :BULLET  # Ball/bomb moves
  }

  # Check if partner benefits from being hit by a move type
  def self.partner_benefits_from_type?(partner, move_type)
    return false unless partner && partner.ability
    ability = partner.ability_id
    return ABSORPTION_ABILITIES[ability] == move_type
  end

  # Check if partner is immune to a move type via ability
  def self.partner_immune_to_type?(partner, move_type)
    return false unless partner && partner.ability
    ability = partner.ability_id
    return IMMUNITY_ABILITIES[ability] == move_type
  end
end

#===============================================================================
# Partner Synergy Move Scoring
# Boost moves that benefit partner through ability
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_partner_synergy,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:team_synergy, ai.trainer)

    # Get partner
    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    move_type = move.type

    # Check if targeting partner for beneficial effect
    if target.index == partner_idx
      if AdvancedBattleAI.partner_benefits_from_type?(partner, move_type)
        score += AdvancedBattleAI::PARTNER_SYNERGY_BONUS
        AdvancedBattleAI.log("Partner synergy: #{partner.ability_id} + #{move_type}", :scoring)
      end
    end

    # Check for spread moves hitting partner
    if move.move.target == :AllNonUsers || move.move.target == :AllBattlers
      if AdvancedBattleAI.partner_immune_to_type?(partner, move_type) ||
         AdvancedBattleAI.partner_benefits_from_type?(partner, move_type)
        score += 15  # Safe to use spread move
        AdvancedBattleAI.log("Spread move safe: partner immune/benefits", :scoring)
      elsif !partner.pbHasType?(move_type) && move.damagingMove?
        # Partner will take damage
        type_mod = Effectiveness.calculate(move_type, *partner.types)
        if Effectiveness.super_effective?(type_mod)
          score -= 30  # Big penalty for super effective on partner
          AdvancedBattleAI.log("Spread move hits partner super-effectively", :scoring)
        elsif type_mod > 0
          score -= 10  # Small penalty for hitting partner
          AdvancedBattleAI.log("Spread move hits partner", :scoring)
        end
      end
    end

    next score
  }
)

#===============================================================================
# Telepathy Awareness
# Don't hesitate to use spread moves if partner has Telepathy
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_telepathy_awareness,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.move.target == :AllNonUsers || move.move.target == :BothFoes

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    if partner.hasActiveAbility?(:TELEPATHY)
      score += 20  # Free to use spread moves
      AdvancedBattleAI.log("Telepathy: free spread move", :scoring)
    end

    next score
  }
)

#===============================================================================
# Threat Assessment in Doubles
# Evaluates combined threat from both opponents
#===============================================================================
class Battle::AI
  # Calculate threat level of a battler
  def calculate_threat_level(battler, perspective_battler)
    return 0 unless battler && !battler.fainted?

    threat = 0

    # Base threat from stats
    offensive = [battler.attack, battler.spatk].max
    speed = battler.speed

    # Speed advantage
    if speed > perspective_battler.speed
      threat += 15
    end

    # Check for super-effective coverage
    battler.moves.each do |move|
      next unless move && move.damagingMove?
      type_mod = Effectiveness.calculate(move.type, *perspective_battler.types)
      if Effectiveness.super_effective?(type_mod)
        threat += 20 + (move.power / 5)
      end
    end

    # Boost threat based on known dangerous moves
    if @memory
      known = @memory.get_known_moves(battler.index)
      known.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data

        # High power moves are scary
        if move_data.power >= 100
          threat += 10
        end

        # Priority moves are scarier
        if move_data.priority > 0 && move_data.power > 0
          threat += 15
        end

        # Setup moves mean they could become a bigger threat
        if move_data.function_code.match?(/RaiseUser/)
          threat += 10
        end
      end
    end

    # Current HP affects threat (low HP = less threat)
    threat = (threat * battler.hp.to_f / battler.totalhp).to_i

    return threat
  end

  # Get the more threatening opponent
  def get_primary_threat(user)
    return nil unless @battle.doubleBattle?

    threats = []
    @battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = @battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      threat_level = calculate_threat_level(opp, user.battler)
      threats.push({ index: opp_idx, threat: threat_level })
    end

    threats.sort_by! { |t| -t[:threat] }
    return threats.first
  end
end

#===============================================================================
# Coordinated Targeting Handler
# Prefer focusing down the higher threat
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_threat_targeting,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)
    next score unless move.damagingMove?

    primary_threat = ai.get_primary_threat(user)
    next score unless primary_threat

    if target.index == primary_threat[:index]
      score += 10  # Prefer targeting primary threat
      AdvancedBattleAI.log("Targeting primary threat", :scoring)
    end

    next score
  }
)

#===============================================================================
# Protect Coordination in Doubles
# Coordinate protect with partner's actions
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_doubles_protect,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?

    protect_functions = [
      "ProtectUser", "ProtectUserFromTargetingMovesSpikyShield",
      "ProtectUserBanefulBunker", "ProtectUserFromDamagingMovesKingsShield"
    ]
    next score unless protect_functions.include?(move.function_code)

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Bonus if partner is likely using a spread move
    partner.moves.each do |m|
      next unless m
      if m.target == :AllNonUsers && m.damagingMove?
        score += 15
        AdvancedBattleAI.log("Protect while partner uses spread", :scoring)
        break
      end
    end

    # Check if opponent has Dynamax (protect is valuable)
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      is_dynamaxed = (opp.dynamax? rescue false)
      if is_dynamaxed
        score += 20
        AdvancedBattleAI.log("Protect vs Dynamax", :scoring)
        break
      end
    end

    next score
  }
)

#===============================================================================
# Follow Me / Rage Powder Coordination
# Use redirection to protect partner
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_redirection,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)

    redirect_functions = ["RedirectAllMovesToUser", "RedirectAllMovesToUserSleepTarget"]
    next score unless redirect_functions.include?(move.function_code)

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Value based on protecting partner
    partner_ai = ai.battlers[partner_idx]
    if partner_ai
      # Protect sweepers trying to set up
      if partner_ai.has_role?(Battle::AI::Roles::SETUP_SWEEPER) ||
         partner_ai.has_role?(Battle::AI::Roles::SWEEPER)
        score += 25
        AdvancedBattleAI.log("Redirect to protect sweeper", :scoring)
      end

      # Protect boosted partners
      if count_positive_stat_stages(partner_ai) >= 2
        score += 20
        AdvancedBattleAI.log("Redirect to protect boosted partner", :scoring)
      end

      # Protect low HP partner
      if partner.hp < partner.totalhp * 0.3
        score += 15
        AdvancedBattleAI.log("Redirect to protect low HP partner", :scoring)
      end
    end

    # Penalty if user is low HP (might faint from redirected attacks)
    if user.hp < user.totalhp * 0.25
      score -= 20
      AdvancedBattleAI.log("Redirect penalty: user is low HP", :scoring)
    end

    next score
  }
)

#===============================================================================
# Helping Hand Coordination
# Use Helping Hand when partner is attacking
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_helping_hand,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "PowerUpAllyMove"

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Check if partner has strong attacks
    best_power = 0
    partner.moves.each do |m|
      next unless m && m.damagingMove?
      best_power = [best_power, m.power].max
    end

    if best_power >= 80
      score += 25
      AdvancedBattleAI.log("Helping Hand for strong attacker", :scoring)
    elsif best_power >= 60
      score += 15
      AdvancedBattleAI.log("Helping Hand for decent attacker", :scoring)
    else
      score -= 10  # Partner doesn't have good attacks
      AdvancedBattleAI.log("Helping Hand penalty: partner's attacks are weak", :scoring)
    end

    # Bonus if partner is boosted
    partner_ai = ai.battlers[partner_idx]
    if partner_ai && count_positive_stat_stages(partner_ai) >= 2
      score += 15
      AdvancedBattleAI.log("Helping Hand for boosted partner", :scoring)
    end

    next score
  }
)

#===============================================================================
# Mat Block / Wide Guard Coordination
# Use team protection moves appropriately
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_wide_guard,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "ProtectUserSideFromMultiTargetDamagingMoves"

    # Check if opponents have spread moves
    has_spread_threat = false
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      opp.moves.each do |m|
        next unless m && m.damagingMove?
        if m.target == :AllNonUsers || m.target == :AllFoes || m.target == :AllBattlers
          has_spread_threat = true
          score += 15
          AdvancedBattleAI.log("Wide Guard vs spread move threat", :scoring)
          break
        end
      end
      break if has_spread_threat
    end

    # Check memory for known spread moves
    if ai.memory && !has_spread_threat
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        known_moves = ai.memory.get_known_moves(opp_idx)
        known_moves.each do |move_id|
          move_data = GameData::Move.try_get(move_id)
          next unless move_data && move_data.power > 0
          if [:AllNonUsers, :AllFoes, :AllBattlers].include?(move_data.target)
            score += 25
            has_spread_threat = true
            AdvancedBattleAI.log("Wide Guard vs known spread: #{move_id}", :scoring)
            break
          end
        end
        break if has_spread_threat
      end
    end

    # Penalty if no spread threat
    if !has_spread_threat
      score -= 30
      AdvancedBattleAI.log("Wide Guard penalty: no spread move threat detected", :scoring)
    end

    next score
  }
)

#===============================================================================
# Quick Guard Coordination
# Protect team from priority moves
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_quick_guard,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "ProtectUserSideFromPriorityMoves"

    # Check if opponents have priority moves
    has_priority_threat = false
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      opp.moves.each do |m|
        next unless m && m.damagingMove?
        if m.priority > 0
          has_priority_threat = true
          score += 10 + m.power / 5
          AdvancedBattleAI.log("Quick Guard vs priority threat", :scoring)
          break
        end
      end
      break if has_priority_threat
    end

    # Check memory for known priority
    if ai.memory && !has_priority_threat
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        if ai.memory.has_shown_priority?(opp_idx)
          score += 20
          has_priority_threat = true
          AdvancedBattleAI.log("Quick Guard vs remembered priority user", :scoring)
          break
        end
      end
    end

    # Penalty if no priority threat
    if !has_priority_threat
      score -= 30
      AdvancedBattleAI.log("Quick Guard penalty: no priority move threat detected", :scoring)
    end

    next score
  }
)

#===============================================================================
# Ally Switch Coordination
# Strategic position swapping
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_ally_switch,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "UserSwapsPositionsWithAlly"

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Check if switching positions would help
    # (e.g., redirect attacks to bulkier mon)

    # If partner is about to be hit by super-effective and user resists
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      opp.moves.each do |m|
        next unless m && m.damagingMove?

        partner_mod = Effectiveness.calculate(m.type, *partner.types)
        user_mod = Effectiveness.calculate(m.type, *user.types)

        # Ally Switch valuable if user resists what threatens partner
        if Effectiveness.super_effective?(partner_mod) && !Effectiveness.super_effective?(user_mod)
          score += 20
          AdvancedBattleAI.log("Ally Switch: take super-effective for partner", :scoring)
          break
        end
      end
    end

    # Also useful for disruption/mindgames at high skill
    if ai.trainer.best_skill?
      score += 5
      AdvancedBattleAI.log("Ally Switch: mindgame value at best skill", :scoring)
    end

    next score
  }
)

#===============================================================================
# Turn-order helper: does (move_a, battler_a) resolve before (move_b, battler_b)
# this round? Priority bracket first, then speed (Trick Room-aware via
# AIBattler#faster_than?). Doesn't touch the battle's live @priority array,
# since that isn't safely queryable mid-decision - this recomputes the same
# priority/speed rule from each battler's stats instead.
#===============================================================================
module AdvancedBattleAI
  def self.acts_before?(move_a, battler_a, move_b, battler_b)
    pri_a = move_a.pbPriority(battler_a.battler) rescue 0
    pri_b = move_b.pbPriority(battler_b.battler) rescue 0
    return pri_a > pri_b if pri_a != pri_b
    return battler_a.faster_than?(battler_b)
  end
end

#===============================================================================
# 6.1 Coordinated KO Timing
# Bonus for combined damage KOs in doubles. Uses the partner's actual
# committed move/target this round if it's already been chosen (earlier
# battler index in a doubles turn), falling back to a best-damage estimate
# only when the partner hasn't acted yet.
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_coordinated_ko,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)
    next score unless move.damagingMove?

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Estimate our damage
    our_damage = 0
    begin
      if ai.move
        ai.move.set_up(move.move) if move.respond_to?(:move)
        our_damage = ai.move.rough_damage
      end
    rescue StandardError
      next score
    end

    # Does the partner already have a real, committed choice this round?
    partner_choice = battle.choices[partner_idx]
    partner_move = nil
    partner_target_idx = nil
    if partner_choice && partner_choice[0] == :UseMove && partner_choice[2]
      partner_move = partner_choice[2]
      partner_target_idx = partner_choice[3]
    end

    if partner_target_idx && partner_target_idx >= 0 && partner_target_idx != target.index
      # Partner has already locked in a different target - no combined KO on
      # this one is possible, so don't credit this move for help that isn't coming.
      next score
    end

    # Partner's damage against this target. The shared ai.move object is
    # bound to the AI's current (user, target) for this handler call - it
    # can't safely be repointed at the partner mid-scoring - so this uses the
    # same standalone rough formula for the partner's estimate whether we're
    # using their real committed move or guessing across their movepool.
    partner_best_damage = 0
    candidate_moves = partner_move ? [partner_move] : partner.moves
    candidate_moves.each do |m|
      next unless m && (m.damagingMove? rescue false)
      m_power = m.power rescue 0
      next if m_power == 0
      target_battler = target.battler
      move_type = m.type rescue :NORMAL
      type_mod = Effectiveness.calculate(move_type, *target_battler.types) rescue 1.0
      stab = (partner.pbHasType?(move_type) rescue false) ? 1.5 : 1.0
      if (m.category rescue 0) == 0  # Physical
        atk = partner.attack
        dfn = [target_battler.defense, 1].max
      else
        atk = partner.spatk
        dfn = [target_battler.spdef, 1].max
      end
      est_dmg = ((2 * partner.level / 5.0 + 2) * m_power * atk / dfn / 50.0 + 2).floor
      est_dmg = (est_dmg * stab * type_mod / Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER).floor
      partner_best_damage = est_dmg if est_dmg > partner_best_damage
    end

    # acts_before? needs the AIBattler wrapper (for faster_than?), not the
    # raw battler `partner` used above for the plain stat/movepool reads.
    partner_ai_battler = ai.battlers[partner_idx]
    partner_acts_first = partner_move && partner_ai_battler &&
                          AdvancedBattleAI.acts_before?(partner_move, partner_ai_battler, move.move, user)

    if partner_acts_first && partner_best_damage >= target.hp
      # The partner's already-locked-in move alone secures the KO before we'd
      # even act - hitting this target too is wasted, so don't reward it and
      # lightly discourage piling on.
      score -= 10
      AdvancedBattleAI.log("Coordinated KO: partner already secures this KO first", :scoring)
      next score
    end

    # Combined damage KO - genuinely needs both hits, neither alone suffices
    if our_damage + partner_best_damage >= target.hp && our_damage < target.hp
      score += 20
      AdvancedBattleAI.log("Coordinated KO: combined damage secures KO", :scoring)
    end

    # KOing this target leaves only 1 opponent (2v1 advantage)
    if our_damage >= target.hp
      opp_count = 0
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        opp_count += 1 if opp && !opp.fainted?
      end
      if opp_count == 2  # This KO would make it 2v1
        score += 15
        AdvancedBattleAI.log("Coordinated KO: creates 2v1 advantage", :scoring)
      end
    end

    # Bonus for finishing a target that has already been hit this turn
    took_damage = (begin; target.battler.tookDamageThisRound; rescue; false; end)
    if took_damage
      score += 10
      AdvancedBattleAI.log("Coordinated KO: finishing damaged target", :scoring)
    end

    next score
  }
)

#===============================================================================
# 6.2 Speed Control Coordination
# Tailwind and speed-lowering moves in doubles context
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_speed_control_doubles,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    partner_ai = ai.battlers[partner_idx]
    next score unless partner_ai

    #---------------------------------------------------------------------------
    # Tailwind
    #---------------------------------------------------------------------------
    if move.function_code == "StartUserSideDoubleSpeed"
      # Check if Trick Room is active (Tailwind counterproductive)
      if battle.field.effects[PBEffects::TrickRoom] > 0
        score -= 20
        AdvancedBattleAI.log("Speed control: Tailwind penalty (Trick Room active)", :scoring)
        next score
      end

      # Check if partner is a sweeper/setup sweeper that's currently slower
      is_sweeper = partner_ai.has_role?(Battle::AI::Roles::SWEEPER) ||
                   partner_ai.has_role?(Battle::AI::Roles::SETUP_SWEEPER) rescue false

      # Check if partner is slower than opponents
      partner_slower_than_any = false
      partner_already_outspeeds_all = true
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        opp_ai = ai.battlers[opp_idx]
        next unless opp_ai && !opp_ai.battler.fainted?
        if opp_ai.faster_than?(partner_ai)
          partner_slower_than_any = true
          partner_already_outspeeds_all = false
        end
      end

      if is_sweeper && partner_slower_than_any
        score += 15
        AdvancedBattleAI.log("Speed control: Tailwind for slow sweeper partner", :scoring)
      elsif partner_already_outspeeds_all
        score -= 15
        AdvancedBattleAI.log("Speed control: Tailwind unnecessary (already fastest)", :scoring)
      end
    end

    #---------------------------------------------------------------------------
    # Icy Wind / Electroweb (LowerTargetSpeed1 and variants)
    #---------------------------------------------------------------------------
    speed_lower_functions = [
      "LowerTargetSpeed1", "LowerTargetSpeed1WeakerInGrassyTerrain",
      "LowerTargetSpeed1MakeTargetWeakerToFire", "PoisonTargetLowerTargetSpeed1"
    ]
    if speed_lower_functions.include?(move.function_code)
      # Check if our side has a speed disadvantage
      our_side_slower = false
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        opp_ai = ai.battlers[opp_idx]
        next unless opp_ai && !opp_ai.battler.fainted?
        if opp_ai.faster_than?(user) || opp_ai.faster_than?(partner_ai)
          our_side_slower = true
          break
        end
      end

      if our_side_slower
        score += 10
        AdvancedBattleAI.log("Speed control: speed-lowering bonus (speed disadvantage)", :scoring)
      end
    end

    next score
  }
)

#===============================================================================
# 6.3 Protect Prediction — Don't Double-Target Into Protect
# Uses move prediction to avoid wasting moves on Protecting targets
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_protect_prediction,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:move_prediction, ai.trainer)
    next score unless move.damagingMove? || move.statusMove?

    # Predict if target will use Protect
    prediction, pred_move, confidence = ai.predict_opponent_move(target.index)

    if prediction == AdvancedBattleAI::Prediction::PROTECT
      # Exception: Feint gets a bonus instead of penalty
      feint_functions = ["RemoveProtections", "RemoveProtectionsBypassSubstitute"]
      if feint_functions.include?(move.function_code)
        score += 25
        AdvancedBattleAI.log("Protect prediction: Feint bonus vs predicted Protect", :scoring)
      else
        # Penalize single-target moves against predicted Protect
        if confidence > 0.7
          score -= 25
          AdvancedBattleAI.log("Protect prediction: heavy penalty (high confidence)", :scoring)
        elsif confidence > 0.5
          score -= 15
          AdvancedBattleAI.log("Protect prediction: penalty (moderate confidence)", :scoring)
        end
      end
    end

    next score
  }
)

#===============================================================================
# 6.4 Feint Coordination
# Use Feint strategically against Protect users in doubles
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_feint_doubles,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)

    feint_functions = ["RemoveProtections", "RemoveProtectionsBypassSubstitute"]
    next score unless feint_functions.include?(move.function_code)

    target_battler = target.battler

    # Check if target used Protect last turn (ProtectRate > 1 means they used it)
    protect_rate = target_battler.effects[PBEffects::ProtectRate] rescue 1
    if protect_rate > 1
      score += 20
      AdvancedBattleAI.log("Feint: bonus vs recent Protect user", :scoring)
    end

    # Check move prediction for Protect
    if AdvancedBattleAI.feature_enabled?(:move_prediction, ai.trainer)
      prediction, pred_move, confidence = ai.predict_opponent_move(target.index)
      if prediction == AdvancedBattleAI::Prediction::PROTECT && confidence > 0.4
        score += 15
        AdvancedBattleAI.log("Feint: bonus vs predicted Protect", :scoring)
      end
    end

    # Penalty if target has never shown Protect (check memory)
    if ai.memory
      has_shown_protect = false
      known_moves = ai.memory.get_known_moves(target.index)
      protect_functions = [
        "ProtectUser", "ProtectUserFromTargetingMovesSpikyShield",
        "ProtectUserBanefulBunker", "ProtectUserFromDamagingMovesKingsShield",
        "ProtectUserFromTargetingMovesSilkTrap", "ProtectUserFromTargetingMovesBurningBulwark"
      ]
      known_moves.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data
        if protect_functions.include?(move_data.function_code)
          has_shown_protect = true
          break
        end
      end

      unless has_shown_protect
        score -= 20
        AdvancedBattleAI.log("Feint: penalty (target never shown Protect)", :scoring)
      end
    end

    next score
  }
)
