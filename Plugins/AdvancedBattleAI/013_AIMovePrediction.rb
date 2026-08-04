#===============================================================================
# Advanced Battle AI - Move Prediction
# Predicts what move the player will use and adjusts strategy accordingly
#===============================================================================

module AdvancedBattleAI
  # Prediction types
  module Prediction
    ATTACK = :attack           # Will use a damaging move
    SETUP = :setup             # Will use a stat-boosting move
    SWITCH = :switch           # Will switch out
    PRIORITY = :priority       # Will use a priority move
    STATUS = :status           # Will use a status move
    PROTECT = :protect         # Will use Protect/Detect
    UNKNOWN = :unknown         # Can't predict
  end
end

#===============================================================================
# Move Prediction System
#===============================================================================
class Battle::AI
  attr_reader :predictions          # Current predictions for each opponent
  attr_reader :prediction_confidence # Confidence level (0.0 - 1.0)

  #-----------------------------------------------------------------------------
  # Initialize prediction tracking
  #-----------------------------------------------------------------------------
  alias advanced_ai_prediction_initialize initialize
  def initialize(battle)
    advanced_ai_prediction_initialize(battle)
    @predictions = {}
    @prediction_confidence = {}
    @player_patterns = {}  # Track player behavior patterns
  end

  #-----------------------------------------------------------------------------
  # Predict opponent's next move
  # Returns [prediction_type, predicted_move, confidence]
  #-----------------------------------------------------------------------------
  def predict_opponent_move(opponent_idx)
    return [AdvancedBattleAI::Prediction::UNKNOWN, nil, 0.0] unless AdvancedBattleAI.feature_enabled?(:move_prediction, @trainer)

    opponent = @battle.battlers[opponent_idx]
    return [AdvancedBattleAI::Prediction::UNKNOWN, nil, 0.0] unless opponent && !opponent.fainted?

    ai_opponent = @battlers[opponent_idx]
    return [AdvancedBattleAI::Prediction::UNKNOWN, nil, 0.0] unless ai_opponent

    # Gather prediction factors
    factors = analyze_prediction_factors(opponent, ai_opponent)

    # Determine most likely action
    prediction, move, confidence = calculate_prediction(opponent, ai_opponent, factors)

    # Store prediction
    @predictions[opponent_idx] = prediction
    @prediction_confidence[opponent_idx] = confidence

    AdvancedBattleAI.log("Predicted #{opponent.name}: #{prediction} (#{(confidence * 100).to_i}% confidence)", :decisions)

    return [prediction, move, confidence]
  end

  #-----------------------------------------------------------------------------
  # Estimate damage for prediction (simpler than full rough_damage calc)
  #-----------------------------------------------------------------------------
  # Delegates to shared utility
  def estimate_move_damage(move_data, attacker_battler, defender_battler)
    AdvancedBattleAI.estimate_damage_battler(move_data, attacker_battler, defender_battler, @battle)
  end

  #-----------------------------------------------------------------------------
  # Analyze factors that influence prediction
  #-----------------------------------------------------------------------------
  def analyze_prediction_factors(opponent, ai_opponent)
    factors = {
      hp_percent: opponent.hp.to_f / opponent.totalhp,
      is_faster: false,
      has_setup: false,
      has_priority: false,
      has_super_effective: false,
      best_damage_percent: 0.0,
      can_ohko_us: false,
      we_can_ohko: false,
      has_recovery: false,
      is_trapped: false,
      consecutive_same_move: 0,
      last_move_used: opponent.lastMoveUsed
    }

    # Check speed comparison against our active Pokemon
    # Find AI-side battlers safely (avoid @user nil reference)
    ai_side_battlers = []
    @battle.battlers.each do |b|
      next unless b && !b.fainted? && !b.pbOwnedByPlayer?
      ai_side_battlers.push(b)
    end

    ai_side_battlers.each do |our_battler|
      our_ai = @battlers[our_battler.index]
      next unless our_ai
      if ai_opponent.faster_than?(our_ai)
        factors[:is_faster] = true
      end

      # Check if opponent can OHKO us (using estimated damage)
      known_moves = get_known_moves(opponent.index)
      known_moves.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data && move_data.power > 0

        damage = estimate_move_damage(move_data, opponent, our_battler)
        damage_percent = damage.to_f / our_battler.totalhp
        factors[:best_damage_percent] = [factors[:best_damage_percent], damage_percent].max
        if damage >= our_battler.hp
          factors[:can_ohko_us] = true
        end
      end

      # Check if we can OHKO opponent (using estimated damage)
      our_battler.moves.each do |move|
        next unless move
        move_data = GameData::Move.try_get(move.id)
        next unless move_data && move_data.power > 0

        damage = estimate_move_damage(move_data, our_battler, opponent)
        if damage >= opponent.hp
          factors[:we_can_ohko] = true
          break
        end
      end
    end

    # Analyze opponent's known moves
    known_moves = get_known_moves(opponent.index)
    known_moves.each do |move_id|
      move_data = GameData::Move.try_get(move_id)
      next unless move_data

      # Setup moves
      if is_setup_move?(move_data)
        factors[:has_setup] = true
      end

      # Priority moves
      if move_data.priority > 0 && move_data.power > 0
        factors[:has_priority] = true
      end

      # Recovery moves
      if is_recovery_move?(move_data)
        factors[:has_recovery] = true
      end

      # Super effective check
      ai_side_battlers.each do |our_battler|
        type_mod = Effectiveness.calculate(move_data.type, *our_battler.types)
        if Effectiveness.super_effective?(type_mod)
          factors[:has_super_effective] = true
        end
      end
    end

    # Check if trapped
    factors[:is_trapped] = opponent.effects[PBEffects::Trapping] > 0 ||
                           opponent.effects[PBEffects::MeanLook] > 0 ||
                           opponent.effects[PBEffects::NoRetreat]

    # Track consecutive same move usage
    if factors[:last_move_used] && @player_patterns[opponent.index]
      pattern = @player_patterns[opponent.index]
      if pattern[:last_moves] && pattern[:last_moves].last == factors[:last_move_used]
        factors[:consecutive_same_move] = pattern[:consecutive_count] || 1
      end
    end

    return factors
  end

  #-----------------------------------------------------------------------------
  # Calculate the prediction based on factors
  #-----------------------------------------------------------------------------
  def calculate_prediction(opponent, ai_opponent, factors)
    scores = {
      AdvancedBattleAI::Prediction::ATTACK => 50,    # Base attack score
      AdvancedBattleAI::Prediction::SETUP => 0,
      AdvancedBattleAI::Prediction::SWITCH => 0,
      AdvancedBattleAI::Prediction::PRIORITY => 0,
      AdvancedBattleAI::Prediction::STATUS => 0,
      AdvancedBattleAI::Prediction::PROTECT => 0
    }

    #---------------------------------------------------------------------------
    # Setup prediction
    #---------------------------------------------------------------------------
    if factors[:has_setup]
      # More likely to set up if:
      # - Faster and we can't OHKO them
      # - High HP
      # - We're a defensive Pokemon
      if factors[:is_faster] && !factors[:we_can_ohko]
        scores[AdvancedBattleAI::Prediction::SETUP] += 40
      end
      if factors[:hp_percent] > 0.7
        scores[AdvancedBattleAI::Prediction::SETUP] += 20
      end
      if factors[:hp_percent] > 0.9
        scores[AdvancedBattleAI::Prediction::SETUP] += 15
      end
      # Less likely if low HP
      if factors[:hp_percent] < 0.4
        scores[AdvancedBattleAI::Prediction::SETUP] -= 30
      end
    end

    #---------------------------------------------------------------------------
    # Switch prediction
    #---------------------------------------------------------------------------
    unless factors[:is_trapped]
      # More likely to switch if:
      # - Low HP and we're faster (can't revenge kill)
      # - Bad type matchup
      # - Can't do much damage to us
      if factors[:hp_percent] < 0.3 && !factors[:is_faster]
        scores[AdvancedBattleAI::Prediction::SWITCH] += 35
      end
      if factors[:best_damage_percent] < 0.2
        scores[AdvancedBattleAI::Prediction::SWITCH] += 25
      end
      # Less likely to switch if they can OHKO us
      if factors[:can_ohko_us]
        scores[AdvancedBattleAI::Prediction::SWITCH] -= 40
      end
    end

    #---------------------------------------------------------------------------
    # Priority prediction
    #---------------------------------------------------------------------------
    if factors[:has_priority]
      # More likely to use priority if:
      # - Low HP (trying to revenge kill before dying)
      # - We're faster (priority negates speed disadvantage)
      if factors[:hp_percent] < 0.4
        scores[AdvancedBattleAI::Prediction::PRIORITY] += 35
      end
      if !factors[:is_faster]
        scores[AdvancedBattleAI::Prediction::PRIORITY] += 20
      end
      # If they used priority last turn and it worked, might use again
      if factors[:last_move_used]
        last_move_data = GameData::Move.try_get(factors[:last_move_used])
        if last_move_data && last_move_data.priority > 0
          scores[AdvancedBattleAI::Prediction::PRIORITY] += 15
        end
      end
    end

    #---------------------------------------------------------------------------
    # Attack prediction
    #---------------------------------------------------------------------------
    # More likely to attack if:
    # - Can OHKO us
    # - Has super effective move
    # - Low HP (no time to set up)
    if factors[:can_ohko_us]
      scores[AdvancedBattleAI::Prediction::ATTACK] += 40
    end
    if factors[:has_super_effective]
      scores[AdvancedBattleAI::Prediction::ATTACK] += 20
    end
    if factors[:hp_percent] < 0.5
      scores[AdvancedBattleAI::Prediction::ATTACK] += 15
    end

    #---------------------------------------------------------------------------
    # Protect prediction
    #---------------------------------------------------------------------------
    # Check if they used Protect recently
    protect_rate = opponent.effects[PBEffects::ProtectRate] || 1
    if protect_rate <= 1
      # Protect hasn't been used yet or succeeded last time
      # More likely if:
      # - They have a speed-boosting ability (Speed Boost)
      # - Stalling for Leftovers/Black Sludge
      # - Toxic/burn damage on us
      if opponent.hasActiveAbility?(:SPEEDBOOST)
        scores[AdvancedBattleAI::Prediction::PROTECT] += 30
      end
      if opponent.hasActiveItem?(:LEFTOVERS) || opponent.hasActiveItem?(:BLACKSLUDGE)
        scores[AdvancedBattleAI::Prediction::PROTECT] += 10
      end
    else
      # Protect was used recently, less likely to work
      scores[AdvancedBattleAI::Prediction::PROTECT] -= 20
    end

    #---------------------------------------------------------------------------
    # Find best prediction
    #---------------------------------------------------------------------------
    best_prediction = scores.max_by { |k, v| v }
    prediction_type = best_prediction[0]
    best_score = best_prediction[1]

    # Calculate confidence based on score difference
    second_best = scores.sort_by { |k, v| -v }[1][1]
    score_gap = best_score - second_best
    confidence = [[score_gap / 50.0, 0.3].max, 0.9].min  # Clamp between 0.3 and 0.9

    # Find the actual predicted move if attacking
    predicted_move = nil
    if prediction_type == AdvancedBattleAI::Prediction::ATTACK ||
       prediction_type == AdvancedBattleAI::Prediction::PRIORITY
      predicted_move = predict_best_attack(opponent, ai_opponent, factors)
    end

    return [prediction_type, predicted_move, confidence]
  end

  #-----------------------------------------------------------------------------
  # Predict which attack move opponent will use
  #-----------------------------------------------------------------------------
  def predict_best_attack(opponent, ai_opponent, factors)
    best_move = nil
    best_damage = 0

    # Check against our active AI-side Pokemon
    @battle.battlers.each do |our_battler|
      next unless our_battler && !our_battler.fainted? && !our_battler.pbOwnedByPlayer?
      our_ai = @battlers[our_battler.index]
      next unless our_ai

      known_moves = get_known_moves(opponent.index)
      known_moves.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data && move_data.power > 0

        # If predicting priority, only consider priority moves
        if factors[:has_priority] && factors[:hp_percent] < 0.4
          next if move_data.priority <= 0
        end

        damage = estimate_move_damage(move_data, opponent, our_battler)
        if damage > best_damage
          best_damage = damage
          best_move = move_id
        end
      end
    end

    return best_move
  end

  #-----------------------------------------------------------------------------
  # Get known moves for opponent (from memory system)
  #-----------------------------------------------------------------------------
  def get_known_moves(opponent_idx)
    opponent = @battle.battlers[opponent_idx]
    return [] unless opponent

    known = []

    # Try to get from AI memory system
    if @memory
      known = @memory.get_known_moves(opponent_idx).dup
    end

    # Also include last move used
    if opponent.lastMoveUsed && !known.include?(opponent.lastMoveUsed)
      known.push(opponent.lastMoveUsed)
    end

    # If we know fewer than 4 moves, use predict_likely_moves as fallback
    if known.length < 4 && @memory
      predicted = @memory.predict_likely_moves(opponent)
      predicted.each do |move_id|
        break if known.length >= 4
        known.push(move_id) unless known.include?(move_id)
      end
    end

    # If we still don't know any moves, fall back to the Pokemon's moveset
    if known.empty?
      opponent.pokemon.moves.each do |move|
        known.push(move.id) if move
      end
    end

    return known
  end

  #-----------------------------------------------------------------------------
  # Update patterns after opponent's move
  #-----------------------------------------------------------------------------
  def record_opponent_move(opponent_idx, move_id)
    @player_patterns[opponent_idx] ||= {
      last_moves: [],
      consecutive_count: 0,
      move_frequency: {}
    }

    pattern = @player_patterns[opponent_idx]

    # Track consecutive usage
    if pattern[:last_moves].last == move_id
      pattern[:consecutive_count] += 1
    else
      pattern[:consecutive_count] = 1
    end

    # Keep last 5 moves
    pattern[:last_moves].push(move_id)
    pattern[:last_moves].shift if pattern[:last_moves].length > 5

    # Track frequency
    pattern[:move_frequency][move_id] ||= 0
    pattern[:move_frequency][move_id] += 1
  end
end

#===============================================================================
# Prediction-Based Score Modifiers
#===============================================================================

#-------------------------------------------------------------------------------
# Don't set up if opponent will OHKO us
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:prediction_dont_setup_vs_ohko,
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:move_prediction, ai.trainer)

    move_data = GameData::Move.try_get(move.id)
    next score unless move_data && ai.is_setup_move?(move_data)

    # Check predictions for all opponents
    dominated = false
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      prediction, pred_move, confidence = ai.predict_opponent_move(opp_idx)

      # If opponent predicted to attack with high confidence
      if prediction == AdvancedBattleAI::Prediction::ATTACK && confidence >= 0.5
        opp = ai.battlers[opp_idx]
        opp_battler = battle.battlers[opp_idx]
        next unless opp && opp_battler

        # Check if opponent is faster and can deal heavy damage
        if opp.faster_than?(user)
          known_moves = ai.get_known_moves(opp_idx)
          known_moves.each do |move_id|
            move_data = GameData::Move.try_get(move_id)
            next unless move_data && move_data.power > 0
            damage = ai.estimate_move_damage(move_data, opp_battler, user.battler)
            if damage >= user.hp * 0.6
              dominated = true
              AdvancedBattleAI.log("Prediction: Not setting up, opponent will deal heavy damage", :scoring)
              break
            end
          end
        end
      end
      break if dominated
    end

    if dominated
      score -= 40
      AdvancedBattleAI.log("Prediction: setup penalty, opponent will deal heavy damage", :scoring)
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Boost attack if opponent predicted to set up
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:prediction_punish_setup,
  proc { |score, move, user, target, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:move_prediction, ai.trainer)
    next score unless move.damagingMove?

    prediction, pred_move, confidence = ai.predict_opponent_move(target.index)

    if prediction == AdvancedBattleAI::Prediction::SETUP && confidence >= 0.4
      # Opponent likely to set up - prioritize attacking
      score += 20
      AdvancedBattleAI.log("Prediction: Boosting attack, opponent likely setting up", :scoring)

      # Extra bonus if we can OHKO them while they set up
      move_data = GameData::Move.try_get(move.id)
      if move_data && move_data.power > 0
        damage = ai.estimate_move_damage(move_data, user.battler, target.battler)
        if damage >= target.hp
          score += 25
          AdvancedBattleAI.log("Prediction: Can OHKO while they set up!", :scoring)
        end
      end
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Boost Protect if opponent predicted to attack heavily
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:prediction_protect_vs_attack,
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:move_prediction, ai.trainer)

    # Check if this is Protect/Detect
    protect_functions = ["ProtectUser", "ProtectUserFromDamagingMovesKingsShield",
                         "ProtectUserFromDamagingMovesObstruct", "ProtectUserBanefulBunker",
                         "ProtectUserFromTargetingMovesSpikyShield"]
    move_data = GameData::Move.try_get(move.id)
    next score unless move_data && protect_functions.include?(move_data.function_code)

    # Check Protect success rate
    protect_rate = user.battler.effects[PBEffects::ProtectRate] || 1
    next score if protect_rate > 2  # Don't rely on low success rate

    # Check predictions
    total_threat = 0
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      prediction, pred_move, confidence = ai.predict_opponent_move(opp_idx)

      if prediction == AdvancedBattleAI::Prediction::ATTACK && confidence >= 0.5
        opp = ai.battlers[opp_idx]
        opp_battler = battle.battlers[opp_idx]
        next unless opp && opp_battler

        # Calculate incoming damage from known moves
        known_moves = ai.get_known_moves(opp_idx)
        known_moves.each do |move_id|
          opp_move_data = GameData::Move.try_get(move_id)
          next unless opp_move_data && opp_move_data.power > 0
          damage = ai.estimate_move_damage(opp_move_data, opp_battler, user.battler)
          damage_percent = damage.to_f / user.totalhp
          total_threat = [total_threat, damage_percent].max
        end
      end
    end

    # Boost Protect if high threat
    if total_threat >= 0.5
      bonus = (total_threat * 50).to_i
      score += bonus
      AdvancedBattleAI.log("Prediction: Boosting Protect, expecting #{(total_threat * 100).to_i}% damage", :scoring)
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Consider switching if predicted to take super effective hit
#-------------------------------------------------------------------------------
Battle::AI::Handlers::ShouldSwitch.add(:prediction_switch_vs_se,
  proc { |battler, reserves, ai, battle|
    next false unless AdvancedBattleAI.feature_enabled?(:move_prediction, ai.trainer)
    next false if reserves.empty?

    # === SAFEGUARDS ===
    # A predicted super-effective hit is a guess, not a fact, so it alone is far
    # too cheap a reason to give up a turn. Without these guards this handler
    # fires on any Pokemon whose typing happens to be weak to something the foe
    # carries, which in practice means switching out of a matchup every turn.
    next false if should_avoid_switching?(battler.battler, ai)

    # Give the Pokemon a chance to do its job before bailing.
    next false if battler.battler.turnCount < 2

    # If we can end an opponent this turn, take the trade rather than fleeing.
    can_ko_any = battle.pbGetOpposingIndicesInOrder(battler.index).any? do |opp_idx|
      opp = battle.battlers[opp_idx]
      next false unless opp && !opp.fainted?
      next best_move_damage(battler.battler, opp) >= opp.hp
    end
    next false if can_ko_any

    dominated = false
    battle.pbGetOpposingIndicesInOrder(battler.index).each do |opp_idx|
      prediction, pred_move, confidence = ai.predict_opponent_move(opp_idx)

      # If opponent predicted to attack
      if prediction == AdvancedBattleAI::Prediction::ATTACK && confidence >= 0.6
        opp = ai.battlers[opp_idx]
        next unless opp

        # Check if predicted move is super effective
        if pred_move
          move_data = GameData::Move.try_get(pred_move)
          opp_battler = battle.battlers[opp_idx]
          if move_data && opp_battler
            type_mod = Effectiveness.calculate(move_data.type, *battler.battler.types)
            if Effectiveness.super_effective?(type_mod)
              # Check damage
              damage = ai.estimate_move_damage(move_data, opp_battler, battler.battler)
              if damage >= battler.hp * 0.6
                dominated = true
                AdvancedBattleAI.log("Prediction: Should switch, expecting SE hit", :decisions)
              end
            end
          end
        end
      end
      break if dominated
    end

    next dominated
  }
)

#-------------------------------------------------------------------------------
# Record opponent moves at end of turn (hook into battle flow)
#-------------------------------------------------------------------------------
# This is done through the memory system in 002_AIMemory.rb
# The predict system reads from memory and tracks patterns
