class Battle::Field_urban < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Urban
    @name                = _INTL("Urban Field")
    @duration            = duration
    @fieldback           = "Urban"
    @nature_power_change = :REVENGE
    @secret_power_effect = 4 # tryLowerStat SPEED
    @field_announcement  = [_INTL("The city comes alive."),
                            _INTL(""),
                            _INTL("")]

    @multipliers = {
      [:power_multiplier, 1.1, _INTL("The streets enhance the blow!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[DOUBLEKICK MACHPUNCH LOWKICK CLOSECOMBAT DOUBLESLAP DOUBLEHIT FAKEOUT SCRATCH TACKLE].include?(move.id)
      },
      [:power_multiplier, 1.2, _INTL("Darkness thrives in the cityscape!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[BITE CRUNCH FEINTATTACK FOULPLAY PURSUIT THROATCHOP SUCKERPUNCH].include?(move.id)
      }
    }

    @effects[:base_type_add] = proc { |move|
      next :DARK if %i[REVENGE].include?(move.id)
    }

    @effects[:add_status] = proc { |move|
      next true if %i[THIEF].include?(move.id)
    }

    @effects[:increase_duration] = proc { |move|
      next 6 if %i[TAUNT].include?(move.id)
    }

    @effects[:effect_boost] = proc { |move|
      next 2 if %i[LOWSWEEP].include?(move.id)
    }

  end
end