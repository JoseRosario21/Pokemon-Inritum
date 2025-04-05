class Battle::Field_darkforest < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION, *args)
    super(battle)
    @id                  = :DarkForest
    @name                = _INTL("Dark Forest Field")
    @duration            = duration
    @fieldback           = "DarkForest"
    @nature_power_change = :MOONBLAST
    @secret_power_effect = 4 # tryLowerStat SPEED
    @field_announcement  = [_INTL("The nature's magic is intensified."),
                            _INTL(""),
                            _INTL("")]

    @multipliers = {
      [:power_multiplier, 1.2, _INTL("Nature sharpens the strike!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :GRASS
      },
      [:power_multiplier, 1.2, _INTL("The forest amplifies the buzz!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[BUGBITE BUGBUZZ LEECHLIFE PINMISSILE SILVERWIND STRUGGLEBUG].include?(move.id)
      },
      [:power_multiplier, 1.2, _INTL("The tree of life grows...")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[ALLURINGVOICE DISARMINGVOICE FAIRYWIND MOONBLAST SPIRITBREAK SPRINGTIDESTORM].include?(move.id)
      },
      [:power_multiplier, 1.2, _INTL("The darkness strengthens...")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[DARKPULSE NIGHTDAZE SNARL FEINTATTACK PURSUIT].include?(move.id)
      }
    }

    @effects[:heal_boost] = proc { |move|
      next true if %i[SYNTHESIS].include?(move.id)
      next true if %i[MOONLIGHT].include?(move.id)
    }

    @effects[:accuracy_modify] = proc { |move|
      next 80 if %i[DARKVOID].include?(move.id)
      next 85 if %i[STUNSPORE POISONPOWDER SLEEPPOWDER].include?(move.id)
      next 100 if %i[LEECHSEED GRASSWHISTLE].include?(move.id)
    }

    @effects[:ingrain_boost] = proc {
      next true
    }

  end
end