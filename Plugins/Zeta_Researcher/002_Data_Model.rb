#===============================================================================
# Zeta Researcher Data Model
#===============================================================================
class ZetaResearcherData
  attr_reader :xp, :total_xp, :tokens, :donated_species
  attr_accessor :zeta_caught_count, :zeta_donated_count
  attr_accessor :last_notified_rank
  attr_reader :mission_progress, :completed_missions, :daily_reset_day

  def initialize
    @xp                  = 0
    @total_xp            = 0
    @tokens              = 0
    @donated_species     = []
    @zeta_caught_count   = 0
    @zeta_donated_count  = 0
    @last_notified_rank  = 0
    @mission_progress    = {}
    @completed_missions  = []
    @daily_reset_day     = nil
  end

  #---------------------------------------------------------------------------
  # Save migration: old saves had @rp/@total_rp, new saves use @xp/@total_xp/@tokens.
  # When loaded from an old save, @xp/@total_xp will be nil; migrate from @rp/@total_rp.
  #---------------------------------------------------------------------------
  def ensure_migrated
    if @xp.nil?
      @xp       = @rp || 0
      @total_xp = @total_rp || 0
      @tokens   = 0
      @rp       = nil
      @total_rp = nil
    end
    @tokens             ||= 0
    @mission_progress   ||= {}
    @completed_missions ||= []
    @daily_reset_day    ||= nil
  end

  #---------------------------------------------------------------------------
  # Research XP (rank progression only)
  #---------------------------------------------------------------------------
  def add_xp(amount)
    ensure_migrated
    @xp       = [@xp + amount, Settings::MAX_RESEARCHER_XP].min
    @total_xp = [@total_xp + amount, Settings::MAX_RESEARCHER_XP].min
  end

  #---------------------------------------------------------------------------
  # Research Tokens (spendable currency)
  #---------------------------------------------------------------------------
  def add_tokens(amount)
    ensure_migrated
    @tokens = [@tokens + amount, Settings::MAX_RESEARCHER_TOKENS].min
  end

  def spend_tokens(amount)
    ensure_migrated
    return false if amount > @tokens
    @tokens -= amount
    return true
  end

  #---------------------------------------------------------------------------
  # Ranks (based on lifetime XP)
  #---------------------------------------------------------------------------
  def rank_index
    ensure_migrated
    ranks = ZetaResearcher::RESEARCHER_RANKS
    idx = 0
    ranks.each_with_index do |rank, i|
      idx = i if @total_xp >= rank[1]
    end
    return idx
  end

  def rank_name
    return ZetaResearcher::RESEARCHER_RANKS[rank_index][0]
  end

  def xp_to_next_rank
    ensure_migrated
    ranks = ZetaResearcher::RESEARCHER_RANKS
    next_idx = rank_index + 1
    return 0 if next_idx >= ranks.length
    return ranks[next_idx][1] - @total_xp
  end

  def next_rank_name
    ranks = ZetaResearcher::RESEARCHER_RANKS
    next_idx = rank_index + 1
    return nil if next_idx >= ranks.length
    return ranks[next_idx][0]
  end

  def has_unlock?(key)
    ranks = ZetaResearcher::RESEARCHER_RANKS
    (0..rank_index).each do |i|
      return true if ranks[i][2] == key
    end
    return false
  end

  #---------------------------------------------------------------------------
  # Donations
  #---------------------------------------------------------------------------
  def donated?(species)
    return @donated_species.include?(species)
  end

  def register_donation(species)
    @donated_species.push(species) if !@donated_species.include?(species)
    @zeta_donated_count += 1
  end

  def unique_donated_count
    return @donated_species.length
  end

  #---------------------------------------------------------------------------
  # Mission progress helpers
  #---------------------------------------------------------------------------
  def mission_progress_for(mission_id)
    ensure_migrated
    return @mission_progress[mission_id] || 0
  end

  def add_mission_progress(mission_id, amount = 1)
    ensure_migrated
    @mission_progress[mission_id] = mission_progress_for(mission_id) + amount
  end

  def mission_completed?(mission_id)
    ensure_migrated
    return @completed_missions.include?(mission_id)
  end

  def complete_mission(mission_id)
    ensure_migrated
    @completed_missions.push(mission_id) if !@completed_missions.include?(mission_id)
  end

  def reset_daily_missions
    ensure_migrated
    ZetaResearcher::RESEARCHER_MISSIONS.each do |id, defn|
      next if defn[:type] != :daily
      @mission_progress.delete(id)
      @completed_missions.delete(id)
    end
  end

  def daily_reset_day=(value)
    @daily_reset_day = value
  end
end

#===============================================================================
# PokemonGlobalMetadata extension (lazy accessor for save compatibility)
#===============================================================================
class PokemonGlobalMetadata
  def zeta_researcher
    @zeta_researcher = ZetaResearcherData.new if !@zeta_researcher
    @zeta_researcher.ensure_migrated
    return @zeta_researcher
  end

  alias zeta_researcher_init initialize
  def initialize
    zeta_researcher_init
    @zeta_researcher = ZetaResearcherData.new
  end
end

#===============================================================================
# Helper functions
#===============================================================================
# Returns the tier data hash for a given Pokemon based on its species BST.
def pbGetZetaTier(pkmn)
  bst = pkmn.species_data.base_stat_total
  ZetaResearcher::ZETA_TIERS.each do |_name, data|
    return data if bst >= data[:min_bst]
  end
  return ZetaResearcher::ZETA_TIERS[:Common]
end

# Returns the tier name (symbol) for a given Pokemon.
def pbGetZetaTierName(pkmn)
  bst = pkmn.species_data.base_stat_total
  ZetaResearcher::ZETA_TIERS.each do |name, data|
    return name if bst >= data[:min_bst]
  end
  return :Common
end

# Shorthand accessor for the researcher data.
def pbZetaResearcher
  return $PokemonGlobal.zeta_researcher
end
