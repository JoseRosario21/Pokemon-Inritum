#===============================================================================
# Difficulty System — New Game Mode Selection
#
# Call DifficultySystem.show_mode_select from a Script event in your intro
# map sequence, before the player name entry prompt.
#
# Example event script call:
#   DifficultySystem.show_mode_select
#===============================================================================
module DifficultySystem
  def self.show_mode_select
    loop do
      cmd = pbMessage(
        _INTL("Before your journey begins, choose a difficulty."),
        [
          _INTL("Classic"),
          _INTL("Story Mode"),
          _INTL("What's the difference?")
        ],
        0
      )
      case cmd
      when 0  # Classic
        pbDifficulty.mode = :classic
        $game_switches[97] = false
        pbMessage(_INTL("Classic Mode selected.\\nPrepare for a challenge!"))
        break
      when 1  # Story Mode — confirm before locking in
        if pbConfirmMessage(_INTL("Story Mode cannot be changed back to Classic Mode. Are you sure?"))
          pbDifficulty.mode = :story
          $game_switches[97] = true
          pbMessage(_INTL("Story Mode selected.\\nSit back and enjoy the adventure!"))
          break
        end
      when 2  # Info
        pbMessage(
          _INTL("Classic: The intended experience. Trainers battle with sharp" \
                " strategies and well-trained Pokémon that grow stronger as" \
                " your journey progresses.\\1")
        )
        pbMessage(
          _INTL("Story: A more relaxed adventure. Trainers use simpler strategies" \
                " and their Pokémon are easier to handle, so you can focus on" \
                " enjoying the story.\\1")
        )
      else  # B button — default to Classic
        pbDifficulty.mode = :classic
        $game_switches[97] = false
        break
      end
    end
  end
end
