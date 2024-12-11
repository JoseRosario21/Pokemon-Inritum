class Battle::Field_cave < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION, *args)
    super(battle)
    @id                  = :Cave
    @name                = _INTL("Cave Field")
    @duration            = duration
    @fieldback           = "Cave"
    @nature_power_change = :ROCKSLIDE
    @secret_power_effect = 4 # tryLowerStat SPEED
    @field_announcement  = [_INTL("The echoes of the cave surround you."),
                            _INTL(""),
                            _INTL("")]

    @multipliers = {
      [:power_multiplier, 1.1, _INTL("The ground trembles violently!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[BULLDOZE DRILLRUN EARTHQUAKE EARTHPOWER PRECIPLEBLADES].include?(move.id)
      },
      [:power_multiplier, 1.2, _INTL("The cave strengthens the attack!")] => proc { |user, target, numTargets, move, type, power, mults, aiCheck|
        next true if %i[ROCKBLAST ROCKSLIDE ROCKTHROW ROCKTOMB STONEEDGE SMACKDOWN].include?(move.id)
      }
    }

  end
end