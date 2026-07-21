#===============================================================================
# Cursed Steel (Animus Golurk)
# Contact moves against the bearer curse the attacker, draining 1/4 max HP
# each turn. The curse clears when the afflicted Pokémon switches out.
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:CURSEDSTEEL,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.fainted?
    next if user.effects[PBEffects::Curse]
    battle.pbShowAbilitySplash(target)
    user.effects[PBEffects::Curse] = true
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} was cursed!", user.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} cursed {3}!", target.pbThis, target.abilityName, user.pbThis(true)))
    end
    battle.pbHideAbilitySplash(target)
  }
)
