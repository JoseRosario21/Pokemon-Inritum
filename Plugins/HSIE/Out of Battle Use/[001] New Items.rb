# Stale Candy
ItemHandlers::UseOnPokemonMaximum.add(:STALECANDY, proc { |item, pkmn|
  next GameData::GrowthRate.max_level - pkmn.level
})

ItemHandlers::UseOnPokemon.add(:STALECANDY, proc { |item, qty, pkmn, scene|
  if pkmn.shadowPokemon?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
  if pkmn.level >= GameData::GrowthRate.max_level
    new_species = pkmn.check_evolution_on_level_up
    if !Settings::RARE_CANDY_USABLE_AT_MAX_LEVEL || !new_species
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    # Check for evolution
    pbFadeOutInWithMusic {
      evo = PokemonEvolutionScene.new
      evo.pbStartScreen(pkmn, new_species)
      evo.pbEvolution
      evo.pbEndScreen
      scene.pbRefresh if scene.is_a?(PokemonPartyScreen)
    }
    next true
  end
  # Level down
  pbSEPlay("Pkmn level up")
  pbChangeLevel(pkmn, pkmn.level - qty, scene)
  scene.pbHardRefresh
  next true
})

# Vial of Glitter
ItemHandlers::UseOnPokemon.add(:VIALOFGLITTER, proc { |item, qty, pkmn, scene|
  if pkmn.shiny? == false
    pbSEPlay('Item Used', 100, 100)
    pbMessage(_INTL("The sparkled glitter changed the color of your pokemon!"))
    pkmn.shiny = true
  elsif pkmn.shiny? == true
    pbMessage(_INTL("The sparkled glitter won't have any effect."))
    next false
  end
})
