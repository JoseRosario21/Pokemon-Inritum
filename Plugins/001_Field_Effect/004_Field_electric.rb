class Battle::Field_electric < Battle::Field
  def initialize(battle, duration = Battle::Field::DEFAULT_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Electric
    @name                = _INTL("Electric Field")
    @duration            = duration
    @fieldback           = "Electric"
    @nature_power_change = :THUNDERBOLT
    @secret_power_effect = 1 # applyNumb
    @field_announcement  = [_INTL("The field is hyper-charged!"),
                            _INTL("An electric current is running across the field!"),
                            _INTL("The electric current disappeared from the field!")]

    @multipliers = {
      [:power_multiplier, 1.3] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if type == :ELECTRIC && user.affectedByTerrain?
      },
    }

    @effects[:status_immunity] = proc { |battler, newStatus, yawn, user, showMessages, selfInflicted, move, ignoreStatus|
      if (newStatus == :SLEEP || yawn) && battler.affectedByTerrain?
        @battle.pbDisplay(_INTL("{1} can't sleep on the electrified field!", battler.pbThis)) if showMessages
        next true
      end
    }

  end
end