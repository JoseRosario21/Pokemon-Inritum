#===============================================================================
# Advanced Battle AI - System Integration
# Hooks into base Battle system for memory recording and feature enabling
#===============================================================================

#===============================================================================
# Add AI accessor and helper methods to Battle class
# The Battle class uses @battleAI internally but has no public accessor
#===============================================================================
class Battle
  def ai
    return @battleAI
  end

  # Helper method to check if this is a double battle
  # (2 or more battlers on at least one side)
  def doubleBattle?
    return pbSideSize(0) >= 2 || pbSideSize(1) >= 2
  end
end

#===============================================================================
# Battle::Battler Hooks
# Record moves as they're used
#===============================================================================
class Battle::Battler
  #-----------------------------------------------------------------------------
  # Hook into move usage to record in AI memory
  #-----------------------------------------------------------------------------
  alias advanced_ai_pbUseMove pbUseMove
  def pbUseMove(choice, specialUsage = false)
    ret = advanced_ai_pbUseMove(choice, specialUsage)

    # Record move in AI memory if AI exists
    move = choice[2]
    if @battle.ai && @battle.ai.memory && move
      @battle.ai.memory.record_move_used(@index, move)

      # Also record Pokemon seen
      side = @battle.opposes?(@index) ? 1 : 0
      @battle.ai.memory.record_pokemon_seen(side, @species)
    end

    return ret
  end

  #-----------------------------------------------------------------------------
  # Hook into item consumption to record in AI memory
  #-----------------------------------------------------------------------------
  alias advanced_ai_pbConsumeItem pbConsumeItem
  def pbConsumeItem(recoverable = true, symbiosis = true, belch = true)
    # Record item before consumption
    if @battle.ai && @battle.ai.memory && @item
      @battle.ai.memory.record_item(@index, @item_id, true)  # consumed
    end

    return advanced_ai_pbConsumeItem(recoverable, symbiosis, belch)
  end

  #-----------------------------------------------------------------------------
  # Hook into HP reduction to record damage in AI memory
  #-----------------------------------------------------------------------------
  alias advanced_ai_pbReduceHP pbReduceHP
  def pbReduceHP(amt, anim = true, registerDamage = true, anyAnim = true)
    ret = advanced_ai_pbReduceHP(amt, anim, registerDamage, anyAnim)

    # Record damage if from a move
    if @battle.ai && @battle.ai.memory && registerDamage && @battle.lastMoveUsed && amt > 0
      attacker_idx = @battle.lastMoveUser
      if attacker_idx && @battle.battlers[attacker_idx]
        move_data = GameData::Move.try_get(@battle.lastMoveUsed)
        move_type = move_data ? move_data.type : nil
        @battle.ai.memory.record_damage(
          @index,
          attacker_idx,
          @battle.lastMoveUsed,
          amt,
          move_type
        )
      end
    end

    return ret
  end
end

#===============================================================================
# Battle Class Hooks
# Record switches
#===============================================================================
class Battle
  #-----------------------------------------------------------------------------
  # Hook into switching to record in AI memory
  #-----------------------------------------------------------------------------
  alias advanced_ai_pbRecallAndReplace pbRecallAndReplace
  def pbRecallAndReplace(idxBattler, idxParty, randomReplacement = false, batonPass = false)
    # Record switch in memory
    if ai && ai.memory
      ai.memory.record_switch(idxBattler)
      ai.memory.clear_battler(idxBattler)
    end

    ret = advanced_ai_pbRecallAndReplace(idxBattler, idxParty, randomReplacement, batonPass)

    # Record new Pokemon seen
    if ai && ai.memory
      new_battler = @battlers[idxBattler]
      if new_battler
        side = opposes?(idxBattler) ? 1 : 0
        ai.memory.record_pokemon_seen(side, new_battler.species)
      end
    end

    return ret
  end

  #-----------------------------------------------------------------------------
  # Hook into battler entering battle to record abilities
  #-----------------------------------------------------------------------------
  if method_defined?(:pbOnBattlerEnteringBattle)
    alias advanced_ai_pbOnBattlerEnteringBattle pbOnBattlerEnteringBattle
  end

  def pbOnBattlerEnteringBattle(battler_index, skip_event_reset = false)
    # Call original first if it exists
    ret = nil
    if respond_to?(:advanced_ai_pbOnBattlerEnteringBattle, true)
      ret = advanced_ai_pbOnBattlerEnteringBattle(battler_index, skip_event_reset)
    end

    # Handle array of indices (the method can receive either single index or array)
    indices = battler_index.is_a?(Array) ? battler_index.flatten : [battler_index]

    # Record ability and Pokemon seen for each entering battler
    indices.each do |idx|
      battler = @battlers[idx]
      next unless battler
      if ai && ai.memory
        # Record Pokemon seen
        side = opposes?(idx) ? 1 : 0
        ai.memory.record_pokemon_seen(side, battler.species)

        # Only record ability for opponent Pokemon whose ability triggers visibly
        # on entry (Intimidate, Drizzle, etc.). The AI shouldn't know abilities
        # that don't announce themselves. For now, record for non-player Pokemon
        # whose ability has a visible on-entry effect.
        if battler.ability_id && !battler.pbOwnedByPlayer?
          visible_on_entry = [
            :INTIMIDATE, :DRIZZLE, :DROUGHT, :SANDSTREAM, :SNOWWARNING,
            :ELECTRICSURGE, :GRASSYSURGE, :MISTYSURGE, :PSYCHICSURGE,
            :AIRLOCK, :CLOUDNINE, :TRACE, :PRESSURE, :UNNERVE,
            :SCREENCLEANER, :NEUTRALIZINGGAS, :DOWNLOAD, :INTREPIDSWORD,
            :DAUNTLESSSHIELD, :ASONEGLASTRIER, :ASONESPECTRIER,
            :CURIOUSMEDICINE, :PASTELVEIL, :PRIMORDIALSEA, :DESOLATELAND,
            :DELTASTREAM
          ]
          if visible_on_entry.include?(battler.ability_id)
            ai.memory.record_ability(idx, battler.ability_id)
          end
        end
      end
    end

    return ret
  end
end

#===============================================================================
# AITrainer Extensions
# Add advanced AI skill flags based on settings
#===============================================================================
class Battle::AI::AITrainer
  alias advanced_ai_set_up_skill_flags set_up_skill_flags

  def set_up_skill_flags
    advanced_ai_set_up_skill_flags

    # Add advanced AI flags based on skill level and settings
    return unless AdvancedBattleAI.any_feature_enabled?(self)

    # Memory features
    if @skill >= AdvancedBattleAI::SKILL_THRESHOLD_MEMORY && AdvancedBattleAI::ENABLE_MOVE_MEMORY
      @skill_flags.push("MemorizeMoves") unless @skill_flags.include?("MemorizeMoves")
    end

    # Role-based features
    if @skill >= AdvancedBattleAI::SKILL_THRESHOLD_ROLES && AdvancedBattleAI::ENABLE_ROLE_SWITCHING
      @skill_flags.push("RoleAware") unless @skill_flags.include?("RoleAware")
    end

    # Setup optimization
    if @skill >= AdvancedBattleAI::SKILL_THRESHOLD_SETUP && AdvancedBattleAI::ENABLE_SETUP_WINDOWS
      @skill_flags.push("SetupSmart") unless @skill_flags.include?("SetupSmart")
    end

    # Double battle coordination
    if @skill >= AdvancedBattleAI::SKILL_THRESHOLD_DOUBLES && AdvancedBattleAI::ENABLE_DOUBLES_COORDINATION
      @skill_flags.push("CoordinateDoubles") unless @skill_flags.include?("CoordinateDoubles")
    end

    # Full AI features
    if @skill >= AdvancedBattleAI::SKILL_THRESHOLD_FULL
      @skill_flags.push("SacrificeAware") unless @skill_flags.include?("SacrificeAware")
      @skill_flags.push("HazardSmart") unless @skill_flags.include?("HazardSmart")
    end

    AdvancedBattleAI.log("AI flags for skill #{@skill}: #{@skill_flags.join(', ')}", :decisions)
  end
end

#===============================================================================
# AIBattler Extensions
# Add helper methods for advanced features
#===============================================================================
class Battle::AI::AIBattler
  # Check if battler knows a move with specific function (via actual moves)
  def has_move_with_function?(*function_codes)
    return false unless @battler
    @battler.moves.each do |move|
      next unless move
      return true if function_codes.any? { |fc| move.function_code.match?(fc) }
    end
    return false
  end

  # Get HP fraction
  def hp_fraction
    return 0 unless @battler && @battler.totalhp > 0
    return @battler.hp.to_f / @battler.totalhp
  end

  # Get all stat stages
  def stages
    return {} unless @battler
    return @battler.stages
  end

  # Get level
  def level
    return @battler ? @battler.level : 50
  end

  # Get types
  def types
    return @battler ? @battler.types : [:NORMAL]
  end

  # Get speed
  def speed
    return @battler ? @battler.speed : 0
  end

  # Get attack
  def attack
    return @battler ? @battler.attack : 0
  end

  # Get defense
  def defense
    return @battler ? @battler.defense : 0
  end

  # Get spatk
  def spatk
    return @battler ? @battler.spatk : 0
  end

  # Get spdef
  def spdef
    return @battler ? @battler.spdef : 0
  end

  # Get HP
  def hp
    return @battler ? @battler.hp : 0
  end

  # Get total HP
  def totalhp
    return @battler ? @battler.totalhp : 1
  end

  # Get side index (using existing @side from AIBattler)
  def side
    return @side || 0
  end

  # Get opposing side index
  def opposing_side_index
    return @side == 0 ? 1 : 0
  end

  # Check type
  def has_type?(type)
    return @battler ? @battler.pbHasType?(type) : false
  end

  # Check active ability
  def has_active_ability?(ability)
    return @battler ? @battler.hasActiveAbility?(ability) : false
  end

  # Check active item
  def has_active_item?(item)
    return @battler ? @battler.hasActiveItem?(item) : false
  end
end

#===============================================================================
# Battle Start Hook
# Initialize roles for all battlers when battle starts
#===============================================================================
class Battle::AI
  alias advanced_ai_create_ai_objects create_ai_objects

  def create_ai_objects
    advanced_ai_create_ai_objects

    # Refresh roles for all battlers
    @battlers.each do |b|
      b.refresh_role if b && b.respond_to?(:refresh_role)
    end

    AdvancedBattleAI.log("Advanced AI initialized", :decisions)
  end
end

#===============================================================================
# Global AI Memory Access
# For debug commands
#===============================================================================
def pbGetAIMemory
  return nil unless $game_temp && $game_temp.respond_to?(:battle) && $game_temp.battle
  return $game_temp.battle.ai.memory rescue nil
end
