#===============================================================================
# Advanced Battle AI - Settings
# Configure which features are enabled and skill thresholds
#===============================================================================
module AdvancedBattleAI
  #-----------------------------------------------------------------------------
  # Feature Toggles - Set to false to disable specific features
  #-----------------------------------------------------------------------------

  # Track opponent's revealed moves, abilities, and items for smarter predictions
  ENABLE_MOVE_MEMORY = true

  # Consider partner abilities in doubles (Flash Fire, Volt Absorb, etc.)
  ENABLE_TEAM_SYNERGY = true

  # Smart hazard layering and removal decisions
  ENABLE_ADVANCED_HAZARDS = true

  # Calculate turns until OHKO to decide setup vs attack
  ENABLE_SETUP_WINDOWS = true

  # Role-based switching decisions (SWEEPER, WALL, CLERIC, etc.)
  # Now with safeguards: HP thresholds, stat boost preservation, better reserve checks
  ENABLE_ROLE_SWITCHING = false

  # Advanced double battle tactics (focus fire, partner protection)
  ENABLE_DOUBLES_COORDINATION = true

  # Perish Song awareness, sacrifice plays, knowing when to let Pokemon faint
  ENABLE_SACRIFICE_AWARENESS = true

  # Adjust scoring for Field Effect plugin terrain/fields (requires Field Effect plugin)
  ENABLE_FIELD_INTEGRATION = true

  # Win condition identification - AI identifies how to win and plays toward it
  ENABLE_WIN_CONDITION = true

  # Move prediction - AI predicts what opponent will do and plays around it
  ENABLE_MOVE_PREDICTION = true

  #-----------------------------------------------------------------------------
  # Skill Thresholds - Minimum skill level for features to activate
  # Default Essentials skill ranges: 0=Wild, 1-31=Basic, 32-47=Medium, 48-99=High, 100+=Best
  #-----------------------------------------------------------------------------

  # Minimum skill to enable any advanced features (below this = default AI)
  SKILL_THRESHOLD_BASIC = 48

  # Skill level for move memory and basic prediction
  SKILL_THRESHOLD_MEMORY = 48

  # Skill level for role-based decisions
  SKILL_THRESHOLD_ROLES = 60

  # Skill level for setup window calculations
  SKILL_THRESHOLD_SETUP = 60

  # Skill level for double battle coordination
  SKILL_THRESHOLD_DOUBLES = 80

  # Skill level for all features (sacrifice plays, full prediction)
  SKILL_THRESHOLD_FULL = 100

  #-----------------------------------------------------------------------------
  # Score Modifiers - Adjust how much each feature affects move scoring
  #-----------------------------------------------------------------------------

  # Multiplier for moves that benefit from known opponent weaknesses
  MEMORY_PREDICTION_BONUS = 1.2

  # Score bonus for setup moves when setup window exists
  SETUP_WINDOW_BONUS = 20

  # Score penalty for setup moves when no safe window
  SETUP_RISKY_PENALTY = -15

  # Score bonus for focusing down a single target in doubles
  DOUBLES_FOCUS_FIRE_BONUS = 15

  # Score bonus for moves that activate partner's beneficial ability
  PARTNER_SYNERGY_BONUS = 25

  # Score bonus for pivot moves when switching is beneficial
  PIVOT_MOVE_BONUS = 20

  # Score threshold for hazard moves (only use if above this)
  HAZARD_SCORE_THRESHOLD = 80

  #-----------------------------------------------------------------------------
  # Role Detection Settings
  #-----------------------------------------------------------------------------

  # Stat ratio threshold for classifying as SWEEPER (Attack+SpAtk vs Defense+SpDef)
  SWEEPER_OFFENSIVE_RATIO = 1.3

  # Stat ratio threshold for classifying as WALL
  WALL_DEFENSIVE_RATIO = 1.3

  # Speed threshold percentile for SWEEPER classification (0.0-1.0)
  SWEEPER_SPEED_PERCENTILE = 0.6

  #-----------------------------------------------------------------------------
  # Debug Settings
  #-----------------------------------------------------------------------------

  # Log AI decisions to console (for debugging)
  DEBUG_LOG_DECISIONS = false

  # Log memory updates to console
  DEBUG_LOG_MEMORY = false

  # Log scoring breakdowns to console
  DEBUG_LOG_SCORING = false
end

#===============================================================================
# New AI Skill Flags
# These can be added to trainer types in PBS to enable specific features
#===============================================================================
# AdvancedAI       - Enables all advanced AI features regardless of skill level
# MemorizeMoves    - Enables move memory system
# CoordinateDoubles - Enables double battle coordination
# SetupSmart       - Enables setup window calculations
# RoleAware        - Enables role-based switching
# SacrificeAware   - Enables sacrifice play awareness
# HazardSmart      - Enables advanced hazard management
# FieldAware       - Enables field effect integration
# WinConditionAware - Enables win condition identification and strategy
# PredictMoves     - Enables move prediction system

#===============================================================================
# Utility methods for checking if features are enabled
#===============================================================================
module AdvancedBattleAI
  module_function

  # Check if a feature is enabled for a given AI trainer
  def feature_enabled?(feature, ai_trainer)
    return false unless ai_trainer
    skill = ai_trainer.skill

    # Check for AdvancedAI flag which enables everything
    return true if ai_trainer.has_skill_flag?("AdvancedAI")

    case feature
    when :memory
      return false unless ENABLE_MOVE_MEMORY
      return true if ai_trainer.has_skill_flag?("MemorizeMoves")
      return skill >= SKILL_THRESHOLD_MEMORY

    when :team_synergy
      return false unless ENABLE_TEAM_SYNERGY
      return skill >= SKILL_THRESHOLD_DOUBLES

    when :hazards
      return false unless ENABLE_ADVANCED_HAZARDS
      return true if ai_trainer.has_skill_flag?("HazardSmart")
      return skill >= SKILL_THRESHOLD_BASIC

    when :setup_windows
      return false unless ENABLE_SETUP_WINDOWS
      return true if ai_trainer.has_skill_flag?("SetupSmart")
      return skill >= SKILL_THRESHOLD_SETUP

    when :roles
      return false unless ENABLE_ROLE_SWITCHING
      return true if ai_trainer.has_skill_flag?("RoleAware")
      return skill >= SKILL_THRESHOLD_ROLES

    when :doubles
      return false unless ENABLE_DOUBLES_COORDINATION
      return true if ai_trainer.has_skill_flag?("CoordinateDoubles")
      return skill >= SKILL_THRESHOLD_DOUBLES

    when :sacrifice
      return false unless ENABLE_SACRIFICE_AWARENESS
      return true if ai_trainer.has_skill_flag?("SacrificeAware")
      return skill >= SKILL_THRESHOLD_FULL

    when :field
      return false unless ENABLE_FIELD_INTEGRATION
      return true if ai_trainer.has_skill_flag?("FieldAware")
      return skill >= SKILL_THRESHOLD_BASIC

    when :win_condition
      return false unless ENABLE_WIN_CONDITION
      return true if ai_trainer.has_skill_flag?("WinConditionAware")
      return skill >= SKILL_THRESHOLD_SETUP

    when :move_prediction
      return false unless ENABLE_MOVE_PREDICTION
      return true if ai_trainer.has_skill_flag?("PredictMoves")
      return skill >= SKILL_THRESHOLD_FULL  # High skill requirement for prediction
    end

    return false
  end

  # Check if any advanced feature is enabled for this trainer
  def any_feature_enabled?(ai_trainer)
    return false unless ai_trainer
    return true if ai_trainer.has_skill_flag?("AdvancedAI")
    return ai_trainer.skill >= SKILL_THRESHOLD_BASIC
  end

  # Debug logging helper
  def log(message, category = :general)
    return unless $DEBUG
    case category
    when :decisions
      return unless DEBUG_LOG_DECISIONS
    when :memory
      return unless DEBUG_LOG_MEMORY
    when :scoring
      return unless DEBUG_LOG_SCORING
    end
    echoln "[AdvancedAI] #{message}"
  end
end
