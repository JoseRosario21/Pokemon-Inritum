#===============================================================================
# Achievements and Records - Settings
#
# Design note, because it differs from how most Essentials achievement scripts
# work and from Rejuvenation's version:
#
# Achievements here are DERIVED, not tracked. v21.1 already counts 49 things in
# $stats (GameStats, Data/Scripts/004_Game classes/012_Game_Stats.rb) and never
# shows any of them to the player. Rather than adding a parallel set of counters
# that can drift out of sync, every achievement is a small proc reading $stats.
#
# The only thing actually stored in the save is which tier the player has
# already been *told* about, so the unlock message fires once. Progress itself
# is recomputed on demand and therefore can never desync, can never be lost by a
# missed hook, and retroactively credits players on existing saves.
#===============================================================================
module Achievements
  # Show a message when an achievement reaches a new tier.
  ANNOUNCE_UNLOCKS = true

  # Sound effect played on unlock. Set to nil for silence.
  UNLOCK_SE = "Pkmn move learnt"

  # How many steps between checks while walking. Battle-end and map-entry checks
  # cover everything else, but the movement achievements are earned by walking
  # and would otherwise not surface until the player left the map.
  STEPS_PER_CHECK = 20

  # Tier names, lowest to highest. The number of tiers an achievement has is
  # decided by how many thresholds it defines, so an achievement with three
  # thresholds uses the first three names here.
  TIER_NAMES = [
    _INTL("Bronze"),
    _INTL("Silver"),
    _INTL("Gold"),
    _INTL("Platinum")
  ]

  TIER_COLORS = [
    ["B87333", "5C3919"],   # bronze
    ["A8B0B8", "54585C"],   # silver
    ["E8C038", "886018"],   # gold
    ["7FE8E8", "3F7474"]    # platinum
  ]

  COLOR_LOCKED   = ["808890", "404448"]
  COLOR_COMPLETE = ["38C838", "186818"]
  COLOR_HEADER   = ["404850", "A0A8B0"]

  def self.tier_tag(level)
    pair = TIER_COLORS[[level - 1, 0].max] || TIER_COLORS[0]
    return sprintf("<c3=%s,%s>", pair[0], pair[1])
  end

  def self.color_tag(pair)
    return sprintf("<c3=%s,%s>", pair[0], pair[1])
  end
end
