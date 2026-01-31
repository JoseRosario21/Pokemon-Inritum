#===============================================================================
# Field Effect Auto-Hooks
# This file hooks into core battle methods to apply field effects automatically
# Making the plugin truly plug-and-play without modifying core scripts
#===============================================================================

#===============================================================================
# Move Type Calculations - Type Change & Type Add
#===============================================================================
class Battle::Move
  alias_method :pbCalcType_field_original, :pbCalcType

  def pbCalcType(user)
    ret = pbCalcType_field_original(user)

    # Apply field-based type change (e.g., Cut → Grass in Forest)
    change_ret = @battle.apply_field_effect(:base_type_change, self)
    ret = change_ret if change_ret && change_ret != ret

    ret
  end
end

#===============================================================================
# Move Additional Type - For moves that gain secondary typing
# Hooks into type effectiveness calculation
# Note: If added type is immune (e.g., Ground vs Flying), move deals 0 damage
#===============================================================================
class Battle::Move
  alias_method :pbCalcTypeMod_field_add, :pbCalcTypeMod

  def pbCalcTypeMod(moveType, user, target)
    ret = pbCalcTypeMod_field_add(moveType, user, target)

    # Check if move gets additional typing from field effects
    add_type = @battle.apply_field_effect(:base_type_add, self)
    if add_type && add_type.is_a?(Symbol)
      # Calculate and apply effectiveness for the additional type
      target.pbTypes(true).each do |def_type|
        ret *= Effectiveness.calculate(add_type, def_type)
      end
    end

    ret
  end
end

#===============================================================================
# Accuracy Modifications
#===============================================================================
class Battle::Move
  alias_method :pbBaseAccuracy_field_original, :pbBaseAccuracy

  def pbBaseAccuracy(user, target)
    original = pbBaseAccuracy_field_original(user, target)

    # Apply field-based accuracy modification
    modified = @battle.apply_field_effect(:accuracy_modify, self)
    return modified if modified && modified != original

    original
  end
end

#===============================================================================
# Target Expansion for Double Battles
#===============================================================================
class Battle::Move
  alias_method :pbTarget_field_original, :pbTarget

  def pbTarget(user)
    target_data = pbTarget_field_original(user)

    # Check if field expands targeting (e.g., Sand Attack hits all in doubles)
    expanded = @battle.apply_field_effect(:target_expand, user, self, target_data)
    return GameData::Target.get(:AllNearFoes) if expanded

    target_data
  end
end

#===============================================================================
# Healing Move Boost (Shore Up, Synthesis, etc.)
#===============================================================================
class Battle::Move::HealingMove
  alias_method :pbHealAmount_field_original, :pbHealAmount if method_defined?(:pbHealAmount)

  def pbHealAmount(user)
    # Check for field-based healing boost first
    if @battle.apply_field_effect(:heal_boost, self)
      return (user.totalhp * 3 / 4.0).round  # 75% instead of 50%
    end

    # Check for field-based healing reduction
    if @battle.apply_field_effect(:heal_reduce, self)
      return (user.totalhp / 4.0).round  # 25% instead of 50%
    end

    # Call original if it exists, otherwise default
    if respond_to?(:pbHealAmount_field_original, true)
      return pbHealAmount_field_original(user)
    end

    (user.totalhp / 2.0).round
  end
end

#===============================================================================
# Shore Up specific handling
#===============================================================================
class Battle::Move::HealUserDependingOnSandstorm
  alias_method :pbHealAmount_shoreup_field, :pbHealAmount

  def pbHealAmount(user)
    # Field boost takes priority
    if @battle.apply_field_effect(:heal_boost, self)
      return (user.totalhp * 3 / 4.0).round
    end

    pbHealAmount_shoreup_field(user)
  end
end if defined?(Battle::Move::HealUserDependingOnSandstorm)

#===============================================================================
# Synthesis/Moonlight/Morning Sun handling
#===============================================================================
class Battle::Move::HealUserDependingOnWeather
  alias_method :pbHealAmount_weather_field, :pbHealAmount

  def pbHealAmount(user)
    # Field boost takes priority
    if @battle.apply_field_effect(:heal_boost, self)
      return (user.totalhp * 3 / 4.0).round
    end

    pbHealAmount_weather_field(user)
  end
end if defined?(Battle::Move::HealUserDependingOnWeather)

#===============================================================================
# Ingrain HP Recovery Boost - Hook into EOR healing
#===============================================================================
class Battle
  alias_method :pbEORHealingEffects_field_ingrain, :pbEORHealingEffects

  def pbEORHealingEffects(priority)
    # Aqua Ring (handled normally)
    priority.each do |battler|
      next if !battler.effects[PBEffects::AquaRing]
      next if !battler.canHeal?
      hpGain = battler.totalhp / 16
      # Check for field boost
      hpGain = battler.totalhp / 8 if apply_field_effect(:aqua_ring_boost, battler)
      hpGain = (hpGain * 1.3).floor if battler.hasActiveItem?(:BIGROOT)
      battler.pbRecoverHP(hpGain)
      pbDisplay(_INTL("Aqua Ring restored {1}'s HP!", battler.pbThis(true)))
    end

    # Ingrain with field boost
    priority.each do |battler|
      next if !battler.effects[PBEffects::Ingrain]
      next if !battler.canHeal?
      # Check for field boost first
      if apply_field_effect(:ingrain_boost, battler)
        hpGain = battler.totalhp / 8  # Boosted
      else
        hpGain = battler.totalhp / 16  # Normal
      end
      hpGain = (hpGain * 1.3).floor if battler.hasActiveItem?(:BIGROOT)
      battler.pbRecoverHP(hpGain)
      pbDisplay(_INTL("{1} absorbed nutrients with its roots!", battler.pbThis))
    end

    # Leech Seed with field boost
    priority.each do |battler|
      next if battler.effects[PBEffects::LeechSeed] < 0
      next if !battler.takesIndirectDamage?
      recipient = @battlers[battler.effects[PBEffects::LeechSeed]]
      next if !recipient || recipient.fainted?
      pbCommonAnimation("LeechSeed", recipient, battler)
      # Check for field boost
      if apply_field_effect(:leech_seed_boost, battler)
        damage = battler.totalhp / 6  # Boosted
      else
        damage = battler.totalhp / 8  # Normal
      end
      battler.pbTakeEffectDamage(damage) do |hp_lost|
        recipient.pbRecoverHPFromDrain(hp_lost, battler,
                                       _INTL("{1}'s health is sapped by Leech Seed!", battler.pbThis))
        recipient.pbAbilitiesOnDamageTaken
      end
      recipient.pbFaint if recipient.fainted?
    end
  end
end

#===============================================================================
# Binding/Trapping Move Damage Boost - Hook into EOR trapping damage
#===============================================================================
class Battle
  alias_method :pbEORTrappingDamage_field_binding, :pbEORTrappingDamage

  def pbEORTrappingDamage(battler)
    return if battler.fainted?
    return if battler.effects[PBEffects::TrappingMove] == nil
    move_name = GameData::Move.get(battler.effects[PBEffects::TrappingMove]).name
    if battler.effects[PBEffects::TrappingUser] >= 0 &&
       (!@battlers[battler.effects[PBEffects::TrappingUser]] ||
        @battlers[battler.effects[PBEffects::TrappingUser]].fainted?)
      battler.effects[PBEffects::TrappingMove] = nil
      return
    end
    pbCommonAnimation("Wrap", battler)
    return if !battler.takesIndirectDamage?

    # Get move data for field check
    move_data = GameData::Move.try_get(battler.effects[PBEffects::TrappingMove])

    # Calculate base damage
    hpLoss = (Settings::MECHANICS_GENERATION >= 6) ? battler.totalhp / 8 : battler.totalhp / 16

    # Check Binding Band
    if @battlers[battler.effects[PBEffects::TrappingUser]].hasActiveItem?(:BINDINGBAND)
      hpLoss = (Settings::MECHANICS_GENERATION >= 6) ? battler.totalhp / 6 : battler.totalhp / 8
    end

    # Check for field boost
    if move_data && apply_field_effect(:binding_boost, move_data)
      hpLoss = battler.totalhp / 6
    end

    @scene.pbDamageAnimation(battler)
    battler.pbTakeEffectDamage(hpLoss, false) do |hp_lost|
      pbDisplay(_INTL("{1} is hurt by {2}!", battler.pbThis, move_name))
    end
  end
end

#===============================================================================
# Taunt Duration Modification
#===============================================================================
class Battle::Move::DisableTargetStatusMoves
  alias_method :pbEffectAgainstTarget_taunt_field, :pbEffectAgainstTarget

  def pbEffectAgainstTarget(user, target)
    # Check for field-modified duration
    field_duration = @battle.apply_field_effect(:increase_duration, self)

    if field_duration
      target.effects[PBEffects::Taunt] = field_duration
      @battle.pbDisplay(_INTL("{1} fell for the taunt!", target.pbThis))
    else
      pbEffectAgainstTarget_taunt_field(user, target)
    end
  end
end if defined?(Battle::Move::DisableTargetStatusMoves)

#===============================================================================
# Stat Drop Effect Boost - Increases stages lowered
#===============================================================================
class Battle::Move::TargetStatDownMove
  alias_method :pbAdditionalEffect_statdown_field, :pbAdditionalEffect

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    return if !target.pbCanLowerStatStage?(@statDown[0], user, self)

    # Check for field effect boost to stat drops
    stages = @statDown[1]
    boosted = @battle.apply_field_effect(:effect_boost, self)
    stages = boosted if boosted && boosted.is_a?(Integer)

    target.pbLowerStatStage(@statDown[0], stages, user)
  end
end if defined?(Battle::Move::TargetStatDownMove)

#===============================================================================
# Effect Chance Boost
#===============================================================================
class Battle::Move
  alias_method :pbAdditionalEffectChance_field, :pbAdditionalEffectChance if method_defined?(:pbAdditionalEffectChance)

  def pbAdditionalEffectChance(user, target, effectChance = 0)
    # Check for field effect chance boost (multiplier, e.g., 2 = double)
    boost = @battle.apply_field_effect(:effect_chance_boost, self)
    if boost && boost.is_a?(Numeric) && boost > 1
      effectChance = [effectChance * boost, 100].min.to_i
    end

    if respond_to?(:pbAdditionalEffectChance_field, true)
      return pbAdditionalEffectChance_field(user, target, effectChance)
    end

    effectChance
  end
end

#===============================================================================
# Move Enhancement Effects - Speed boost, stat boost from specific moves
# PBS: Effect = speed_boost_move,SPLASH,2,User gained momentum!
# Must hook specific move classes that override pbEffectGeneral
#===============================================================================

# Hook for Splash specifically (DoesNothingUnusableInGravity)
class Battle::Move::DoesNothingUnusableInGravity
  alias_method :pbEffectGeneral_splash_original, :pbEffectGeneral

  def pbEffectGeneral(user)
    # Check for field-based speed boost for Splash
    speed_info = @battle.apply_field_effect(:speed_boost_move, user, self)
    if speed_info && speed_info.is_a?(Hash)
      stages = speed_info[:stages] || 2
      message = speed_info[:message]
      if message && !message.empty?
        @battle.pbDisplay(_INTL(message.gsub("{1}", user.pbThis)))
      else
        @battle.pbDisplay(_INTL("{1} gained momentum!", user.pbThis))
      end
      user.pbRaiseStatStage(:SPEED, stages, user)
      return  # Move effect replaced by field effect
    end

    # Check for generic stat boost
    stat_info = @battle.apply_field_effect(:stat_boost_move, user, self)
    if stat_info && stat_info.is_a?(Hash)
      stat = stat_info[:stat] || :SPEED
      stages = stat_info[:stages] || 1
      message = stat_info[:message]
      @battle.pbDisplay(_INTL(message.gsub("{1}", user.pbThis))) if message && !message.empty?
      user.pbRaiseStatStage(stat, stages, user)
      return
    end

    # No field effect, use original (But nothing happened!)
    pbEffectGeneral_splash_original(user)
  end
end if defined?(Battle::Move::DoesNothingUnusableInGravity)

# Generic hook for other moves that might use stat boosts
class Battle::Move
  alias_method :pbEffectGeneral_field_enhance, :pbEffectGeneral if method_defined?(:pbEffectGeneral)

  def pbEffectGeneral(user)
    # Check for field-based stat boost for this move
    stat_info = @battle.apply_field_effect(:stat_boost_move, user, self)
    if stat_info && stat_info.is_a?(Hash)
      stat = stat_info[:stat] || :SPEED
      stages = stat_info[:stages] || 1
      message = stat_info[:message]
      @battle.pbDisplay(_INTL(message.gsub("{1}", user.pbThis))) if message && !message.empty?
      user.pbRaiseStatStage(stat, stages, user)
      # Don't return - let move continue with normal effects
    end

    # Check for speed boost (for moves other than Splash)
    speed_info = @battle.apply_field_effect(:speed_boost_move, user, self)
    if speed_info && speed_info.is_a?(Hash)
      stages = speed_info[:stages] || 2
      message = speed_info[:message]
      if message && !message.empty?
        @battle.pbDisplay(_INTL(message.gsub("{1}", user.pbThis)))
      else
        @battle.pbDisplay(_INTL("{1} gained momentum!", user.pbThis))
      end
      user.pbRaiseStatStage(:SPEED, stages, user)
    end

    # Call original
    pbEffectGeneral_field_enhance(user) if respond_to?(:pbEffectGeneral_field_enhance, true)
  end
end

#===============================================================================
# Charge Move Skip (Dig, Dive, etc.)
# NOTE: If DBK is installed, it already handles this via skipChargingTurn?
# This hook is only for non-DBK installations
#===============================================================================
unless defined?(Battle::Move::TwoTurnMove) &&
       Battle::Move::TwoTurnMove.method_defined?(:skipChargingTurn?)
  class Battle::Move::TwoTurnMove
    alias_method :pbIsChargingTurn_field, :pbIsChargingTurn? if method_defined?(:pbIsChargingTurn?)

    def pbIsChargingTurn?(user)
      # Check if field allows skipping charge
      if @battle.apply_field_effect(:no_charging, user, self)
        return false  # Skip charge turn
      end

      if respond_to?(:pbIsChargingTurn_field, true)
        return pbIsChargingTurn_field(user)
      end

      # Default behavior
      @chargingTurn
    end
  end
end

#===============================================================================
# Speed Modifications
#===============================================================================
class Battle::Battler
  alias_method :pbSpeed_field_original, :pbSpeed

  def pbSpeed
    speed = pbSpeed_field_original

    # Apply field-based speed modifications
    if @battle.apply_field_effect(:speed_double, self)
      speed *= 2
    elsif @battle.apply_field_effect(:speed_halve, self)
      speed /= 2
    end

    [speed.round, 1].max
  end
end

#===============================================================================
# Battle Start Effects - Hook into pbOnAllBattlersEnteringBattle
# This runs after set_default_field so the field is properly initialized
#===============================================================================
class Battle
  alias_method :pbOnAllBattlersEnteringBattle_field_hooks, :pbOnAllBattlersEnteringBattle

  def pbOnAllBattlersEnteringBattle
    # Initialize field counters
    @field_counters ||= {}
    @field_combo_history ||= []

    # Call original
    pbOnAllBattlersEnteringBattle_field_hooks

    # Apply begin battle effects AFTER all battlers have entered
    return unless has_field?
    eachBattler do |b|
      apply_field_effect(:begin_battle, b)
    end
  end
end

#===============================================================================
# Damage Calculation - Main hook for :calc_damage
# Always hooks, but checks at runtime if another plugin already called it
#===============================================================================
class Battle::Move
  alias_method :pbCalcDamageMultipliers_field_standalone, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # Mark that we're starting damage calc (reset flag)
    @battle.field_calc_damage_called = false if @battle.respond_to?(:field_calc_damage_called=)

    # Call original (which may include DBK's version that calls apply_field_effect)
    pbCalcDamageMultipliers_field_standalone(user, target, numTargets, type, baseDmg, multipliers)

    # Apply field damage calculation if not already called
    unless @battle.respond_to?(:field_calc_damage_called) && @battle.field_calc_damage_called
      @battle.apply_field_effect(:calc_damage, user, target, numTargets, self, type, baseDmg, multipliers, false)
    end
  end
end

# Add tracking flag to Battle
class Battle
  attr_accessor :field_calc_damage_called
end

#===============================================================================
# Two-Turn Move Charge Skip - Main hook for :no_charging
# Adds skipChargingTurn? if not already defined
#===============================================================================
class Battle::Move::TwoTurnMove
  unless method_defined?(:skipChargingTurn?)
    def skipChargingTurn?(user)
      return @battle.apply_field_effect(:no_charging, user, self)
    end

    alias_method :pbIsChargingTurn_field_standalone, :pbIsChargingTurn?

    def pbIsChargingTurn?(user)
      @chargingTurn = false
      @damagingTurn = true
      if !user.effects[PBEffects::TwoTurnAttack]
        if skipChargingTurn?(user)
          @chargingTurn = true
          @damagingTurn = true
        else
          @chargingTurn = true
          @damagingTurn = user.hasActiveItem?(:POWERHERB)
        end
      end
      return !@damagingTurn
    end
  end
end

#===============================================================================
# Priority Block (Psychic Terrain)
#===============================================================================
class Battle::Move
  alias_method :pbPriority_field_original, :pbPriority if method_defined?(:pbPriority)

  def pbPriority(user)
    prio = respond_to?(:pbPriority_field_original, true) ? pbPriority_field_original(user) : @priority

    # Check if field blocks priority moves against grounded targets
    if prio > 0 && @battle.apply_field_effect(:block_priority, user, self)
      # Priority is blocked - this is handled in target selection/execution
      # We don't modify priority here, the block happens in move execution
    end

    prio
  end
end

#===============================================================================
# Nature Power and Secret Power
#===============================================================================
class Battle::Move::UseMoveDependingOnEnvironment
  alias_method :pbMoveFailed_naturepower_field, :pbMoveFailed? if method_defined?(:pbMoveFailed?)

  def pbMoveFailedAI?(user, targets)
    return false
  end

  def getNaturePowerMove
    # Check field-based Nature Power change first
    field_move = @battle.apply_field_effect(:nature_power_change, self)
    return field_move if field_move

    # Default terrain-based moves
    case @battle.field.terrain
    when :Electric then return :THUNDERBOLT
    when :Grassy   then return :ENERGYBALL
    when :Misty    then return :MOONBLAST
    when :Psychic  then return :PSYCHIC
    end

    # Environment-based defaults
    :TRIATTACK
  end
end if defined?(Battle::Move::UseMoveDependingOnEnvironment)

class Battle::Move::EffectDependsOnEnvironment
  def getSecretPowerEffect
    # Check field-based Secret Power effect first
    field_effect = @battle.apply_field_effect(:secret_power_effect, @user, @targets, self)
    return field_effect if field_effect

    # Default: paralysis
    1
  end
end if defined?(Battle::Move::EffectDependsOnEnvironment)

#===============================================================================
# Camouflage Type Change
#===============================================================================
class Battle::Move::SetUserTypesBasedOnEnvironment
  alias_method :pbMoveFailed_camouflage_field, :pbMoveFailed? if method_defined?(:pbMoveFailed?)

  def getCamouflageType
    # Check field-based type first
    field_type = @battle.apply_field_effect(:camouflage_type, self)
    return field_type if field_type

    # Terrain-based
    case @battle.field.terrain
    when :Electric then return :ELECTRIC
    when :Grassy   then return :GRASS
    when :Misty    then return :FAIRY
    when :Psychic  then return :PSYCHIC
    end

    :NORMAL
  end
end if defined?(Battle::Move::SetUserTypesBasedOnEnvironment)

#===============================================================================
# Aqua Ring Boost
#===============================================================================
class Battle::Battler
  alias_method :pbRecoverHPFromAquaRing_field, :pbRecoverHPFromAquaRing if method_defined?(:pbRecoverHPFromAquaRing)

  def pbRecoverHPFromAquaRing
    return if !@effects[PBEffects::AquaRing]

    # Check for field boost
    if @battle.apply_field_effect(:aqua_ring_boost)
      hpGain = @totalhp / 8  # Boosted
    else
      hpGain = @totalhp / 16  # Normal
    end

    hpGain = (hpGain * 1.3).floor if hasActiveItem?(:BIGROOT)

    pbRecoverHP(hpGain)
    @battle.pbDisplay(_INTL("{1}'s Aqua Ring restored its HP!", pbThis))
  end
end

#===============================================================================
# Leech Seed Boost
#===============================================================================
class Battle::Battler
  alias_method :pbLeechSeedDamage_field, :pbTakeLeechSeedDamage if method_defined?(:pbTakeLeechSeedDamage)

  def pbTakeLeechSeedDamage
    return if @effects[PBEffects::LeechSeed] < 0

    # Check for field boost
    boosted = @battle.apply_field_effect(:leech_seed_boost)

    hpLoss = boosted ? @totalhp / 6 : @totalhp / 8
    hpLoss = 1 if hpLoss < 1

    pbReduceHP(hpLoss, false)
    @battle.pbDisplay(_INTL("{1}'s health is sapped by Leech Seed!", pbThis))

    # Heal the seeder
    recipient = @battle.battlers[@effects[PBEffects::LeechSeed]]
    if recipient && !recipient.fainted?
      hpGain = hpLoss
      hpGain = (hpGain * 1.3).floor if recipient.hasActiveItem?(:BIGROOT)
      recipient.pbRecoverHP(hpGain)
    end
  end
end

#===============================================================================
# Cleanup: Remove apply_field_effect calls from original files
# These hooks now handle everything automatically
#===============================================================================
# The following effect keys are now auto-hooked:
# - :base_type_change    (Move type modification)
# - :base_type_add       (Secondary type)
# - :accuracy_modify     (Accuracy changes)
# - :target_expand       (Double battle targeting)
# - :heal_boost          (Healing move boost)
# - :heal_reduce         (Healing move reduction)
# - :ingrain_boost       (Ingrain recovery)
# - :binding_boost       (Trapping damage)
# - :increase_duration   (Effect duration)
# - :effect_chance_boost (Effect chance)
# - :no_charging         (Skip charge turn)
# - :speed_double        (Speed boost)
# - :speed_halve         (Speed reduction)
# - :begin_battle        (Battle start)
# - :calc_damage         (Damage multipliers)
# - :block_priority      (Priority block)
# - :nature_power_change (Nature Power move)
# - :secret_power_effect (Secret Power effect)
# - :camouflage_type     (Camouflage type)
# - :aqua_ring_boost     (Aqua Ring recovery)
# - :leech_seed_boost    (Leech Seed damage)
# - :add_status          (Status application - in FieldBattleHooks)
