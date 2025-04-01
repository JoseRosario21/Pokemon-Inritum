class Battle::Field_normalized < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Normalized
    @name                = _INTL("Normalized Field")
    @duration            = duration
    @fieldback           = "Normalized"
    @nature_power_change = :TRIATTACK
    @secret_power_effect = 4 # tryLowerStat SPEED
    @field_announcement  = [_INTL("The battlefield embraces balance!"),
                            _INTL(""),
                            _INTL("")]

    @multipliers = {
      [:power_multiplier, 1.2, _INTL("The attack resonates with the field's balance!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :NORMAL && user.affectedByTerrain?
      }
    }

    @effects[:begin_battle] = proc { |user|
      next true
    }

  end
end