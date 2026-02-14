#===============================================================================
# Advanced Battle AI - Plugin Compatibility
# Integration with Dynamax, Terastallization, and Field Effect plugins
#===============================================================================

#===============================================================================
# Dynamax Integration (Deluxe Battle Kit)
# Role-aware Dynamax decisions
#===============================================================================
if defined?(Settings::DYNAMAX_POKEMON)
  AdvancedBattleAI.log("Dynamax plugin detected, adding integration", :general)

  # Enhance Dynamax scoring with role awareness
  class Battle::AI::AIBattler
    alias advanced_ai_dynamax_get_total_dynamax_score get_total_dynamax_score if method_defined?(:get_total_dynamax_score)

    def get_total_dynamax_score
      score = 0
      score = advanced_ai_dynamax_get_total_dynamax_score if respond_to?(:advanced_ai_dynamax_get_total_dynamax_score)

      return score unless AdvancedBattleAI.feature_enabled?(:roles, @ai.trainer)

      # Role-based adjustments
      case @detected_role
      when Battle::AI::Roles::SWEEPER, Battle::AI::Roles::SETUP_SWEEPER
        # Sweepers benefit a lot from Dynamax (doubled HP, Max Moves)
        score += 20
        AdvancedBattleAI.log("Dynamax bonus for sweeper", :scoring)

      when Battle::AI::Roles::PHYSICAL_WALL, Battle::AI::Roles::SPECIAL_WALL, Battle::AI::Roles::MIXED_WALL
        # Walls also benefit from doubled HP
        score += 15

      when Battle::AI::Roles::HAZARD_SETTER
        # Less valuable - job should be done
        score -= 10

      when Battle::AI::Roles::PIVOT
        # Can't use pivot moves while Dynamaxed
        score -= 15
      end

      # Consider setup window
      window = @ai.calculate_full_setup_window(self, @ai.battle) rescue { safe: true }
      if window[:safe]
        score += 10
      else
        score -= 15  # Don't Dynamax if about to die
      end

      return score
    end
  end

  # Don't switch out while Dynamaxed
  Battle::AI::Handlers::ShouldNotSwitch.add(:advanced_dynamax_no_switch,
    proc { |battler, reserves, ai, battle|
      is_dynamaxed = (battler.dynamax? rescue false)
      next false unless is_dynamaxed
      AdvancedBattleAI.log("Not switching: Dynamaxed", :decisions)
      next true
    }
  )

  # Protect is extra valuable against Dynamax
  Battle::AI::Handlers::GeneralMoveScore.add(:advanced_vs_dynamax_protect,
    proc { |score, move, user, ai, battle|
      protect_functions = ["ProtectUser", "ProtectUserFromTargetingMovesSpikyShield"]
      next score unless protect_functions.include?(move.function_code)

      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        opp = battle.battlers[opp_idx]
        next unless opp && !opp.fainted?
        is_dynamaxed = (opp.dynamax? rescue false)
        if is_dynamaxed
          score += 25
          AdvancedBattleAI.log("Protect vs Dynamax", :scoring)
          break
        end
      end

      next score
    }
  )
end

#===============================================================================
# Terastallization Integration (Gen 9 Pack or DBK)
# Memory-aware Tera type selection
#===============================================================================
if defined?(Settings::TERASTALLIZE_POKEMON) || defined?(GameData::TeraType)
  AdvancedBattleAI.log("Terastallization detected, adding integration", :general)

  class Battle::AI
    alias advanced_ai_tera_pbEnemyShouldTerastallize? pbEnemyShouldTerastallize? if method_defined?(:pbEnemyShouldTerastallize?)

    def pbEnemyShouldTerastallize?(idxBattler)
      # Call original first
      should_tera = false
      should_tera = advanced_ai_tera_pbEnemyShouldTerastallize?(idxBattler) if respond_to?(:advanced_ai_tera_pbEnemyShouldTerastallize?)

      return should_tera unless AdvancedBattleAI.feature_enabled?(:memory, @trainer)
      return should_tera unless @memory

      battler = @battle.battlers[idxBattler]
      return should_tera unless battler

      # Check if opponent has shown super-effective moves
      @battle.pbGetOpposingIndicesInOrder(idxBattler).each do |opp_idx|
        known_moves = @memory.get_known_moves(opp_idx)
        next if known_moves.empty?

        # Count dangerous moves against current typing
        dangerous_count = known_moves.count do |move_id|
          move_data = GameData::Move.try_get(move_id)
          next false unless move_data && move_data.power > 0
          type_mod = Effectiveness.calculate(move_data.type, *battler.types)
          Effectiveness.super_effective?(type_mod)
        end

        # More dangerous moves = more reason to Tera for defense
        if dangerous_count >= 2
          AdvancedBattleAI.log("Tera consideration: #{dangerous_count} known threats", :decisions)
          should_tera = true
          break
        end
      end

      return should_tera
    end
  end
end

#===============================================================================
# Field Effect Integration
# Field-aware move scoring
#===============================================================================
if defined?(Battle::Field) || defined?(PBFieldEffects)
  AdvancedBattleAI.log("Field Effect plugin detected, adding integration", :general)

  Battle::AI::Handlers::GeneralMoveScore.add(:advanced_field_effect_scoring,
    proc { |score, move, user, ai, battle|
      next score unless AdvancedBattleAI.feature_enabled?(:field, ai.trainer)

      # Get current field effect
      field = nil
      if battle.respond_to?(:field_id)
        field = battle.field_id rescue nil
      end

      next score unless field && field != :BASE

      # Field-specific scoring adjustments
      case field
      when :ELECTRIC
        if move.type == :ELECTRIC
          score += 15
          AdvancedBattleAI.log("Electric field boost", :scoring)
        end
        # Rising Voltage doubles in Electric Terrain
        if move.function_code == "DoublePowerInElectricTerrain"
          score += 25
        end

      when :GRASSY
        if move.type == :GRASS
          score += 15
        end
        # Grassy Glide gets priority
        if move.function_code == "HigherPriorityInGrassyTerrain"
          score += 20
          AdvancedBattleAI.log("Grassy Glide priority boost", :scoring)
        end

      when :PSYCHIC
        if move.type == :PSYCHIC
          score += 15
        end
        # Expanding Force hits all foes
        if move.function_code == "HitsAllFoesInPsychicTerrain"
          score += 20 if battle.doubleBattle?
        end

      when :MISTY
        # Dragon moves weakened
        if move.type == :DRAGON
          score -= 10
        end

      when :BEACH
        if move.type == :WATER
          score += 10
        end
        if move.type == :GROUND || move.type == :ROCK
          score += 10
        end

      when :FOREST
        if move.type == :GRASS || move.type == :BUG
          score += 10
        end

      when :DARKFOREST
        if move.type == :DARK || move.type == :GHOST
          score += 10
        end
        if move.type == :GRASS || move.type == :BUG
          score += 5
        end

      when :CAVE
        if move.type == :ROCK || move.type == :GROUND
          score += 10
        end

      when :CRYSTALCAVE
        if move.type == :ROCK
          score += 10
        end
        if move.type == :FAIRY
          score += 10
        end

      when :FAIRYGROVE
        if move.type == :FAIRY
          score += 15
        end
        if move.type == :DRAGON
          score -= 15
        end

      when :URBAN
        if move.type == :STEEL || move.type == :ELECTRIC
          score += 10
        end

      when :NORMALIZED
        if move.type == :NORMAL
          score += 10
        end
      end

      # Bonus for field-changing moves if field is bad for us
      field_change_functions = [
        "StartSunWeather", "StartRainWeather", "StartSandstormWeather",
        "StartHailWeather", "StartElectricTerrain", "StartGrassyTerrain",
        "StartPsychicTerrain", "StartMistyTerrain"
      ]
      if field_change_functions.include?(move.function_code)
        # Consider if current field is bad
        # This is a simplified check
        score += 10  # Small bonus for changing field
      end

      next score
    }
  )
end

#===============================================================================
# Z-Power Integration (Deluxe Battle Kit)
# Role-aware Z-Move decisions
#===============================================================================
if defined?(Settings::Z_POWERED_POKEMON)
  AdvancedBattleAI.log("Z-Power plugin detected, adding integration", :general)

  # Enhance Z-Move scoring with role awareness
  Battle::AI::Handlers::GeneralMoveScore.add(:advanced_zmove_role_scoring,
    proc { |score, move, user, ai, battle|
      # Check if this is a Z-Move (depends on how DBK implements it)
      is_zmove = move.respond_to?(:zMove?) && move.zMove? rescue false
      next score unless is_zmove

      next score unless AdvancedBattleAI.feature_enabled?(:roles, ai.trainer)

      user_ai = ai.battlers[user.index]
      next score unless user_ai

      case user_ai.detected_role
      when Battle::AI::Roles::SWEEPER
        # Z-Moves are great for breaking through walls
        score += 20
        AdvancedBattleAI.log("Z-Move bonus for sweeper", :scoring)

      when Battle::AI::Roles::SETUP_SWEEPER
        # Z-Status moves give boosts, very valuable
        if move.statusMove?
          score += 25
        end

      when Battle::AI::Roles::STALLBREAKER
        # Z-Moves help break stall
        score += 15
      end

      next score
    }
  )
end

#===============================================================================
# Mega Evolution Enhancement
# Role-aware Mega Evolution decisions
#===============================================================================
class Battle::AI
  alias advanced_ai_mega_pbEnemyShouldMegaEvolve? pbEnemyShouldMegaEvolve? if method_defined?(:pbEnemyShouldMegaEvolve?)

  def pbEnemyShouldMegaEvolve?
    should_mega = false
    should_mega = advanced_ai_mega_pbEnemyShouldMegaEvolve? if respond_to?(:advanced_ai_mega_pbEnemyShouldMegaEvolve?)

    return should_mega unless AdvancedBattleAI.feature_enabled?(:roles, @trainer)

    user_ai = @battlers[@user.index]
    return should_mega unless user_ai

    # Role-based Mega Evolution timing
    case user_ai.detected_role
    when Battle::AI::Roles::SWEEPER, Battle::AI::Roles::SETUP_SWEEPER
      # Sweepers should Mega when ready to sweep
      if count_positive_stat_stages(user_ai) >= 2
        should_mega = true
        AdvancedBattleAI.log("Mega after setup", :decisions)
      end

    when Battle::AI::Roles::PHYSICAL_WALL, Battle::AI::Roles::SPECIAL_WALL
      # Walls should Mega immediately for bulk
      should_mega = true

    when Battle::AI::Roles::HAZARD_SETTER
      # Don't waste Mega on hazard setter usually
      should_mega = false if user_ai.hp_fraction < 0.5
    end

    return should_mega
  end
end

#===============================================================================
# Compatibility Check on Load
#===============================================================================
