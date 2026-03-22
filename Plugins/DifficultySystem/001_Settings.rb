#===============================================================================
# Difficulty System — Settings
#===============================================================================
module DifficultySystem
  #-----------------------------------------------------------------------------
  # Trainer tier classification
  # Add trainer type symbols to the appropriate list as new types are created.
  #-----------------------------------------------------------------------------
  GYM_LEADER_TYPES = [
    :GYM_LEADER, :ELITE_FOUR, :CHAMPION,
    :ADMIN, :BOSS, :GIOVANNI
  ].freeze

  ACE_TRAINER_TYPES = [
    :ACE_TRAINER, :VETERAN, :EXPERT,
    :BLACK_BELT, :BATTLE_GIRL
  ].freeze

  def self.trainer_tier(trainer_type)
    return :boss    if GYM_LEADER_TYPES.include?(trainer_type)
    return :ace     if ACE_TRAINER_TYPES.include?(trainer_type)
    return :regular
  end

  #-----------------------------------------------------------------------------
  # Badge brackets (18 gyms total)
  #   Tier 0 → badges 0–3   (early game)
  #   Tier 1 → badges 4–8   (mid game)
  #   Tier 2 → badges 9–12  (late game)
  #   Tier 3 → badges 13+   (endgame / E4 / Champion)
  #-----------------------------------------------------------------------------
  BADGE_BRACKET_THRESHOLDS = [4, 9, 13].freeze

  def self.badge_bracket
    b = $player.badge_count
    return 3 if b >= BADGE_BRACKET_THRESHOLDS[2]
    return 2 if b >= BADGE_BRACKET_THRESHOLDS[1]
    return 1 if b >= BADGE_BRACKET_THRESHOLDS[0]
    return 0
  end

  #-----------------------------------------------------------------------------
  # IV / EV defaults per mode, tier, and badge bracket
  #
  # Format: [iv_value, ev_value]
  #   iv_value  — integer applied to all 6 stats
  #   ev_value  — integer applied flat to all 6 stats, OR:
  #               :boss_spread → 252 in best offensive stat, 252 Speed, 4 HP
  #
  # Only applied when a Pokémon has no explicitly set IVs/EVs in PBS.
  #-----------------------------------------------------------------------------
  IV_EV_TABLE = {
    classic: {
      boss: [
        [10, 0],          # tier 0: badges 0–3
        [18, 0],          # tier 1: badges 4–8
        [25, 42],         # tier 2: badges 9–12
        [31, :boss_spread] # tier 3: badges 13+
      ],
      ace: [
        [8,  0],
        [15, 0],
        [20, 28],
        [25, 57]
      ],
      regular: [
        [3,  0],
        [8,  0],
        [12, 0],
        [15, 0]
      ]
    },
    story: {
      boss: [
        [3,  0],
        [8,  0],
        [12, 0],
        [15, 0]
      ],
      ace: [
        [2,  0],
        [5,  0],
        [8,  0],
        [12, 0]
      ],
      regular: [
        [0,  0],
        [3,  0],
        [5,  0],
        [8,  0]
      ]
    }
  }.freeze

  def self.iv_ev_for(tier)
    mode    = pbStoryMode? ? :story : :classic
    bracket = badge_bracket
    IV_EV_TABLE[mode][tier][bracket]
  end

  #-----------------------------------------------------------------------------
  # AI skill levels per mode, tier, and badge count
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
