#===============================================================================
# Boss Dex - Menu entry
#
# Pokegear app, alongside Field Notes and Records. Buttons are text-only (see
# Plugins/PokegearTweaks), so "icon_name" is inert.
#
# Order 36 sits it next to Field Notes (35); 40/41 belong to Zeta_Researcher and
# 45 to Records.
#===============================================================================
MenuHandlers.add(:pokegear_menu, :bossdex, {
  "name"      => _INTL("Boss Dex"),
  "icon_name" => "bossdex",
  "order"     => 36,
  "condition" => proc { next BossDex::SHOW_APP_ALWAYS || BossDex.any_encountered? },
  "effect"    => proc { |_menu|
    pbPlayDecisionSE
    pbFadeOutIn { pbViewBossDex }
    next false
  }
})
