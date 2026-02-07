module Settings
  # Maximum Research XP a player can accumulate (lifetime).
  MAX_RESEARCHER_XP = 99_999

  # Maximum Research Tokens a player can hold (spendable currency).
  MAX_RESEARCHER_TOKENS = 99_999

  # Game Switch that controls whether the "Researcher" pause menu option is visible.
  RESEARCHER_UNLOCKED_SWITCH = 98
end

#===============================================================================
# Zeta Researcher Constants
#===============================================================================
module ZetaResearcher
  # BST-based tiers (checked high to low). Each tier defines:
  #   :min_bst            - minimum base stat total to qualify
  #   :catch_xp           - XP awarded on catching a Zeta of this tier
  #   :catch_tokens       - Tokens awarded on catching a Zeta of this tier
  #   :donate_xp          - XP awarded on donating a Zeta of this tier
  #   :donate_tokens      - Tokens awarded on donating a Zeta of this tier
  #   :first_bonus_xp     - extra XP for first-time species donation
  #   :first_bonus_tokens - extra Tokens for first-time species donation
  ZETA_TIERS = {
    :Legendary => { :min_bst => 600, :catch_xp => 50,  :catch_tokens => 1,
                    :donate_xp => 100, :donate_tokens => 20,
                    :first_bonus_xp => 200, :first_bonus_tokens => 40 },
    :Epic      => { :min_bst => 500, :catch_xp => 30,  :catch_tokens => 1,
                    :donate_xp => 60,  :donate_tokens => 12,
                    :first_bonus_xp => 120, :first_bonus_tokens => 24 },
    :Rare      => { :min_bst => 400, :catch_xp => 15,  :catch_tokens => 1,
                    :donate_xp => 30,  :donate_tokens => 6,
                    :first_bonus_xp => 60,  :first_bonus_tokens => 12 },
    :Common    => { :min_bst => 0,   :catch_xp => 5,   :catch_tokens => 1,
                    :donate_xp => 10,  :donate_tokens => 2,
                    :first_bonus_xp => 25,  :first_bonus_tokens => 5 }
  }

  # Researcher ranks. Each entry: [name, total_xp_threshold, unlock_key]
  # total_xp (lifetime) is used for ranking, not spendable tokens.
  RESEARCHER_RANKS = [
    ["Novice",     0,    :novice],
    ["Junior",     50,  :junior],
    ["Researcher", 200,  :researcher],
    ["Senior",     500, :senior],
    ["Assistant",  1000,   :assistant],
    ["Lead",       2000, :lead],
    ["Professor",  5000, :professor]
  ]

  #=============================================================================
  # RP Shop Stock - items available at each rank (cumulative).
  # The player sees all items from their rank and every rank below it.
  # Each entry maps a rank index (matching RESEARCHER_RANKS) to an item list.
  # Items use their bp_price from PBS as the Token cost.
  #=============================================================================
  RP_SHOP_STOCK = {
    0 => [                            # Novice — EV Training + Tickets
      :MACHOBRACE,
      :POWERWEIGHT, :POWERBRACER, :POWERBELT,
      :POWERLENS, :POWERBAND, :POWERANKLET,
      :EVTICKET, :IVTICKET
    ],
    1 => [                            # Junior — Mints (15 tokens each)
      :LONELYMINT, :ADAMANTMINT, :NAUGHTYMINT, :BRAVEMINT,
      :BOLDMINT, :IMPISHMINT, :LAXMINT, :RELAXEDMINT,
      :MODESTMINT, :MILDMINT, :RASHMINT, :QUIETMINT,
      :CALMMINT, :GENTLEMINT, :CAREFULMINT, :SASSYMINT,
      :TIMIDMINT, :HASTYMINT, :JOLLYMINT, :NAIVEMINT,
      :SERIOUSMINT
    ],
    2 => [                            # Researcher — Low-tier held items
      :FOCUSSASH, :AIRBALLOON, :EJECTBUTTON, :EJECTPACK,
      :REDCARD, :WEAKNESSPOLICY, :BLUNDERPOLICY,
      :THROATSPRAY, :ROOMSERVICE, :TERRAINEXTENDER,
      :BINDINGBAND, :RARECANDY
    ],
    3 => [                            # Senior — High-tier held items
      :CHOICEBAND, :CHOICESPECS, :CHOICESCARF,
      :LIFEORB, :LEFTOVERS, :ASSAULTVEST,
      :ROCKYHELMET, :HEAVYDUTYBOOTS, :SAFETYGOGGLES,
      :EXPERTBELT, :EVIOLITE, :METRONOME,
      :MUSCLEBAND, :WISEGLASSES, :SCOPELENS,
      :PROTECTIVEPADS, :UTILITYUMBRELLA
    ],
    4 => [                            # Assistant — Ability items + PP Up
      :ABILITYCAPSULE, :ABILITYPATCH, :PPUP
    ],
    5 => [                            # Lead — Bottle Cap (150 tokens)
      :BOTTLECAP
    ],
    6 => [                            # Professor — Premium items
      :GOLDBOTTLECAP, :PPMAX
    ]
  }

  #=============================================================================
  # Research Missions
  # Each mission has:
  #   :name       - display name
  #   :desc       - description text
  #   :type       - :daily or :one_time
  #   :tier       - minimum rank index required (0 = Novice)
  #   :auto_track - tracking hook symbol (:catch_pokemon, :catch_zeta, :catch_type,
  #                 :donate_zeta, :win_trainer)
  #   :goal       - number required to complete
  #   :rewards    - { tokens: N } and optionally { tokens: N, items: [[:ITEM, qty]] }
  #   :type_param - (optional) for :catch_type missions, the required Pokémon type
  #=============================================================================
  RESEARCHER_MISSIONS = {
    # --- Tier 0 (Novice) dailies ---
    :daily_catch_any    => { :name => "Field Work",       :desc => "Catch 5 wild Pokémon.",
                             :type => :daily, :tier => 0, :auto_track => :catch_pokemon, :goal => 5,
                             :rewards => { :tokens => 5 } },
    :daily_catch_zeta   => { :name => "Zeta Specimen",    :desc => "Catch a Zeta Pokémon.",
                             :type => :daily, :tier => 0, :auto_track => :catch_zeta, :goal => 1,
                             :rewards => { :tokens => 10 } },
    :daily_win_trainers => { :name => "Battle Practice",  :desc => "Win 3 trainer battles.",
                             :type => :daily, :tier => 0, :auto_track => :win_trainer, :goal => 3,
                             :rewards => { :tokens => 8 } },
    # --- One-time missions ---
    :ot_catch_50        => { :name => "Seasoned Catcher", :desc => "Catch 50 wild Pokémon total.",
                             :type => :one_time, :tier => 0, :auto_track => :catch_pokemon, :goal => 50,
                             :rewards => { :tokens => 50 } },
    :ot_donate_10       => { :name => "Generous Donor",   :desc => "Donate 10 Zeta Pokémon.",
                             :type => :one_time, :tier => 1, :auto_track => :donate_zeta, :goal => 10,
                             :rewards => { :tokens => 80 } },
    :ot_win_50          => { :name => "Battle Veteran",   :desc => "Win 50 trainer battles.",
                             :type => :one_time, :tier => 0, :auto_track => :win_trainer, :goal => 50,
                             :rewards => { :tokens => 60 } }
  }
end
