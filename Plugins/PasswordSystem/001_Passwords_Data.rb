##─────────────────────────────────────────────────────────────────────────────
## Password System — Data Definitions
## Add your passwords here. Keys are case-insensitive and whitespace-trimmed.
##─────────────────────────────────────────────────────────────────────────────

module PasswordSystem
  # ---------------------------------------------------------------------------
  # Effect type reference:
  #
  #   :item     — Give item(s) to the player's bag.
  #               Required: :item (Symbol)
  #               Optional: :quantity (default 1)
  #
  #   :pokemon  — Give an event Pokémon. Player is prompted for nickname and
  #               the Pokémon is stored in party or box automatically.
  #               Required: :species (Symbol), :level (Integer)
  #               Optional: :shiny (true/false), :moves (Array of Symbols),
  #                         :obtain_text (String), :held_item (Symbol),
  #                         :gender (:MALE/:FEMALE/:GENDERLESS)
  #
  #   :switch   — Set a game switch on or off.
  #               Required: :switch (Integer, switch ID)
  #               Optional: :value (true/false, default true)
  #
  #   :variable — Set a game variable to a value.
  #               Required: :variable (Integer, variable ID), :value
  #
  #   :multi    — Apply multiple effects at once.
  #               Required: :effects (Array of effect hashes, each with :type)
  #
  # All types require:
  #   :name        — Short display name shown to the player.
  # All types accept:
  #   :description — Optional message shown after successful redemption.
  # ---------------------------------------------------------------------------

  PASSWORDS = {
    # ── Item example ──────────────────────────────────────────────────────────
    # "INRITUM2024" => {
    #   type:        :item,
    #   item:        :RARECANDY,
    #   quantity:    3,
    #   name:        _INTL("3 Rare Candies"),
    #   description: _INTL("A thank-you gift from the Inritum team!"),
    # },

    # ── Event Pokémon example ─────────────────────────────────────────────────
    # "SPECIALMEW" => {
    #   type:        :pokemon,
    #   species:     :MEW,
    #   level:       10,
    #   shiny:       false,
    #   obtain_text: _INTL("Pokémon Inritum"),
    #   name:        _INTL("Fateful Mew"),
    #   description: _INTL("A mysterious Mew arrived!"),
    # },

    # ── Switch unlock example ─────────────────────────────────────────────────
    # "OPENTHECAVE" => {
    #   type:        :switch,
    #   switch:      50,
    #   value:       true,
    #   name:        _INTL("Hidden Cave Access"),
    #   description: _INTL("A new path has opened somewhere in the world..."),
    # },

    # ── Variable example ──────────────────────────────────────────────────────
    # "HARDMODE" => {
    #   type:     :variable,
    #   variable: 20,
    #   value:    2,
    #   name:     _INTL("Hard Mode"),
    # },

    # ── Multi-effect example ──────────────────────────────────────────────────
    # "BIGBUNDLE" => {
    #   type: :multi,
    #   name: _INTL("Starter Bundle"),
    #   effects: [
    #     { type: :item, item: :POTION,    quantity: 5 },
    #     { type: :item, item: :POKEBALL,  quantity: 10 },
    #     { type: :switch, switch: 51, value: true },
    #   ],
    #   description: _INTL("Everything you need to begin your journey!"),
    # },
  }
end
