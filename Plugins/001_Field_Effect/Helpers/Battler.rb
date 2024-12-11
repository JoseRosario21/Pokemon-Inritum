class Battle::Battler
  def add_random_ability(showcase = false, trigger = true)
    return if fainted?
    added_abil = choose_random_ability(self)
    addAbility(added_abil, showcase, trigger)
  end

  def unique_id
    @pokemon.unique_id
  end

  def owner_party_all_fainted?
    @battle.pbParty(@index).all?(&:fainted?)
  end
end