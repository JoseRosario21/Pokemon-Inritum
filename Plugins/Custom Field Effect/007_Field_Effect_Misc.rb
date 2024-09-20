#===============================================================================
# Weather Move
#===============================================================================

# Sunny Day
class Battle::Move::StartSunWeather < Battle::Move::WeatherMove
  def initialize(battle, move)
    super
    @weatherType = :Sun
  end
end

# Rain Dance
class Battle::Move::StartRainWeather < Battle::Move::WeatherMove
  def initialize(battle, move)
    super
    @weatherType = :Rain
  end
end

# Sandstorm
class Battle::Move::StartSandstormWeather < Battle::Move::WeatherMove
  def initialize(battle, move)
    super
    @weatherType = :Sandstorm
  end
end

# Hail
class Battle::Move::StartHailWeather < Battle::Move::WeatherMove
  def initialize(battle, move)
    super
    @weatherType = :Hail
  end
end

#===============================================================================
# Weather Extender
#===============================================================================

Battle::ItemEffects::WeatherExtender.add(:DAMPROCK,
  proc { |item, weather, duration, battler, battle|
    next 8 if [:Rain].include?(weather)
  }
)

Battle::ItemEffects::WeatherExtender.add(:HEATROCK,
  proc { |item, weather, duration, battler, battle|
    next 8 if [:Sun].include?(weather)
  }
)

Battle::ItemEffects::WeatherExtender.add(:ICYROCK,
  proc { |item, weather, duration, battler, battle|
    next 8 if [:Hail].include?(weather)
  }
)

Battle::ItemEffects::WeatherExtender.add(:SMOOTHROCK,
  proc { |item, weather, duration, battler, battle|
    next 8 if [:Sandstorm].include?(weather)
  }
)
#===============================================================================
# Terrain Move
#===============================================================================

# Electric Terrain
class Battle::Move::StartElectricTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    if [:Electric].include?(@battle.field.terrain)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    @battle.pbStartTerrain(user, :Electric)
  end
end

# Grassy Terrain
class Battle::Move::StartGrassyTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    if [:Grassy].include?(@battle.field.terrain)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    @battle.pbStartTerrain(user, :Grassy)
  end
end

# Misty Terrain
class Battle::Move::StartMistyTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    if [:Misty].include?(@battle.field.terrain)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    @battle.pbStartTerrain(user, :Misty)
  end
end

# Psychic Terrain
class Battle::Move::StartPsychicTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    if [:Psychic].include?(@battle.field.terrain)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    @battle.pbStartTerrain(user, :Psychic)
  end
end

#===============================================================================
# Terrain Extender
#===============================================================================

Battle::ItemEffects::TerrainExtender.add(:TERRAINEXTENDER,
  proc { |item, terrain, duration, battler, battle|
    next 8
  }
)

#===============================================================================
# Terrain Stat Boost
#===============================================================================

Battle::ItemEffects::TerrainStatBoost.add(:ELECTRICSEED,
  proc { |item, battler, battle|
    next false if ![:Electric].include?(battle.field.terrain)
    next false if !battler.pbCanRaiseStatStage?(:DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:DEFENSE, 1, battler, itemName)
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:GRASSYSEED,
  proc { |item, battler, battle|
    next false if ![:Grassy].include?(battle.field.terrain)
    next false if !battler.pbCanRaiseStatStage?(:DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:DEFENSE, 1, battler, itemName)
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:MISTYSEED,
  proc { |item, battler, battle|
    next false if ![:Misty].include?(battle.field.terrain)
    next false if !battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:SPECIAL_DEFENSE, 1, battler, itemName)
  }
)

Battle::ItemEffects::TerrainStatBoost.add(:PSYCHICSEED,
  proc { |item, battler, battle|
    next false if ![:Psychic].include?(battle.field.terrain)
    next false if !battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler)
    itemName = GameData::Item.get(item).name
    battle.pbCommonAnimation("UseItem", battler)
    next battler.pbRaiseStatStageByCause(:SPECIAL_DEFENSE, 1, battler, itemName)
  }
)

#===============================================================================
# No Heal
#===============================================================================

ItemHandlers::CanUseInBattle.add(:POTION, proc { |item, pokemon, battler, move, firstAction, battle, scene, showMessages|
  fe = FIELD_EFFECTS[battle.field.field_effect]
  if fe[:other_effect]["no heal"]
    scene.pbDisplay(_INTL("It won't have any effect on this field!")) if showMessages
    next false
  end
  if !pokemon.able? || pokemon.hp == pokemon.totalhp
    scene.pbDisplay(_INTL("It won't have any effect.")) if showMessages
    next false
  end
  next true
})