class Battle::Field_psychic < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Psychic
    @name                = _INTL("Psychic Field")
    @duration            = duration
    @fieldback           = "Psychic"
    @nature_power_change = :PSYCHIC
    @secret_power_effect = 4 # tryLowerStat SPEED
    @field_announcement  = [_INTL("The field became mysterious!"),
                            _INTL("The field is weird!"),
                            _INTL("The weirdness disappeared from the field!")]

    @multipliers = {
      [:power_multiplier, 1.3] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :PSYCHIC && user.affectedByTerrain?
      },
    }

    @effects[:block_move] = proc { |move, user, target, typeMod, show_message, priority, aiCheck|
      if target.affectedByTerrain? && target.opposes?(user) && priority > 0
        @battle.pbDisplay(_INTL("{1} is protected by the psychic field!", target.pbThis)) if show_message
        next true
      end
    }

  end
end