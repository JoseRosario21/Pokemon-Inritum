#===============================================================================
# Difficulty System — AI Skill Override
#
# Aliases Battle::AI::AITrainer#set_up_skill so that @skill reflects the
# current difficulty mode and badge count.
#
# Called first in initialize, before set_up_skill_flags — so flags like
# ConsiderSwitching and ReserveLastPokemon are derived from the adjusted skill.
#===============================================================================
class Battle::AI::AITrainer
  alias difficulty_set_up_skill_original set_up_skill unless method_defined?(:difficulty_set_up_skill_original)

  def set_up_skill
    difficulty_set_up_skill_original
    return unless @trainer  # wild battles — leave untouched
    tier   = DifficultySystem.trainer_tier(@trainer.trainer_type)
    @skill = DifficultySystem.ai_skill_for(tier)
  end
end
