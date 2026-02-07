#===============================================================================
# Zeta Researcher Mission - wrapper class for mission definitions
#===============================================================================
class ZetaResearcherMission
  attr_reader :id

  def initialize(id)
    @id = id
    @data = ZetaResearcher::RESEARCHER_MISSIONS[id]
  end

  def name
    return @data[:name]
  end

  def description
    return @data[:desc]
  end

  def daily?
    return @data[:type] == :daily
  end

  def one_time?
    return @data[:type] == :one_time
  end

  def goal
    return @data[:goal]
  end

  def rewards
    return @data[:rewards]
  end

  def tier_required
    return @data[:tier]
  end

  def auto_track
    return @data[:auto_track]
  end

  def type_param
    return @data[:type_param]
  end

  def token_reward
    return (@data[:rewards] && @data[:rewards][:tokens]) || 0
  end

  def item_rewards
    return (@data[:rewards] && @data[:rewards][:items]) || []
  end

  def progress
    return pbZetaResearcher.mission_progress_for(@id)
  end

  def completed?
    return pbZetaResearcher.mission_completed?(@id)
  end

  def available?(rank_index = nil)
    rank_index = pbZetaResearcher.rank_index if rank_index.nil?
    return rank_index >= tier_required
  end

  def locked?(rank_index = nil)
    return !available?(rank_index)
  end
end

#===============================================================================
# Helper functions to query missions
#===============================================================================
def pbGetAllMissions
  return ZetaResearcher::RESEARCHER_MISSIONS.keys.map { |id| ZetaResearcherMission.new(id) }
end

def pbGetAvailableMissions
  rank = pbZetaResearcher.rank_index
  return pbGetAllMissions.select { |m| m.available?(rank) }
end

def pbGetDailyMissions
  return pbGetAvailableMissions.select { |m| m.daily? }
end

def pbGetOneTimeMissions
  return pbGetAvailableMissions.select { |m| m.one_time? }
end

def pbGetLockedMissions
  rank = pbZetaResearcher.rank_index
  return pbGetAllMissions.select { |m| m.locked?(rank) }
end
