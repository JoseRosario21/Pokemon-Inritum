#-------------------------------------------------------------------------------
# Phenomenon: BW Style Grass Rustle, Water Drops, Cave Dust & Flying Birds
# v3.0 by Boonzeet with code help from Maruno & Marin, Grass graphic by DaSpirit
# v20.1 Upgrade with help from Ned & Vendily
#-------------------------------------------------------------------------------
# Please give credit when using. Changes in this version:
# - Upgraded for Essentials v20.1
# - Updates to algorithms for efficiency
#===============================================================================
# Main code
#-------------------------------------------------------------------------------
# SUPPORT CAN'T BE PROVIDED FOR EDITS MADE TO THIS FILE.
#===============================================================================

class Array # Add quick random array fetch - by Marin
  def random
    self[rand(size)]
  end
end

class PhenomenonInstance
  attr_accessor :timer, :x, :y, :type, :active, :drawing # number # symbol # bool # bool

  def initialize(types)
    echoln("Initializing for map with types: #{types}")
    @x = nil
    @y = nil
    @types = types
    timer_val = PhenomenonConfig::Frequency <= 60 ? 60 : rand(PhenomenonConfig::Frequency - 60) + 6
    @timer = Graphics.frame_count + timer_val
    @active = false
  end
end

class Phenomenon
  @@instance = nil
  @@possible = false
  @@activated = false
  @@expBoost = false
  @@types = nil

  class << self
    attr_accessor :instance, :possible, :activated, :expBoost, :types # [x,y,type,timer]    # bool   # bool
  end

  def self.generate
    echoln '## self.generate ##'
    ph = instance
    return unless ph

    echoln("Generating phenomena...\n")
    phenomenon_tiles = [] # x, y, type
    # limit range to around the player
    x_range = [[$game_player.x - 16, 0].max, [$game_player.x + 16, $game_map.width].min]
    y_range = [[$game_player.y - 16, 0].max, [$game_player.y + 16, $game_map.height].min]
    hasGrass = types.include?(:PhenomenonGrass)
    hasWater = types.include?(:PhenomenonWater)
    hasCave = types.include?(:PhenomenonCave)
    hasBird = types.include?(:PhenomenonBird)
    # list all grass tiles
    blocked_tiles = nil
    if PhenomenonConfig::BlockedTiles.key?($game_map.map_id)
      blocked_tiles = PhenomenonConfig::BlockedTiles[$game_map.map_id]
    end
    for x in x_range[0]..x_range[1]
      for y in y_range[0]..y_range[1]
        unless blocked_tiles.nil?
          next if blocked_tiles[:x] && blocked_tiles[:x].include?(x)
          next if blocked_tiles[:y] && blocked_tiles[:x].include?(y)
          next if blocked_tiles[:tiles] && blocked_tiles[:x].include?([x, y])
        end
        terrain_tag = $game_map.terrain_tag(x, y)
        if hasGrass && terrain_tag.id == :Grass
          phenomenon_tiles.push([x, y, :PhenomenonGrass])
        elsif hasWater && %i[Water StillWater].include?(terrain_tag.id)
          phenomenon_tiles.push([x, y, :PhenomenonWater])
        elsif hasCave && !terrain_tag.can_surf && $map_factory.isPassableStrict?($game_map.map_id, x, y, $game_player)
          phenomenon_tiles.push([x, y, :PhenomenonCave])
        elsif hasBird && terrain_tag.id == :BirdBridge && $map_factory.isPassableStrict?($game_map.map_id, x, y,
                                                                                         $game_player)
          phenomenon_tiles.push([x, y, :PhenomenonBird])
        end
      end
    end
    if phenomenon_tiles.length == 0
      Kernel.echoln("A phenomenon is set up but no compatible tiles are available! Phenomena: #{@types}")
      cancel
    else
      selected_tile = phenomenon_tiles.random
      ph.x = selected_tile[0]
      ph.y = selected_tile[1]
      ph.type = selected_tile[2]
      ph.timer = Graphics.frame_count + PhenomenonConfig::Timer
      ph.active = true
    end
  end

  def self.activate
    ph = instance
    Kernel.echoln("Activating phenomenon for #{ph.type}")
    item = nil
    chance = rand(10) # Different types have chance different effects, e.g. items in caves
    encounter = $PokemonEncounters.choose_wild_pokemon(ph.type)
    if ph.type == :PhenomenonCave && chance < 5
      item = chance > 0 ? PhenomenonConfig::Items[:commonCave].random : PhenomenonConfig::Items[:rareCave].random
    elsif ph.type == :PhenomenonBird && chance < 8
      item = chance > 0 ? PhenomenonConfig::Items[:bird].random : :PRETTYWING
    end
    if !item.nil?
      cancel
      pbReceiveItem(item)
    elsif !encounter.nil?
      if PhenomenonConfig::BattleMusic != '' && FileTest.audio_exist?("Audio/BGM/#{PhenomenonConfig::BattleMusic}")
        $PokemonGlobal.nextBattleBGM = PhenomenonConfig::BattleMusic
      end
      $game_temp.force_single_battle
      self.activated = true
      WildBattle.start(encounter[0], encounter[1])
    end
  end

  def self.drawAnim(_sound)
    return unless instance
    return if @waiting

    x = instance.x
    y = instance.y
    dist = (((x - $game_player.x).abs + (y - $game_player.y).abs) / 4).floor
    if dist <= 6 && dist >= 0
      animation = PhenomenonConfig::Types[instance.type]
      $scene.spriteset.addUserAnimation(animation[0], x, y, true, animation[2])
      pbSEPlay(animation[1], [75, 65, 55, 40, 27, 22, 15][dist]) # if sound
    end
    # pbWait(1)

    pbWaitAsync(0.5) do
      instance.drawing = false if instance
    end

    # instance.drawing = false if instance
  end

  def self.cancel
    self.instance = nil
  end

  def self.load_types
    types = []
    PhenomenonConfig::Types.each do |(key, _value)|
      # Kernel.echo("Testing map #{$game_map.map_id}, against #{key}, with value #{value}...\n")
      types.push(key) if $PokemonEncounters && $PokemonEncounters.map_has_encounter_type?($game_map.map_id, key)
    end
    self.possible = types.size > 0 && $player.party.length > 0 # set to false if no encounters for map or trainer has no pokemon ($Trainer to $player)
    self.types = types
  end

  def self.waiting?
    defined?(instance) && !instance.nil? && !instance.active
  end

  # Returns true if an existing phenomenon has been set up and exists
  def self.active?
    defined?(instance) && !instance.nil? && instance.active
  end

  # Returns true if there's a phenomenon and the player is on top of it
  def self.playerOn?
    active? && $game_player.x == instance.x && $game_player.y == instance.y
  end
end
