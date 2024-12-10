class Battle::Field_grassy < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Grassy
    @name                = _INTL("Grassy Field")
    @duration            = duration
    @fieldback           = "Grassy"
    @nature_power_change = :ENERGYBALL
    @secret_power_effect = 2 # applySleep
    @field_announcement  = [_INTL("The field is in full bloom!"),
                            _INTL("Grass is covering the field!"),
                            _INTL("The grass disappeared from the field!")]

    @multipliers = {
      [:power_multiplier, 1.3] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :GRASS && user.affectedByTerrain?
      },
      [:final_damage_multiplier, 0.5, _INTL("The grass softened the attack!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[EARTHQUAKE BULLDOZE].include?(move.id) && target.affectedByTerrain?
      },
    }

    @effects[:EOR_field_battler] = proc { |battler|
      battler.pbRecoverHP(battler.totalhp / 16) if battler.affectedByTerrain?
    }

  end
end