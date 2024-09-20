# These are in-battle field effects.
class Battle::ActiveField
  attr_accessor :default_field
  attr_accessor :field_effect
  attr_accessor :field_effect_duration
  attr_accessor :field_effects
  attr_accessor :field_effects_duration

  alias field_effect_initialize initialize
  def initialize
    field_effect_initialize
	@default_field = :None
	@field_effect = :None
	@field_effect_duration = 0
	@field_effects = []
	@field_effects_duration = []
	@effects[PBEffects::InverseRoom] = 0
  end
end

class Battle
  def pbSetDefaultField
	setDefaultField(:Electric) if [].include?($game_map.map_id)
	setDefaultField($field)  if $field && $field != :None
	$field = :None
  end

  def setDefaultField(value)
	@field.default_field = value
  end

  def pbStartBattleCore
    pbSetDefaultField
    # Set up the battlers on each side
    sendOuts = pbSetUpSides
    @battleAI.create_ai_objects
    # Create all the sprites and play the battle intro animation
    @scene.pbStartBattle(self)
    # Show trainers on both sides sending out Pokémon
    pbStartBattleSendOut(sendOuts)
    # Weather announcement
    weather_data = GameData::BattleWeather.try_get(@field.weather)
    pbCommonAnimation(weather_data.animation) if weather_data
	pbWeatherStartMessage
    # Terrain announcement
    terrain_data = GameData::BattleTerrain.try_get(@field.terrain)
    pbCommonAnimation(terrain_data.animation) if terrain_data
	pbTerrainStartMessage
	# Field announcement
	pbStartField(@field.default_field, -1, nil, true)
    # Abilities upon entering battle
    pbOnAllBattlersEnteringBattle
    # Main battle loop
    pbBattleLoop
  end

  def pbStartField(new_field, duration = 5, user = nil, start_battle = false)
    return if new_field == :None || duration == 0
	# Update field effect duration
    if @field.field_effect == new_field
	  if duration > 0 && @field.field_effect_duration > 0
	    @field.field_effect_duration += 1
	  else
	    @field.field_effect_duration = -1
	  end
	  @field.field_effects_duration[-1] = @field.field_effect_duration
	  pbFieldMessageStart
	  pbHideAbilitySplash(user) if user
	  return
	end
    pbEndField(true)
	# Remove the same old field
	remove_field = @field.field_effects.index(new_field)
	if remove_field
	  remove_duration = @field.field_effects_duration[remove_field]
	  if remove_duration > 0 # Do not remove infinite duration field
	    duration += remove_duration
        @field.field_effects.delete_at(remove_field)
        @field.field_effects_duration.delete_at(remove_field)
	  end
	end
	# Add field to list
	@field.field_effects.push(new_field)
	@field.field_effects_duration.push(duration)
	# Start new field
	@field.field_effect = new_field
	@field.field_effect_duration = duration
	pbFieldMessageStart
	@scene.pbSetFieldbg # if !start_battle
	pbHideAbilitySplash(user) if user
	pbFieldSetEffect_battle
	pbPriority(true).each { |battler| pbFieldSetEffect_battler(battler) if !start_battle }
  end

  def pbEOREndField
    return if @field.field_effect == :None
    pbEORFieldEffect_battle
	pbPriority(true).each { |battler| pbEORFieldEffect_battler(battler) }
	# Sync field duration
	@field.field_effects_duration[-1] = @field.field_effect_duration
	# Remove every field that duration is 0
	indices_to_remove = []
	@field.field_effects_duration.each_with_index do |duration, index|
	  next if duration == -1
	  @field.field_effects_duration[index] = duration - 1
      indices_to_remove.push(index) if duration == 1
	end
	indices_to_remove.reverse_each do |index|
	  @field.field_effects.delete_at(index)
	  @field.field_effects_duration.delete_at(index)
	end
	# Field wears off or continues
	if @field.field_effects.empty?
      pbEndField
	else
	  top_field = @field.field_effects[-1]
	  top_field_duration = @field.field_effects_duration[-1]
	  if @field.field_effect == top_field
	    @field.field_effect_duration = top_field_duration
	    pbFieldMessageContinue
	  else
	    pbStartField(top_field, top_field_duration)
	  end
	end
  end

  def pbEndField(top_switch = false)
    return if @field.field_effect == :None
    pbFieldMessageEnd
	if !top_switch
      @field.field_effect = :None
      @scene.pbSetFieldbg
	end
    pbFieldEndEffect_battle
    pbPriority(true).each { |battler| pbFieldEndEffect_battler(battler) }
  end

  def pbFieldMessageStart
    return if @field.field_effect == :None
	message = FIELD_EFFECTS[@field.field_effect][:message_start_continue_end][0]
	pbDisplay(_INTL(message)) if message && !message.empty?
  end

  def pbFieldMessageContinue
    return if @field.field_effect == :None
	message = FIELD_EFFECTS[@field.field_effect][:message_start_continue_end][1]
	duration = @field.field_effect_duration
	if message && !message.empty?
	 text = _INTL(message)
	 text = _INTL("{1}({2} more turns)", message, duration) if duration > 1
	 pbDisplay(text)
	end
  end

  def pbFieldMessageEnd
    return if @field.field_effect == :None
	message = FIELD_EFFECTS[@field.field_effect][:message_start_continue_end][2]
	pbDisplay(_INTL(message)) if message && !message.empty?
  end

#===============================================================================
# Field Effect
#===============================================================================
  def pbFieldSetEffect_battle
    return if @field.field_effect == :None
	field_effect = FIELD_EFFECTS[@field.field_effect]
#===============================================================================
	weather = field_effect[:weather_terrain_effect]["weather"][0]
	weather_duration = field_effect[:weather_terrain_effect]["weather"][1]
	weather_duration = 5 if !weather_duration
	terrain = field_effect[:weather_terrain_effect]["terrain"][0]
	terrain_duration = field_effect[:weather_terrain_effect]["terrain"][1]
	terrain_duration = 5 if !terrain_duration
	if weather && weather == :None && @field.weather != :None
	  pbDisplay(_INTL("The weather returned to normal!"))
	  weather_duration = -1
	end
	pbStartWeather(nil, weather, weather_duration) if weather
	if terrain && terrain == :None && @field.terrain != :None
	  pbDisplay(_INTL("The terrain returned to normal!"))
	  terrain_duration = -1
	end
	pbStartTerrain(nil, terrain, terrain_duration) if terrain
#===============================================================================
	field_effect[:global_field_effect].each do |key, value|
	  next if value == 0
	  value = 5 if !value
	  value = value.abs if value < 0
	  case key
	  when "Fairy Lock"
	    @field.effects[PBEffects::FairyLock] = value
	    pbDisplay(_INTL("No one will be able to run away!"))
	  when "Gravity"
	    @field.effects[PBEffects::Gravity] = value
	    pbDisplay(_INTL("Gravity intensified!"))
	  when "Inverse Room"
	    @field.effects[PBEffects::InverseRoom] = value
	    pbDisplay(_INTL("The type matchup has been twisted!"))
	  when "Magic Room"
	    @field.effects[PBEffects::MagicRoom] = value
	    pbDisplay(_INTL("It created a bizarre area in which Pokémon's held items lose their effects!"))
	  when "Trick Room"
	    @field.effects[PBEffects::TrickRoom] = value
	    pbDisplay(_INTL("The dimensions have been twisted!"))
	  when "Wonder Room"
	    @field.effects[PBEffects::WonderRoom] = value
	    pbDisplay(_INTL("It created a bizarre area in which the Defense and Sp. Def stats are swapped!"))
	  end
	end
	pbDisplay(_INTL("The type matchup has been twisted!")) if field_effect[:other_effect]["inverse battle"]
	pbDisplay(_INTL("No one will be able to run away!")) if field_effect[:other_effect]["no switch"]
  end

  def pbFieldSetEffect_battler(battler)
    return if @field.field_effect == :None
    return if battler.fainted?
    return if battler.set_effect_triggered
	battler.set_effect_triggered = true # only trigger once
	field_effect = FIELD_EFFECTS[@field.field_effect]
#===============================================================================
	display_type_message = false
	field_effect[:battler_type_change].each do |key, value|
	  if key.is_a?(TrueClass)
		battler.pbAddThirdType(value[2]) if value[2]
		battler.pbChangeSecondType(value[1]) if value[1]
		battler.pbChangeFirstType(value[0]) if value[0]
		display_type_message = true if value[0] || value[1] || value[2]
		break
	  elsif key.is_a?(Array)
	    key.each do |k|
	      change = false
		  change = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
		  change = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
		  change = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
		  change = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
		  if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		    k = :POISON if k == :TOXIC
		    change = true if battler.pbHasStatus?(k)
		  end
		  if change
		    battler.pbAddThirdType(value[2]) if value[2]
		    battler.pbChangeSecondType(value[1]) if value[1]
		    battler.pbChangeFirstType(value[0]) if value[0]
		    display_type_message = true if value[0]
		  end
		end
	  end
	end
	pbDisplay(_INTL("{1}'s type has been changed!", battler.pbThis)) if display_type_message
#===============================================================================
	display_ability_message = false
	field_effect[:battler_ability_change].each do |key, value|
	  key.each do |k|
	    change = false
		change = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
		change = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
		change = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
		change = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
		if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		  k = :POISON if k == :TOXIC
		  change = true if battler.pbHasStatus?(k)
		end
		if change
		  abiliy_change = false
		  if PluginManager.installed?("Demanding Yellow Custom Scripts")
		    if !battler.ability_list.include?(value)
			  battler.ability_list.push(value)
			  abiliy_change = true
			end
		  else
		    if battler.ability_id != value
			  battler.ability_id = value
			  abiliy_change = true
			end
		  end
		  display_ability_message = true if abiliy_change
		end
	  end
	end
#===============================================================================
	field_effect[:battler_ability_add].each do |key, value|
	  key.each do |k|
	    change = false
		change = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
		change = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
		change = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
		change = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
		if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		  k = :POISON if k == :TOXIC
		  change = true if battler.pbHasStatus?(k)
		end
		if change && value.any?
		  if PluginManager.installed?("Demanding Yellow Custom Scripts")
		    value.each { |v| battler.ability_list.push(v) }
			battler.ability_list = battler.ability_list.uniq
		  elsif PluginManager.installed?("Innate Abilities") || PluginManager.installed?("Infinite Ability") || PluginManager.installed?("All Abilities Mutation")
		    value.each { |v| battler.abilityMutationList.push(v) }
			battler.abilityMutationList = battler.abilityMutationList.uniq
		  end
		  display_ability_message = true
		end
	  end
	end
	pbDisplay(_INTL("{1}'s ability has been changed!", battler.pbThis)) if display_ability_message
#===============================================================================
	status = field_effect[:battler_start_switch_status][0]
	chance = field_effect[:battler_start_switch_status][1]["chance"]
	chance = 100 if !chance
	if status && (GameData::Status.exists?(status) || !GameData::Status.exists?(status) && status == :TOXIC) && pbRandom(100) < chance
	  battler.pbSleep if battler.pbCanSleep?(nil, false) && status == :SLEEP
	  if field_effect[:battler_start_switch_status][2]["badly poisoned"]
	    battler.pbPoison(nil, nil, true) if battler.pbCanPoison?(nil, false) && [:POISON, :TOXIC].include?(status)
	  else
		battler.pbPoison if battler.pbCanPoison?(nil, false) && [:POISON, :TOXIC].include?(status)
	  end
	  battler.pbBurn if battler.pbCanBurn?(nil, false) && status == :BURN
	  battler.pbParalyze if battler.pbCanParalyze?(nil, false) && status == :PARALYSIS
	  battler.pbFreeze if battler.pbCanFreeze?(nil, false) && status == :FROZEN
	  battler.pbDrowse if battler.pbCanDrowse?(nil, false) && status == :DROWSY
	  battler.pbFrostbite if battler.pbCanFrostbite?(nil, false) && status == :FROSTBITE
	end
#===============================================================================
	field_effect[:battler_start_switch_hp].each do |key, value|
	  hp_lost = value["hp lost"]
	  hp_gain = value["hp gain"]
	  lost_amt = [(battler.totalhp * hp_lost).round, 1].max if hp_lost
	  gain_amt = [(battler.totalhp * hp_gain).round, 1].max if hp_gain
	  if key.is_a?(TrueClass)
	    if hp_lost
	      battler.pbReduceHP(lost_amt)
		  pbDisplay(_INTL("{1} was damaged by the field!", battler.pbThis))
		  battler.pbItemHPHealCheck
		  battler.pbFaint if battler.fainted?
		end
		if hp_gain && battler.canHeal?
	      battler.pbRecoverHP(gain_amt)
		  pbDisplay(_INTL("{1} was healed by the field!", battler.pbThis))
		end
		break
	  elsif key.is_a?(Array)
	    key.each do |k|
	      if hp_lost
		    lost = false
		    lost = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
		    lost = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
		    lost = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
		    lost = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
		    if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		      k = :POISON if k == :TOXIC
		      lost = true if battler.pbHasStatus?(k)
		    end
			if lost
		      battler.pbReduceHP(lost_amt)
			  pbDisplay(_INTL("{1} was damaged by the field!", battler.pbThis))
			  battler.pbItemHPHealCheck
			  battler.pbFaint if battler.fainted?
			end
	      end
	      if hp_gain && battler.canHeal?
		    gain = false
		    gain = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
		    gain = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
		    gain = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
		    gain = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
		    if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		      k = :POISON if k == :TOXIC
		      gain = true if battler.pbHasStatus?(k)
		    end
			if gain
		     battler.pbRecoverHP(gain_amt)
			 pbDisplay(_INTL("{1} was healed by the field!", battler.pbThis))
			end
		  end
	    end
	  end
	end
#===============================================================================
	field_effect[:battler_start_switch_buff].each do |key, value|
	  key.each do |k|
	    change = false
	    change = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
	    change = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
	    change = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
	    change = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
	    if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
	      k = :POISON if k == :TOXIC
	      change = true if battler.pbHasStatus?(k)
	    end
	    if change
		  value.each do |k, v|
		    if v > 0 && battler.pbCanRaiseStatStage?(k, battler)
		      battler.pbRaiseStatStage(k, v, battler)
		    elsif v < 0 && battler.pbCanLowerStatStage?(k, battler)
		      battler.pbLowerStatStage(k, v.abs, battler)
		    end
	      end
	    end
	  end
	end
#===============================================================================
	cure = false
	case battler.status
	when :SLEEP
	  cure = true if field_effect[:battler_start_switch_cure]["sleep"]
    when :POISON
      cure = true if field_effect[:battler_start_switch_cure]["toxic"]
	when :BURN
      cure = true if field_effect[:battler_start_switch_cure]["burn"]
	when :PARALYSIS
      cure = true if field_effect[:battler_start_switch_cure]["paralysis"]
	when :FROZEN
	  cure = true if field_effect[:battler_start_switch_cure]["frozen"]
	when :DROWSY
	  cure = true if field_effect[:battler_start_switch_cure]["drowsy"]
    when :FROSTBITE
	  cure = true if field_effect[:battler_start_switch_cure]["frostbite"]
	end
	if cure
	  battler.pbCureStatus(true)
	end
  end

  def pbEORFieldEffect_battle
    return if @field.field_effect == :None
  end

  def pbEORFieldEffect_battler(battler)
    return if @field.field_effect == :None
    return if battler.fainted?
	field_effect = FIELD_EFFECTS[@field.field_effect]
#===============================================================================
	status = field_effect[:EOR_effect_status][0]
	chance = field_effect[:EOR_effect_status][1]["chance"]
	chance = 100 if !chance
	if status && (GameData::Status.exists?(status) || !GameData::Status.exists?(status) && status == :TOXIC) && pbRandom(100) < chance
	  battler.pbSleep if battler.pbCanSleep?(nil, false) && status == :SLEEP
	  if field_effect[:EOR_effect_status][2]["badly poisoned"]
	    battler.pbPoison(nil, nil, true) if battler.pbCanPoison?(nil, false) && [:POISON, :TOXIC].include?(status)
	  else
		battler.pbPoison if battler.pbCanPoison?(nil, false) && [:POISON, :TOXIC].include?(status)
	  end
	  battler.pbBurn if battler.pbCanBurn?(nil, false) && status == :BURN
	  battler.pbParalyze if battler.pbCanParalyze?(nil, false) && status == :PARALYSIS
	  battler.pbFreeze if battler.pbCanFreeze?(nil, false) && status == :FROZEN
	  battler.pbDrowse if battler.pbCanDrowse?(nil, false) && status == :DROWSY
	  battler.pbFrostbite if battler.pbCanFrostbite?(nil, false) && status == :FROSTBITE
	end
#===============================================================================
	field_effect[:EOR_effect_hp].each do |key, value| # The same as :battler_start_switch_hp, maybe could def a method
	  hp_lost = value["hp lost"]
	  hp_gain = value["hp gain"]
	  lost_amt = [(battler.totalhp * hp_lost).round, 1].max if hp_lost
	  gain_amt = [(battler.totalhp * hp_gain).round, 1].max if hp_gain
	  if key.is_a?(TrueClass)
	    if hp_lost
	      battler.pbReduceHP(lost_amt)
		  pbDisplay(_INTL("{1} was damaged by the field!", battler.pbThis))
		  battler.pbItemHPHealCheck
		  battler.pbFaint if battler.fainted?
		end
		if hp_gain && battler.canHeal?
	      battler.pbRecoverHP(gain_amt)
		  pbDisplay(_INTL("{1} was healed by the field!", battler.pbThis))
		end
		break
	  elsif key.is_a?(Array)
	    key.each do |k|
	      if hp_lost
		    lost = false
		    lost = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
		    lost = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
		    lost = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
		    lost = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
		    if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		      k = :POISON if k == :TOXIC
		      lost = true if battler.pbHasStatus?(k)
		    end
			if lost
		      battler.pbReduceHP(lost_amt)
			  pbDisplay(_INTL("{1} was damaged by the field!", battler.pbThis))
			  battler.pbItemHPHealCheck
			  battler.pbFaint if battler.fainted?
			end
	      end
	      if hp_gain && battler.canHeal?
		    gain = false
		    gain = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
		    gain = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
		    gain = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
		    gain = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
		    if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
		      k = :POISON if k == :TOXIC
		      gain = true if battler.pbHasStatus?(k)
		    end
			if gain
		     battler.pbRecoverHP(gain_amt)
			 pbDisplay(_INTL("{1} was healed by the field!", battler.pbThis))
			end
		  end
	    end
	  end
	end
#===============================================================================
	field_effect[:EOR_effect_buff].each do |key, value| # The same as :battler_start_switch_buff, maybe could def a method
	  key.each do |k|
	    change = false
	    change = true if GameData::Species.exists?(k) && battler.isSpecies?(k)
	    change = true if GameData::Type.exists?(k) && battler.pbHasType?(k)
	    change = true if GameData::Ability.exists?(k) && battler.hasActiveAbility?(k)
	    change = true if GameData::Item.exists?(k) && battler.hasActiveItem?(k)
	    if GameData::Status.exists?(k) && k != :POISON || !GameData::Status.exists?(k) && k == :TOXIC
	      k = :POISON if k == :TOXIC
	      change = true if battler.pbHasStatus?(k)
	    end
	    if change
		  value.each do |k, v|
		    if v > 0 && battler.pbCanRaiseStatStage?(k, battler)
		      battler.pbRaiseStatStage(k, v, battler)
		    elsif v < 0 && battler.pbCanLowerStatStage?(k, battler)
		      battler.pbLowerStatStage(k, v.abs, battler)
		    end
	      end
	    end
	  end
	end
  end

  def pbFieldEndEffect_battle
    return if @field.field_effect == :None
  end

  def pbFieldEndEffect_battler(battler)
    return if @field.field_effect == :None
    return if battler.fainted?
  end
end

class Battle::Move
  def pbCalcType_field_effect(user, ret)
    return ret if @battle.field.field_effect == :None
	field_effect = FIELD_EFFECTS[@battle.field.field_effect]
#===============================================================================
	field_effect[:move_type_change].each do |key, value|
	  ret = value if key.any? && key.include?(@id)
	  break
	end
	field_effect[:move_type_change_type].each do |key, value|
	  ret = value if key.any? && key.include?(ret)
	  break
	end
	field_effect[:move_type_change_subtype].each do |key, value|
	  key.each do |k|
	    case k
	    when "damaging"
		  ret = value if pbDamagingMove?
	    when "physical"
		  ret = value if pbPhysicalMove?
	    when "special"
		  ret = value if pbSpecialMove?
		when "status"
		  ret = value if pbStatusMove?
	    when "priority"
		  ret = value if priorityMove?(user)
	    when "contact"
		  ret = value if contactMove?
		when "noncontact"
		  ret = value if !contactMove?
		when "protect"
		  ret = value if protectMove?
		when "air"
		  ret = value if airMove?
		when "ball"
		  ret = value if ballMove?
		when "beam"
		  ret = value if beamMove?
		when "biting"
		  ret = value if bitingMove?
		when "bomb"
		  ret = value if bombMove?
		when "bone"
		  ret = value if boneMove?
		when "charging"
		  ret = value if chargingMove?
		when "dance"
		  ret = value if danceMove?
		when "drain"
		  ret = value if drainMove?
		when "drill"
		  ret = value if drillMove?
		when "explosion"
		  ret = value if explosionMove?
		when "field"
		  ret = value if fieldMove?
		when "flinching"
		  ret = value if flinchingMove?
		when "head"
		  ret = value if headMove?
		when "healing"
		  ret = value if healingMove?
		when "horn"
		  ret = value if hornMove?
		when "kicking"
		  ret = value if kickingMove?
		when "multihit"
		  ret = value if multihitMove?
		when "powder"
		  ret = value if powderMove?
		when "pulse"
		  ret = value if pulseMove?
		when "punching"
		  ret = value if punchingMove?
		when "rampage"
		  ret = value if rampageMove?
		when "recharging"
		  ret = value if rechargingMove?
		when "recoil"
		  ret = value if recoilMove?
		when "slicing"
		  ret = value if slicingMove?
		when "sound"
		  ret = value if soundMove?
		when "trapping"
		  ret = value if trappingMove?
		when "weather"
		  ret = value if weatherMove?
		when "wind"
		  ret = value if windMove?
		when "wing"
		  ret = value if wingMove?
	    end
	    break
	  end
	end
#===============================================================================
	type = field_effect[:hidden_power_type]
	ret = type if type && [:HIDDENPOWER].include?(@id)
	#puts ret
	return ret
  end

  def pbCalcTypeModSingle_field_effect(moveType, defType, user, target, ret)
    return ret if @battle.field.field_effect == :None
	field_effect = FIELD_EFFECTS[@battle.field.field_effect]
#===============================================================================
	field_effect[:move_type_add].each do |key, value|
	  ret *= Effectiveness.calculate(value, defType) if key.any? && key.include?(@id)
	  break
	end
	field_effect[:move_type_add_type].each do |key, value|
	  ret *= Effectiveness.calculate(value, defType) if key.any? && key.include?(moveType)
	  break
	end
	field_effect[:move_type_add_subtype].each do |key, value|
	  key.each do |k|
	    case k
	    when "damaging"
		  ret *= Effectiveness.calculate(value, defType) if pbDamagingMove?
	    when "physical"
		  ret *= Effectiveness.calculate(value, defType) if pbPhysicalMove?
	    when "special"
		  ret *= Effectiveness.calculate(value, defType) if pbSpecialMove?
		when "status"
	    when "priority"
		  ret *= Effectiveness.calculate(value, defType) if priorityMove?(user)
	    when "contact"
		  ret *= Effectiveness.calculate(value, defType) if contactMove?
		when "noncontact"
		  ret *= Effectiveness.calculate(value, defType) if !contactMove?
		when "protect"
		when "air"
		  ret *= Effectiveness.calculate(value, defType) if airMove?
		when "ball"
		  ret *= Effectiveness.calculate(value, defType) if ballMove?
		when "beam"
		  ret *= Effectiveness.calculate(value, defType) if beamMove?
		when "biting"
		  ret *= Effectiveness.calculate(value, defType) if bitingMove?
		when "bomb"
		  ret *= Effectiveness.calculate(value, defType) if bombMove?
		when "bone"
		  ret *= Effectiveness.calculate(value, defType) if boneMove?
		when "charging"
		  ret *= Effectiveness.calculate(value, defType) if chargingMove?
		when "dance"
		  ret *= Effectiveness.calculate(value, defType) if danceMove?
		when "drain"
		  ret *= Effectiveness.calculate(value, defType) if drainMove?
		when "drill"
		  ret *= Effectiveness.calculate(value, defType) if drillMove?
		when "explosion"
		  ret *= Effectiveness.calculate(value, defType) if explosionMove?
		when "field"
		  ret *= Effectiveness.calculate(value, defType) if fieldMove?
		when "flinching"
		  ret *= Effectiveness.calculate(value, defType) if flinchingMove?
		when "head"
		  ret *= Effectiveness.calculate(value, defType) if headMove?
		when "healing"
		  ret *= Effectiveness.calculate(value, defType) if healingMove?
		when "horn"
		  ret *= Effectiveness.calculate(value, defType) if hornMove?
		when "kicking"
		  ret *= Effectiveness.calculate(value, defType) if kickingMove?
		when "multihit"
		  ret *= Effectiveness.calculate(value, defType) if multihitMove?
		when "powder"
		  ret *= Effectiveness.calculate(value, defType) if powderMove?
		when "pulse"
		  ret *= Effectiveness.calculate(value, defType) if pulseMove?
		when "punching"
		  ret *= Effectiveness.calculate(value, defType) if punchingMove?
		when "rampage"
		  ret *= Effectiveness.calculate(value, defType) if rampageMove?
		when "recharging"
		  ret *= Effectiveness.calculate(value, defType) if rechargingMove?
		when "recoil"
		  ret *= Effectiveness.calculate(value, defType) if recoilMove?
		when "slicing"
		  ret *= Effectiveness.calculate(value, defType) if slicingMove?
		when "sound"
		  ret *= Effectiveness.calculate(value, defType) if soundMove?
		when "trapping"
		  ret *= Effectiveness.calculate(value, defType) if trappingMove?
		when "weather"
		  ret *= Effectiveness.calculate(value, defType) if weatherMove?
		when "wind"
		  ret *= Effectiveness.calculate(value, defType) if windMove?
		when "wing"
		  ret *= Effectiveness.calculate(value, defType) if wingMove?
	    end
	    break
	  end
	end
#===============================================================================
	if field_effect[:other_effect]["inverse battle"] || @battle.field.effects[PBEffects::InverseRoom] > 0
	  if ret >= Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
	    ret = Effectiveness::NOT_VERY_EFFECTIVE_MULTIPLIER
	  elsif ret <= Effectiveness::NOT_VERY_EFFECTIVE_MULTIPLIER
	    ret = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
	  end
	end
	return ret
  end

  def pbPriority_field_effect(user, ret)
    return ret if @battle.field.field_effect == :None
	field_effect = FIELD_EFFECTS[@battle.field.field_effect]
	field_effect[:move_priority].each do |key, value|
	  ret += value if key.any? && key.include?(@id)
	  break
	end
	field_effect[:move_priority_type].each do |key, value|
	  ret += value if key.any? && key.include?(@calcType)
	  break
	end
	field_effect[:move_priority_subtype].each do |key, value|
	  key.each do |k|
	    case k
	    when "damaging"
		  ret += value if pbDamagingMove?
	    when "physical"
		  ret += value if pbPhysicalMove?
	    when "special"
		  ret += value if pbSpecialMove?
		when "status"
		  ret += value if pbStatusMove?
	    when "priority"
		  ret += value if priorityMove?(user)
	    when "contact"
		  ret += value if contactMove?
		when "noncontact"
		  ret += value if !contactMove?
		when "protect"
		  ret += value if protectMove?
		when "air"
		  ret += value if airMove?
		when "ball"
		  ret += value if ballMove?
		when "beam"
		  ret += value if beamMove?
		when "biting"
		  ret += value if bitingMove?
		when "bomb"
		  ret += value if bombMove?
		when "bone"
		  ret += value if boneMove?
		when "charging"
		  ret += value if chargingMove?
		when "dance"
		  ret += value if danceMove?
		when "drain"
		  ret += value if drainMove?
		when "drill"
		  ret += value if drillMove?
		when "explosion"
		  ret += value if explosionMove?
		when "field"
		  ret += value if fieldMove?
		when "flinching"
		  ret += value if flinchingMove?
		when "head"
		  ret += value if headMove?
		when "healing"
		  ret += value if healingMove?
		when "horn"
		  ret += value if hornMove?
		when "kicking"
		  ret += value if kickingMove?
		when "multihit"
		  ret += value if multihitMove?
		when "powder"
		  ret += value if powderMove?
		when "pulse"
		  ret += value if pulseMove?
		when "punching"
		  ret += value if punchingMove?
		when "rampage"
		  ret += value if rampageMove?
		when "recharging"
		  ret += value if rechargingMove?
		when "recoil"
		  ret += value if recoilMove?
		when "slicing"
		  ret += value if slicingMove?
		when "sound"
		  ret += value if soundMove?
		when "trapping"
		  ret += value if trappingMove?
		when "weather"
		  ret += value if weatherMove?
		when "wind"
		  ret += value if windMove?
		when "wing"
		  ret += value if wingMove?
	    end
	    break
	  end
	end
	#puts ret
    return ret
  end

  def pbCalcAccuracyModifiers_field_effect(user, target, modifiers)
    return if @battle.field.field_effect == :None
  	field_effect = FIELD_EFFECTS[@battle.field.field_effect]
	field_effect[:move_accuracy].each do |key, value|
	  pbCalcFieldModifiers_accuracy(modifiers, value) if key.include?(@id)
	  break
	end
	field_effect[:move_accuracy_type].each do |key, value|
	  pbCalcFieldModifiers_accuracy(modifiers, value) if key.include?(@calcType)
	  break
	end
	field_effect[:move_accuracy_subtype].each do |key, value|
	  key.each do |k|
	    case k
	    when "damaging"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if pbDamagingMove?
	    when "physical"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if pbPhysicalMove?
	    when "special"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if pbSpecialMove?
		when "status"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if pbStatusMove?
	    when "priority"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if priorityMove?(user)
	    when "contact"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if contactMove?
		when "noncontact"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if !contactMove?
		when "protect"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if protectMove?
		when "air"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if airMove?
		when "ball"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if ballMove?
		when "beam"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if beamMove?
		when "biting"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if bitingMove?
		when "bomb"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if bombMove?
		when "bone"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if boneMove?
		when "charging"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if chargingMove?
		when "dance"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if danceMove?
		when "drain"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if drainMove?
		when "drill"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if drillMove?
		when "explosion"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if explosionMove?
		when "field"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if fieldMove?
		when "flinching"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if flinchingMove?
		when "head"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if headMove?
		when "healing"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if healingMove?
		when "horn"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if hornMove?
		when "kicking"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if kickingMove?
		when "multihit"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if multihitMove?
		when "powder"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if powderMove?
		when "pulse"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if pulseMove?
		when "punching"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if punchingMove?
		when "rampage"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if rampageMove?
		when "recharging"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if rechargingMove?
		when "recoil"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if recoilMove?
		when "slicing"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if slicingMove?
		when "sound"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if soundMove?
		when "trapping"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if trappingMove?
		when "weather"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if weatherMove?
		when "wind"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if windMove?
		when "wing"
		  pbCalcFieldModifiers_accuracy(modifiers, value) if wingMove?
	    end
	    break
	  end
	end
	#puts modifiers
  end

  def pbCalcDamageMults_field_effect(user, target, numTargets, type, baseDmg, multipliers)
    return if @battle.field.field_effect == :None
	field_effect = FIELD_EFFECTS[@battle.field.field_effect]
#===============================================================================
	field_effect[:user_target_boost].each do |key, value|
	  if !key[0] && key[1] && GameData::Species.exists?(key[1]) # nil Species
	    pbCalcFieldMultipliers_damage(multipliers, value) if target.isSpecies?(key[1])
	  elsif !key[0] && key[1] && GameData::Type.exists?(key[1]) # nil Type
	    pbCalcFieldMultipliers_damage(multipliers, value) if target.pbHasType?(key[1])
	  elsif !key[0] && key[1] && GameData::Ability.exists?(key[1]) # nil Ability
	    pbCalcFieldMultipliers_damage(multipliers, value) if target.hasActiveAbility?(key[1])
	  elsif !key[0] && key[1] && GameData::Item.exists?(key[1]) # nil Item
	    pbCalcFieldMultipliers_damage(multipliers, value) if target.hasActiveItem?(key[1])
	  elsif !key[0] && key[1] && (GameData::Status.exists?(key[1]) && key[1] != :POISON || !GameData::Status.exists?(key[1]) && key[1] == :TOXIC) # nil Status
	    key[1] = :POISON if key[1] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if target.pbHasStatus?(key[1])
	  elsif key[0] && !key[1] && GameData::Species.exists?(key[0]) # Species nil
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.isSpecies?(key[0])
	  elsif key[0] && !key[1] && GameData::Type.exists?(key[0]) # Type nil
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasType?(key[0])
	  elsif key[0] && !key[1] && GameData::Ability.exists?(key[0]) # Ability nil
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveAbility?(key[0])
	  elsif key[0] && !key[1] && GameData::Item.exists?(key[0]) # Item nil
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveItem?(key[0])
	  elsif key[0] && !key[1] && (GameData::Status.exists?(key[0]) && key[0] != :POISON || !GameData::Status.exists?(key[0]) && key[0] == :TOXIC) # Status nil
	    key[0] = :POISON if key[0] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasStatus?(key[0])
	  elsif key[0] && key[1] && GameData::Species.exists?(key[0]) && GameData::Species.exists?(key[1]) # Species Species
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.isSpecies?(key[0]) && target.isSpecies?(key[1])
	  elsif key[0] && key[1] && GameData::Species.exists?(key[0]) && GameData::Type.exists?(key[1]) # Species Type
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.isSpecies?(key[0]) && target.pbHasType?(key[1])
	  elsif key[0] && key[1] && GameData::Species.exists?(key[0]) && GameData::Ability.exists?(key[1]) # Species Ability
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.isSpecies?(key[0]) && target.hasActiveAbility?(key[1])
	  elsif key[0] && key[1] && GameData::Species.exists?(key[0]) && GameData::Item.exists?(key[1]) # Species Item
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.isSpecies?(key[0]) && target.hasActiveItem?(key[1])
	  elsif key[0] && key[1] && GameData::Species.exists?(key[0]) && (GameData::Status.exists?(key[1]) && key[1] != :POISON || !GameData::Status.exists?(key[1]) && key[1] == :TOXIC) # Species Status
	    key[1] = :POISON if key[1] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.isSpecies?(key[0]) && target.pbHasStatus?(key[1])
	  elsif key[0] && key[1] && GameData::Type.exists?(key[0]) && GameData::Species.exists?(key[1]) # Type Species
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasType?(key[0]) && target.isSpecies?(key[1])
	  elsif key[0] && key[1] && GameData::Type.exists?(key[0]) && GameData::Type.exists?(key[1]) # Type Type
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasType?(key[0]) && target.pbHasType?(key[1])
	  elsif key[0] && key[1] && GameData::Type.exists?(key[0]) && GameData::Ability.exists?(key[1]) # Type Ability
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasType?(key[0]) && target.hasActiveAbility?(key[1])
	  elsif key[0] && key[1] && GameData::Type.exists?(key[0]) && GameData::Item.exists?(key[1]) # Type Item
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasType?(key[0]) && target.hasActiveItem?(key[1])
	  elsif key[0] && key[1] && GameData::Type.exists?(key[0]) && (GameData::Status.exists?(key[1]) && key[1] != :POISON || !GameData::Status.exists?(key[1]) && key[1] == :TOXIC) # Type Status
	    key[1] = :POISON if key[1] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasType?(key[0]) && target.pbHasStatus?(key[1])
	  elsif key[0] && key[1] && GameData::Ability.exists?(key[0]) && GameData::Species.exists?(key[1]) # Ability Species
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveAbility?(key[0]) && target.isSpecies?(key[1])
	  elsif key[0] && key[1] && GameData::Ability.exists?(key[0]) && GameData::Type.exists?(key[1]) # Ability Type
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveAbility?(key[0]) && target.pbHasType?(key[1])
	  elsif key[0] && key[1] && GameData::Ability.exists?(key[0]) && GameData::Ability.exists?(key[1]) # Ability Ability
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveAbility?(key[0]) && target.hasActiveAbility?(key[1])
	  elsif key[0] && key[1] && GameData::Ability.exists?(key[0]) && GameData::Item.exists?(key[1]) # Ability Item
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveAbility?(key[0]) && target.hasActiveItem?(key[1])
	  elsif key[0] && key[1] && GameData::Ability.exists?(key[0]) && (GameData::Status.exists?(key[1]) && key[1] != :POISON || !GameData::Status.exists?(key[1]) && key[1] == :TOXIC) # Ability Status
	    key[1] = :POISON if key[1] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveAbility?(key[0]) && target.pbHasStatus?(key[1])
	  elsif key[0] && key[1] && GameData::Item.exists?(key[0]) && GameData::Species.exists?(key[1]) # Item Species
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveItem?(key[0]) && target.isSpecies?(key[1])
	  elsif key[0] && key[1] && GameData::Item.exists?(key[0]) && GameData::Type.exists?(key[1]) # Item Type
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveItem?(key[0]) && target.pbHasType?(key[1])
	  elsif key[0] && key[1] && GameData::Item.exists?(key[0]) && GameData::Ability.exists?(key[1]) # Item Ability
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveItem?(key[0]) && target.hasActiveAbility?(key[1])
	  elsif key[0] && key[1] && GameData::Item.exists?(key[0]) && GameData::Item.exists?(key[1]) # Item Item
	    pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveItem?(key[0]) && target.hasActiveItem?(key[1])
	  elsif key[0] && key[1] && GameData::Item.exists?(key[0]) && (GameData::Status.exists?(key[1]) && key[1] != :POISON || !GameData::Status.exists?(key[1]) && key[1] == :TOXIC) # Item Status
	    key[1] = :POISON if key[1] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.hasActiveItem?(key[0]) && target.pbHasStatus?(key[1])
	  elsif key[0] && key[1] && (GameData::Status.exists?(key[0]) && key[0] != :POISON || !GameData::Status.exists?(key[0]) && key[0] == :TOXIC) && GameData::Species.exists?(key[1]) # Status Species
	     key[0] = :POISON if key[0] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasStatus?(key[0]) && target.isSpecies?(key[1])
	  elsif key[0] && key[1] && (GameData::Status.exists?(key[0]) && key[0] != :POISON || !GameData::Status.exists?(key[0]) && key[0] == :TOXIC) && GameData::Type.exists?(key[1]) # Status Type
	     key[0] = :POISON if key[0] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasStatus?(key[0]) && target.pbHasType?(key[1])
	  elsif key[0] && key[1] && (GameData::Status.exists?(key[0]) && key[0] != :POISON || !GameData::Status.exists?(key[0]) && key[0] == :TOXIC) && GameData::Ability.exists?(key[1]) # Status Ability
	     key[0] = :POISON if key[0] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasStatus?(key[0]) && target.hasActiveAbility?(key[1])
	  elsif key[0] && key[1] && (GameData::Status.exists?(key[0]) && key[0] != :POISON || !GameData::Status.exists?(key[0]) && key[0] == :TOXIC) && GameData::Item.exists?(key[1]) # Status Item
	     key[0] = :POISON if key[0] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasStatus?(key[0]) && target.hasActiveItem?(key[1])
	  elsif key[0] && key[1] && (GameData::Status.exists?(key[0]) && key[0] != :POISON || !GameData::Status.exists?(key[0]) && key[0] == :TOXIC) && (GameData::Status.exists?(key[1]) && key[1] != :POISON || !GameData::Status.exists?(key[1]) && key[1] == :TOXIC) # Status Status
		key[0] = :POISON if key[0] == :TOXIC
		key[1] = :POISON if key[1] == :TOXIC
		pbCalcFieldMultipliers_damage(multipliers, value) if user.pbHasStatus?(key[0]) && target.pbHasStatus?(key[1])
	  end
	end
#===============================================================================
	message = false
	field_effect[:move_boost].each do |key, value|
	  if key.include?(@id)
	    pbCalcFieldMultipliers_damage(multipliers, value)
		message = true
	  end
	end
#===============================================================================
	field_effect[:move_boost_type].each do |key, value|
	  if key.include?(@calcType)
	    pbCalcFieldMultipliers_damage(multipliers, value)
		message = true
	  end
	end
#===============================================================================
	field_effect[:move_boost_subtype].each do |key, value|
	  key.each do |k|
	    case k
	    when "damaging"
		  if pbDamagingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
	    when "physical"
		  if pbPhysicalMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
	    when "special"
		  if pbSpecialMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "status"
	    when "priority"
		  if pbDamagingMove? && priorityMove?(user)
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
	    when "contact"
		  if pbDamagingMove? && contactMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "noncontact"
		  if pbDamagingMove? && !contactMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "protect"
		when "air"
		  if airMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "ball"
		  if ballMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "beam"
		  if beamMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "biting"
		  if bitingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "bomb"
		  if bombMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "bone"
		  if boneMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "charging"
		  if chargingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "dance"
		  if danceMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "drain"
		  if drainMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "drill"
		  if drillMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "explosion"
		  if explosionMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "field"
		  if fieldMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "flinching"
		  if flinchingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "head"
		  if headMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "healing"
		  if healingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "horn"
		  if hornMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "kicking"
		  if kickingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "multihit"
		  if multihitMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "powder"
		  if powderMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "pulse"
		  if pulseMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "punching"
		  if punchingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "rampage"
		  if rampageMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "recharging"
		  if rechargingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "recoil"
		  if recoilMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "slicing"
		  if slicingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "sound"
		  if soundMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "trapping"
		  if trappingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "weather"
		  if weatherMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "wind"
		  if windMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
		when "wing"
		  if wingMove?
	        pbCalcFieldMultipliers_damage(multipliers, value)
			message = true
		  end
	    end
	  end
	end
#===============================================================================
	if message
	  field_effect[:move_boost_message].each do |key, value|
	    value.each do |v|
		  if GameData::Move.exists?(v) && v == @id 
		    @battle.pbDisplay(_INTL(key))
		    break
		  elsif GameData::Type.exists?(v) && v == @calcType
		    @battle.pbDisplay(_INTL(key))
		    break
		  elsif v.is_a?(String)
		    display_message = false
		    case v
			when "damaging"
			  display_message = true if pbDamagingMove?
			when "physical"
			  display_message = true if pbPhysicalMove?
			when "special"
			  display_message = true if pbSpecialMove?
			when "status"
			when "priority"
			  display_message = true if pbDamagingMove? && priorityMove?(user)
			when "contact"
			  display_message = true if pbDamagingMove? && contactMove?
			when "noncontact"
			  display_message = true if pbDamagingMove? && !contactMove?
			when "protect"
			when "air"
			  display_message = true if airMove?
			when "ball"
			  display_message = true if ballMove?
			when "beam"
			  display_message = true if beamMove?
			when "biting"
			  display_message = true if bitingMove?
			when "bomb"
			  display_message = true if bombMove?
			when "bone"
			  display_message = true if boneMove?
			when "charging"
			  display_message = true if chargingMove?
			when "dance"
			  display_message = true if danceMove?
			when "drain"
			  display_message = true if drainMove?
			when "drill"
			  display_message = true if drillMove?
			when "explosion"
			  display_message = true if explosionMove?
			when "field"
			  display_message = true if fieldMove?
			when "flinching"
			  display_message = true if flinchingMove?
			when "head"
			  display_message = true if headMove?
			when "healing"
			  display_message = true if healingMove?
			when "horn"
			  display_message = true if hornMove?
			when "kicking"
			  display_message = true if kickingMove?
			when "multihit"
			  display_message = true if multiHitMove?
			when "powder"
			  display_message = true if powderMove?
			when "pulse"
			  display_message = true if pulseMove?
			when "punching"
			  display_message = true if punchingMove?
			when "rampage"
			  display_message = true if rampageMove?
			when "recharging"
			  display_message = true if rechargingMove?
			when "recoil"
			  display_message = true if recoilMove?
			when "slicing"
			  display_message = true if slicingMove?
			when "sound"
			  display_message = true if soundMove?
			when "trapping"
			  display_message = true if trappingMove?
			when "weather"
			  display_message = true if weatherMove?
			when "wind"
			  display_message = true if windMove?
			when "wing"
			  display_message = true if wingMove?
			end
		    @battle.pbDisplay(_INTL(key)) if display_message
		    break
		  end
		end
	  end
	end
	puts multipliers
  end

  def pbCalcFieldModifiers_accuracy(modifiers, value)
    modifiers[:base_accuracy] = value["base"] if value["base"]
    modifiers[:accuracy_multiplier] *= value["modifier"]
  end

  def pbCalcFieldMultipliers_damage(multipliers, value)
	multipliers[:power_multiplier] *= value["power"]
	multipliers[:attack_multiplier] *= value["atk"] if pbPhysicalMove?
	multipliers[:attack_multiplier] *= value["sp_atk"] if pbSpecialMove?
	multipliers[:final_damage_multiplier] *= value["dmg"]
  end
end

class Battle::Scene
  def pbSetFieldbg
    field_name = FIELD_EFFECTS[@battle.field.field_effect][:field_name_bg][1]
	if @battle.field.field_effect != :None && field_name
	  root = "Graphics/Fieldbacks/"
	  @sprites["battle_bg"].setBitmap("#{root}/#{field_name + "battlebg"}")
	  @sprites["base_0"].setBitmap("#{root}/#{field_name + "playerbase"}")
	  @sprites["base_1"].setBitmap("#{root}/#{field_name + "enemybase"}")
	else
	  pbRefreshEverything
	end
  end

  alias field_effect_pbGetDisplayEffects pbGetDisplayEffects
  def pbGetDisplayEffects(battler)
    display_effects = field_effect_pbGetDisplayEffects(battler)
	field_effect = FIELD_EFFECTS[@battle.field.field_effect]
	field_name = field_effect[:field_DBK_EBUI_display][0] if field_effect
	field_duration = @battle.field.field_effect_duration
#===============================================================================
    if @battle.field.effects[PBEffects::InverseRoom] > 0
	  duration = @battle.field.effects[PBEffects::InverseRoom]
      name = _INTL("Inverse Room")
      tick = _INTL("{1}/5", duration)
      desc = _INTL("Twist type matchup.")
	  display_effects.unshift([name, tick, desc])
	end
#===============================================================================
	if field_name && field_effect != :None
	 name = _INTL(field_name)
	 tick = "--"
	 tick = _INTL("{1}/5", field_duration) if field_duration > 0
	 desc = _INTL(field_effect[:field_DBK_EBUI_display][1])
	 display_effects.unshift([name, tick, desc])
	end
	return display_effects
  end
end