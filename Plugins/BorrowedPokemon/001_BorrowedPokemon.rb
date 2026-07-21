#===============================================================================
# BorrowedPokemon
# Tracks a Pokémon temporarily lent to the player for a quest.
# Guards: cannot be released, cannot be stored in PC, cannot evolve while borrowed.
#
# Usage (event script):
#   pkmn = BorrowedPokemon.give(:BONSLY, 5, "Albert")
#   # ... player trains it ...
#   BorrowedPokemon.return_to_owner  # call when handing back
#===============================================================================

#===============================================================================
# Save-persistent ID storage
#===============================================================================
class PokemonGlobalMetadata
  def borrowed_pokemon_id
    @borrowed_pokemon_id ||= nil
  end

  def borrowed_pokemon_id=(val)
    @borrowed_pokemon_id = val
  end

  def borrowed_battle_count
    @borrowed_battle_count ||= 0
  end

  def borrowed_battle_count=(val)
    @borrowed_battle_count = val
  end

  def borrowed_battle_target
    @borrowed_battle_target ||= 10
  end

  def borrowed_battle_target=(val)
    @borrowed_battle_target = val
  end

  def borrowed_start_level
    @borrowed_start_level ||= 0
  end

  def borrowed_start_level=(val)
    @borrowed_start_level = val
  end
end

#===============================================================================
# Core module
#===============================================================================
module BorrowedPokemon
  @participated = false

  module_function

  # Creates the Pokémon, applies guards, adds to party, and registers it.
  # Returns the Pokemon on success, or nil if the party is full.
  # The caller is responsible for showing a "make room" message when nil is returned.
  def give(species, level, owner_name, gender: :MALE, nature: :HARDY, iv: 15, battle_target: 10)
    return nil if $player.party.length >= 6
    pkmn = Pokemon.new(species, level)
    gender_int = { MALE: 0, FEMALE: 1, UNKNOWN: 2 }[gender] || gender
    pkmn.owner        = Pokemon::Owner.new_foreign(owner_name, gender_int)
    pkmn.nature       = nature
    pkmn.iv.keys.each { |s| pkmn.iv[s] = iv }
    pkmn.calc_stats
    pkmn.cannot_release = true
    pkmn.cannot_store   = true
    pkmn.cannot_trade   = true
    $player.party.push(pkmn)
    $PokemonGlobal.borrowed_pokemon_id     = pkmn.personalID
    $PokemonGlobal.borrowed_battle_target  = battle_target
    $PokemonGlobal.borrowed_start_level    = level
    return pkmn
  end

  # Removes the guards and clears tracking. Call this when the player hands it back.
  def return_to_owner
    pkmn = find
    if pkmn
      pkmn.cannot_release = false
      pkmn.cannot_store   = false
      pkmn.cannot_trade   = false
      $player.party.delete(pkmn)
    end
    $PokemonGlobal.borrowed_pokemon_id   = nil
    $PokemonGlobal.borrowed_battle_count = 0
  end

  def active?
    !$PokemonGlobal.borrowed_pokemon_id.nil?
  end

  # Finds the borrowed Pokémon in the player's party.
  def find
    return nil unless active?
    $player.party.find { |p| p.personalID == $PokemonGlobal.borrowed_pokemon_id }
  end

  def battle_count
    $PokemonGlobal.borrowed_battle_count
  end

  def levels_gained
    pkmn = find
    return 0 unless pkmn
    pkmn.level - $PokemonGlobal.borrowed_start_level
  end

  # Returns true once the borrowed Pokémon has taken part in the required number of battles.
  def ready?
    $PokemonGlobal.borrowed_battle_count >= $PokemonGlobal.borrowed_battle_target
  end

  # Called from the Battle alias below, before participants are cleared.
  def mark_participated!
    @participated = true
  end

  def participated?
    @participated ||= false
  end

  def reset_participation!
    @participated = false
  end
end

#===============================================================================
# Block evolution while borrowed
#===============================================================================
class Pokemon
  alias_method :check_evolution_on_level_up_borrowed_original, :check_evolution_on_level_up

  def check_evolution_on_level_up
    return nil if BorrowedPokemon.active? &&
                  personalID == $PokemonGlobal.borrowed_pokemon_id
    check_evolution_on_level_up_borrowed_original
  end
end

#===============================================================================
# Participation tracking — hook into EXP distribution before participants clear
# pbGainExp iterates b.participants for each fainted/captured enemy battler, then
# clears the array (line 55). We check here so on_end_battle can read the flag.
#===============================================================================
class Battle
  alias_method :pbGainExp_borrowed_original, :pbGainExp

  def pbGainExp
    if BorrowedPokemon.active?
      borrowed_id  = $PokemonGlobal.borrowed_pokemon_id
      borrowed_idx = pbParty(0).index { |p| p&.personalID == borrowed_id }
      if borrowed_idx
        @battlers.each do |b|
          next unless b&.opposes?
          next if b.participants.empty?
          next unless b.fainted? || b.captured
          if b.participants.include?(borrowed_idx)
            BorrowedPokemon.mark_participated!
            break
          end
        end
      end
    end
    pbGainExp_borrowed_original
  end
end

#===============================================================================
# Battle counter + Chapter 3 quest completion
# Increments only if the borrowed Pokémon was an active battler (gained EXP),
# caps at 10, and resets the participation flag for the next battle.
#===============================================================================
EventHandlers.add(:on_end_battle, :borrowed_pokemon_training_check,
  proc { |decision, canLose|
    next unless BorrowedPokemon.active?
    if BorrowedPokemon.find && decision != 2 && BorrowedPokemon.participated?
      target = $PokemonGlobal.borrowed_battle_target
      $PokemonGlobal.borrowed_battle_count =
        [$PokemonGlobal.borrowed_battle_count + 1, target].min
    end
    BorrowedPokemon.reset_participation!
    next unless BorrowedPokemon.ready?
    advanceQuestToStageSilent(:Chapter3, 8, colorQuest("orange"), true)
    pbMessage(_INTL("This should be enough. Let's bring Bonsly back to Albert and Ida!"))
  }
)
