#===============================================================================
# Daily Rifts - Settings
# Configure tiers, Pokémon pools, reward pools, and catch rules.
#===============================================================================
module DailyRifts

  # Hours before a rift regenerates a new Pokémon
  COOLDOWN_HOURS = 24

  # Catch rate multiplier applied to the post-win catch opportunity
  CATCH_RATE_MULTIPLIER = 3

  # Number of guaranteed 31-IV stats on the catchable Pokémon
  GUARANTEED_PERFECT_IVS = 2

  # HP fraction for the catchable Pokémon (simulates being weakened)
  CATCH_HP_FRACTION = 0.20

  #-----------------------------------------------------------------------------
  # Tier configuration
  # min_badges    : badges needed to unlock this tier
  # level_min/max : level range; interpolated by badge count within the tier
  # rewards_min/max: how many items the player receives on completion
  #-----------------------------------------------------------------------------
  TIER_CONFIG = {
    1 => { min_badges: 0, level_min: 8,  level_max: 18, rewards_min: 1, rewards_max: 2 },
    2 => { min_badges: 2, level_min: 18, level_max: 32, rewards_min: 2, rewards_max: 3 },
    3 => { min_badges: 4, level_min: 32, level_max: 48, rewards_min: 2, rewards_max: 3 },
    4 => { min_badges: 6, level_min: 48, level_max: 62, rewards_min: 3, rewards_max: 4 },
    5 => { min_badges: 8, level_min: 62, level_max: 75, rewards_min: 3, rewards_max: 5 },
  }.freeze

  # Display names for each tier (used in scene and messages)
  TIER_NAMES = ["Faint", "Dim", "Mystic", "Ancient", "Eternal"].freeze

  # Color per tier for the silhouette scene glow (R, G, B)
  TIER_COLORS = [
    [100, 200, 100],   # Tier 1: green
    [80,  140, 230],   # Tier 2: blue
    [180, 90,  230],   # Tier 3: purple
    [230, 170, 50],    # Tier 4: gold
    [230, 60,  60],    # Tier 5: red
  ].freeze

  #-----------------------------------------------------------------------------
  # Pokémon pools per tier.
  # Each entry is a species symbol. Customize these for your game's Pokédex.
  # The generator picks one each day based on a seeded RNG.
  #-----------------------------------------------------------------------------
  TIER_POKEMON_POOLS = {
    1 => [
      :RATTATA, :PIDGEY, :EKANS, :SANDSHREW, :ODDISH,
      :PARAS, :MEOWTH, :PSYDUCK, :SLOWPOKE, :SHELLDER,
      :GASTLY, :DROWZEE, :KRABBY, :HORSEA, :GOLDEEN,
    ],
    2 => [
      :KADABRA, :MACHOKE, :TENTACOOL, :MAGNETON, :DODUO,
      :DEWGONG, :HAUNTER, :VOLTORB, :EXEGGCUTE, :KOFFING,
      :RHYHORN, :CHANSEY, :TANGELA, :KANGASKHAN, :STARYU,
    ],
    3 => [
      :ONIX, :HYPNO, :KINGLER, :ELECTRODE, :MAROWAK,
      :HITMONCHAN, :HITMONLEE, :LICKITUNG, :RHYDON, :STARMIE,
      :ELECTABUZZ, :MAGMAR, :PINSIR, :TAUROS, :SCYTHER,
    ],
    4 => [
      :DRATINI, :LAPRAS, :PORYGON, :AERODACTYL, :SNORLAX,
      :ARTICUNO, :ZAPDOS, :MOLTRES, :DRAGONAIR, :JYNX,
      :MR__MIME, :EEVEE, :VAPOREON, :JOLTEON, :FLAREON,
    ],
    5 => [
      :DRAGONITE, :GENGAR, :ALAKAZAM, :MACHAMP, :GOLEM,
      :ARCANINE, :CLOYSTER, :GYARADOS, :KABUTOPS, :OMASTAR,
      :NIDOKING, :NIDOQUEEN, :VICTREEBEL, :EXEGGUTOR, :WEEZING,
    ],
  }.freeze

  #-----------------------------------------------------------------------------
  # Reward pools per tier.
  # Each entry: { item: :ITEM_ID, weight: N }
  # Higher weight = more likely to be selected.
  #-----------------------------------------------------------------------------
  REWARD_POOLS = {
    1 => [
      { item: :POMEGBERRY,  weight: 12 },
      { item: :KELPSYBERRY, weight: 12 },
      { item: :QUALOTBERRY, weight: 12 },
      { item: :HONDEWBERRY, weight: 12 },
      { item: :GREPABERRY,  weight: 12 },
      { item: :TAMATOBERRY, weight: 12 },
      { item: :EXPCANDYXS,  weight: 10 },
      { item: :EXPCANDYS,   weight: 8  },
      { item: :PEARL,       weight: 8  },
    ],
    2 => [
      { item: :POMEGBERRY,  weight: 10 },
      { item: :KELPSYBERRY, weight: 10 },
      { item: :QUALOTBERRY, weight: 10 },
      { item: :HONDEWBERRY, weight: 10 },
      { item: :GREPABERRY,  weight: 10 },
      { item: :TAMATOBERRY, weight: 10 },
      { item: :EXPCANDYS,   weight: 10 },
      { item: :EXPCANDYM,   weight: 8  },
      { item: :PEARL,       weight: 8  },
      { item: :BIGPEARL,    weight: 5  },
    ],
    3 => [
      { item: :POMEGBERRY,  weight: 8  },
      { item: :KELPSYBERRY, weight: 8  },
      { item: :QUALOTBERRY, weight: 8  },
      { item: :HONDEWBERRY, weight: 8  },
      { item: :GREPABERRY,  weight: 8  },
      { item: :TAMATOBERRY, weight: 8  },
      { item: :EXPCANDYM,   weight: 10 },
      { item: :EXPCANDYL,   weight: 6  },
      { item: :BIGPEARL,    weight: 8  },
      { item: :PEARLSTRING, weight: 4  },
      { item: :RARECANDY,   weight: 3  },
    ],
    4 => [
      { item: :POMEGBERRY,  weight: 5  },
      { item: :KELPSYBERRY, weight: 5  },
      { item: :QUALOTBERRY, weight: 5  },
      { item: :HONDEWBERRY, weight: 5  },
      { item: :GREPABERRY,  weight: 5  },
      { item: :TAMATOBERRY, weight: 5  },
      { item: :EXPCANDYL,   weight: 10 },
      { item: :EXPCANDYXL,  weight: 7  },
      { item: :PEARLSTRING, weight: 8  },
      { item: :RARECANDY,   weight: 6  },
    ],
    5 => [
      { item: :POMEGBERRY,  weight: 4  },
      { item: :KELPSYBERRY, weight: 4  },
      { item: :QUALOTBERRY, weight: 4  },
      { item: :HONDEWBERRY, weight: 4  },
      { item: :GREPABERRY,  weight: 4  },
      { item: :TAMATOBERRY, weight: 4  },
      { item: :EXPCANDYXL,  weight: 10 },
      { item: :PEARLSTRING, weight: 10 },
      { item: :RARECANDY,   weight: 8  },
    ],
  }.freeze

end
