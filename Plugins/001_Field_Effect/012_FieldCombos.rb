#===============================================================================
# Field Combo Detection System
# Tracks move history and detects move combinations for field transformations
#===============================================================================
module Battle::FieldCombos
  COMBO_HISTORY_SIZE = 5

  module_function

  #-----------------------------------------------------------------------------
  # Record a move into the combo history
  # @param battle [Battle] The battle object
  # @param move [Battle::Move] The move that was used
  #-----------------------------------------------------------------------------
  def record_move(battle, move)
    return unless battle.respond_to?(:field_combo_history)
    return if move.nil?

    battle.field_combo_history ||= []
    battle.field_combo_history.push(move.id)

    # Keep history limited to prevent memory issues
    while battle.field_combo_history.length > COMBO_HISTORY_SIZE
      battle.field_combo_history.shift
    end
  end

  #-----------------------------------------------------------------------------
  # Check if a combo has been completed
  # @param battle [Battle] The battle object
  # @param required_moves [Array<Symbol>] Array of move IDs required for the combo
  # @param ordered [Boolean] Whether the moves must be in order (default: false)
  # @return [Boolean] Whether the combo is active
  #-----------------------------------------------------------------------------
  def has_combo?(battle, required_moves, ordered: false)
    return false unless battle.respond_to?(:field_combo_history)
    return false if battle.field_combo_history.nil? || battle.field_combo_history.empty?
    return false if required_moves.nil? || required_moves.empty?

    history = battle.field_combo_history

    if ordered
      # For ordered combos, check if moves appear in sequence
      return has_ordered_combo?(history, required_moves)
    else
      # For unordered combos, just check if all moves are present
      return required_moves.all? { |m| history.include?(m) }
    end
  end

  #-----------------------------------------------------------------------------
  # Check for an ordered combo in history
  #-----------------------------------------------------------------------------
  def has_ordered_combo?(history, required_moves)
    return false if history.length < required_moves.length

    # Find starting positions where the first required move appears
    history.each_with_index do |move, start_idx|
      next unless move == required_moves[0]
      next if start_idx + required_moves.length > history.length

      # Check if subsequent moves match
      matches = true
      required_moves.each_with_index do |req_move, offset|
        if history[start_idx + offset] != req_move
          matches = false
          break
        end
      end

      return true if matches
    end

    return false
  end

  #-----------------------------------------------------------------------------
  # Clear the combo history (usually after a successful combo)
  # @param battle [Battle] The battle object
  #-----------------------------------------------------------------------------
  def clear_history(battle)
    return unless battle.respond_to?(:field_combo_history)
    battle.field_combo_history = []
  end

  #-----------------------------------------------------------------------------
  # Check all defined combos for the current field and return the first match
  # @param battle [Battle] The battle object
  # @param move [Battle::Move] The move that was just used
  # @return [Hash, nil] The matched combo data or nil
  #-----------------------------------------------------------------------------
  def check_combos(battle, move)
    return nil unless battle.respond_to?(:field_id)

    field_data = GameData::FieldEffect.try_get(battle.field_id)
    return nil unless field_data

    # Record this move first
    record_move(battle, move)

    # Check each defined combo
    field_data.combos.each do |combo|
      next unless combo[:moves] && combo[:moves].length > 0

      # Check if combo is complete (unordered by default)
      if has_combo?(battle, combo[:moves])
        return combo
      end
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Execute a combo transformation
  # @param battle [Battle] The battle object
  # @param combo [Hash] The combo data containing :result_field and :message
  #-----------------------------------------------------------------------------
  def execute_combo(battle, combo)
    return unless combo

    # Display combo message
    if combo[:message] && !combo[:message].empty?
      battle.pbDisplay(_INTL(combo[:message]))
    end

    # Clear combo history after successful combo
    clear_history(battle)

    # Transform to new field (nil means clear field)
    if combo[:result_field]
      battle.create_new_field(combo[:result_field])
    else
      battle.end_current_field
    end
  end
end
