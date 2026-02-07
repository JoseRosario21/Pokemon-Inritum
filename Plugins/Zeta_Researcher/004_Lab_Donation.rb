#===============================================================================
# Zeta Lab Donation - NPC interaction for donating Zeta Pokemon
#===============================================================================

# Process a single donation and return { xp:, tokens: } awarded.
def pbProcessDonation(pkmn)
  tier = pbGetZetaTier(pkmn)
  xp = tier[:donate_xp]
  tokens = tier[:donate_tokens]
  species = pkmn.species
  if !pbZetaResearcher.donated?(species)
    xp += tier[:first_bonus_xp]
    tokens += tier[:first_bonus_tokens]
  end
  pbZetaResearcher.register_donation(species)
  pbZetaResearcher.add_xp(xp)
  pbZetaResearcher.add_tokens(tokens)
  # Track donate mission
  pbTrackMission(:donate_zeta, 1)
  return { :xp => xp, :tokens => tokens }
end

# Main entry point for Zeta donation (call from map event script).
def pbZetaDonation
  if $player.party.count { |p| p.zeta? } == 0 &&
     !pbHasZetaInPC?
    pbMessage(_INTL("You don't have any Zeta Pokémon to donate."))
    return
  end
  cmd = pbMessage(
    _INTL("Would you like to donate a Zeta Pokémon for research?"),
    [_INTL("From Party"), _INTL("From PC"), _INTL("Cancel")], 3
  )
  case cmd
  when 0 then pbZetaDonateFromParty
  when 1 then pbZetaDonateFromPC
  end
end

#===============================================================================
# Party donation flow
#===============================================================================
def pbZetaDonateFromParty
  pbChooseNonEggPokemon(1, 3)
  pkmn_index = pbGet(1)
  return if pkmn_index < 0
  pkmn = $player.party[pkmn_index]
  if !pkmn.zeta?
    pbMessage(_INTL("That Pokémon is not a Zeta Pokémon."))
    return
  end
  if $player.party.length <= 1
    pbMessage(_INTL("You can't donate your last Pokémon!"))
    return
  end
  return if !pbConfirmMessage(_INTL("Donate {1} to research? This cannot be undone.", pkmn.name))
  result = pbProcessDonation(pkmn)
  $player.party.delete_at(pkmn_index)
  tier_name = pbGetZetaTierName(pkmn)
  pbMessage(_INTL("Thank you for donating {1}!", pkmn.name))
  pbMessage(_INTL("You earned {1} XP and {2} Tokens! [{3} tier]", result[:xp], result[:tokens], tier_name))
  pbCheckResearcherRankUp
end

#===============================================================================
# PC donation flow
#===============================================================================
def pbHasZetaInPC?
  (0...$PokemonStorage.maxBoxes).each do |box|
    (0...$PokemonStorage.maxPokemon(box)).each do |slot|
      p = $PokemonStorage[box, slot]
      return true if p && p.zeta?
    end
  end
  return false
end

def pbZetaDonateFromPC
  zeta_list = []
  (0...$PokemonStorage.maxBoxes).each do |box|
    (0...$PokemonStorage.maxPokemon(box)).each do |slot|
      p = $PokemonStorage[box, slot]
      next if !p || !p.zeta?
      tier_name = pbGetZetaTierName(p)
      zeta_list.push([box, slot, p, tier_name])
    end
  end
  if zeta_list.empty?
    pbMessage(_INTL("You don't have any Zeta Pokémon in your PC Boxes."))
    return
  end
  commands = zeta_list.map { |e| _INTL("{1} ({2}) [Lv.{3}]", e[2].name, e[3], e[2].level) }
  commands.push(_INTL("Cancel"))
  loop do
    choice = pbMessage(_INTL("Choose a Zeta Pokémon to donate."), commands, commands.length)
    break if choice >= zeta_list.length
    entry = zeta_list[choice]
    pkmn = entry[2]
    next if !pbConfirmMessage(_INTL("Donate {1} to research? This cannot be undone.", pkmn.name))
    result = pbProcessDonation(pkmn)
    $PokemonStorage[entry[0], entry[1]] = nil
    tier_name = entry[3]
    pbMessage(_INTL("Thank you for donating {1}!", pkmn.name))
    pbMessage(_INTL("You earned {1} XP and {2} Tokens! [{3} tier]", result[:xp], result[:tokens], tier_name))
    pbCheckResearcherRankUp
    # Remove from list and commands so the menu updates
    zeta_list.delete_at(choice)
    commands.delete_at(choice)
    break if zeta_list.empty?
  end
end
