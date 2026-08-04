#===============================================================================
# Boss Dex - Settings
#
# A codex of the bosses the player has faced, in the spirit of Rejuvenation's
# Rift Dex. Like Field Notes, every entry is generated from the registry -- here
# BossBattle::BOSS_DATA -- so adding a boss adds its dex entry automatically and
# a stat tweak can never leave the codex lying.
#
# Progression is two-stage rather than Rejuvenation's single unlock switch:
#
#   unseen      not listed by name at all
#   encountered you fought it; name, species and flavour text
#   defeated    you won; full readout of shields, phases and charge attack
#
# That way the dex is a reward for winning rather than a strategy guide handed
# out before the fight.
#===============================================================================
module BossDex
  # Whether the Pokegear app is listed before any boss has been met. Kept true
  # for the same reason as Field Notes: an app that silently does not exist yet
  # reads as a bug, not as progression.
  SHOW_APP_ALWAYS = true

  # Show undefeated bosses' full details anyway (useful while testing).
  REVEAL_EVERYTHING = false

  # Colours, as ["base", "shadow"] hex pairs.
  COLOR_DEFEATED    = ["E8C038", "886018"]   # gold
  COLOR_ENCOUNTERED = ["A8B0B8", "54585C"]   # silver
  COLOR_LOCKED      = ["707880", "383C40"]
  COLOR_HEADER      = ["404850", "A0A8B0"]

  def self.color_tag(pair)
    return sprintf("<c3=%s,%s>", pair[0], pair[1])
  end
end
