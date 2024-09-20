module Battle::AbilityEffects
  OnWeatherChange = AbilityHandlerHash.new

  def self.triggerOnWeatherChange(ability, battler, battle, ability_changed)
    OnWeatherChange.trigger(ability, battler, battle, ability_changed)
  end
end

#===============================================================================
# Weather Ability
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:DELTASTREAM,
  proc { |ability, battler, battle, switch_in|
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbStartWeatherAbility(:StrongWinds, battler, -1, true)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:DESOLATELAND,
  proc { |ability, battler, battle, switch_in|
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbStartWeatherAbility(:HarshSun, battler, -1, true)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:DRIZZLE,
  proc { |ability, battler, battle, switch_in|
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbStartWeatherAbility(:Rain, battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:DROUGHT,
  proc { |ability, battler, battle, switch_in|
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbStartWeatherAbility(:Sun, battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:ORICHALCUMPULSE,
  proc { |ability, battler, battle, switch_in|
    if [:Sun, :HarshSun].include?(battler.effectiveWeather)
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1} basked in the sunlight, sending its ancient pulse into a frenzy!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    elsif !battle.limited_ability_triggered?(battler, ability)
      battle.pbStartWeatherAbility(:Sun, battler)
      battle.pbDisplay(_INTL("{1} turned the sunlight harsh, sending its ancient pulse into a frenzy!", battler.pbThis))
    end
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:PRIMORDIALSEA,
  proc { |ability, battler, battle, switch_in|
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbStartWeatherAbility(:HeavyRain, battler, -1, true)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:SANDSTREAM,
  proc { |ability, battler, battle, switch_in|
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbStartWeatherAbility(:Sandstorm, battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:SNOWWARNING,
  proc { |ability, battler, battle, switch_in|
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbStartWeatherAbility(:Hail, battler)
  }
)

#===============================================================================
# Terrain Ability
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:ELECTRICSURGE,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isTapu? && battle.tapu_terrain
    next if [:Electric].include?(battle.field.terrain)
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbShowAbilitySplash(battler)
	battle.tapu_terrain = true if battler.isTapu?
    battle.pbStartTerrain(battler, :Electric)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:GRASSYSURGE,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isTapu? && battle.tapu_terrain
    next if [:Grassy].include?(battle.field.terrain)
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbShowAbilitySplash(battler)
	battle.tapu_terrain = true if battler.isTapu?
    battle.pbStartTerrain(battler, :Grassy)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:HADRONENGINE,
  proc { |ability, battler, battle, switch_in|
    if [:Electric].include?(battle.field.terrain) 
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1} used the Electric Terrain to energize its futuristic engine!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    else
	  next if !battler.isTapu? && battle.tapu_terrain
	  next if battle.limited_ability_triggered?(battler, ability)
      battle.pbShowAbilitySplash(battler)
	  battle.tapu_terrain = true if battler.isTapu?
      battle.pbStartTerrain(battler, :Electric)
      battle.pbDisplay(_INTL("{1} turned the ground into Electric Terrain, energizing its futuristic engine!", battler.pbThis))
    end
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:MISTYSURGE,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isTapu? && battle.tapu_terrain
    next if [:Misty].include?(battle.field.terrain)
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbShowAbilitySplash(battler)
	battle.tapu_terrain = true if battler.isTapu?
    battle.pbStartTerrain(battler, :Misty)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:PSYCHICSURGE,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isTapu? && battle.tapu_terrain
    next if [:Psychic].include?(battle.field.terrain)
	next if battle.limited_ability_triggered?(battler, ability)
    battle.pbShowAbilitySplash(battler)
	battle.tapu_terrain = true if battler.isTapu?
    battle.pbStartTerrain(battler, :Psychic)
  }
)