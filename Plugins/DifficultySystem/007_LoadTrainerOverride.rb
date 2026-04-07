#===============================================================================
# Difficulty System — Story Mode Trainer Redirect
#
# In Story Mode, pbLoadTrainer checks for a story variant of the requested
# trainer (version + 100). If one exists it is used; otherwise falls back
# to the Classic version transparently.
#
# Convention:
#   trainers.txt         → [TYPE, Name, version]       (Classic)
#   trainers_story.txt   → [TYPE, Name, version + 100] (Story variant)
#
# Only define story variants for fights that actually need tuning.
# Fillers with no story entry automatically use Classic data.
#===============================================================================
alias difficulty_load_trainer_original pbLoadTrainer

def pbLoadTrainer(tr_type, tr_name, tr_version = 0)
  if pbStoryMode?
    story_data = GameData::Trainer.try_get(tr_type, tr_name, tr_version + 100)
    return story_data.to_trainer if story_data
  end
  difficulty_load_trainer_original(tr_type, tr_name, tr_version)
end
