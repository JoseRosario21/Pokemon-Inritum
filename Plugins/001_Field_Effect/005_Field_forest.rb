class Battle::Field_forest < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Forest
    @name                = _INTL("Forest Field")
    @duration            = duration
    @fieldback           = "Forest"
    @nature_power_change = :BUGBUZZ
    @secret_power_effect = 4 # tryLowerStat SPEED
    @field_announcement  = [_INTL("The woods grow dense."),
                            _INTL(""),
                            _INTL("")]

    @multipliers = {
      [:power_multiplier, 1.2, _INTL("Nature sharpens the strike!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :GRASS
      },
      [:power_multiplier, 1.2, _INTL("The forest amplifies the buzz!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[BUGBITE BUGBUZZ LEECHLIFE PINMISSILE SILVERWIND STRUGGLEBUG].include?(move.id)
      },
      [:power_multiplier, 1.1, _INTL("The forest ignites, fueling the blaze!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[FLAMECHARGE INCINERATE HEATCRASH FLAREBLITZ].include?(move.id)
      }
    }

    @effects[:binding_boost] = proc { |move|
      next true if %i[INFESTATION].include?(move.id)
    }

    @effects[:heal_boost] = proc { |move|
      next true if %i[SYNTHESIS].include?(move.id)
    }

    @effects[:accuracy_modify] = proc { |move|
      next 85 if %i[STUNSPORE POISONPOWDER SLEEPPOWDER].include?(move.id)
      next 100 if %i[LEECHSEED GRASSWHISTLE].include?(move.id)
    }

    @effects[:base_type_change] = proc { |move|
      next :GRASS if %i[CUT].include?(move.id)
    }

    @effects[:ingrain_boost] = proc {
      next true
    }

  end
end