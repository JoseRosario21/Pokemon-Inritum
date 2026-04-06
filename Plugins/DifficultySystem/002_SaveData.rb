#===============================================================================
# Difficulty System — Save Data
#===============================================================================
class DifficultyData
  attr_reader :mode   # :classic or :story

  def initialize
    @mode = :classic
  end

  def mode=(val)
    @mode = val if [:classic, :story].include?(val)
  end

  # Old saves that predate this plugin have no @mode — default to :classic.
  def ensure_migrated
    @mode ||= :classic
  end
end

#-------------------------------------------------------------------------------
# Extend PokemonGlobalMetadata to store difficulty data in the save file.
#-------------------------------------------------------------------------------
class PokemonGlobalMetadata
  def difficulty
    @difficulty ||= DifficultyData.new
    @difficulty.ensure_migrated
    @difficulty
  end
end

#-------------------------------------------------------------------------------
# Global helpers
#-------------------------------------------------------------------------------
def pbDifficulty
  $PokemonGlobal.difficulty
end

def pbStoryMode?
  pbDifficulty.mode == :story
end
