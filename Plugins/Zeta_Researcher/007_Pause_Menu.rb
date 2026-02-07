#===============================================================================
# Add "Researcher" to the Pokégear
# Requires icon at Graphics/UI/Pokegear/icon_researcher.png
#===============================================================================
MenuHandlers.add(:pokegear_menu, :researcher, {
  "name"      => _INTL("Researcher"),
  "icon_name" => "researcher",
  "order"     => 40,
  "condition" => proc { next $game_switches[Settings::RESEARCHER_UNLOCKED_SWITCH] },
  "effect"    => proc { |menu|
    pbFadeOutIn {
      scene = ZetaResearcherScene.new
      screen = ZetaResearcherScreen.new(scene)
      screen.pbStartScreen
    }
    next false
  }
})

#===============================================================================
# Add "Missions" to the Pokégear
# Requires icon at Graphics/UI/Pokegear/icon_missions.png
#===============================================================================
MenuHandlers.add(:pokegear_menu, :missions, {
  "name"      => _INTL("Missions"),
  "icon_name" => "missions",
  "order"     => 41,
  "condition" => proc { next $game_switches[Settings::RESEARCHER_UNLOCKED_SWITCH] },
  "effect"    => proc { |menu|
    pbFadeOutIn {
      scene = MissionBoardScene.new
      screen = MissionBoardScreen.new(scene)
      screen.pbStartScreen
    }
    next false
  }
})
