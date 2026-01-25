#===============================================================================
# Advanced Battle AI - Hazard Management
# Intelligent hazard layering and removal decisions
#===============================================================================

#===============================================================================
# Stealth Rock Scoring Enhancement
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("AddStealthRocksToFoeSide",
  proc { |score, move, user, ai, battle|
    next Battle::AI::MOVE_USELESS_SCORE if user.pbOpposingSide.effects[PBEffects::StealthRock]
    next score unless AdvancedBattleAI.feature_enabled?(:hazards, ai.trainer)

    # Calculate hazard value based on opponent's remaining Pokemon
    hazard_value = calculate_stealth_rock_value(user, ai, battle)

    # Base score adjustment
    score = Battle::AI::MOVE_BASE_SCORE + hazard_value

    # Bonus if we also have other hazards to layer
    if user.has_move_with_function?("AddSpikesToFoeSide")
      score += 5
      AdvancedBattleAI.log("SR bonus: have Spikes too", :scoring)
    end
    if user.has_move_with_function?("AddToxicSpikesToFoeSide")
      score += 5
      AdvancedBattleAI.log("SR bonus: have T-Spikes too", :scoring)
    end

    # Bonus for early game setup
    if battle.turnCount <= 2
      score += 15
      AdvancedBattleAI.log("SR bonus: early game", :scoring)
    end

    # Penalty if opponent has shown Defog/Rapid Spin
    if ai.memory
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        if ai.memory.has_shown_hazard_removal?(opp_idx)
          score -= 15
          AdvancedBattleAI.log("SR penalty: opponent has removal", :scoring)
          break
        end
      end
    end

    # Consider Heavy-Duty Boots prevalence (can't fully check, but assume some have it)
    remaining_pokemon = count_opponent_remaining_pokemon(user, battle)
    if remaining_pokemon >= 4
      score += 10  # More valuable with more switches expected
    end

    next [score, AdvancedBattleAI::HAZARD_SCORE_THRESHOLD].max
  }
)

#===============================================================================
# Spikes Scoring Enhancement
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("AddSpikesToFoeSide",
  proc { |score, move, user, ai, battle|
    spikes_count = user.pbOpposingSide.effects[PBEffects::Spikes] || 0
    next Battle::AI::MOVE_USELESS_SCORE if spikes_count >= 3
    next score unless AdvancedBattleAI.feature_enabled?(:hazards, ai.trainer)

    # Base value decreases with each layer
    layer_values = [25, 15, 8]  # Value for 1st, 2nd, 3rd layer
    hazard_value = layer_values[spikes_count] || 0

    score = Battle::AI::MOVE_BASE_SCORE + hazard_value

    # Bonus if Stealth Rock is already up (layering synergy)
    if user.pbOpposingSide.effects[PBEffects::StealthRock]
      score += 10
      AdvancedBattleAI.log("Spikes bonus: SR already up", :scoring)
    end

    # Bonus for grounded opponents
    grounded_count = count_grounded_opponents(user, ai, battle)
    score += grounded_count * 5

    # Penalty for many Flying/Levitate opponents
    flying_count = count_immune_to_ground(user, ai, battle)
    score -= flying_count * 8

    # Early game bonus
    if battle.turnCount <= 3
      score += 10
    end

    next [score, AdvancedBattleAI::HAZARD_SCORE_THRESHOLD - 10].max
  }
)

#===============================================================================
# Toxic Spikes Scoring Enhancement
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("AddToxicSpikesToFoeSide",
  proc { |score, move, user, ai, battle|
    tspikes_count = user.pbOpposingSide.effects[PBEffects::ToxicSpikes] || 0
    next Battle::AI::MOVE_USELESS_SCORE if tspikes_count >= 2
    next score unless AdvancedBattleAI.feature_enabled?(:hazards, ai.trainer)

    # Value depends on layer
    layer_values = [20, 15]  # 1 layer = poison, 2 layers = toxic
    hazard_value = layer_values[tspikes_count] || 0

    score = Battle::AI::MOVE_BASE_SCORE + hazard_value

    # Bonus against stall teams (works well with chip damage)
    if ai.memory
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        if ai.memory.has_shown_recovery?(opp_idx)
          score += 15
          AdvancedBattleAI.log("T-Spikes bonus: opponent has recovery", :scoring)
          break
        end
      end
    end

    # Penalty for Poison-type opponents (absorb T-Spikes)
    poison_count = count_poison_type_opponents(user, ai, battle)
    score -= poison_count * 15  # Big penalty - Poison types absorb T-Spikes

    # Penalty for Steel-type opponents (immune)
    steel_count = count_steel_type_opponents(user, ai, battle)
    score -= steel_count * 8

    # Bonus if 2nd layer (badly poison is much stronger)
    if tspikes_count == 1
      score += 5
    end

    next [score, AdvancedBattleAI::HAZARD_SCORE_THRESHOLD - 15].max
  }
)

#===============================================================================
# Sticky Web Scoring Enhancement
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("AddStickyWebToFoeSide",
  proc { |score, move, user, ai, battle|
    next Battle::AI::MOVE_USELESS_SCORE if user.pbOpposingSide.effects[PBEffects::StickyWeb]
    next score unless AdvancedBattleAI.feature_enabled?(:hazards, ai.trainer)

    # Sticky Web value depends on speed matchups
    speed_advantage = calculate_speed_advantage_with_web(user, ai, battle)

    score = Battle::AI::MOVE_BASE_SCORE + (speed_advantage * 5)

    # Big bonus if our team is slightly slower
    if speed_advantage >= 2
      score += 20
      AdvancedBattleAI.log("Sticky Web bonus: speed advantage gain", :scoring)
    end

    # Bonus if we have sweepers that would benefit
    if ai.team_has_role?(user.side, Battle::AI::Roles::SWEEPER)
      score += 10
    end

    # Penalty for many Flying/Levitate opponents
    flying_count = count_immune_to_ground(user, ai, battle)
    score -= flying_count * 10

    next [score, AdvancedBattleAI::HAZARD_SCORE_THRESHOLD - 5].max
  }
)

#===============================================================================
# Rapid Spin Scoring Enhancement
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("RemoveUserBindingAndEntryHazards",
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:hazards, ai.trainer)

    # Calculate value of hazards on our side
    our_hazard_value = calculate_own_hazard_damage_value(user, ai, battle)

    # Calculate value of hazards on opponent's side (we might accidentally help them)
    their_hazard_value = calculate_opponent_hazard_value(user, ai, battle)

    # Net benefit calculation
    net_benefit = our_hazard_value - (their_hazard_value * 0.3)  # Small penalty for removing their binding

    score += net_benefit.to_i

    # Bonus if bound/trapped
    if user.effects[PBEffects::Trapping] > 0
      score += 20
      AdvancedBattleAI.log("Rapid Spin bonus: trapped", :scoring)
    end

    # Bonus if Leech Seed
    if user.effects[PBEffects::LeechSeed] >= 0
      score += 15
    end

    # Also gets +1 Speed, small bonus
    score += 5

    # If no hazards/trapping to remove, still a decent attacking move
    if our_hazard_value == 0 && user.effects[PBEffects::Trapping] == 0
      score = Battle::AI::MOVE_BASE_SCORE  # Just use base score
    end

    next score
  }
)

#===============================================================================
# Defog Scoring Enhancement
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("LowerTargetEvasion1RemoveSideEffects",
  proc { |score, move, user, ai, battle|
    next score unless AdvancedBattleAI.feature_enabled?(:hazards, ai.trainer)

    # Calculate value of hazards on our side
    our_hazard_value = calculate_own_hazard_damage_value(user, ai, battle)

    # Calculate value of hazards on opponent's side (Defog removes both!)
    their_hazard_value = calculate_opponent_hazard_value(user, ai, battle)

    # Calculate screen values
    our_screens = calculate_screen_value(user.pbOwnSide, battle)
    their_screens = calculate_screen_value(user.pbOpposingSide, battle)

    # Net calculation: we want to remove our hazards and their screens
    # But we lose our hazards too...
    net_benefit = our_hazard_value + their_screens - their_hazard_value - our_screens

    score += net_benefit.to_i

    # If we have important hazards up, big penalty for Defog
    if their_hazard_value >= 30
      score -= 25
      AdvancedBattleAI.log("Defog penalty: would remove our hazards", :scoring)
    end

    # If opponent has Aurora Veil, big bonus
    if user.pbOpposingSide.effects[PBEffects::AuroraVeil] > 0
      score += 30
      AdvancedBattleAI.log("Defog bonus: removes Aurora Veil", :scoring)
    end

    # Terrain considerations (Defog clears terrain too)
    if battle.field.terrain != :None
      # Check if terrain benefits us or opponent
      terrain_benefit = evaluate_terrain_benefit(user, battle)
      score -= terrain_benefit  # Negative if terrain helps us
    end

    next score
  }
)

#===============================================================================
# Helper Functions
#===============================================================================

# Calculate Stealth Rock damage value against opponent's team
def calculate_stealth_rock_value(user, ai, battle)
  return 0 unless ai

  total_value = 0
  seen_species = ai.memory ? ai.memory.get_pokemon_seen(user.opposing_side_index) : []

  # Check visible opponents
  battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
    opp = battle.battlers[opp_idx]
    next unless opp && !opp.fainted?

    # Skip if has Magic Guard
    next if opp.hasActiveAbility?(:MAGICGUARD)

    # Skip if has Heavy-Duty Boots (we can't know for sure, but check item)
    next if opp.hasActiveItem?(:HEAVYDUTYBOOTS)

    type_mod = Effectiveness.calculate(:ROCK, *opp.types)
    damage_fraction = type_mod / 8.0  # SR deals 1/8 * effectiveness

    # Value based on damage
    if damage_fraction >= 0.5
      total_value += 30  # 4x weak
    elsif damage_fraction >= 0.25
      total_value += 20  # 2x weak
    elsif damage_fraction >= 0.125
      total_value += 10  # Neutral
    else
      total_value += 3   # Resistant
    end
  end

  # Add value for unseen Pokemon (estimate)
  remaining = count_opponent_remaining_pokemon(user, battle) - battle.pbGetOpposingIndicesInOrder(user.index).length
  total_value += remaining * 12  # Average value per unseen Pokemon

  return total_value
end

# Count opponent's remaining Pokemon
def count_opponent_remaining_pokemon(user, battle)
  count = 0
  if battle.opponent
    battle.opponent.each do |trainer|
      trainer.party.each { |p| count += 1 if p && p.able? }
    end
  end
  return [count, 6].min
end

# Count grounded opponents (affected by Spikes/T-Spikes)
def count_grounded_opponents(user, ai, battle)
  count = 0
  battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
    opp = battle.battlers[opp_idx]
    next unless opp && !opp.fainted?
    next if opp.airborne?
    count += 1
  end
  return count
end

# Count opponents immune to ground (Flying type or Levitate)
def count_immune_to_ground(user, ai, battle)
  count = 0
  battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
    opp = battle.battlers[opp_idx]
    next unless opp && !opp.fainted?
    if opp.airborne? || opp.pbHasType?(:FLYING) || opp.hasActiveAbility?(:LEVITATE)
      count += 1
    end
  end
  return count
end

# Count Poison-type opponents
def count_poison_type_opponents(user, ai, battle)
  count = 0
  battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
    opp = battle.battlers[opp_idx]
    next unless opp && !opp.fainted?
    count += 1 if opp.pbHasType?(:POISON)
  end
  return count
end

# Count Steel-type opponents
def count_steel_type_opponents(user, ai, battle)
  count = 0
  battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
    opp = battle.battlers[opp_idx]
    next unless opp && !opp.fainted?
    count += 1 if opp.pbHasType?(:STEEL)
  end
  return count
end

# Calculate speed advantage gained from Sticky Web
def calculate_speed_advantage_with_web(user, ai, battle)
  advantage = 0

  battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
    opp = battle.battlers[opp_idx]
    next unless opp && !opp.fainted?
    next if opp.airborne?  # Web doesn't affect flying

    # If opponent is currently faster but would be slower with -1 Speed
    if opp.speed > user.speed
      # Rough estimate: -1 Speed is about 33% reduction
      reduced_speed = (opp.speed * 0.67).to_i
      if reduced_speed < user.speed
        advantage += 1
      end
    end
  end

  return advantage
end

# Calculate value of hazards on our side
def calculate_own_hazard_damage_value(user, ai, battle)
  value = 0
  side = user.pbOwnSide

  # Stealth Rock
  if side.effects[PBEffects::StealthRock]
    value += 25  # Significant value to remove
  end

  # Spikes
  spikes = side.effects[PBEffects::Spikes] || 0
  value += spikes * 12

  # Toxic Spikes
  tspikes = side.effects[PBEffects::ToxicSpikes] || 0
  value += tspikes * 15

  # Sticky Web
  if side.effects[PBEffects::StickyWeb]
    value += 20
  end

  return value
end

# Calculate value of hazards on opponent's side (that we set up)
def calculate_opponent_hazard_value(user, ai, battle)
  value = 0
  side = user.pbOpposingSide

  # Stealth Rock
  if side.effects[PBEffects::StealthRock]
    value += 25
  end

  # Spikes
  spikes = side.effects[PBEffects::Spikes] || 0
  value += spikes * 12

  # Toxic Spikes
  tspikes = side.effects[PBEffects::ToxicSpikes] || 0
  value += tspikes * 15

  # Sticky Web
  if side.effects[PBEffects::StickyWeb]
    value += 20
  end

  return value
end

# Calculate value of screens on a side
def calculate_screen_value(side, battle)
  value = 0

  if side.effects[PBEffects::Reflect] > 0
    value += 15
  end

  if side.effects[PBEffects::LightScreen] > 0
    value += 15
  end

  if side.effects[PBEffects::AuroraVeil] > 0
    value += 30
  end

  return value
end

# Evaluate if current terrain benefits user's side
def evaluate_terrain_benefit(user, battle)
  terrain = battle.field.terrain
  return 0 if terrain == :None

  benefit = 0

  case terrain
  when :Electric
    # Benefits Electric types
    benefit += 10 if user.pbHasType?(:ELECTRIC)
  when :Grassy
    # Heals grounded Pokemon, boosts Grass
    benefit += 10 if user.pbHasType?(:GRASS)
    benefit += 5 unless user.airborne?
  when :Misty
    # Protects from status, weakens Dragon
    benefit += 10 unless user.airborne?
  when :Psychic
    # Boosts Psychic, blocks priority
    benefit += 10 if user.pbHasType?(:PSYCHIC)
  end

  return benefit
end
