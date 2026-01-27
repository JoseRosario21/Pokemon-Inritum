# Force Zeta via game switch (debug tool).
EventHandlers.add(:on_wild_pokemon_created, :make_zeta_switch,
  proc { |pkmn|
    pkmn.zeta = true if $game_switches[Settings::ZETA_WILD_POKEMON_SWITCH]
  }
)

# When a wild Pokemon is Zeta, max the IVs of its 2 highest base stats.
EventHandlers.add(:on_wild_pokemon_created, :zeta_max_ivs,
  proc { |pkmn|
    next unless pkmn.zeta?
    # Use original (pre-boost) base stats to determine which 2 stats to max
    base = pkmn.species_data.base_stats
    sorted = base.sort_by { |_k, v| -v }
    top_two = sorted.first(2).map { |s| s[0] }
    top_two.each { |stat| pkmn.iv[stat] = Pokemon::IV_STAT_LIMIT }
    pkmn.calc_stats
  }
)
