#==============================================================================
# RiddleDetectors
# Wraps item and move handlers to detect when the player solves riddles.
# Each riddle checks the current map and the RiddleCount variable (44).
#==============================================================================

#------------------------------------------------------------------------------
# Riddle 1 — Pomeg Berry (Map 45, RiddleCount == 0)
# "Show me how life and friendship are related."
#------------------------------------------------------------------------------
_pomeg_original = ItemHandlers::UseOnPokemon.instance_variable_get(:@hash)[:POMEGBERRY]

ItemHandlers::UseOnPokemon.add(:POMEGBERRY, proc { |item, qty, pkmn, scene|
  result = _pomeg_original&.call(item, qty, pkmn, scene)
  if $game_map&.map_id == 45 && $game_variables[44] == 0
    $game_variables[44] += 1
    $game_map.need_refresh = true
  end
  next result
})

#------------------------------------------------------------------------------
# Riddle 2 — Name entry (Map 45, RiddleCount == 1)
# "Enigmatic by essence... My body and my Pokédex number are related: 5!"
# Answer: Staryu (#120, 5! = 120)
#------------------------------------------------------------------------------
def pbRiddle2Solved?
  return $game_variables[45].downcase == "staryu"
end

#------------------------------------------------------------------------------
# Riddle 3 — Sweet Scent (Map 45, RiddleCount == 2)
# "Winds may move but you remain stationary. A particular scent..."
#------------------------------------------------------------------------------
_sweetscent_original = HiddenMoveHandlers::UseMove.instance_variable_get(:@hash)[:SWEETSCENT]

HiddenMoveHandlers::UseMove.add(:SWEETSCENT, proc { |move, pokemon|
  result = _sweetscent_original&.call(move, pokemon)
  if result && $game_map&.map_id == 45 && $game_variables[44] == 2
    $game_variables[44] += 1
    $game_map.need_refresh = true
  end
  next result
})

#------------------------------------------------------------------------------
# Riddle 4 — Name entry (Map 45, RiddleCount == 3)
# A mirror is what I am. Look at me and I shall melt
# Answer: Bronzor (Pure dex references)
#------------------------------------------------------------------------------
def pbRiddle4Solved?
  return $game_variables[45].downcase == "bronzor"
end