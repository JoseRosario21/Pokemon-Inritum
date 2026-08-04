#===============================================================================
# Field Notes - Menu entry
#
# Lives on the Pokegear, matching how Rejuvenation presents its field catalogue
# as one of the player's apps. Pokegear buttons are text-only (see
# Plugins/PokegearTweaks), so "icon_name" below is inert -- kept only so an icon
# can be restored by reverting that plugin.
#
# Hidden until the player has actually battled on a field, so it doesn't clutter
# the app list during the opening hours of the game.
#===============================================================================
MenuHandlers.add(:pokegear_menu, :fieldnotes, {
  "name"      => _INTL("Field Notes"),
  "icon_name" => "fieldnotes",
  "order"     => 35,
  # Always listed by default -- see SHOW_APP_ALWAYS in 000_Settings.rb for why.
  "condition" => proc { next FieldNotes::SHOW_APP_ALWAYS || FieldNotes.any_seen? },
  "effect"    => proc { |_menu|
    pbPlayDecisionSE
    pbFadeOutIn { pbViewFieldNotes }
    next false
  }
})
