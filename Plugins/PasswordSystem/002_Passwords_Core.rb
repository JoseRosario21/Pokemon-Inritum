##─────────────────────────────────────────────────────────────────────────────
## Password System — Save Data & Redemption Logic
##─────────────────────────────────────────────────────────────────────────────

#-------------------------------------------------------------------------------
# Extend Player to track redeemed passwords. Uses lazy initialisation so old
# saves without the field behave correctly (treated as having redeemed nothing).
#-------------------------------------------------------------------------------
class Player
  def redeemed_passwords
    @redeemed_passwords ||= []
  end

  def redeemed_passwords=(val)
    @redeemed_passwords = val
  end
end

#-------------------------------------------------------------------------------
# Core redemption entry point.
# Returns true if the password was accepted and applied, false otherwise.
# Displays all messages internally — callers just check the return value.
#-------------------------------------------------------------------------------
def pbRedeemPassword(raw_password)
  key = raw_password.strip.upcase
  effect = PasswordSystem::PASSWORDS[key]

  unless effect
    pbMessage(_INTL("That password is not valid."))
    return false
  end

  if $player.redeemed_passwords.include?(key)
    pbMessage(_INTL("That password has already been redeemed."))
    return false
  end

  success = pbApplyPasswordEffect(effect)
  if success
    $player.redeemed_passwords.push(key)
    desc = effect[:description]
    pbMessage(desc) if desc && !desc.empty?
  end
  return success
end

#-------------------------------------------------------------------------------
# Dispatch an effect hash to the appropriate handler.
# Returns true on success, false if something blocked it (e.g. full bag).
#-------------------------------------------------------------------------------
def pbApplyPasswordEffect(effect)
  case effect[:type]
  when :item     then return pbPasswordEffectItem(effect)
  when :pokemon  then return pbPasswordEffectPokemon(effect)
  when :switch   then return pbPasswordEffectSwitch(effect)
  when :variable then return pbPasswordEffectVariable(effect)
  when :multi
    effect[:effects].each do |sub|
      return false unless pbApplyPasswordEffect(sub)
    end
    return true
  else
    pbMessage(_INTL("Unknown reward type. Please contact the developer."))
    return false
  end
end

#-------------------------------------------------------------------------------
# :item — add to bag
#-------------------------------------------------------------------------------
def pbPasswordEffectItem(effect)
  item = effect[:item]
  qty  = effect[:quantity] || 1
  unless $bag.can_add?(item, qty)
    pbMessage(_INTL("Your Bag is full! Make some space and try again."))
    return false
  end
  pbReceiveItem(item, qty)
  return true
end

#-------------------------------------------------------------------------------
# :pokemon — build, animate, nickname, store
#-------------------------------------------------------------------------------
def pbPasswordEffectPokemon(effect)
  if pbBoxesFull?
    pbMessage(_INTL("Your party and all your Boxes are full!\\nPlease make space and try again."))
    return false
  end

  species = effect[:species]
  level   = effect[:level] || 5

  pkmn = Pokemon.new(species, level)
  pkmn.shiny           = true if effect[:shiny]
  pkmn.obtain_method   = 4      # Fateful encounter
  pkmn.obtain_text     = effect[:obtain_text] || _INTL("Pokémon Inritum")
  pkmn.obtain_level    = level
  pkmn.obtain_map      = $game_map&.map_id || 0
  pkmn.timeReceived    = pbGetTimeNow.to_i
  pkmn.item            = effect[:held_item] if effect[:held_item]

  if effect[:gender]
    case effect[:gender]
    when :MALE       then pkmn.gender = 0
    when :FEMALE     then pkmn.gender = 1
    when :GENDERLESS then pkmn.gender = 2
    end
  end

  if effect[:moves]
    pkmn.forget_all_moves
    effect[:moves].each { |m| pkmn.learn(m) }
  end

  pkmn.calc_stats
  pkmn.record_first_moves

  pbPasswordPokemonGiftAnimation(pkmn)

  was_owned = $player.owned?(pkmn.species)
  pbNicknameAndStore(pkmn)

  if Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && !was_owned &&
     $player.has_pokedex && $player.pokedex.species_in_unlocked_dex?(pkmn.species)
    pbMessage(_INTL("{1}'s data was added to the Pokédex.", pkmn.name))
    $player.pokedex.register_last_seen(pkmn)
    pbFadeOutIn do
      scene  = PokemonPokedexInfo_Scene.new
      screen = PokemonPokedexInfoScreen.new(scene)
      screen.pbDexEntry(pkmn.species)
    end
  end

  return true
end

#-------------------------------------------------------------------------------
# :switch — set a game switch
#-------------------------------------------------------------------------------
def pbPasswordEffectSwitch(effect)
  $game_switches[effect[:switch]] = effect.fetch(:value, true)
  pbMessage(_INTL("A new feature has been unlocked: \\c[1]{1}\\c[0]!", effect[:name]))
  return true
end

#-------------------------------------------------------------------------------
# :variable — set a game variable
#-------------------------------------------------------------------------------
def pbPasswordEffectVariable(effect)
  $game_variables[effect[:variable]] = effect[:value]
  pbMessage(_INTL("A new feature has been activated: \\c[1]{1}\\c[0]!", effect[:name]))
  return true
end
