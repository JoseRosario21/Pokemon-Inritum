#===============================================================================
# Achievements - Debug helpers
#
# The first check on a save that predates this plugin marks everything already
# earned as "known" without announcing it, so an existing save is not buried
# under twenty pop-ups on load. That is deliberate -- but it also means an
# achievement you had already earned will never announce, which looks exactly
# like the notification being broken.
#
# These make the difference visible.
#===============================================================================
def pbResetAchievementNotifications
  return if !$PokemonGlobal
  $PokemonGlobal.achievements_notified = {}
  $PokemonGlobal.achievements_initialised = false
  return true
end

# Re-announces everything currently earned, one toast at a time.
def pbReplayAchievementNotifications
  return if !$PokemonGlobal
  pbResetAchievementNotifications
  # Mark as initialised WITHOUT recording levels, so the next check sees every
  # earned tier as new and announces it.
  $PokemonGlobal.achievements_initialised = true
  Achievements.check_all
end

MenuHandlers.add(:debug_menu, :achievements_replay, {
  "name"        => _INTL("Replay achievement pop-ups"),
  "parent"      => :field_menu,
  "description" => _INTL("Re-announce every achievement already earned. Useful for checking the pop-up works."),
  "effect"      => proc {
    pbReplayAchievementNotifications
    pbMessage(_INTL("Queued pop-ups for every earned tier. Close the menu to watch them."))
    next false
  }
})

MenuHandlers.add(:debug_menu, :achievements_reset, {
  "name"        => _INTL("Reset achievement record"),
  "parent"      => :field_menu,
  "description" => _INTL("Forget which achievements have been announced. They will be silently re-absorbed on the next check."),
  "effect"      => proc {
    pbResetAchievementNotifications
    pbMessage(_INTL("Achievement notification record cleared."))
    next false
  }
})
