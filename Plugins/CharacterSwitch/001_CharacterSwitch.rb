#===============================================================================
# Character Switch
#
# Hands control to a different playable character for a scene or a chapter, then
# gives the player their own save back exactly as it was.
#
# Rejuvenation does this with ~600 lines of hardcoded `when "Aelita Nightmare"`
# branches. Only the last hundred lines of that are reusable -- the
# backup/restore protocol -- so that is what this is, driven by a data table.
#
# Usage from an event Script command:
#
#   pbSwitchCharacter(:AELITA)   # become Aelita; the player's state is stashed
#   ...cutscene...
#   pbRestorePlayer              # give the player back, exactly as before
#
# Or scoped, which restores even if the block raises:
#
#   pbAsCharacter(:AELITA) { ... }
#
# While switched, $game_switches[NOT_PLAYER_SWITCH] is true so events can branch
# on "this isn't the real player", and money loss on defeat is suppressed.
#===============================================================================
module CharacterSwitch
  # A switch events can check to tell whether the party belongs to the player.
  NOT_PLAYER_SWITCH = :NotPlayerCharacter

  #-----------------------------------------------------------------------------
  # The cast. Everything is optional except :player_id.
  #
  #   :name       String   Display name (defaults to the metadata name)
  #   :player_id  Integer  GameData::PlayerMetadata id -- the sprite set
  #   :outfit     Integer  Outfit index
  #   :party      Array    [[species, level], ...] or a trainer to load
  #   :trainer    Array    [trainer_type, name, party_id] loaded via pbGetTrainer
  #   :items      Array    [[item, qty], ...] given to the temporary bag
  #   :money      Integer  Money for this character
  #   :keep_bag   Boolean  Use the player's real bag instead of an empty one
  #   :keep_party Boolean  Use the player's real party (for "you, but disguised")
  #-----------------------------------------------------------------------------
  CHARACTERS = {
    :MERYL => {
      :name      => "Meryl",
      :player_id => 1,
      :outfit    => 0,
      :party     => [[:PRIMARINA, 40]],
      :items     => [[:POTION, 2]],
      :money     => 500
    }
  }

  module_function

  def character(id)
    return CHARACTERS[id.to_sym]
  end

  def switched?
    return $PokemonGlobal && !$PokemonGlobal.character_switch_backup.nil?
  end
end

#===============================================================================
# The stash. Held on PokemonGlobalMetadata so it survives a save made mid-swap
# -- a player who saves during a switched chapter must still be restorable.
#===============================================================================
class PokemonGlobalMetadata
  def character_switch_backup
    @character_switch_backup = nil if !defined?(@character_switch_backup)
    return @character_switch_backup
  end

  def character_switch_backup=(value)
    @character_switch_backup = value
  end
end

module CharacterSwitch
  module_function

  #-----------------------------------------------------------------------------
  # Backup / restore
  #
  # Deliberately stores references, not deep copies: the point is to hand back
  # the exact same objects, and a Marshal round-trip of a party is both slow and
  # a chance to lose something a plugin attached to a Pokemon.
  #-----------------------------------------------------------------------------
  def backup_player
    return {
      :name         => $player.name,
      :character_id => $player.character_ID,
      :outfit       => $player.outfit,
      :party        => $player.party,
      :money        => $player.money,
      :bag          => $PokemonBag,
      :storage      => $PokemonStorage
    }
  end

  def apply_backup(backup)
    return if !backup
    $player.name         = backup[:name]
    $player.character_ID = backup[:character_id] if backup[:character_id]
    $player.outfit       = backup[:outfit]       if backup[:outfit]
    $player.party        = backup[:party]
    $player.money        = backup[:money]
    $PokemonBag          = backup[:bag]         if backup[:bag]
    $PokemonStorage      = backup[:storage]     if backup[:storage]
  end

  #-----------------------------------------------------------------------------
  def build_party(config)
    return $player.party if config[:keep_party]
    party = []
    if config[:trainer].is_a?(Array)
      begin
        # GameData::Trainer.get(type, name, version) -> .to_trainer builds the
        # real NPCTrainer with its party, which is how the battle system does it.
        tr_type, tr_name, tr_version = config[:trainer]
        data = GameData::Trainer.get(tr_type, tr_name, tr_version || 0)
        trainer = data&.to_trainer
        party = trainer.party if trainer && trainer.party
      rescue StandardError => e
        echoln("[Character Switch] could not load trainer #{config[:trainer].inspect}: #{e.message}")
      end
    end
    if party.empty? && config[:party].is_a?(Array)
      config[:party].each do |entry|
        species, level = entry
        next if species.nil?
        begin
          party.push(Pokemon.new(species, level || 5, $player))
        rescue StandardError => e
          echoln("[Character Switch] could not create #{species}: #{e.message}")
        end
      end
    end
    return party
  end

  def build_bag(config)
    return $PokemonBag if config[:keep_bag]
    bag = PokemonBag.new
    (config[:items] || []).each do |entry|
      item, qty = entry
      bag.add(item, qty || 1) rescue nil
    end
    return bag
  end

  #-----------------------------------------------------------------------------
  def switch_to(id)
    config = character(id)
    if !config
      echoln("[Character Switch] no character defined for #{id.inspect}")
      return false
    end
    # Nested switches would overwrite the original stash and lose the real
    # player for good, so restore first.
    restore if switched?

    $PokemonGlobal.character_switch_backup = backup_player

    pbChangePlayer(config[:player_id]) if config[:player_id]
    $player.name   = config[:name]   if config[:name]
    $player.outfit = config[:outfit] if config[:outfit]
    $player.party  = build_party(config)
    $PokemonBag    = build_bag(config)
    $player.money  = config[:money] || 0

    $game_switches[NOT_PLAYER_SWITCH] = true
    $game_temp.character_switch_id = id.to_sym
    return true
  end

  def restore
    backup = $PokemonGlobal&.character_switch_backup
    return false if !backup
    apply_backup(backup)
    $PokemonGlobal.character_switch_backup = nil
    $game_switches[NOT_PLAYER_SWITCH] = false
    $game_temp.character_switch_id = nil
    return true
  end
end

class Game_Temp
  attr_accessor :character_switch_id
end

#===============================================================================
# Event-facing helpers
#===============================================================================
def pbSwitchCharacter(id)
  return CharacterSwitch.switch_to(id)
end

def pbRestorePlayer
  return CharacterSwitch.restore
end

# Scoped form. Restores even if the block raises, which matters because a
# cutscene crashing mid-swap would otherwise strand the player as someone else.
def pbAsCharacter(id)
  switched = CharacterSwitch.switch_to(id)
  begin
    yield if block_given?
  ensure
    CharacterSwitch.restore if switched
  end
end

def pbIsCharacterSwitched?
  return CharacterSwitch.switched?
end

#===============================================================================
# While switched, losing a battle must not cost the real player money -- the
# wallet on screen belongs to a temporary character.
#===============================================================================
class Battle
  # Guarded on the base method existing: if a future Essentials version renames
  # or removes pbLoseMoney, skipping this is a lost nicety, whereas an
  # unguarded alias would be a NameError at boot.
  if method_defined?(:pbLoseMoney) && !method_defined?(:character_switch_pbLoseMoney)
    alias character_switch_pbLoseMoney pbLoseMoney

    def pbLoseMoney
      return if CharacterSwitch.switched?
      character_switch_pbLoseMoney
    end
  end
end
