#===============================================================================
# Field Transformation System
# Handles move-triggered field changes, counter mechanics, and combo transformations
#===============================================================================
module Battle::FieldTransformations
  module_function

  #-----------------------------------------------------------------------------
  # Main entry point - called after a move is executed
  # @param battle [Battle] The battle object
  # @param user [Battle::Battler] The battler who used the move
  # @param move [Battle::Move] The move that was used
  # @param targets [Array<Battle::Battler>] The targets of the move
  #-----------------------------------------------------------------------------
  def check_after_move(battle, user, move, targets)
    return unless battle.respond_to?(:field_id)
    return if move.nil?

    field_data = GameData::FieldEffect.try_get(battle.field_id)

    # Even without PBS data, we should record moves for combos
    Battle::FieldCombos.record_move(battle, move) if battle.respond_to?(:field_combo_history)

    return unless field_data

    # 1. Check destroy triggers (removes field entirely)
    destroy = check_destroy_triggers(battle, user, move, field_data)
    if destroy
      execute_destroy(battle, destroy)
      return
    end

    # 2. Check direct move→field transformations
    transformation = check_move_transformations(battle, user, move, field_data)
    if transformation
      execute_transformation(battle, transformation)
      return
    end

    # 3. Check counter-based transformations
    counter_result = check_counters(battle, user, move, field_data)
    if counter_result
      execute_counter_transformation(battle, counter_result)
      return
    end

    # 4. Check combo transformations
    combo = check_combos(battle, user, move, field_data)
    if combo
      Battle::FieldCombos.execute_combo(battle, combo)
      return
    end
  end

  #-----------------------------------------------------------------------------
  # Check for destroy triggers (moves that remove the field)
  #-----------------------------------------------------------------------------
  def check_destroy_triggers(battle, user, move, field_data)
    return nil unless field_data.destroy_triggers && !field_data.destroy_triggers.empty?

    field_data.destroy_triggers.each do |destroy|
      next unless destroy[:trigger_move]

      # Check if move matches the trigger
      if move.id == destroy[:trigger_move]
        # Check additional conditions
        if destroy[:condition].nil? ||
           Battle::FieldConditions.met?(battle, user, destroy[:condition])
          return destroy
        end
      end
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Execute a destroy trigger (remove the field)
  #-----------------------------------------------------------------------------
  def execute_destroy(battle, destroy)
    # Display destruction message
    if destroy[:message] && !destroy[:message].empty?
      battle.pbDisplay(_INTL(destroy[:message]))
    end

    # End the current field and return to base/none
    battle.end_current_field
  end

  #-----------------------------------------------------------------------------
  # Check for direct move→field transformations
  #-----------------------------------------------------------------------------
  def check_move_transformations(battle, user, move, field_data)
    return nil unless field_data.transformations && !field_data.transformations.empty?

    field_data.transformations.each do |transform|
      next unless transform[:trigger_move]

      # Check if move matches the trigger
      if move.id == transform[:trigger_move]
        # Check additional conditions
        if transform[:condition].nil? ||
           Battle::FieldConditions.met?(battle, user, transform[:condition])
          return transform
        end
      end
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Execute a direct transformation
  #-----------------------------------------------------------------------------
  def execute_transformation(battle, transform)
    # Display transformation message
    if transform[:message] && !transform[:message].empty?
      battle.pbDisplay(_INTL(transform[:message]))
    end

    # Transform to new field (nil means clear field)
    if transform[:new_field]
      battle.create_new_field(transform[:new_field])
    else
      battle.end_current_field
    end
  end

  #-----------------------------------------------------------------------------
  # Check counter-based transformations
  # Counters track cumulative effects (e.g., "3 Water moves floods the field")
  #-----------------------------------------------------------------------------
  def check_counters(battle, user, move, field_data)
    return nil unless field_data.counters && !field_data.counters.empty?
    return nil unless battle.respond_to?(:field_counters)

    field_data.counters.each do |counter|
      next unless counter[:trigger] && counter[:name]

      # Check if move matches the counter trigger
      if move_matches_trigger?(move, user, counter[:trigger])
        # Increment the counter
        battle.increment_field_counter(counter[:name])

        # Check if threshold reached
        current_value = battle.field_counters[counter[:name]] || 0
        if current_value >= counter[:threshold]
          return counter
        end
      end
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Execute a counter-based transformation
  #-----------------------------------------------------------------------------
  def execute_counter_transformation(battle, counter)
    # Display transformation message
    if counter[:message] && !counter[:message].empty?
      battle.pbDisplay(_INTL(counter[:message]))
    end

    # Reset all counters on field change
    battle.reset_field_counters if battle.respond_to?(:reset_field_counters)

    # Transform to new field
    if counter[:result_field]
      battle.create_new_field(counter[:result_field])
    else
      battle.end_current_field
    end
  end

  #-----------------------------------------------------------------------------
  # Check combo transformations (delegates to FieldCombos module)
  #-----------------------------------------------------------------------------
  def check_combos(battle, user, move, field_data)
    return nil unless field_data.combos && !field_data.combos.empty?

    field_data.combos.each do |combo|
      next unless combo[:moves] && combo[:moves].length > 0

      # Check if combo is complete
      if Battle::FieldCombos.has_combo?(battle, combo[:moves])
        return combo
      end
    end

    return nil
  end

  #-----------------------------------------------------------------------------
  # Check if a move matches a counter trigger
  # Triggers can be: "type:WATER", "move:SURF", "category:special", "flag:contact"
  #-----------------------------------------------------------------------------
  def move_matches_trigger?(move, user, trigger)
    return false if trigger.nil? || trigger.empty?

    trigger = trigger.strip.downcase

    # Type trigger: "type:WATER" or "type:WATER,FIRE"
    if trigger.start_with?("type:")
      types = trigger[5..-1].split(",").map { |t| t.strip.upcase.to_sym }
      return types.include?(move.type)
    end

    # Specific move trigger: "move:SURF"
    if trigger.start_with?("move:")
      move_id = trigger[5..-1].strip.upcase.to_sym
      return move.id == move_id
    end

    # Category trigger: "category:physical", "category:special", "category:status"
    if trigger.start_with?("category:")
      cat = trigger[9..-1].strip.downcase
      case cat
      when "physical"
        return move.physicalMove?
      when "special"
        return move.specialMove?
      when "status"
        return move.statusMove?
      end
    end

    # Flag trigger: "flag:contact", "flag:sound", etc.
    if trigger.start_with?("flag:")
      flag = trigger[5..-1].strip
      return move.flags.any? { |f| f.downcase == flag.downcase }
    end

    # User type trigger: "usertype:WATER" - if user has this type
    if trigger.start_with?("usertype:")
      type = trigger[9..-1].strip.upcase.to_sym
      return user&.pbHasType?(type) || false
    end

    return false
  end
end

# Counter Management Methods are defined in 001_Battle.rb
