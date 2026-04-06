#===============================================================================
# Difficulty System — In-Game Mode Switch NPC
#
# Place an NPC in any map (Pokémon Centers recommended) and call this from
# their Script event page:
#
#   DifficultySystem.offer_story_mode_switch
#
# The NPC's second event page should use the condition:
#   Script: pbStoryMode?
# so their dialogue changes after the switch has been made.
#===============================================================================
module DifficultySystem
  # Offers a one-way switch from Classic → Story Mode.
  # Returns true if the switch was made, false otherwise.
  def self.offer_story_mode_switch
    if pbStoryMode?
      pbMessage(_INTL("You are already playing in Story Mode."))
      return false
    end

    pbMessage(
      _INTL("Story Mode makes battles easier: trainers use weaker strategies," \
            " their Pokémon have lower stats, and Gym Leaders bring one fewer Pokémon.\\1")
    )
    pbMessage(_INTL("\\1Warning: this cannot be undone. You cannot switch back to Classic Mode.\\1"))

    unless pbConfirmMessage(_INTL("Switch to Story Mode?"))
      pbMessage(_INTL("Understood. Good luck on your journey!"))
      return false
    end

    pbDifficulty.mode = :story
    pbMessage(_INTL("Difficulty switched to Story Mode.\\nEnjoy the adventure!"))
    return true
  end
end
