#===============================================================================
# Text Log - Settings
#
# A rolling backlog of everything the game has said, reviewable at any time.
# Story-heavy games lose players to a mistimed button press; this is the fix.
#
# Reached from the pause menu, and from the map with the key below.
#===============================================================================
module TextLog
  # How many entries to keep. Each is a short string, so this is cheap; the cost
  # is that it all sits in the save file.
  LIMIT = 200

  # Map shortcut. JUMPDOWN is "Y" under the game's mkxp bindingNames and is
  # unbound on the map, which is also the key Rejuvenation uses for this.
  # Set ENABLE_MAP_KEY to false to rely on the pause menu alone.
  ENABLE_MAP_KEY = true
  MAP_KEY        = Input::JUMPDOWN

  # Log the player's dialogue choices too, so a log entry shows what was picked.
  LOG_CHOICES = true

  # Log battle messages. Off by default: a single battle produces dozens of
  # lines and would push the story out of a 200-entry log within one fight.
  LOG_BATTLE = false

  COLOR_CHOICE = ["E8C038", "886018"]
  COLOR_SYSTEM = ["8890A0", "444850"]

  def self.color_tag(pair)
    return sprintf("<c3=%s,%s>", pair[0], pair[1])
  end
end
