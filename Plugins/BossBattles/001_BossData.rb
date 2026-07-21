#===============================================================================
# Boss Battles - Configuration
#
# Define all bosses here. Call pbBossBattle(:BOSS_ID) from a map event.
#
# ── Per-boss keys ────────────────────────────────────────────────────────────
#  :name          String   Custom display name (optional, defaults to species name)
#  :species        Symbol   Pokémon species
#  :level          Integer  Pokémon level
#  :form           Integer  Form index (default 0)
#  :ability        Symbol   Ability (default: species default)
#  :nature         Symbol   Nature (default :HARDY)
#  :moves          Array    4 move symbols (default: species learnset)
#  :item           Symbol   Held item (default: none)
#  :iv             Integer  Uniform IV value 0–31 (default 31)
#  :catchable      Boolean  Whether the boss can be caught after all shields
#                           break (default false)
#  :entry_text     String   Message shown before the battle starts (optional)
#
# ── Shield system ────────────────────────────────────────────────────────────
#  :shield_count   Integer  Number of shields (0 = no shields, boss just fights)
#
#  :on_break       Hash     Keyed by shield number, highest first.
#    Each entry supports:
#      :message        String   Displayed on shield break ({1} = boss name)
#      :animation      Symbol   Common animation to play (e.g. :TRANSFORM)
#      :form_change    Integer  New form index
#      :type_change    Array    New types as symbols, e.g. [:GHOST, :DARK]
#      :ability        Symbol   New ability
#      :moves          Array    Replacement moveset (1–4 move symbols)
#      :stat_changes   Hash     e.g. { SPECIAL_ATTACK: +2, SPEED: -1 }
#                               Full stat IDs: HP ATTACK DEFENSE
#                               SPECIAL_ATTACK SPECIAL_DEFENSE SPEED
#      :status_cure    Boolean  Cure status condition on break
#      :stat_reset     Boolean  Reset all stat stages to 0 on break
#      :weather        Symbol   Set weather (:Sun, :Rain, :Sandstorm, :Hail, …)
#      :weather_turns  Integer  Duration for weather (default 5)
#      :bgm            String   Filename of new BGM to play
#      :ally_call      Hash     { species: :SYMBOL, level: N }
#                               Summons an ally into the battle on this break
#
# ── Charge attack ────────────────────────────────────────────────────────────
#  :charge_attack  Hash
#      :interval   Integer  Fires every N end-of-rounds (e.g. 3)
#      :move       Symbol   Move to use (targets a random opponent)
#      :warning    String   Optional message shown at start of the interval
#                           ({1} = boss name)
#
#===============================================================================

module BossBattle

  BOSS_DATA = {

    #===========================================================================
    # Example: Chandelure boss (2 shields)
    # First shield break → type changes, new moves, BGM swap
    # Second shield break → form-equivalent stat boost, ally Ghost
    #===========================================================================
    :CHANDELURE_BOSS => {
      name:          "Shadow Chandelure",
      species:       :CHANDELURE,
      level:         60,
      form:          0,
      ability:       :SHADOWTAG,
      nature:        :MODEST,
      moves:         [:SHADOWBALL],
      item:          :LIFEORB,
      iv:            31,
      catchable:     false,
      entry_text:    "A twisted flame blazes within the rift...\nShadow Chandelure has awakened!",

      shield_count:  2,

      on_break: {
        # Shield 2 breaks first
        2 => {
          message:      "{1}'s seal of restraint shatters!",
          animation:    "Explosion",
          type_change:  [:GHOST, :DARK],
          moves:        [:SHADOWBALL],
          stat_changes: { SPECIAL_ATTACK: 2 },
          bgm:          "Battle - Intense",
        },
        # Shield 1 breaks last (before boss is vulnerable)
        1 => {
          message:      "{1} is consumed by darkness!",
          animation:    "Explosion",
          ability:      :NOGUARD,
          moves:        [:SHADOWBALL],
          stat_changes: { SPECIAL_ATTACK: 2, SPEED: 1 },
          status_cure:  true,
          stat_reset:   false,
          ally_call:    { species: :LITWICK, level: 55 },
        },
      },

      charge_attack: {
        interval: 3,
        move:     :OVERHEAT,
        warning:  "{1} is gathering a surge of dark flames!",
      },
    },

    #===========================================================================
    # Animus Golurk — Ceryneian Temple guardian
    #===========================================================================
    :ANIMUS_GOLURK => {
      name:          "Animus Golurk",
      species:       :GOLURK,
      level:         45,
      form:          2,
      ability:       :CURSEDSTEEL,
      nature:        :ADAMANT,
      moves:         [:SPIRITBREAK, :JETPUNCH, :BULLETPUNCH, :IRONHEAD], # TODO: swap :IRONHEAD for final 4th move
      iv:            31,
      catchable:     false,
      entry_text:    "The Ceryneian Temple falls silent.\nIts eternal guardian will not let you pass.",

      shield_count:  1,

      on_break: {
        1 => {
          message:      "{1}'s battle scars ignite with cursed energy!",
          stat_changes: { ATTACK: 2 },
        },
      },
    },

    #===========================================================================
    # Minimal template — copy this for new bosses
    #===========================================================================
    # :MY_BOSS => {
    #   species:      :GARCHOMP,
    #   level:        70,
    #   nature:       :JOLLY,
    #   moves:        [:EARTHQUAKE, :DRAGONCLAW, :STONEEDGE, :SWORDSDANCE],
    #   iv:           31,
    #   catchable:    false,
    #   entry_text:   "The Land Shark stirs...",
    #
    #   shield_count: 1,
    #
    #   on_break: {
    #     1 => {
    #       message:      "{1} roars with renewed fury!",
    #       stat_changes: { ATTACK: 3, SPEED: 2 },
    #     },
    #   },
    #
    #   charge_attack: {
    #     interval: 4,
    #     move:     :DRAGONRUSH,
    #     warning:  "{1} coils up for a devastating strike!",
    #   },
    # },

  }

end
