#===============================================================================
# Difficulty System — Settings
#===============================================================================
module DifficultySystem
  #-----------------------------------------------------------------------------
  # Trainer tier classification
  # Add trainer type symbols to the appropriate list as new types are created.
  #-----------------------------------------------------------------------------
  BOSS_TRAINER_TYPES = [
    :GYM_LEADER_LYRA, :GYM_LEADER_HOWARD,
    :RIVAL1, :RIVAL2,
    :TEAM_REBIRTH_LEADER, :TEAM_REBIRTH_ELITE_GRUNT_M, :TEAM_REBIRTH_ELITE_GRUNT2_M,
  ].freeze

  ACE_TRAINER_TYPES = [
    :COOLTRAINER_M, :COOLTRAINER_F,
    :MERCENARY, :INQUISITOR, :TEAM_REBIRTH_GRUNT_M,
    :POKEGANG, :XP18Simulation
  ].freeze

  def self.trainer_tier(trainer_type)
    return :boss    if BOSS_TRAINER_TYPES.include?(trainer_type)
    return :ace     if ACE_TRAINER_TYPES.include?(trainer_type)
    return :regular
  end

  #-----------------------------------------------------------------------------
  # AI skill levels per mode and tier.
  #
  # Classic: boss is always 100; ace and regular scale linearly to 100 by badge 13.
  # Story:   fixed lower values, no scaling.
  #-----------------------------------------------------------------------------
  AI_TABLE = {
    classic: {
      boss:    ->(_b) { 100 },
      ace:     ->(b)  { (80 + (b * 20.0 / 13)).round.clamp(80, 100) },
      regular: ->(b)  { (60 + (b * 40.0 / 13)).round.clamp(60, 100) }
    },
    story: {
      boss:    ->(_b) { 60 },
      ace:     ->(_b) { 40 },
      regular: ->(_b) { 30 }
    }
  }.freeze

  def self.ai_skill_for(tier)
    mode = pbStoryMode? ? :story : :classic
    AI_TABLE[mode][tier].call($player.badge_count)
  end
end
