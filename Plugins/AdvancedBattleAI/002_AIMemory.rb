#===============================================================================
# Advanced Battle AI - Memory System
# Tracks revealed information about opponent Pokemon during battle
#===============================================================================
class Battle::AI
  # Access the memory system
  attr_reader :memory

  #-----------------------------------------------------------------------------
  # Initialize memory system when AI is created
  #-----------------------------------------------------------------------------
  alias advanced_ai_initialize initialize
  def initialize(battle)
    advanced_ai_initialize(battle)
    @memory = AIMemory.new(battle)
  end
end

#===============================================================================
# AI Memory Class
# Stores and manages information learned about opponents during battle
#===============================================================================
class Battle::AI::AIMemory
  attr_reader :battle

  def initialize(battle)
    @battle = battle
    @revealed_moves = {}      # battler_index => [move_ids]
    @revealed_abilities = {}  # battler_index => ability_id
    @revealed_items = {}      # battler_index => item_id (nil if consumed)
    @damage_taken = {}        # battler_index => [{attacker:, move:, damage:, type:}]
    @switch_count = {}        # battler_index => count of switches
    @last_move_used = {}      # battler_index => move_id
    @pokemon_seen = {}        # side => [species seen]
  end

  #-----------------------------------------------------------------------------
  # Move Recording
  #-----------------------------------------------------------------------------

  # Record a move being used by a battler
  def record_move_used(battler_index, move)
    return unless move
    @revealed_moves[battler_index] ||= []
    move_id = move.is_a?(Battle::Move) ? move.id : move
    unless @revealed_moves[battler_index].include?(move_id)
      @revealed_moves[battler_index].push(move_id)
      AdvancedBattleAI.log("Recorded move #{move_id} for battler #{battler_index}", :memory)
    end
    @last_move_used[battler_index] = move_id
  end

  # Get all known moves for a battler
  def get_known_moves(battler_index)
    return @revealed_moves[battler_index] || []
  end

  # Get the last move used by a battler
  def get_last_move(battler_index)
    return @last_move_used[battler_index]
  end

  # Check if we know a specific move for a battler
  def knows_move?(battler_index, move_id)
    moves = get_known_moves(battler_index)
    return moves.include?(move_id)
  end

  # Check if battler knows any move with a specific function code
  def knows_move_with_function?(battler_index, *function_codes)
    get_known_moves(battler_index).each do |move_id|
      move_data = GameData::Move.try_get(move_id)
      next unless move_data
      return true if function_codes.include?(move_data.function_code)
    end
    return false
  end

  # Check if battler knows any move of a specific type
  def knows_move_of_type?(battler_index, type)
    get_known_moves(battler_index).each do |move_id|
      move_data = GameData::Move.try_get(move_id)
      next unless move_data
      return true if move_data.type == type
    end
    return false
  end

  # Predict possible fourth move based on species common movesets
  def predict_likely_moves(battler)
    return [] unless battler
    known = get_known_moves(battler.index)
    return [] if known.length >= 4

    predicted = []
    species_data = battler.pokemon.species_data

    # Get level-up moves the Pokemon could know at current level
    level_moves = species_data.moves.select { |m| m[0] <= battler.level }.map { |m| m[1] }

    # Get TM/TR moves (common competitive choices)
    tutor_moves = species_data.tutor_moves || []

    # Combine and filter out known moves
    all_possible = (level_moves + tutor_moves).uniq - known

    # Prioritize moves based on type coverage and utility
    all_possible.each do |move_id|
      move_data = GameData::Move.try_get(move_id)
      next unless move_data
      # Prioritize STAB moves
      if move_data.type == battler.types[0] || (battler.types.length > 1 && move_data.type == battler.types[1])
        predicted.unshift(move_id)
      # Prioritize status moves for walls, attacking for sweepers
      elsif move_data.category == 2 # Status
        predicted.push(move_id)
      else
        predicted.push(move_id)
      end
    end

    return predicted.first(4 - known.length)
  end

  #-----------------------------------------------------------------------------
  # Ability Recording
  #-----------------------------------------------------------------------------

  # Record an ability being triggered/revealed
  def record_ability(battler_index, ability_id)
    return unless ability_id
    @revealed_abilities[battler_index] = ability_id
    AdvancedBattleAI.log("Recorded ability #{ability_id} for battler #{battler_index}", :memory)
  end

  # Get known ability for a battler
  def get_known_ability(battler_index)
    return @revealed_abilities[battler_index]
  end

  # Check if we know the ability for a battler
  def ability_known?(battler_index)
    return @revealed_abilities.key?(battler_index)
  end

  # Predict ability based on species (if not yet revealed)
  def predict_ability(battler)
    return get_known_ability(battler.index) if ability_known?(battler.index)
    return nil unless battler

    species_data = battler.pokemon.species_data
    abilities = species_data.abilities + (species_data.hidden_abilities || [])

    # Return the most common ability (first listed is usually most common)
    return abilities.first
  end

  #-----------------------------------------------------------------------------
  # Item Recording
  #-----------------------------------------------------------------------------

  # Record an item being revealed or consumed
  def record_item(battler_index, item_id, consumed = false)
    if consumed
      @revealed_items[battler_index] = nil
      AdvancedBattleAI.log("Item consumed for battler #{battler_index}", :memory)
    else
      @revealed_items[battler_index] = item_id
      AdvancedBattleAI.log("Recorded item #{item_id} for battler #{battler_index}", :memory)
    end
  end

  # Get known item for a battler (nil if consumed or unknown)
  def get_known_item(battler_index)
    return @revealed_items[battler_index]
  end

  # Check if item was consumed
  def item_consumed?(battler_index)
    return @revealed_items.key?(battler_index) && @revealed_items[battler_index].nil?
  end

  #-----------------------------------------------------------------------------
  # Damage Recording
  #-----------------------------------------------------------------------------

  # Record damage dealt to a battler
  def record_damage(defender_index, attacker_index, move, damage, type)
    @damage_taken[defender_index] ||= []
    @damage_taken[defender_index].push({
      attacker: attacker_index,
      move: move.is_a?(Battle::Move) ? move.id : move,
      damage: damage,
      type: type,
      turn: @battle.turnCount
    })
  end

  # Get all damage records for a battler
  def get_damage_history(battler_index)
    return @damage_taken[battler_index] || []
  end

  # Estimate damage a move might deal based on similar past moves
  def estimate_damage_from_history(attacker_index, defender_index, move_type)
    history = get_damage_history(defender_index)
    relevant = history.select { |h| h[:attacker] == attacker_index && h[:type] == move_type }
    return nil if relevant.empty?

    # Return average damage from similar moves
    total = relevant.sum { |h| h[:damage] }
    return total / relevant.length
  end

  #-----------------------------------------------------------------------------
  # Switch Tracking
  #-----------------------------------------------------------------------------

  # Record a switch
  def record_switch(battler_index)
    @switch_count[battler_index] ||= 0
    @switch_count[battler_index] += 1
  end

  # Get switch count for a battler
  def get_switch_count(battler_index)
    return @switch_count[battler_index] || 0
  end

  #-----------------------------------------------------------------------------
  # Pokemon Seen Tracking
  #-----------------------------------------------------------------------------

  # Record a Pokemon being seen on a side
  def record_pokemon_seen(side, species)
    @pokemon_seen[side] ||= []
    unless @pokemon_seen[side].include?(species)
      @pokemon_seen[side].push(species)
    end
  end

  # Get all Pokemon seen on a side
  def get_pokemon_seen(side)
    return @pokemon_seen[side] || []
  end

  # Estimate remaining unrevealed Pokemon count
  def estimate_remaining_pokemon(side)
    seen = get_pokemon_seen(side).length
    # In most trainer battles, party size is 6
    return [6 - seen, 0].max
  end

  #-----------------------------------------------------------------------------
  # Choice Lock Detection
  #-----------------------------------------------------------------------------

  CHOICE_ITEMS = [:CHOICEBAND, :CHOICESCARF, :CHOICESPECS]

  # Check if opponent appears to be Choice-locked
  def opponent_choice_locked?(battler_index)
    # If we know their item is a Choice item, they're locked after using a move
    known_item = get_known_item(battler_index)
    if known_item && CHOICE_ITEMS.include?(known_item)
      return get_last_move(battler_index) != nil
    end
    # Heuristic: if they used the same damaging move twice in a row with unknown item,
    # they might be Choice-locked (not conclusive but useful)
    return false unless @revealed_moves[battler_index]
    return false if @revealed_items.key?(battler_index) && !CHOICE_ITEMS.include?(known_item)
    # Check damage history for repeated same-move usage
    history = @damage_taken.values.flatten.select { |h| h[:attacker] == battler_index }
    return false if history.length < 2
    last_two = history.last(2)
    last_two[0][:move] == last_two[1][:move] && last_two[0][:move] == get_last_move(battler_index)
  end

  # Get the move the opponent is locked into (nil if not locked)
  def get_choice_locked_move(battler_index)
    return nil unless opponent_choice_locked?(battler_index)
    return get_last_move(battler_index)
  end

  #-----------------------------------------------------------------------------
  # Item Prediction
  #-----------------------------------------------------------------------------

  # Predict what item a battler likely holds (heuristic, for high-skill AI)
  def predict_item(battler)
    return nil unless battler
    idx = battler.index

    # If item already known, return it
    return get_known_item(idx) if @revealed_items.key?(idx) && get_known_item(idx)

    # If item was consumed, they have nothing
    return nil if item_consumed?(idx)

    # If they used a status move freely, they're NOT Choice-locked
    known_moves = get_known_moves(idx)
    used_status = known_moves.any? do |move_id|
      move_data = GameData::Move.try_get(move_id)
      move_data && move_data.category == 2  # Status
    end

    # If they survived what should be an OHKO at full HP, likely Sash
    history = get_damage_history(idx)
    if !history.empty? && battler.hp == 1
      last_hit = history.last
      if last_hit[:damage] >= battler.totalhp
        return :FOCUSSASH
      end
    end

    # Heuristic based on stats and role
    atk = battler.attack
    spatk = battler.spatk
    speed = battler.speed
    bulk = battler.defense + battler.spdef

    if !used_status
      # Offensive Pokemon with no status moves might have Choice item
      if atk > spatk && atk > bulk
        return :CHOICEBAND
      elsif spatk > atk && spatk > bulk
        return :CHOICESPECS
      end
    end

    # Bulky Pokemon likely have Leftovers
    if bulk > atk && bulk > spatk
      return :LEFTOVERS
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Threat Analysis
  #-----------------------------------------------------------------------------

  # Check if opponent has shown priority moves
  def has_shown_priority?(battler_index)
    priority_functions = [
      "HigherPriorityInGrassyTerrain",     # Grassy Glide
      "IncreasedCriticalHitRatePriority",  # Quick Attack-like
      "PriorityMove"                        # Generic priority
    ]
    get_known_moves(battler_index).each do |move_id|
      move_data = GameData::Move.try_get(move_id)
      next unless move_data
      return true if move_data.priority > 0
      return true if priority_functions.include?(move_data.function_code)
    end
    return false
  end

  # Check if opponent has shown setup moves
  def has_shown_setup?(battler_index)
    setup_functions = [
      "RaiseUserAttack1",
      "RaiseUserAttack2",
      "RaiseUserDefense1",
      "RaiseUserDefense2",
      "RaiseUserSpAtk1",
      "RaiseUserSpAtk2",
      "RaiseUserSpeed1",
      "RaiseUserSpeed2",
      "RaiseUserAtkSpAtk1",
      "RaiseUserMainStats1",
      "MaxUserAttackLoseHalfOfTotalHP",  # Belly Drum
      "RaiseUserAtkDef1",
      "RaiseUserAtkSpd1",
      "RaiseUserDefSpDef1"
    ]
    return knows_move_with_function?(battler_index, *setup_functions)
  end

  # Check if opponent has shown recovery moves
  def has_shown_recovery?(battler_index)
    recovery_functions = [
      "HealUserHalfOfTotalHP",
      "HealUserHalfOfTotalHPLoseFlyingTypeThisTurn",
      "HealUserDependingOnWeather",
      "HealUserDependingOnSandstorm",
      "HealUserFullyAndFallAsleep",
      "HealUserPositionNextTurn"
    ]
    return knows_move_with_function?(battler_index, *recovery_functions)
  end

  # Check if opponent has shown hazard moves
  def has_shown_hazards?(battler_index)
    hazard_functions = [
      "AddSpikesToFoeSide",
      "AddToxicSpikesToFoeSide",
      "AddStealthRocksToFoeSide",
      "AddStickyWebToFoeSide"
    ]
    return knows_move_with_function?(battler_index, *hazard_functions)
  end

  # Check if opponent has shown hazard removal
  def has_shown_hazard_removal?(battler_index)
    removal_functions = [
      "RemoveUserBindingAndEntryHazards",  # Rapid Spin
      "LowerTargetEvasion1RemoveSideEffects", # Defog
      "RemoveScreensAndSafeguard"  # Court Change swaps, not removes
    ]
    return knows_move_with_function?(battler_index, *removal_functions)
  end

  #-----------------------------------------------------------------------------
  # Status Strategy Helpers
  #-----------------------------------------------------------------------------

  # Returns true if battler's Attack > SpAtk * 1.3 (physically offensive)
  def target_is_physically_offensive?(battler)
    return false unless battler
    b = battler.respond_to?(:battler) ? battler.battler : battler
    return false unless b
    atk = b.attack rescue 0
    spatk = b.spatk rescue 0
    return false if atk == 0 || spatk == 0
    return atk > spatk * 1.3
  end

  # Returns true if battler outspeeds all of our remaining team
  def target_is_fast_threat?(target, ai, battle)
    return false unless target && ai && battle
    target_battler = target.respond_to?(:battler) ? target.battler : target
    return false unless target_battler

    # Check all of our side's battlers
    our_indices = battle.pbGetOpposingIndicesInOrder(target_battler.index)
    return false if our_indices.empty?

    our_indices.each do |idx|
      our_battler = ai.battlers[idx] rescue nil
      next unless our_battler && !our_battler.battler.fainted?
      # If any of our Pokemon is faster, target isn't a fast threat
      return false if our_battler.faster_than?(target)
    end

    return true
  end

  #-----------------------------------------------------------------------------
  # Clear memory for a specific battler (when switched out)
  #-----------------------------------------------------------------------------
  def clear_battler(battler_index)
    # Keep the moves known for the species, but clear damage history
    @damage_taken[battler_index] = []
    @last_move_used[battler_index] = nil
    # Don't clear revealed_moves, revealed_abilities, revealed_items
    # as these persist for the Pokemon even when switched
  end

  #-----------------------------------------------------------------------------
  # Clear all memory (battle end)
  #-----------------------------------------------------------------------------
  def clear_all
    @revealed_moves.clear
    @revealed_abilities.clear
    @revealed_items.clear
    @damage_taken.clear
    @switch_count.clear
    @last_move_used.clear
    @pokemon_seen.clear
  end
end
