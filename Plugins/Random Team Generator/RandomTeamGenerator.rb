def pbRandomTeamGenerator(partySize)
  # Sets Trainer Class, Name, and other properties...
  opp = NPCTrainer.new("XP-18 Simulation", :YOUNGSTER)
  opp.lose_text = "Simulated battle over..."

  # Creates a hash of Pokemon with their respective details
  pokemon_details = {
    TOTODILE:   { level: 13, ability: :TORRENT,       moves: [:SCARYFACE, :BITE, :AQUAJET],           item: :ORANBERRY, nature: :ADAMANT  },
    CHARMANDER: { level: 12, ability: :BLAZE,         moves: [:DRAGONBREATH, :EMBER, :SMOKESCREEN],   item: :CHARCOAL                     },
    TREECKO:    { level: 13, ability: :OVERGROW,      moves: [:MEGADRAIN, :QUICKATTACK, :AERIALACE],  item: :BIGROOT                      },
    EEVEE:      { level: 11, ability: :ADAPTABILITY,  moves: [:QUICKATTACK, :SANDATTACK, :COVET],     item: :SILKSCARF                    },
    PIKACHU:    { level: 11, ability: :STATIC,        moves: [:ELECTROBALL],                          item: :CHOICESCARF,                 },
    BUTTERFREE: { level: 10, ability: :COMPOUNDEYES,  moves: [:CONFUSION, :GUST, :POISONPOWDER],                                          },
    BEEDRILL:   { level: 10, ability: :SWARM,         moves: [:BUGBITE, :FURYATTACK, :POISONSTING],   item: :POISONBARB                   },
    ODDISH:     { level: 12, ability: :CHLOROPHYLL,   moves: [:MEGADRAIN, :ACID, :GROWTH],            item: :ORANBERRY,                   },
    ZIGZAGOON:  { level: 13, ability: :PICKUP,        moves: [:HEADBUTT, :GROWL],                     item: :LEFTOVERS                    },
    MACHOP:     { level: 13, ability: :GUTS,          moves: [:LOWSWEEP, :BRICKBREAK, :FOCUSENERGY],  item: :BLACKBELT                    },
    WIGLETT:    { level: 13, ability: :GOOEY,         moves: [:WRAP, :AQUAJET, :MUDSLAP]                                                  },
    SHELLDER:   { level: 14, ability: :SHELLARMOR,    moves: [:WITHDRAW, :WATERGUN, :ICESHARD],       item: :SHELLBELL                    },
    HIPPOPOTAS: { level: 13, ability: :SANDSTREAM,    moves: [:BITE, :SANDTOMB, :YAWN],               item: :SMOOTHROCK                   },
    SNORUNT:    { level: 13, ability: :ICEBODY,       moves: [:ASTONISH, :SNOWSCAPE, :POWDERSNOW],    item: :ORANBERRY                    },
    TRAPINCH:   { level: 13, ability: :HYPERCUTTER,   moves: [:BULLDOZE, :BITE],                      item: :SOFTSAND                     },
    KOFFING:    { level: 14, ability: :LEVITATE,      moves: [:POISONGAS, :SMOG, :SMOKESCREEN],                                           },
    SEEL:       { level: 13, ability: :ICEBODY,       moves: [:ICYWIND, :ENCORE, :CHARM],             item: :EJECTBUTTON,                 },
    ZUBAT:      { level: 15, ability: :INNERFOCUS,    moves: [:POISONFANG, :MEANLOOK, :SUPERSONIC],   item: :WIDELENS                     },
    GOOMY:      { level: 12, ability: :SAPSIPPER,     moves: [:WATERGUN, :ABSORB, :DRAGONBREATH],     item: :WISEGLASSES,                 }
  }

  # Select unique Pokemon for the opponent's party
  selected_pokemon = pokemon_details.keys.sample(partySize)

  opp.party = selected_pokemon.map do |species|
    details = pokemon_details[species]
    pkmn = Pokemon.new(species, details[:level])
    pkmn.ability  = details[:ability]
    pkmn.item     = details[:item] if details[:item]
    pkmn.moves    = details[:moves]
    pkmn.nature   = details[:nature] if details[:nature]
    pkmn.calc_stats
    pkmn
  end

  # Starts the Trainer Battle
  TrainerBattle.start(opp)
end