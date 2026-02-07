#===============================================================================
# Mission Hook - Track trainer battle wins via BattleCreationHelperMethods
#===============================================================================
module BattleCreationHelperMethods
  class << self
    alias zeta_researcher_set_outcome set_outcome
    def set_outcome(outcome, outcome_variable = 1, trainer_battle = false)
      zeta_researcher_set_outcome(outcome, outcome_variable, trainer_battle)
      pbTrackMission(:win_trainer, 1) if outcome == 1 && trainer_battle
    end
  end
end
