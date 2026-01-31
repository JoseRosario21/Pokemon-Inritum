#===============================================================================
# Field Condition Evaluation System
# Parses and evaluates condition strings for field transformations
#===============================================================================
module Battle::FieldConditions
  module_function

  #-----------------------------------------------------------------------------
  # Main condition evaluation entry point
  # @param battle [Battle] The battle object
  # @param user [Battle::Battler] The battler who used the move (can be nil)
  # @param condition [String] The condition string to evaluate
  # @return [Boolean] Whether the condition is met
  #-----------------------------------------------------------------------------
  def met?(battle, user, condition)
    return true if condition.nil? || condition.empty?

    condition = condition.strip.downcase

    # Handle compound conditions (AND)
    if condition.include?("&")
      return condition.split("&").all? { |c| met?(battle, user, c.strip) }
    end

    # Handle OR conditions
    if condition.include?("|")
      return condition.split("|").any? { |c| met?(battle, user, c.strip) }
    end

    # Handle negation
    if condition.start_with?("!")
      return !met?(battle, user, condition[1..-1])
    end

    # Parse individual condition types
    case condition
    when "grounded"
      return user&.affectedByTerrain? || false
    when "airborne", "flying"
      return user && !user.affectedByTerrain?
    when "sunny", "sun"
      return [:Sun, :HarshSun].include?(battle.pbWeather)
    when "rainy", "rain"
      return [:Rain, :HeavyRain].include?(battle.pbWeather)
    when "sandstorm", "sand"
      return battle.pbWeather == :Sandstorm
    when "hail", "snow"
      return [:Hail, :Snow].include?(battle.pbWeather)
    when "fog"
      return battle.pbWeather == :Fog
    when "noweather", "clearsky"
      return battle.pbWeather == :None
    when "day", "daytime"
      return PBDayNight.isDay?
    when "night", "nighttime"
      return PBDayNight.isNight?
    when "indoors"
      return !$game_map.metadata&.outdoor_map
    when "outdoors"
      return $game_map.metadata&.outdoor_map || false
    else
      # Handle parameterized conditions
      return evaluate_parameterized_condition(battle, user, condition)
    end
  end

  #-----------------------------------------------------------------------------
  # Evaluate conditions with parameters (type:X, move:X, counter:X>=N, etc.)
  #-----------------------------------------------------------------------------
  def evaluate_parameterized_condition(battle, user, condition)
    # Type check: "type:WATER" or "type:WATER,FIRE"
    if condition.start_with?("type:")
      types = condition[5..-1].split(",").map { |t| t.strip.upcase.to_sym }
      return false unless user
      return types.any? { |t| user.pbHasType?(t) }
    end

    # Move category: "category:physical", "category:special", "category:status"
    if condition.start_with?("category:")
      # This would need move context - handled in transformation check
      return true
    end

    # Move flag: "flag:contact", "flag:sound", etc.
    if condition.start_with?("flag:")
      # This would need move context - handled in transformation check
      return true
    end

    # Counter threshold: "counter:water_buildup>=3"
    if condition.start_with?("counter:")
      return evaluate_counter_condition(battle, condition[8..-1])
    end

    # Ability check: "ability:DRIZZLE"
    if condition.start_with?("ability:")
      ability = condition[8..-1].strip.upcase.to_sym
      return false unless user
      return user.ability_id == ability
    end

    # Item check: "item:TERRAINEXTENDER"
    if condition.start_with?("item:")
      item = condition[5..-1].strip.upcase.to_sym
      return false unless user
      return user.item_id == item
    end

    # HP threshold: "hp<50", "hp>=25"
    if condition.match?(/^hp[<>=]/)
      return evaluate_hp_condition(user, condition)
    end

    # Status check: "status:POISON", "status:BURN"
    if condition.start_with?("status:")
      status = condition[7..-1].strip.upcase.to_sym
      return false unless user
      return user.status == status
    end

    # Unknown condition - default to true (permissive)
    echoln("[FieldConditions] Unknown condition: #{condition}")
    return true
  end

  #-----------------------------------------------------------------------------
  # Evaluate counter-based conditions
  # Format: "counter_name>=value" or "counter_name<value"
  #-----------------------------------------------------------------------------
  def evaluate_counter_condition(battle, expr)
    return false unless battle.respond_to?(:field_counters)

    if expr.include?(">=")
      parts = expr.split(">=")
      counter_name = parts[0].strip.to_sym
      threshold = parts[1].strip.to_i
      return (battle.field_counters[counter_name] || 0) >= threshold
    elsif expr.include?("<=")
      parts = expr.split("<=")
      counter_name = parts[0].strip.to_sym
      threshold = parts[1].strip.to_i
      return (battle.field_counters[counter_name] || 0) <= threshold
    elsif expr.include?(">")
      parts = expr.split(">")
      counter_name = parts[0].strip.to_sym
      threshold = parts[1].strip.to_i
      return (battle.field_counters[counter_name] || 0) > threshold
    elsif expr.include?("<")
      parts = expr.split("<")
      counter_name = parts[0].strip.to_sym
      threshold = parts[1].strip.to_i
      return (battle.field_counters[counter_name] || 0) < threshold
    elsif expr.include?("==")
      parts = expr.split("==")
      counter_name = parts[0].strip.to_sym
      threshold = parts[1].strip.to_i
      return (battle.field_counters[counter_name] || 0) == threshold
    end

    return false
  end

  #-----------------------------------------------------------------------------
  # Evaluate HP-based conditions
  # Format: "hp<50" (percent), "hp>=100"
  #-----------------------------------------------------------------------------
  def evaluate_hp_condition(user, condition)
    return false unless user

    hp_percent = (user.hp.to_f / user.totalhp * 100).round

    if condition.include?(">=")
      threshold = condition.split(">=")[1].to_i
      return hp_percent >= threshold
    elsif condition.include?("<=")
      threshold = condition.split("<=")[1].to_i
      return hp_percent <= threshold
    elsif condition.include?(">")
      threshold = condition.split(">")[1].to_i
      return hp_percent > threshold
    elsif condition.include?("<")
      threshold = condition.split("<")[1].to_i
      return hp_percent < threshold
    elsif condition.include?("==")
      threshold = condition.split("==")[1].to_i
      return hp_percent == threshold
    end

    return false
  end

  #-----------------------------------------------------------------------------
  # Check if a move matches certain criteria
  # @param move [Battle::Move] The move object
  # @param criteria [String] The criteria to check (e.g., "type:WATER", "flag:contact")
  #-----------------------------------------------------------------------------
  def move_matches?(move, criteria)
    return true if criteria.nil? || criteria.empty?

    criteria = criteria.strip.downcase

    # Type check
    if criteria.start_with?("type:")
      type = criteria[5..-1].strip.upcase.to_sym
      return move.type == type
    end

    # Move ID check
    if criteria.start_with?("move:")
      move_id = criteria[5..-1].strip.upcase.to_sym
      return move.id == move_id
    end

    # Category check
    if criteria.start_with?("category:")
      cat = criteria[9..-1].strip.downcase
      case cat
      when "physical"
        return move.physicalMove?
      when "special"
        return move.specialMove?
      when "status"
        return move.statusMove?
      end
    end

    # Flag check
    if criteria.start_with?("flag:")
      flag = criteria[5..-1].strip
      return move.flags.any? { |f| f.downcase == flag.downcase }
    end

    return false
  end
end
