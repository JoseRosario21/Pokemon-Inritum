#===============================================================================
# Achievements and Records - Menu entry
#
# Lives on the Pokegear, matching how Rejuvenation presents its achievements
# screen. Buttons are text-only (see Plugins/PokegearTweaks), so "icon_name"
# below is inert -- kept only so an icon can be restored by reverting that
# plugin.
#
# Always available -- unlike Field Notes there is nothing to spoil, and the
# Records page is meaningful from the first save.
#===============================================================================
MenuHandlers.add(:pokegear_menu, :achievements, {
  "name"      => _INTL("Records"),
  "icon_name" => "achievements",
  # 40 and 41 are taken by Zeta_Researcher's Researcher/Missions entries.
  "order"     => 45,
  "effect"    => proc { |_menu|
    pbPlayDecisionSE
    pbFadeOutIn { pbViewAchievements }
    next false
  }
})
