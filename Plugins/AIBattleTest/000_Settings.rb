#===============================================================================
# AI Battle Test - Settings
#
# A regression harness for the battle AI. It runs real battles with no graphics
# and no input, catching any exception the AI, a move effect, a field effect or
# an item handler throws, and writing them to a log with the RNG seed needed to
# reproduce them.
#
# This exists because the AI here is large, custom and under active edit
# (Plugins/AdvancedBattleAI is 16 files, plus DBK's item AI). A crash in an
# uncommon branch is otherwise only found by a player, mid-boss-fight.
#
# Debug menu -> "AI battle test". Nothing here runs during normal play.
#===============================================================================
module AIBattleTest
  # Where results are written, relative to the game folder.
  LOG_FILE = "ai_battle_test.txt"

  # Hard cap on rounds before a battle is declared stalled and abandoned. Two
  # defensive teams can otherwise loop until the heat death of the universe.
  MAX_TURNS = 100

  # Levels used for generated Pokemon.
  LEVEL = 50

  # Party size for random battles.
  PARTY_SIZE = 3

  # How often the harness yields to Graphics.update so the window stays
  # responsive. Lower is smoother, higher is faster.
  FRAMES_PER_YIELD = 250

  # Species pool for generated Pokemon. Empty means "everything with a valid
  # level-up moveset", which is the honest default -- restricting the pool hides
  # exactly the odd form/ability combinations most likely to crash.
  SPECIES_POOL = []

  # Moves never assigned to test Pokemon. These either need a partner, a held
  # item, or a specific battle type to make sense, and their failure branches
  # are not what this harness is for.
  EXCLUDED_MOVES = [:STRUGGLE, :SKETCH]

  # Battle types exercised by the "full sweep" run.
  SWEEP_SINGLES = true
  SWEEP_DOUBLES = true
end
