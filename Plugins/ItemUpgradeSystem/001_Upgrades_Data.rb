##─────────────────────────────────────────────────────────────────────────────
## Item Upgrade System — Tier Definitions
##─────────────────────────────────────────────────────────────────────────────
## Each entry defines the full upgrade path for one item (10 levels).
## Level 1 is always the unmodified base effect — no cost, no change.
## Level 2 is always a free first upgrade.
## Levels 3–10 require items from the player's bag.
##
## :tiers  — Array of 10 hashes (index 0 = level 1).
##   :label      — Effect description shown in the upgrade UI.
##   :multiplier — Numeric value passed to the battle effect proc.
##   :cost       — nil (free), or Array of [item_symbol, quantity] pairs.
##─────────────────────────────────────────────────────────────────────────────

module ItemUpgradeSystem
  UPGRADES = {
    # ── Lucky Egg ─────────────────────────────────────────────────────────────
    # Boosts Exp gained in battle. Vanilla base = 1.5×.
    :LUCKYEGG => {
      name:        _INTL("Lucky Egg"),
      description: _INTL("Boosts the Exp. Points gained in battle."),
      tiers: [
        { label: _INTL("1.5× Exp"), multiplier: 1.5, cost: nil },                    # Lv.1  base
        { label: _INTL("2× Exp"),   multiplier: 2.0, cost: nil },                    # Lv.2  free
        { label: _INTL("2.5× Exp"), multiplier: 2.5, cost: [[:BIGPEARL,    3]] },   # Lv.3
        { label: _INTL("3× Exp"),   multiplier: 3.0, cost: [[:BIGPEARL,    4]] },   # Lv.4
        { label: _INTL("3.5× Exp"), multiplier: 3.5, cost: [[:BIGPEARL,    5]] },   # Lv.5
        { label: _INTL("4× Exp"),   multiplier: 4.0, cost: [[:BIGPEARL,    6]] },   # Lv.6
        { label: _INTL("4.5× Exp"), multiplier: 4.5, cost: [[:BIGPEARL,    7]] },   # Lv.7
        { label: _INTL("5× Exp"),   multiplier: 5.0, cost: [[:PEARLSTRING, 2]] },   # Lv.8
        { label: _INTL("5.5× Exp"), multiplier: 5.5, cost: [[:PEARLSTRING, 3]] },   # Lv.9
        { label: _INTL("6× Exp"),   multiplier: 6.0, cost: [[:PEARLSTRING, 4]] },   # Lv.10
      ],
    },

    # ── Amulet Coin ───────────────────────────────────────────────────────────
    # Multiplies prize money earned from trainer battles and Pay Day.
    # Vanilla base = 2×. Luck Incense shares the same upgrade level.
    :AMULETCOIN => {
      name:        _INTL("Amulet Coin"),
      description: _INTL("Multiplies prize money earned from trainer battles."),
      tiers: [
        { label: _INTL("2× money"),  multiplier: 2,  cost: nil },                    # Lv.1  base
        { label: _INTL("2.5× money"), multiplier: 3, cost: nil },                    # Lv.2  free
        { label: _INTL("3× money"),  multiplier: 3,  cost: nil },                    # Lv.3  free (N/A)
        { label: _INTL("4× money"),  multiplier: 4,  cost: [[:BIGNUGGET,  4]] },    # Lv.4
        { label: _INTL("5× money"),  multiplier: 5,  cost: [[:BIGNUGGET,  5]] },    # Lv.5
        { label: _INTL("6× money"),  multiplier: 6,  cost: [[:BIGNUGGET,  6]] },    # Lv.6
        { label: _INTL("7× money"),  multiplier: 7,  cost: [[:BIGNUGGET,  7]] },    # Lv.7
        { label: _INTL("8× money"),  multiplier: 8,  cost: [[:BIGNUGGET,  8]] },    # Lv.8
        { label: _INTL("9× money"),  multiplier: 9,  cost: [[:BIGNUGGET,  9]] },    # Lv.9
        { label: _INTL("10× money"), multiplier: 10, cost: [[:BIGNUGGET, 10]] },    # Lv.10
      ],
    },

    # ── Power Items (shared level) ────────────────────────────────────────────
    # Increases the flat EV bonus added by all 6 Power items in battle.
    # One upgrade level applies to all of them simultaneously.
    # :POWERITEMS is a virtual key — the shop checks if any power item is in bag.
    :POWERITEMS => {
      name:        _INTL("Power Items"),
      description: _INTL("Upgrades all Power items to grant more EVs per battle."),
      tiers: [
        { label: _INTL("+8 EVs"),  multiplier: 8,  cost: nil },                      # Lv.1  base
        { label: _INTL("+16 EVs"), multiplier: 16, cost: [[:STARPIECE,   2]] },      # Lv.2
        { label: _INTL("+24 EVs"), multiplier: 24, cost: [[:STARPIECE,   3]] },      # Lv.3
        { label: _INTL("+32 EVs"), multiplier: 32, cost: [[:STARPIECE,   4]] },      # Lv.4
        { label: _INTL("+40 EVs"), multiplier: 40, cost: [[:STARPIECE,   5]] },      # Lv.5
        { label: _INTL("+48 EVs"), multiplier: 48, cost: [[:STARPIECE,   6]] },      # Lv.6
        { label: _INTL("+56 EVs"), multiplier: 56, cost: [[:STARPIECE,   7]] },      # Lv.7
        { label: _INTL("+64 EVs"), multiplier: 64, cost: [[:COMETSHARD, 2]] },      # Lv.8
        { label: _INTL("+72 EVs"), multiplier: 72, cost: [[:COMETSHARD, 3]] },      # Lv.9
        { label: _INTL("+80 EVs"), multiplier: 80, cost: [[:COMETSHARD, 4]] },      # Lv.10
      ],
    },

    # ── Macho Brace ───────────────────────────────────────────────────────────
    # Boosts EVs gained in battle. Speed is halved in battle at all levels.
    :MACHOBRACE => {
      name:        _INTL("Macho Brace"),
      description: _INTL("Boosts Effort Values gained in battle.\nHolder's Speed is halved in battle."),
      tiers: [
        { label: _INTL("2× EVs"),  multiplier: 2,  cost: nil },                     # Lv.1  base
        { label: _INTL("2.5× EVs"), multiplier: 3, cost: nil },                     # Lv.2  free (rounds to 3× for integer EVs)
        { label: _INTL("3× EVs"),  multiplier: 3,  cost: [[:EVERSTONE,  3]] },      # Lv.3
        { label: _INTL("4× EVs"),  multiplier: 4,  cost: [[:EVERSTONE,  4]] },      # Lv.4
        { label: _INTL("5× EVs"),  multiplier: 5,  cost: [[:EVERSTONE,  5]] },      # Lv.5
        { label: _INTL("6× EVs"),  multiplier: 6,  cost: [[:EVERSTONE,  6]] },      # Lv.6
        { label: _INTL("7× EVs"),  multiplier: 7,  cost: [[:EVERSTONE,  7]] },      # Lv.7
        { label: _INTL("8× EVs"),  multiplier: 8,  cost: [[:EVERSTONE,  8]] },      # Lv.8
        { label: _INTL("9× EVs"),  multiplier: 9,  cost: [[:EVERSTONE,  9]] },      # Lv.9
        { label: _INTL("10× EVs"), multiplier: 10, cost: [[:EVERSTONE, 10]] },      # Lv.10
      ],
    },
  }
end
