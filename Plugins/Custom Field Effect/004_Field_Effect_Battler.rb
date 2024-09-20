class Battle::Battler
  attr_accessor :triggered_abils
  attr_accessor :set_effect_triggered
  attr_accessor :field_speed_triggered

  alias field_effect_pbInitEffects pbInitEffects
  def pbInitEffects(batonPass)
    field_effect_pbInitEffects(batonPass)
	@triggered_abils = []
	@set_effect_triggered = false
	@field_speed_triggered = false
  end

#===============================================================================
# Speed
#===============================================================================
  alias field_effect_pbSpeed pbSpeed
  def pbSpeed
	if !@field_speed_triggered && @battle.field.field_effect != :None
	  fe = FIELD_EFFECTS[@battle.field.field_effect]
	  fe[:battler_speed_change].each do |key, value|
	    key.each do |k|
	      change = false
		  change = true if GameData::Species.exists?(k) && isSpecies?(k)
		  change = true if GameData::Type.exists?(k) && pbHasType?(k)
		  change = true if GameData::Ability.exists?(k) && hasActiveAbility?(k)
		  change = true if GameData::Item.exists?(k) && hasActiveItem?(k)
		  if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		    k = :POISON if k == :TOXIC
		    change = true if pbHasStatus?(k)
		  end
		  if change
		    @speed *= value
		    @field_speed_triggered = true
		  end
	    end
	  end
	end
	return field_effect_pbSpeed
  end

#===============================================================================
#
#===============================================================================
  def isTapu?
    tapu_family = [:TAPUKOKO, :TAPULELE, :TAPUBULU, :TAPUFINI]
    tapu_family.each { |b| return true if isSpecies?(b) }
	return false
  end

#===============================================================================
# Type
#===============================================================================
  def pbChangeFirstType(newType)
    @types[0] = newType
  end

  def pbChangeSecondType(newType)
    @types[1] = newType
  end

  def pbAddThirdType(newType)
	@effects[PBEffects::ExtraType] = newType
  end

  def pbGetRandomType
    type_list = [] 
    GameData::Type.each do |t| 
      next if t.pseudo_type
      next if [:QMARKS, :SHADOW].include?(t.id)
	  #next if pbTypes.include?(t.id)
      type_list.push(t.id)
    end
    return type_list.sample
  end

  def pbChangeTypes(newType)
    if newType.is_a?(Battle::Battler)
      newTypes = newType.pbTypes
      newTypes.push(:NORMAL) if newTypes.length == 0
      newExtraType = newType.effects[PBEffects::ExtraType]
      newExtraType = nil if newTypes.include?(newExtraType)
      @types = newTypes.clone
      @effects[PBEffects::ExtraType] = newExtraType
	elsif newType.is_a?(Array)
	  newTypes = newType.uniq
      @types = newTypes.take(2)
      @effects[PBEffects::ExtraType] = newTypes[2] if newTypes[2]
    else
      newType = GameData::Type.get(newType).id
      @types = [newType]
      @effects[PBEffects::ExtraType] = nil
    end
    @effects[PBEffects::BurnUp] = false
    @effects[PBEffects::Roost]  = false
	#@battle.scene.pbRefreshOne(@index)
  end

  if PluginManager.installed?("Generation 9 Pack")
    alias paldea_pbChangeTypes pbChangeTypes
    def pbChangeTypes(newType)
      paldea_pbChangeTypes(newType)
      @effects[PBEffects::DoubleShock] = false
      if abilityActive? && @proteanTrigger # Protean/Libero
        if PluginManager.installed?("Demanding Yellow Custom Scripts")
	      @ability_list.each do |ability_id|
	        @ability_id = ability_id
            Battle::AbilityEffects.triggerOnTypeChange(ability_id, self, newType)
	      end
		else
		  Battle::AbilityEffects.triggerOnTypeChange(self.ability, self, newType)
		end
      end 
    end
  end

  if PluginManager.installed?("[DBK] Terastallization")
    alias tera_pbChangeTypes pbChangeTypes
    def pbChangeTypes(newType)
      if newType.is_a?(Battle::Battler) && newType.tera?
        newTypes = newType.pbPreTeraTypes
        newExtraType = newType.effects[PBEffects::ExtraType]
        newTypes.delete(newExtraType)
        newTypes.push(:NORMAL) if newTypes.length == 0
        @types = newTypes.clone
        @effects[PBEffects::ExtraType] = newExtraType
      else
        tera_pbChangeTypes(newType)
      end
    end
  end

#===============================================================================
# Ability
#===============================================================================
  def pbAbilitiesOnSwitchIn
    if (!fainted? && unstoppableAbility?) || abilityActive?
      Battle::AbilityEffects.triggerOnSwitchIn(self.ability, self, @battle, true)
    end
  end

  if PluginManager.installed?("Demanding Yellow Custom Scripts")
    def pbAbilitiesOnSwitchIn
      @battle.pbPriority(true).each do |b|
        next if !b || !b.abilityActive? || b.index == @index
	    b.ability_list.each do |ability_id|
	      b.ability_id = ability_id
	      Battle::AbilityEffects.triggerOnBattlerSwitchIn(ability_id, b, @battle, self)
	    end
      end
	  @ability_list.each do |ability_id|
        if (!fainted? && unstoppableAbility?(ability_id)) || abilityActive?
	      @ability_id = ability_id
          Battle::AbilityEffects.triggerOnSwitchIn(ability_id, self, @battle, true)
        end
	  end
    end
  end

  def pbAbilityOnWeatherChange(ability_changed = false)
    return if !abilityActive?
    Battle::AbilityEffects.triggerOnWeatherChange(self.ability, self, @battle, ability_changed)
  end

  if PluginManager.installed?("Demanding Yellow Custom Scripts")
    def pbAbilityOnWeatherChange(ability_changed = false)
      return if !abilityActive?
	  @ability_list.each do |ability_id|
	    @ability_id = ability_id
        Battle::AbilityEffects.triggerOnWeatherChange(ability_id, self, @battle, ability_changed)
	  end
    end
  end

  def pbOnLosingAbility(oldAbil, suppressed = false)
    if oldAbil == :NEUTRALIZINGGAS && (suppressed || !@effects[PBEffects::GastroAcid])
      pbAbilitiesOnNeutralizingGasEnding
    elsif [:UNNERVE, :ASONECHILLINGNEIGH, :ASONEGRIMNEIGH].include?(oldAbil) && (suppressed || !@effects[PBEffects::GastroAcid])
      pbItemsOnUnnerveEnding
    elsif oldAbil == :ILLUSION && @effects[PBEffects::Illusion]
      @effects[PBEffects::Illusion] = nil
      if !@effects[PBEffects::Transform]
        @battle.scene.pbChangePokemon(self, @pokemon)
        @battle.pbDisplay(_INTL("{1}'s {2} wore off!", pbThis, GameData::Ability.get(oldAbil).name))
        @battle.pbSetSeen(self)
      end
    end
    @effects[PBEffects::GastroAcid] = false if unstoppableAbility?
    @effects[PBEffects::SlowStart]  = 0 if self.ability != :SLOWSTART
    @effects[PBEffects::Truant]     = false if self.ability != :TRUANT
    # Check for end of primordial weather
    @battle.pbEndPrimordialWeather
    # Revert form if Flower Gift/Forecast was lost
	pbAbilityOnWeatherChange(true)
    # Abilities that trigger when the weather changes
    pbCheckFormOnWeatherChange(true)
    # Abilities that trigger when the terrain changes
    pbAbilityOnTerrainChange(true)
  end

  if PluginManager.installed?("Demanding Yellow Custom Scripts")
    def pbOnLosingAbility(oldAbil, suppressed = false)
      if oldAbil == :NEUTRALIZINGGAS && (suppressed || !@effects[PBEffects::GastroAcid])
        pbAbilitiesOnNeutralizingGasEnding
      elsif [:UNNERVE, :ASONECHILLINGNEIGH, :ASONEGRIMNEIGH].include?(oldAbil) && (suppressed || !@effects[PBEffects::GastroAcid])
        pbItemsOnUnnerveEnding
      elsif oldAbil == :ILLUSION && @effects[PBEffects::Illusion]
        @effects[PBEffects::Illusion] = nil
        if !@effects[PBEffects::Transform]
          @battle.scene.pbChangePokemon(self, @pokemon)
          @battle.pbDisplay(_INTL("{1}'s {2} wore off!", pbThis, GameData::Ability.get(oldAbil).name))
          @battle.pbSetSeen(self)
        end
      end
      @effects[PBEffects::GastroAcid] = false if pbUnstoppableAbility?
      @effects[PBEffects::SlowStart]  = 0 if !@ability_list.include?(:SLOWSTART)
      @effects[PBEffects::Truant]     = false if !@ability_list.include?(:TRUANT)
      # Check for end of primordial weather
      @battle.pbEndPrimordialWeather
      # Revert form if Flower Gift/Forecast was lost
	  pbAbilityOnWeatherChange(true)
      # Abilities that trigger when the weather changes
      pbCheckFormOnWeatherChange(true)
      # Abilities that trigger when the terrain changes
      pbAbilityOnTerrainChange(true)
    end
  end

#===============================================================================
#
#===============================================================================
  alias field_effect_trappedInBattle? trappedInBattle?
  def trappedInBattle?
    fe = FIELD_EFFECTS[@battle.field.field_effect]
	return true if fe[:other_effect]["no switch"]
    return field_effect_trappedInBattle?
  end

  alias field_effect_canHeal? canHeal?
  def canHeal?
    fe = FIELD_EFFECTS[@battle.field.field_effect]
	return false if fe[:other_effect]["no heal"]
    return field_effect_canHeal?
  end

#===============================================================================
# Status
#===============================================================================
  alias field_effect_pbCanInflictStatus? pbCanInflictStatus?
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
	return false if statusImmune(newStatus, showMessages)
    return field_effect_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end

  alias field_effect_pbCanSynchronizeStatus? pbCanSynchronizeStatus?
  def pbCanSynchronizeStatus?(newStatus, user)
	return false if statusImmune(newStatus)
    return field_effect_pbCanSynchronizeStatus?(newStatus, user)
  end

  def statusImmune(newStatus, showMessages = false)
    return false if @battle.field.field_effect == :None
  	fe = FIELD_EFFECTS[@battle.field.field_effect]
	immune = false
	case newStatus
	when :SLEEP
	  immune = true if fe[:block_status]["sleep"]
    when :POISON
      immune = true if fe[:block_status]["toxic"]
	when :BURN
      immune = true if fe[:block_status]["burn"]
	when :PARALYSIS
      immune = true if fe[:block_status]["paralysis"]
	when :FROZEN
	  immune = true if fe[:block_status]["frozen"]
	when :DROWSY
	  immune = true if fe[:block_status]["drowsy"]
    when :FROSTBITE
	  immune = true if fe[:block_status]["frostbite"]
	end
	if immune
	  @battle.pbDisplay(_INTL("{1} is protected by the field!", pbThis)) if showMessages
	  return true
	end
  end

  alias field_effect_pbCanSleepYawn? pbCanSleepYawn?
  def pbCanSleepYawn?
    fe = FIELD_EFFECTS[@battle.field.field_effect]
	if fe[:block_status]["yawn"]
	  @battle.pbDisplay(_INTL("{1} is protected by the field!", pbThis))
      return false
	end
    return field_effect_pbCanSleepYawn?
  end

  alias field_effect_pbCanConfuse? pbCanConfuse?
  def pbCanConfuse?(user = nil, showMessages = true, move = nil, selfInflicted = false)
    fe = FIELD_EFFECTS[@battle.field.field_effect]
	if fe[:block_status]["confusion"]
	  @battle.pbDisplay(_INTL("{1} is protected by the field!", pbThis))
      return false
	end
    return field_effect_pbCanConfuse?(user, showMessages, move, selfInflicted)
  end

  if PluginManager.installed?("Deluxe Battle Kit") && !PluginManager.installed?("Demanding Yellow Custom Scripts")
    alias field_effect_pbTryUseMove dx_pbTryUseMove
  else
    alias field_effect_pbTryUseMove pbTryUseMove
  end

#===============================================================================
# Move
#===============================================================================
  def pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
    fe = FIELD_EFFECTS[@battle.field.field_effect]
	immune = false
	immune = true if fe[:block_move]["priority"] && move.priorityMove?(self)
	immune = true if fe[:block_move]["status"] && move.statusMove?
	immune = true if (fe[:block_move]["healing"] || fe[:other_effect]["no heal"]) && move.healingMove?
	immune = true if fe[:block_move]["protect"] && move.protectMove?
	if immune
	  @battle.pbDisplay(_INTL("{1} used {2}!", pbThis, move.name))
	  @battle.pbDisplay(_INTL("{1} cannot use {2} on this field!", pbThis, move.name))
	  @lastMoveFailed = true
	  return false
	end
    return field_effect_pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
  end

  if PluginManager.installed?("Deluxe Battle Kit")
    alias new_dx_pbTryUseMove pbTryUseMove
    def pbTryUseMove(*args)
      ret = new_dx_pbTryUseMove(*args)
      if ret
        move = args[1]
        triggers = ["BeforeMove", @species, move.type, move.id]
        if args[1].damagingMove?
          triggers.push("BeforeDamagingMove", @species, move.type)
          triggers.push("BeforePhysicalMove", @species, move.type) if args[1].pbPhysicalMove?
          triggers.push("BeforeSpecialMove",  @species, move.type) if args[1].pbSpecialMove?
        else
          triggers.push("BeforeStatusMove", @species, move.type)
        end
        @battle.pbDeluxeTriggers(self, args[0][3], *triggers)
      end
      return ret
    end
  end

  if PluginManager.installed?("Deluxe Battle Kit") && !PluginManager.installed?("Demanding Yellow Custom Scripts")
    alias field_effect_pbSuccessCheckAgainstTarget dx_pbSuccessCheckAgainstTarget
  else
    alias field_effect_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
  end

  def pbSuccessCheckAgainstTarget(move, user, target, targets) # may delete this later
=begin
    show_message = move.pbShowFailMessages?(targets)
    typeMod = move.pbCalcTypeMod(move.calcType, user, target)
    target.damageState.typeMod = typeMod
    fe = FIELD_EFFECTS[@battle.field.field_effect]
	immune = false
	immune = true if fe[:block_move]["priority"] && move.priorityMove?(user)
	if immune
	  @battle.pbDisplay(_INTL("{1} cannot use {2} on this field!", pbThis, move.name)) if show_message
	  return false
	end
=end
	return field_effect_pbSuccessCheckAgainstTarget(move, user, target, targets)
  end

  if PluginManager.installed?("Deluxe Battle Kit")
    alias new_dx_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
    def pbSuccessCheckAgainstTarget(move, user, target, targets)
      ret = new_dx_pbSuccessCheckAgainstTarget(move, user, target, targets)
      if !ret
        @battle.pbDeluxeTriggers(user, target.index, "UserMoveNegated", move.id, move.type, user.species)
        @battle.pbDeluxeTriggers(target, user.index, "TargetNegatedMove", move.id, move.type, target.species)
      end	  
      return ret
    end
  end

#===============================================================================
# Stat Stage
#===============================================================================
  alias field_effect_pbCanRaiseStatStage? pbCanRaiseStatStage?
  def pbCanRaiseStatStage?(stat, user = nil, move = nil, showFailMsg = false, ignoreContrary = false)
    return false if fainted?
    return pbCanLowerStatStage?(stat, user, move, showFailMsg, true) if hasActiveAbility?(:CONTRARY) && !ignoreContrary
	fe = FIELD_EFFECTS[@battle.field.field_effect]
	if fe[:other_effect]["no raise"]
      @battle.pbDisplay(_INTL("{1}'s {2} cannot be raised on this field!", pbThis, GameData::Stat.get(stat).name)) if showFailMsg
	  return false
	end
    return field_effect_pbCanRaiseStatStage?(stat, user, move, showFailMsg, ignoreContrary)
  end

  alias field_effect_pbCanLowerStatStage? pbCanLowerStatStage?
  def pbCanLowerStatStage?(stat, user = nil, move = nil, showFailMsg = false, ignoreContrary = false, ignoreMirrorArmor = false)
    return false if fainted?
    return pbCanRaiseStatStage?(stat, user, move, showFailMsg, true) if hasActiveAbility?(:CONTRARY) && !ignoreContrary
	fe = FIELD_EFFECTS[@battle.field.field_effect]
	if fe[:other_effect]["no lower"]
      @battle.pbDisplay(_INTL("{1}'s {2} cannot be lowered on this field!", pbThis, GameData::Stat.get(stat).name)) if showFailMsg
	  return false
	end
    return field_effect_pbCanLowerStatStage?(stat, user, move, showFailMsg, ignoreContrary, ignoreMirrorArmor)
  end
end