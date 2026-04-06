#===============================================================================
# Daily Rifts - Save Data
# Stores per-rift state inside PokemonGlobalMetadata.
#
# Each rift entry is a Hash:
#   species:          Symbol   - species being battled this cycle
#   tier:             Integer  - 1–5, computed at generation time
#   level:            Integer  - battle level for this cycle
#   generated_at:     Integer  - Unix timestamp when this cycle started
#   state:            Symbol   - :available | :complete
#   silhouette_shown: Boolean  - whether the scene has been shown this cycle
#===============================================================================
class DailyRiftsSaveData
  def initialize
    @rifts = {}
  end

  def ensure_migrated
    @rifts ||= {}
  end

  # Returns the entry Hash for a given rift ID, or nil.
  def get(rift_id)
    ensure_migrated
    @rifts[rift_id.to_s]
  end

  # Saves or replaces the entry for a given rift ID.
  def set(rift_id, entry)
    ensure_migrated
    @rifts[rift_id.to_s] = entry
  end

  # Removes the entry entirely (e.g. after expiry).
  def delete(rift_id)
    ensure_migrated
    @rifts.delete(rift_id.to_s)
  end
end

#===============================================================================
# PokemonGlobalMetadata extension (lazy accessor for save compatibility)
#===============================================================================
class PokemonGlobalMetadata
  def daily_rifts
    @daily_rifts = DailyRiftsSaveData.new if !@daily_rifts
    @daily_rifts.ensure_migrated
    return @daily_rifts
  end

  alias daily_rifts_init initialize
  def initialize
    daily_rifts_init
    @daily_rifts = DailyRiftsSaveData.new
  end
end

# Shorthand accessor.
def pbDailyRifts
  return $PokemonGlobal.daily_rifts
end
