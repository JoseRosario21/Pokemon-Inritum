module XP18
  module_function

  #-----------------------------------------------------------------------------
  # Collect candidate species filtered by BST range and blacklist.
  #-----------------------------------------------------------------------------
  def candidate_species(bst_min, bst_max, max_level = nil)
    candidates = []
    GameData::Species.each_species do |sp|
      next if BLACKLIST.include?(sp.id)
      bst = sp.base_stat_total
      next if bst < bst_min || bst > bst_max
      # Ensure species has at least one damaging move learnable by max_level
      if max_level
        has_damage = sp.moves.any? { |m| m[0] <= max_level && move_is_damaging?(m[1]) }
        next unless has_damage
      end
      candidates.push(sp.id)
    end
    candidates
  end

  #-----------------------------------------------------------------------------
  # Check if a move is damaging (Physical or Special).
  #-----------------------------------------------------------------------------
  def move_is_damaging?(move_id)
    return false unless GameData::Move.exists?(move_id)
    GameData::Move.get(move_id).category < 2  # 0=Physical, 1=Special
  end

  #-----------------------------------------------------------------------------
  # Generate a team of `count` Pokemon within the given level/BST ranges.
  #-----------------------------------------------------------------------------
  def generate_team(count, level_range, bst_range_arr)
    bst_min, bst_max = bst_range_arr
    min_lv, max_lv = level_range
    candidates = candidate_species(bst_min, bst_max, max_lv)
    # Fallback: if not enough candidates, widen BST range
    if candidates.length < count
      candidates = candidate_species([bst_min - 50, 100].max, bst_max + 50, max_lv)
    end
    # Still not enough? Use whatever we have (shouldn't happen with full dex)
    selected = candidates.sample([count, candidates.length].min)
    team = []
    selected.each do |species_id|
      level = rand(min_lv..max_lv)
      team.push(build_pokemon(species_id, level))
    end
    team
  end

  #-----------------------------------------------------------------------------
  # Generate an EV-themed team: species biased toward the trained stat.
  #-----------------------------------------------------------------------------
  def generate_ev_team(player_pkmn, ev_stat)
    level = [player_pkmn.level + EV_LEVEL_OFFSET, 5].max
    # BST range based on the selected Pokemon's level, not the level cap
    bst_min, bst_max = bst_range_for_level(player_pkmn.level)
    # Collect candidates biased toward the EV stat
    candidates = []
    GameData::Species.each_species do |sp|
      next if BLACKLIST.include?(sp.id)
      bst = sp.base_stat_total
      next if bst < bst_min || bst > bst_max
      # Must have at least one damaging move at this level
      has_damage = sp.moves.any? { |m| m[0] <= level && move_is_damaging?(m[1]) }
      next unless has_damage
      # Prefer species that yield this EV (thematic)
      ev_yield = sp.evs[ev_stat] || 0
      # Also accept species with high base stat in the trained stat
      base_val = sp.base_stats[ev_stat] || 0
      score = ev_yield * 3 + base_val
      candidates.push([sp.id, score])
    end
    # Sort by score descending, take top pool, then sample
    candidates.sort_by! { |c| -c[1] }
    pool = candidates.first([candidates.length, 20].min).map { |c| c[0] }
    pool = pool.sample([EV_ENEMY_COUNT, pool.length].min)
    # Fallback if pool too small: widen BST range
    if pool.length < EV_ENEMY_COUNT
      extras = candidate_species([bst_min - 50, 100].max, bst_max + 50, level)
      extras -= pool
      pool += extras.sample(EV_ENEMY_COUNT - pool.length)
    end
    pool.map { |sp| build_pokemon(sp, level) }
  end

  #-----------------------------------------------------------------------------
  # Build a single Pokemon with smart moveset, random nature/ability/item.
  #-----------------------------------------------------------------------------
  def build_pokemon(species_id, level)
    sp_data = GameData::Species.get(species_id)
    # Temporarily enable bypass so Level Caps don't clamp enemy levels
    if LEVEL_CAP_BYPASS_SWITCH
      bypass_was = $game_switches[LEVEL_CAP_BYPASS_SWITCH]
      $game_switches[LEVEL_CAP_BYPASS_SWITCH] = true
    end
    pkmn = Pokemon.new(species_id, level, nil, false)
    if LEVEL_CAP_BYPASS_SWITCH
      $game_switches[LEVEL_CAP_BYPASS_SWITCH] = bypass_was
    end
    # Random ability from species pool
    all_abilities = (sp_data.abilities + sp_data.hidden_abilities).uniq.compact
    all_abilities = sp_data.abilities if all_abilities.empty?
    pkmn.ability = all_abilities.sample if all_abilities.any?
    # Random nature
    natures = []
    GameData::Nature.each { |n| natures.push(n.id) }
    pkmn.nature = natures.sample
    # Set IVs to 20 across the board (competent but not perfect)
    GameData::Stat.each_main { |s| pkmn.iv[s.id] = 20 }
    # Smart moveset
    moves = build_moveset(species_id, level)
    moves.each { |m| pkmn.learn_move(m) }
    # Held item (tiered by level, only if item exists in game data)
    valid_items = held_items_for_level(level).select { |i| GameData::Item.exists?(i) }
    # Don't give Eviolite to fully evolved Pokemon (no further evolutions)
    if sp_data.get_evolutions.empty?
      valid_items.delete(:EVIOLITE)
    end
    pkmn.item = valid_items.sample if valid_items.any?
    pkmn.calc_stats
    pkmn.hp = pkmn.totalhp
    pkmn
  end
end
