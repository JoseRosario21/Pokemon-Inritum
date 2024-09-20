module Settings
  HAIL_WEATHER_TYPE = 2
end

module PBEffects
  InverseRoom = 950
end

class Battle
  attr_accessor :triggered_abils
  attr_accessor :tapu_terrain
  
  alias field_effect_initialize initialize
  def initialize(scene, p1, p2, player, opponent)
    field_effect_initialize(scene, p1, p2, player, opponent)
	@triggered_abils = [Array.new(@party1.length) { [] }, Array.new(@party2.length) { [] }]
	@tapu_terrain = false
  end

  alias field_effect_pbDebugMenu pbDebugMenu
  def pbDebugMenu
    if @field.field_effect != :None
	  allBattlers.each { |b| b.pbAbilityOnWeatherChange }
      pbBattleDebug(self)
	  @scene.pbRefreshEverything
      @scene.pbSetFieldbg
      allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
      pbEndPrimordialWeather
      allBattlers.each { |b| b.pbAbilityOnTerrainChange }
      allBattlers.each do |b|
        b.pbCheckFormOnMovesetChange
        b.pbCheckFormOnStatusChange
      end
	else
	  allBattlers.each { |b| b.pbAbilityOnWeatherChange }
      field_effect_pbDebugMenu
	end
  end

  alias anti_cheat_pbStartBattleCore pbStartBattleCore
  def pbStartBattleCore
    pbAntiCheat if defined?(pbAntiCheat)
	anti_cheat_pbStartBattleCore
  end

#===============================================================================
#
#===============================================================================
  def pbOnBattlerEnteringBattle(battler_index, skip_event_reset = false)
    battler_index = [battler_index] if !battler_index.is_a?(Array)
    battler_index.flatten!
    if !skip_event_reset
      allBattlers.each do |b|
        b.droppedBelowHalfHP = false
        b.statsDropped = false
      end
    end
	pbPriority(true).each do |b|
	  next if !battler_index.include?(b.index) || b.fainted?
	  pbMessagesOnBattlerEnteringBattle(b)
	end
    # For each battler that entered battle, in speed order
    pbPriority(true).each do |b|
      next if !battler_index.include?(b.index) || b.fainted?
      pbRecordBattlerAsParticipated(b)
      # Position/field effects triggered by the battler appearing
	  pbFieldSetEffect_battler(b)
      pbEffectsOnBattlerEnteringPosition(b) # Healing Wish/Lunar Dance
      pbEntryHazards(b)
      # Battler faints if it is knocked out because of an entry hazard above
      if b.fainted?
        b.pbFaint
        pbGainExp
        pbJudge
        next
      end
      b.pbCheckForm
      # Primal Revert upon entering battle
      pbPrimalReversion(b.index)
      # Ending primordial weather, checking Trace
      b.pbContinualAbilityChecks(true)
      # Abilities that trigger upon switching in
	  b.pbAbilitiesOnSwitchIn
      pbEndPrimordialWeather   # Checking this again just in case
      # Items that trigger upon switching in (Air Balloon message)
      if b.itemActive?
        Battle::ItemEffects.triggerOnSwitchIn(b.item, b, self)
      end
      # Berry check, status-curing ability check
      b.pbHeldItemTriggerCheck
      b.pbAbilityStatusCureCheck
    end
    # Check for triggering of Emergency Exit/Wimp Out/Eject Pack (only one will
    # be triggered)
    pbPriority(true).each do |b|
      break if b.pbItemOnStatDropped
      break if b.pbAbilitiesOnDamageTaken
    end
    allBattlers.each do |b|
      b.droppedBelowHalfHP = false
      b.statsDropped = false
    end
  end

#===============================================================================
# Limited Abilities
#===============================================================================
  def ability_triggered?(battler, check_ability)
    return @triggered_abils[battler.index & 1][battler.pokemonIndex].include?(check_ability)
  end

  def set_ability_trigger(battler, check_ability)
    @triggered_abils[battler.index & 1][battler.pokemonIndex].push(check_ability)
  end


  def battle_limited_ability_triggered?(battler, check_ability)
    if ability_triggered?(battler, check_ability)
	  return true
    elsif battle_limit_ability(battler).include?(check_ability)
      set_ability_trigger(battler, check_ability)
	  return false
	end
  end

  def switch_limited_ability_triggered?(battler, check_ability)
	if battler.triggered_abils.include?(check_ability)
	  return true
    elsif switch_limit_ability(battler).include?(check_ability)
	  battler.triggered_abils.push(check_ability)
	  return false
	end
  end

  def limited_ability_triggered?(battler, check_ability)
    return true if battle_limited_ability_triggered?(battler, check_ability)
    return switch_limited_ability_triggered?(battler, check_ability)
  end

  def battle_limit_ability(battler)
    fe = FIELD_EFFECTS[@field.field_effect]
    ret = LIMITED_ABILITY[:one_battle]
	#ret = [] if !battler.pbOwnedByPlayer?
	ret = [] if fe[:other_effect]["abil un-ltd"]
    return ret
  end

  def switch_limit_ability(battler)
    fe = FIELD_EFFECTS[@field.field_effect]
    ret = LIMITED_ABILITY[:one_switch]
	#ret = [] if !battler.pbOwnedByPlayer?
	ret = [] if fe[:other_effect]["abil un-ltd"]
    return ret
  end

#===============================================================================
# Weather
#===============================================================================
  def pbWeatherStartMessage
    return if @field.weather == :None
    case @field.weather
    when :Sun         then pbDisplay(_INTL("The sunlight turned harsh!"))
    when :Rain        then pbDisplay(_INTL("It started to rain!"))
    when :Sandstorm   then pbDisplay(_INTL("A sandstorm brewed!"))
    when :HarshSun    then pbDisplay(_INTL("The sunlight turned extremely harsh!"))
    when :HeavyRain   then pbDisplay(_INTL("A heavy rain began to fall!"))
    when :StrongWinds then pbDisplay(_INTL("Mysterious strong winds are protecting Flying-type Pokémon!"))
    when :ShadowSky   then pbDisplay(_INTL("A shadow sky appeared!"))
    when :Hail
      if Settings::HAIL_WEATHER_TYPE == 1
        pbDisplay(_INTL("It started to snow!"))
      else
        pbDisplay(_INTL("It started to hail!"))
      end
    end
  end

  def pbWeatherContiuneMessage
    return if @field.weather == :None
    case @field.weather
    when :Sun         then pbDisplay(_INTL("The sunlight is strong."))
    when :Rain        then pbDisplay(_INTL("Rain continues to fall."))
    when :Sandstorm   then pbDisplay(_INTL("The sandstorm is raging."))
    when :HarshSun    then pbDisplay(_INTL("The sunlight is extremely harsh."))
    when :HeavyRain   then pbDisplay(_INTL("It is raining heavily."))
    when :StrongWinds then pbDisplay(_INTL("The wind is strong."))
    when :ShadowSky   then pbDisplay(_INTL("The shadow sky continues."))
    when :Hail
      if Settings::HAIL_WEATHER_TYPE == 1
        pbDisplay(_INTL("The snow is falling."))
      else
        pbDisplay(_INTL("The hail is crashing down."))
      end
    end
  end

  def pbWeatherEndMessage
    return if @field.weather == :None
    case @field.weather
    when :Sun         then pbDisplay(_INTL("The sunlight faded."))
    when :Rain        then pbDisplay(_INTL("The rain stopped."))
    when :Sandstorm   then pbDisplay(_INTL("The sandstorm subsided."))
    when :HarshSun    then pbDisplay(_INTL("The harsh sunlight faded!"))
    when :HeavyRain   then pbDisplay(_INTL("The heavy rain has lifted!"))
    when :StrongWinds then pbDisplay(_INTL("The mysterious air current has dissipated!"))
    when :ShadowSky   then pbDisplay(_INTL("The shadow sky faded."))
    when :Hail
      if Settings::HAIL_WEATHER_TYPE == 1
        pbDisplay(_INTL("The snow stopped."))
      else
        pbDisplay(_INTL("The hail stopped."))
      end
    end
  end

  alias field_effect_pbWeather pbWeather
  def pbWeather
    return field_effect_pbWeather
  end

  # Used for causing weather by a move or by an ability.
  def pbStartWeather(user, newWeather, duration = 5, showAnim = true)
    return if newWeather == :None
    return if @field.weather == newWeather
    @field.weather = newWeather
    if duration > 0 && user && user.itemActive?
      duration = Battle::ItemEffects.triggerWeatherExtender(user.item, @field.weather, duration, user, self)
    end
    @field.weatherDuration = duration
    weather_data = GameData::BattleWeather.try_get(@field.weather)
    pbCommonAnimation(weather_data.animation) if showAnim && weather_data
	pbWeatherStartMessage
	pbHideAbilitySplash(user) if user
    # Check for end of primordial weather, and weather-triggered form changes
	allBattlers.each { |b| b.pbAbilityOnWeatherChange }
    allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
    pbEndPrimordialWeather
  end

  alias paldea_pbStartWeather pbStartWeather
  def pbStartWeather(user, newWeather, duration = 5, showAnim = true)
    return if newWeather == :None
    return if @field.weather == newWeather
    start = true
    fe = FIELD_EFFECTS[@field.field_effect]
	new_weather = fe[:other_weather_terrain_effect]["no weather"]
    if new_weather.is_a?(TrueClass)
	  start = false
	elsif new_weather == newWeather
	  start = false
	end
	new_duration = fe[:other_weather_terrain_effect]["perm weather"]
	if new_duration.is_a?(TrueClass)
      duration = -1
	elsif new_duration.is_a?(Numeric) && duration > 0
	 duration += new_duration
	 if new_duration < 0 && duration <= 0
	  start = false
	 end
	end
	if !start
	  pbDisplay(_INTL("A mysterious force has prevented the weather from being activated!"))
	  pbHideAbilitySplash(user) if user
	  return
	end
    if newWeather == :Hail && Settings::HAIL_WEATHER_TYPE > 0
      @field.weather = newWeather
      if duration > 0 && user && user.itemActive?
        duration = Battle::ItemEffects.triggerWeatherExtender(user.item, @field.weather, duration, user, self)
      end
      @field.weatherDuration = duration
      weather_data = GameData::BattleWeather.try_get(@field.weather)
      pbCommonAnimation(weather_data.animation) if showAnim && weather_data
	  pbWeatherStartMessage
	  pbHideAbilitySplash(user) if user
	  allBattlers.each { |b| b.pbAbilityOnWeatherChange }
      allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
      pbEndPrimordialWeather
    else
      paldea_pbStartWeather(user, newWeather, duration, showAnim)
    end
  end

  def pbStartWeatherAbility(new_weather, user, duration = 5, ignore_primal = false)
    return if !ignore_primal && [:HarshSun, :HeavyRain, :StrongWinds].include?(@field.weather)
    return if new_weather == :None
    return if @field.weather == new_weather
	duration = -1 if !Settings::FIXED_DURATION_WEATHER_FROM_ABILITY
    pbShowAbilitySplash(user) if user
    pbDisplay(_INTL("{1}'s {2} activated!", user.pbThis, user.abilityName)) if !Scene::USE_ABILITY_SPLASH
    pbStartWeather(user, new_weather, duration)
  end

  def pbEndPrimordialWeather
    return if @field.weather == @field.defaultWeather
    oldWeather = @field.weather
	fe = FIELD_EFFECTS[@field.field_effect]
	weather = fe[:weather_terrain_effect]["weather"][0]
    # End Primordial Sea, Desolate Land, Delta Stream
    case @field.weather
    when :HarshSun
      if !pbCheckGlobalAbility(:DESOLATELAND) && weather != :HarshSun
        @field.weather = :None
        pbDisplay(_INTL("The harsh sunlight faded!"))
      end
    when :HeavyRain
      if !pbCheckGlobalAbility(:PRIMORDIALSEA) && weather != :HeavyRain
        @field.weather = :None
        pbDisplay(_INTL("The heavy rain has lifted!"))
      end
    when :StrongWinds
      if !pbCheckGlobalAbility(:DELTASTREAM) && weather != :StrongWinds
        @field.weather = :None
        pbDisplay(_INTL("The mysterious air current has dissipated!"))
      end
    end
    if @field.weather != oldWeather
      # Check for form changes caused by the weather changing
	  allBattlers.each { |b| b.pbAbilityOnWeatherChange }
      allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
      # Start up the default weather
      pbStartWeather(nil, @field.defaultWeather, -1)
    end
  end

  def pbEOREndWeather(priority)
    return if @field.weather == :None
    # NOTE: Primordial weather doesn't need to be checked here, because if it
    #       could wear off here, it will have worn off already.
    # Count down weather duration
    @field.weatherDuration -= 1 if @field.weatherDuration > 0
    # Weather wears off
    if @field.weatherDuration == 0
	  pbWeatherEndMessage
      @field.weather = :None
      # Check for form changes caused by the weather changing
	  allBattlers.each { |b| b.pbAbilityOnWeatherChange }
      allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
      # Start up the default weather
      pbStartWeather(nil, @field.defaultWeather, -1)
      return if @field.weather == :None
    end
    # Weather continues
    weather_data = GameData::BattleWeather.try_get(@field.weather)
    pbCommonAnimation(weather_data.animation) if weather_data
	pbWeatherContiuneMessage
    # Effects due to weather
    priority.each do |b|
      # Weather-related abilities
      if b.abilityActive?
	    if PluginManager.installed?("Demanding Yellow Custom Scripts")
	      b.ability_list.each do |ability_id|
	        b.ability_id = ability_id
            Battle::AbilityEffects.triggerEndOfRoundWeather(ability_id, b.effectiveWeather, b, self)
	      end
		else
		  Battle::AbilityEffects.triggerEndOfRoundWeather(b.ability, b.effectiveWeather, b, self)
		end
        b.pbFaint if b.fainted?
      end
      # Weather damage
      pbEORWeatherDamage(b)
    end
  end

  alias paldea_pbEOREndWeather pbEOREndWeather
  def pbEOREndWeather(priority)
    return if @field.weather == :None
    if @field.weather == :Hail && Settings::HAIL_WEATHER_TYPE > 0
      @field.weatherDuration -= 1 if @field.weatherDuration > 0
      if @field.weatherDuration == 0
		pbWeatherEndMessage
        @field.weather = :None
		allBattlers.each { |b| b.pbAbilityOnWeatherChange }
        allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
        pbStartWeather(nil, @field.defaultWeather, -1) if @field.defaultWeather != :None
        return if @field.weather == :None
      end
      weather_data = GameData::BattleWeather.try_get(@field.weather)
      pbCommonAnimation(weather_data.animation) if weather_data && !@weather
      pbWeatherContiuneMessage
	  priority.each do |b|
        if b.abilityActive?
	      if PluginManager.installed?("Demanding Yellow Custom Scripts")
	        b.ability_list.each do |ability_id|
	          b.ability_id = ability_id
              Battle::AbilityEffects.triggerEndOfRoundWeather(ability_id, b.effectiveWeather, b, self)
	        end
		  else
		    Battle::AbilityEffects.triggerEndOfRoundWeather(b.ability, b.effectiveWeather, b, self)
		  end
          b.pbFaint if b.fainted?
        end
        pbEORWeatherDamage(b)
      end
    else
      paldea_pbEOREndWeather(priority)
    end
  end

  if PluginManager.installed?("Deluxe Battle Kit")
    alias dx_pbEOREndWeather pbEOREndWeather
    def pbEOREndWeather(priority)
      oldWeather = @field.weather
      dx_pbEOREndWeather(priority)
      newWeather = @field.weather
      if newWeather == :None && oldWeather != :None
        allBattlers.each do |b|
          pbDeluxeTriggers(b, nil, "WeatherEnded", oldWeather)
        end
      end
    end
  end

#===============================================================================
# Terrain
#===============================================================================
  def pbTerrainStartMessage
    return if @field.terrain == :None
    case @field.terrain
    when :Electric then pbDisplay(_INTL("An electric current runs across the battlefield!"))
    when :Grassy   then pbDisplay(_INTL("Grass is covering the battlefield!"))
    when :Misty    then pbDisplay(_INTL("Mist swirls about the battlefield!"))
    when :Psychic  then pbDisplay(_INTL("The battlefield is weird!"))
    end
  end

  def pbTerrainContinueMessage
    return if @field.terrain == :None
    pbTerrainStartMessage
  end

  def pbTerrainEndMessage
    return if @field.terrain == :None
    case @field.terrain
    when :Electric then pbDisplay(_INTL("The electric current disappeared from the battlefield!"))
    when :Grassy   then pbDisplay(_INTL("The grass disappeared from the battlefield!"))
    when :Misty    then pbDisplay(_INTL("The mist disappeared from the battlefield!"))
    when :Psychic  then pbDisplay(_INTL("The weirdness disappeared from the battlefield!"))
    end
  end

  def pbStartTerrain(user, newTerrain, duration = 5, showAnim = true)
	return if newTerrain == :None
    return if @field.terrain == newTerrain
    start = true
    fe = FIELD_EFFECTS[@field.field_effect]
	new_terrain = fe[:other_weather_terrain_effect]["no terrain"]
    if new_terrain.is_a?(TrueClass)
	  start = false
	elsif new_terrain == newTerrain
	  start = false
	end
	new_duration = fe[:other_weather_terrain_effect]["perm terrain"]
	if new_duration.is_a?(TrueClass)
      duration = -1
	elsif new_duration.is_a?(Numeric) && duration > 0
	 duration += new_duration
	 if new_duration < 0 && duration <= 0
	  start = false
	 end
	end
	if !start
	  pbDisplay(_INTL("A mysterious force has prevented the terrain from being activated!"))
	  pbHideAbilitySplash(user) if user
	  return
	end
    @field.terrain = newTerrain
    if duration > 0 && user && user.itemActive?
      duration = Battle::ItemEffects.triggerTerrainExtender(user.item, newTerrain, duration, user, self)
    end
    @field.terrainDuration = duration
    terrain_data = GameData::BattleTerrain.try_get(@field.terrain)
    pbCommonAnimation(terrain_data.animation) if showAnim && terrain_data
	pbTerrainContinueMessage
	pbHideAbilitySplash(user) if user
    # Check for abilities/items that trigger upon the terrain changing
    allBattlers.each { |b| b.pbAbilityOnTerrainChange }
    allBattlers.each { |b| b.pbItemTerrainStatBoostCheck }
  end

  def pbEOREndTerrain
    return if @field.terrain == :None
    # Count down terrain duration
    @field.terrainDuration -= 1 if @field.terrainDuration > 0
	if @field.terrainDuration != 0
      # Terrain continues
      terrain_data = GameData::BattleTerrain.try_get(@field.terrain)
      pbCommonAnimation(terrain_data.animation) if terrain_data
	  pbTerrainContinueMessage
    # Terrain wears off
    elsif @field.terrainDuration == 0
	  pbTerrainEndMessage
	  @tapu_terrain = false if @tapu_terrain
      @field.terrain = :None
      allBattlers.each { |battler| battler.pbAbilityOnTerrainChange }
      # Start up the default terrain
      pbStartTerrain(nil, @field.defaultTerrain, -1)
    end
  end

  if PluginManager.installed?("Deluxe Battle Kit")
    alias dx_pbEOREndTerrain pbEOREndTerrain
    def pbEOREndTerrain
      oldTerrain = @field.terrain
      dx_pbEOREndTerrain
      newTerrain = @field.terrain
      if newTerrain == :None && oldTerrain != :None
        allBattlers.each do |b|
          pbDeluxeTriggers(b, nil, "TerrainEnded", oldTerrain)
        end
      end
    end
  end

  alias field_effect_pbEOREndTerrain pbEOREndTerrain
  def pbEOREndTerrain
    field_effect_pbEOREndTerrain
	pbEOREndField
  end

#===============================================================================
# No Item
#===============================================================================
  alias field_effect_pbItemMenu pbItemMenu
  def pbItemMenu(idxBattler, firstAction)
    fe = FIELD_EFFECTS[@field.field_effect]
    if fe[:other_effect]["no item"] && trainerBattle?
      pbDisplay(_INTL("Items cannot be used on this field!"))
      return false
    end
	return field_effect_pbItemMenu(idxBattler, firstAction)
  end

#===============================================================================
# End Of Round end effects that apply to the whole field
#===============================================================================
  def pbEORCountDownFieldEffect(effect, msg)
    return if @field.effects[effect] <= 0
    @field.effects[effect] -= 1 if effect != PBEffects::FairyLock
    return if @field.effects[effect] > 0
    pbDisplay(msg)
    if effect == PBEffects::MagicRoom
      pbPriority(true).each { |battler| battler.pbItemTerrainStatBoostCheck }
    end
  end

  if PluginManager.installed?("Deluxe Battle Kit")
    def pbEORCountDownFieldEffect(effect, msg)
      return if @field.effects[effect] <= 0
      @field.effects[effect] -= 1 if effect != PBEffects::FairyLock
      return if @field.effects[effect] > 0
      pbDisplay(msg)
      if effect == PBEffects::MagicRoom
        pbPriority(true).each { |battler| battler.pbItemTerrainStatBoostCheck }
      end
      $DELUXE_PBEFFECTS[:field][:counter].each do |id|
        next if !PBEffects.const_defined?(id)
        next if effect != PBEffects.const_get(id)
        allBattlers.each do |b|
          pbDeluxeTriggers(b, nil, "FieldEffectEnded", id)
        end
        break
      end
    end
  end

  def pbEOREndFieldEffects(priority)
    # Fairy Lock
    pbEORCountDownFieldEffect(PBEffects::FairyLock, _INTL("The Fairy Lock effect wore off!"))
    # Gravity
    pbEORCountDownFieldEffect(PBEffects::Gravity, _INTL("Gravity returned to normal!"))
    # Inverse Room
    pbEORCountDownFieldEffect(PBEffects::InverseRoom, _INTL("The Inverse Room disappeared!"))
    # Magic Room
    pbEORCountDownFieldEffect(PBEffects::MagicRoom, _INTL("Magic Room wore off, and held items' effects returned to normal!"))
    # Trick Room
    pbEORCountDownFieldEffect(PBEffects::TrickRoom, _INTL("The twisted dimensions returned to normal!"))
    # Wonder Room
    pbEORCountDownFieldEffect(PBEffects::WonderRoom, _INTL("Wonder Room wore off, and Defense and Sp. Def stats returned to normal!"))
    # Water Sport
    pbEORCountDownFieldEffect(PBEffects::WaterSportField, _INTL("The effects of Water Sport have faded."))
    # Mud Sport
    pbEORCountDownFieldEffect(PBEffects::MudSportField, _INTL("The effects of Mud Sport have faded."))
  end
end