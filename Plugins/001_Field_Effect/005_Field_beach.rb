class Battle::Field_beach < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Beach
    @name                = _INTL("Beach Field")
    @duration            = duration
    @fieldback           = "Beach"
    @nature_power_change = :MUDDYWATER
    @secret_power_effect = 4 # tryLowerStat SPEED
    @field_announcement  = [_INTL("A soothing breeze flows through the beach."),
                            _INTL(""),
                            _INTL("")]

    @multipliers = {
      [:power_multiplier, 1.2, _INTL("The rising tides powered up the move!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[MUDDYWATER].include?(move.id)
      },
      [:power_multiplier, 1.1, _INTL("The rising tides powered up the move!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[SCALD].include?(move.id)
        next true if %i[SURF].include?(move.id)
        next true if %i[WATERGUN].include?(move.id)
        next true if %i[BUBBLEBEAM].include?(move.id)
        next true if %i[BUBBLE].include?(move.id)
        next true if %i[WAVECRASH].include?(move.id)
      },
      [:power_multiplier, 1.2, _INTL("The damp sand strengthened the attack!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[MUDBOMB].include?(move.id)
        next true if %i[MUDSHOT].include?(move.id)
        next true if %i[MUDSLAP].include?(move.id)
      },
      [:final_damage_multiplier, 0.6, _INTL("The electricity was dispersed in the sand!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :ELECTRIC && target.affectedByTerrain?
      },
    }

    @effects[:target_expand] = proc { |user, move, preTargetData|
      next true if %i[SANDATTACK].include?(move.id)
    }

    @effects[:no_charging] = proc { |user, move|
      next true if %i[DIG].include?(move.id)
    }

    @effects[:binding_boost] = proc { |move|
      next true if %i[SANDTOMB].include?(move.id)
    }

    @effects[:heal_boost] = proc { |move|
      next true if %i[SHOREUP].include?(move.id)
    }

    @effects[:speed_modify] = proc { |move|
      next true if %i[SPLASH].include?(move.id)
    }

    @effects[:base_type_add] = proc { |move|
      next :GROUND if %i[MUDDYWATER].include?(move.id)
    }

  end
end