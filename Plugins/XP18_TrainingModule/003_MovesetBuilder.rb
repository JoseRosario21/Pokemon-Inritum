module XP18
  module_function

  #-----------------------------------------------------------------------------
  # Build a smart 4-move moveset for a species at a given level.
  #-----------------------------------------------------------------------------
  def build_moveset(species_id, level)
    sp_data = GameData::Species.get(species_id)
    species_types = sp_data.types
    # Collect only level-up moves at or below the Pokemon's level
    # This ensures move power scales naturally with progression
    available = []
    sp_data.moves.each { |m| available.push(m[1]) if m[0] <= level }
    available.uniq!
    # Filter to moves that exist in game data
    available.select! { |m| GameData::Move.exists?(m) }
    return [:TACKLE] if available.empty?
    # Score and select moves
    selected = []
    4.times do
      best_move = nil
      best_score = -999
      available.each do |move_id|
        next if selected.include?(move_id)
        sc = score_move(move_id, species_types, selected)
        if sc > best_score
          best_score = sc
          best_move = move_id
        end
      end
      break unless best_move
      selected.push(best_move)
    end
    # Ensure at least one damaging move
    unless selected.any? { |m| move_is_damaging?(m) }
      dmg = available.select { |m| move_is_damaging?(m) && !selected.include?(m) }
      selected[selected.length - 1] = dmg.sample if dmg.any? && selected.any?
    end
    selected
  end

  #-----------------------------------------------------------------------------
  # Score a move for moveset selection.
  #-----------------------------------------------------------------------------
  def score_move(move_id, species_types, already_selected)
    md = GameData::Move.get(move_id)
    score = 0
    is_damaging = md.category < 2
    if is_damaging
      # Base power contribution
      score += md.power
      # STAB bonus
      score += 50 if species_types.include?(md.type)
      # Coverage bonus: new type not already covered
      selected_types = already_selected.map { |m|
        GameData::Move.get(m).type if move_is_damaging?(m)
      }.compact
      if !selected_types.include?(md.type)
        score += 30
      else
        score -= 30  # Penalize redundant type coverage
      end
      # Useful secondary effect bonus
      score += 20 if md.effect_chance > 0
    else
      # Status move scoring
      score += score_status_move(md)
      # Limit to 1 status move: penalize if we already have one
      has_status = already_selected.any? { |m|
        GameData::Move.exists?(m) && GameData::Move.get(m).category == 2
      }
      score -= 60 if has_status
    end
    score
  end

  #-----------------------------------------------------------------------------
  # Score status moves by their function/usefulness.
  #-----------------------------------------------------------------------------
  def score_status_move(md)
    fc = md.function_code
    # Setup moves (stat boosters)
    return 65 if fc.start_with?("RaiseUser")
    # Recovery moves
    return 55 if fc.start_with?("HealUser")
    # Status infliction
    return 50 if fc.start_with?("Paralyze", "Poison", "Burn", "Sleep", "Confuse", "Freeze")
    # Screens/hazards
    return 45 if fc.start_with?("StartWeaken", "AddSpikes", "AddStealthRock")
    # Protect
    return 40 if fc.start_with?("Protect")
    # Generic status with some effect
    return 25 if md.effect_chance > 0
    # Low priority for unknown status moves
    10
  end
end
