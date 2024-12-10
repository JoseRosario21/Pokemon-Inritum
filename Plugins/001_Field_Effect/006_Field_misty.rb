class Battle::Field_misty < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Misty
    @name                = _INTL("Misty Field")
    @duration            = duration
    @fieldback           = "Misty"
    @nature_power_change = :MOONBLAST
    @secret_power_effect = 3 # tryLowerStat SPECIAL_ATTACK
    @field_announcement  = [_INTL("Mist settles on the field!"),
                            _INTL("Mist is swirling about the field!"),
                            _INTL("The mist disappeared from the field!")]

    @multipliers = {
      [:final_damage_multiplier, 0.5] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :DRAGON && target.affectedByTerrain?
      },
    }

    @effects[:status_immunity] = proc { |battler, newStatus, yawn, user, showMessages, selfInflicted, move, ignoreStatus|
      if battler.affectedByTerrain?
        @battle.pbDisplay(_INTL("{1} is protected by the misty field!", battler.pbThis)) if showMessages
        next true
      end
    }

  end
end