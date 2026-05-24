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
  #                         :gender (:MALE/:FEMALE/:GENDERLESS),
  #                         :nature (Symbol, e.g. :TIMID),
  #                         :ability (Symbol, e.g. :LEVITATE),
  #                         :ball (Symbol, e.g. :POKEBALL, :MASTERBALL),
  #                         :ivs (Hash, e.g. { HP: 31, SPEED: 31 }),
  #                         :zeta (true/false, gifts a Zeta Pokémon)
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
  #   :expires_at  — Optional expiry date. Use Time.new(year, month, day).
  #                  e.g. expires_at: Time.new(2025, 12, 31)
  #                  After this date the code is rejected with an expiry message.
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

    "INRITUM2025" => {
      type:       :item,
      item:       :RARECANDY,
      quantity:   3,
      name:       _INTL("3 Rare Candies"),
      expires_at: Time.new(2025, 1, 1),
    },
    "EPISODE3" => {
      type:        :pokemon,
      species:     :RALTS,
      level:       10,
      # Optional fields below demonstrate the full range of customization available for event Pokémon.
      nature:      :TIMID,
      ability:     :TRACE,
      ball:        :CHERISHBALL,
      zeta:       true,
      ivs:         { HP: 31, SPECIAL_ATTACK: 31, SPEED: 31 },
      moves:       [:SHADOWSNEAK, :CALMMIND, :PSYBEAM, :DAZZLINGGLEAM],
      held_item:   :SITRUSBERRY,
      shiny:       true,
      obtain_text: _INTL("Pokémon Inritum"),
      name:        _INTL("Episode 3 Ralts"),
      description: _INTL("A mysterious Ralts appeared!"),
    },
  }
end
