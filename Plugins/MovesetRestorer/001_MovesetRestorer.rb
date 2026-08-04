#===============================================================================
# Moveset Restorer
#
# Closes a real hole in the GameUpdater pipeline: when a patch changes a
# species' learnset, Pokemon already in a save keep whatever they had. They can
# end up knowing moves the species no longer learns, or missing moves it now
# gets -- and nothing in the game ever tells the player or offers a fix.
#
# How it works:
#
#   1. A fingerprint of every species' level-up learnset is stored in the save.
#   2. On load, fingerprints are compared against the current PBS data.
#   3. Any Pokemon whose species changed is offered a restore: its level-up
#      moveset for its current level, keeping anything it still legally knows.
#
# The player is always asked. A patch that deliberately removes a move from a
# learnset should not silently strip it from a Pokemon someone has raised.
#===============================================================================
module MovesetRestorer
  # Ask about this on load. Turn off to make it debug-menu only.
  CHECK_ON_LOAD = true

  # Also scan boxes, not just the party. Slower on a full PC, but a patch does
  # not care where a Pokemon is stored.
  INCLUDE_STORAGE = true

  module_function

  #-----------------------------------------------------------------------------
  # A deterministic fingerprint of a species' level-up learnset.
  #
  # Ruby's String#hash is seeded per process, so it is NOT stable across runs and
  # cannot be used here -- this is a small FNV-1a instead, which gives the same
  # number every launch.
  #-----------------------------------------------------------------------------
  def fingerprint(species_data)
    return 0 if !species_data || !species_data.moves
    text = species_data.moves.map { |pair| "#{pair[0]}:#{pair[1]}" }.join(",")
    hash = 2_166_136_261
    text.each_byte do |b|
      hash ^= b
      hash = (hash * 16_777_619) & 0xFFFFFFFF
    end
    return hash
  end

  def current_fingerprints
    out = {}
    GameData::Species.each do |data|
      out[data.id] = fingerprint(data)
    end
    return out
  end

  #-----------------------------------------------------------------------------
  # Which species' learnsets have changed since the snapshot?
  # An empty snapshot means "first run since the plugin was added" -- that is not
  # a patch, so it records silently and reports nothing.
  #-----------------------------------------------------------------------------
  def changed_species
    return [] if !$PokemonGlobal
    stored = $PokemonGlobal.learnset_fingerprints
    return [] if stored.nil? || stored.empty?
    current = current_fingerprints
    changed = []
    current.each do |id, fp|
      next if !stored.key?(id)     # a brand-new species is an addition, not a change
      changed.push(id) if stored[id] != fp
    end
    return changed
  end

  def record_fingerprints
    return if !$PokemonGlobal
    $PokemonGlobal.learnset_fingerprints = current_fingerprints
  end

  #-----------------------------------------------------------------------------
  # Pokemon affected by a set of changed species.
  #-----------------------------------------------------------------------------
  def affected_pokemon(species_list)
    return [] if species_list.empty?
    out = []
    if $player&.party
      $player.party.each { |pkmn| out.push(pkmn) if pkmn && species_list.include?(pkmn.species) }
    end
    if INCLUDE_STORAGE && $PokemonStorage
      $PokemonStorage.maxBoxes.times do |box|
        $PokemonStorage[box].each do |pkmn|
          out.push(pkmn) if pkmn && species_list.include?(pkmn.species)
        end
      end
    end
    return out
  end

  #-----------------------------------------------------------------------------
  # The level-up moveset a Pokemon would have if caught fresh at its level.
  #-----------------------------------------------------------------------------
  def expected_moves(pkmn)
    data = GameData::Species.get_species_form(pkmn.species, pkmn.form) rescue nil
    data ||= GameData::Species.try_get(pkmn.species)
    return [] if !data || !data.moves
    moves = []
    data.moves.each do |pair|
      next if pair[0] > pkmn.level
      moves.push(pair[1])
    end
    # Last four learned, which is what a freshly caught Pokemon would know.
    return moves.uniq.last(4)
  end

  # Moves the Pokemon knows that its species can no longer learn by level-up.
  def orphaned_moves(pkmn)
    data = GameData::Species.get_species_form(pkmn.species, pkmn.form) rescue nil
    data ||= GameData::Species.try_get(pkmn.species)
    return [] if !data || !data.moves
    learnable = data.moves.map { |pair| pair[1] }
    return pkmn.moves.map(&:id).reject { |id| learnable.include?(id) }
  end

  def restore(pkmn)
    moves = expected_moves(pkmn)
    return false if moves.empty?
    pkmn.moves = moves.map { |id| Pokemon::Move.new(id) }
    return true
  end

  #-----------------------------------------------------------------------------
  # The player-facing flow.
  #-----------------------------------------------------------------------------
  def run_check(silent_if_none = true)
    changed = changed_species
    if changed.empty?
      record_fingerprints
      pbMessage(_INTL("No learnsets have changed.")) if !silent_if_none
      return 0
    end
    affected = affected_pokemon(changed)
    if affected.empty?
      record_fingerprints
      pbMessage(_INTL("Learnsets changed, but none of your Pokemon are affected.")) if !silent_if_none
      return 0
    end

    pbMessage(_INTL("This update changed the moves some Pokemon can learn.\1"))
    pbMessage(_INTL("{1} of your Pokemon are affected. You can restore each one's moves, or keep what it has.",
                    affected.length))

    restored = 0
    affected.each do |pkmn|
      expected = expected_moves(pkmn)
      next if expected.empty?
      current_names = pkmn.moves.map { |m| m.name }.join(", ")
      new_names = expected.map { |id| GameData::Move.try_get(id)&.name || id.to_s }.join(", ")
      next if current_names == new_names   # nothing would actually change
      orphans = orphaned_moves(pkmn)
      msg = _INTL("{1}\nNow knows: {2}", pkmn.name, current_names)
      msg += _INTL("\nNo longer learnable: {1}",
                   orphans.map { |id| GameData::Move.try_get(id)&.name || id.to_s }.join(", ")) if !orphans.empty?
      msg += _INTL("\nRestore to: {1}", new_names)
      if pbConfirmMessage(msg)
        restored += 1 if restore(pkmn)
      end
    end

    record_fingerprints
    pbMessage(_INTL("{1} Pokemon had their moves restored.", restored)) if restored > 0
    return restored
  end
end

#===============================================================================
# Storage on the save.
#===============================================================================
class PokemonGlobalMetadata
  def learnset_fingerprints
    @learnset_fingerprints = nil if !defined?(@learnset_fingerprints)
    return @learnset_fingerprints
  end

  def learnset_fingerprints=(value)
    @learnset_fingerprints = value
  end
end

#===============================================================================
# Trigger. Runs once per session, on the first map entered after loading, so it
# never interrupts a cutscene mid-transfer.
#===============================================================================
EventHandlers.add(:on_enter_map, :moveset_restorer_check,
  proc {
    next if !MovesetRestorer::CHECK_ON_LOAD
    next if $game_temp.moveset_check_done
    $game_temp.moveset_check_done = true
    begin
      MovesetRestorer.run_check(true)
    rescue StandardError => e
      echoln("[Moveset Restorer] check failed: #{e.message}") if $DEBUG
    end
  }
)

class Game_Temp
  attr_accessor :moveset_check_done
end

#===============================================================================
MenuHandlers.add(:debug_menu, :moveset_restorer, {
  "name"        => _INTL("Check learnset changes"),
  "parent"      => :pokemon_menu,
  "description" => _INTL("Compare stored learnsets against current PBS data and offer to restore affected Pokemon."),
  "effect"      => proc {
    MovesetRestorer.run_check(false)
    next false
  }
})
