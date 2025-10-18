#===
# Adding Terrain Tags for Rock Climb
# Edit Terrain Tag if needed
#===
module GameData
  class TerrainTag
    attr_reader :rock_climb_tag
    attr_reader :RockClimb
    attr_reader :RockCrest

	alias initialize_RockClimb initialize
    def initialize(hash)
	  initialize_RockClimb(hash)
      @rock_climb_tag         = hash[:rock_climb_tag]   || false
      @RockClimb              = hash[:RockClimb]  || false
      @RockCrest              = hash[:RockCrest]  || false
    end
  end
end

GameData::TerrainTag.register({
  :id                     => :RockClimb,
  :id_number              => 17,   #Default: 17
  :rock_climb_tag         => true,
  :RockClimb              => true
})

GameData::TerrainTag.register({
  :id                     => :RockCrest,
  :id_number              => 18,   #Default: 18
  :rock_climb_tag         => true,
  :RockCrest              => true
})

#===
# All Hidden Move Configurations
#===
EventHandlers.add(:on_player_interact, :rockclimbing,
  proc { |_sender, _e|
    terrain = $game_player.pbFacingTerrainTag
    if terrain.rock_climb_tag
      pbRockClimb
    end
  }
)
HiddenMoveHandlers::CanUseMove.add(:ROCKCLIMB,proc { |move,pkmn|
  next false if !pbCheckHiddenMoveBadge(RockClimbSettings::BADGE_FOR_ROCKCLIMB)
  if !$game_player.pbFacingTerrainTag.rock_climb_tag || ($game_player.direction == 2 && !RockClimbSettings::ENABLE_DESCENDING)
    pbMessage(_INTL("Can't use that here."))
    next false
  end
  next true
})

HiddenMoveHandlers::UseMove.add(:ROCKCLIMB,proc { |move,pokemon|
  if !pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL("{1} used {2}!",pokemon.name,GameData::Move.get(move).name))
  end
  pbRockClimbMain
  next true
})

#===
# Rock Climb Hidden Move Check
#===
def pbRockClimb
  move = :ROCKCLIMB
  movefinder = $player.get_pokemon_with_move(move)
  pbMessage(_INTL("A wall of rock is in front of you."))
  return false if !pbCheckHiddenMoveBadge(RockClimbSettings::BADGE_FOR_ROCKCLIMB) || (!$DEBUG && !movefinder)
  return false if $game_player.direction != 8 && ($game_player.direction == 2 && !RockClimbSettings::ENABLE_DESCENDING)
  if pbConfirmMessage(_INTL("Would you like to use Rock Climb?"))
    speciesname = !movefinder ? $player.name : movefinder.name
    pbMessage(_INTL("{1} used Rock Climb.",speciesname))
    pbHiddenMoveAnimation(movefinder)
    pbRockClimbMain
    return true
  end
  return false
end

#===
# Rock Climb Main Function
#===
def pbRockClimbMain
  old_through = $game_player.through
  $game_player.through = true
  pbRockClimbStart
  $game_temp.rock_climb_base_coords = nil
  
  old_speed = $game_player.move_speed
  $game_player.move_speed = RockClimbSettings::ROCK_CLIMB_SPEED

  case $game_player.direction
  when 2
    pbDescendRock
  else
    pbAscendRock
  end
  
  $game_player.move_speed = old_speed
  pbRockClimbEnd
  $game_player.through = old_through
end

#===
# Rock Climb Start Function
#===
def pbRockClimbStart
  pbCancelVehicles
  $PokemonGlobal.rockclimbing = true
  $PokemonEncounters.reset_step_count
  pbUpdateVehicle
  $game_temp.rock_climb_base_coords = $map_factory.getFacingCoords($game_player.x, $game_player.y, $game_player.direction)
  $game_player.jumpForward
  while $game_player.jumping?
    Graphics.update
    Input.update
    pbUpdateSceneMap
  end
end

#===
# Rock Climb End Function
#===
def pbRockClimbEnd
  return false if !$PokemonGlobal.rockclimbing
  return false if $game_player.pbFacingTerrainTag.rock_climb_tag
  $game_temp.rock_climb_base_coords = [$game_player.x, $game_player.y]
  if $game_player.jumpForward
    $game_temp.rock_climb_base_coords = nil
    $PokemonGlobal.rockclimbing = false
    return true
  end
  return false
end

#===
# Rock Climb Ascending Animation
#===
def pbAscendRock
  counter = 0
  loop do
    pbSEPlay(RockClimbSettings::ROCK_CLIMB_SFX)
    $game_player.move_up
    rock = $scene.spriteset.addUserAnimation(RockClimbSettings::ROCK_CRUMBLE_ANIMATION_ID,$game_player.x,$game_player.y,true,0)
    until !$game_player.moving? do
      rock = $scene.spriteset.addUserAnimation(RockClimbSettings::ROCK_CRUMBLE_ANIMATION_ID,$game_player.x,$game_player.y,true,0) if rock.disposed?
      dust = $scene.spriteset.addUserAnimation(RockClimbSettings::ROCK_DUST_ANIMATION_UP_ID,$game_player.x,$game_player.y,true,1) if counter % 4 == 0
      Graphics.update
      pbUpdateSceneMap
      counter += 1
    end
    terrain = $game_player.pbFacingTerrainTag
    break if !terrain.RockClimb && !terrain.RockCrest
  end
end

#===
# Rock Climb Descending [No Animation]
#===
def pbDescendRock
  counter = 0
  loop do
    pbSEPlay(RockClimbSettings::ROCK_CLIMB_SFX)
    $game_player.move_down
    rock = $scene.spriteset.addUserAnimation(RockClimbSettings::ROCK_CRUMBLE_ANIMATION_ID,$game_player.x,$game_player.y,true,0)
    until !$game_player.moving? do
      rock = $scene.spriteset.addUserAnimation(RockClimbSettings::ROCK_CRUMBLE_ANIMATION_ID,$game_player.x,$game_player.y,true,0) if rock.disposed?
      dust = $scene.spriteset.addUserAnimation(RockClimbSettings::ROCK_DUST_ANIMATION_DOWN_ID,$game_player.x,$game_player.y,true,0) if counter % 4 == 0
      Graphics.update
      pbUpdateSceneMap
      counter += 1
    end
    terrain = $game_player.pbFacingTerrainTag
    break if !terrain.RockClimb && !terrain.RockCrest
  end
end

#===
# Adds Rock Climbing to $PokemonGlobal
#===
class PokemonGlobalMetadata
  attr_accessor :rockclimbing

  alias initialize_RockClimb initialize
  def initialize
    initialize_RockClimb
    @rockclimbing = false
  end
end

#===
# Adds the Rock Climb Base Spirte
#===
class Sprite_Character
  alias initialize_RockClimb initialize
  def initialize(viewport, character = nil)
    @rockclimbbase = Sprite_RockClimbBase.new(self, viewport) if character == $game_player
    initialize_RockClimb(viewport,character)
  end

  alias dispose_RockClimb dispose
  def dispose
    dispose_RockClimb
    @rockclimbbase&.dispose
    @rockclimbbase = nil
  end

  alias update_RockClimb update
  def update
    update_RockClimb
    @rockclimbbase&.update
  end
end

#===
# Overwrites functions locally to add the Rock Climb section
#===
class Game_Map
  alias playerPassable_RockClimb playerPassable?
  def playerPassable?(x, y, d, self_event = nil)
    [2, 1, 0].each do |i|
      tile_id = data[x, y, i]
      next if tile_id == 0
      terrain = GameData::TerrainTag.try_get(@terrain_tags[tile_id])
      if terrain
        return true if $PokemonGlobal.rockclimbing && terrain.rock_climb_tag
      end
    end
    return playerPassable_RockClimb(x, y, d, self_event)
  end
end

class Game_Character
  attr_accessor :pattern_rockclimb

  alias initialize_RockClimb initialize
  def initialize(map = nil)
    initialize_RockClimb(map)
    @pattern_rockclimb = 0
  end
end

#===
# Overwrites functions locally to add the Rock Climb check
#===
class Game_Player < Game_Character
  alias can_run_RockClimb can_run?
  def can_run?
    return false if $PokemonGlobal.rockclimbing
    can_run_RockClimb
  end
  
  alias set_movement_type_RockClimb set_movement_type
  def set_movement_type(type)
    meta = GameData::PlayerMetadata.get($player&.character_ID || 1)
    case type
    when :rockclimbing, :rockclimbing_stopped
      new_charset = pbGetPlayerCharset(meta.surf_charset)
      @character_name = new_charset if new_charset
    else
      set_movement_type_RockClimb(type)
    end
  end

  alias update_move_RockClimb update_move
  def update_move
    if !@moved_last_frame || @stopped_last_frame   # Started a new step
      if $PokemonGlobal&.rockclimbing
        set_movement_type(:rockclimbing)
      else
        update_move_RockClimb
      end
    end
    super
  end

  alias update_stop_RockClimb update_stop
  def update_stop
    if @stopped_last_frame
      if $PokemonGlobal&.rockclimbing
        set_movement_type(:rockclimbing_stopped)
      else
        update_stop_RockClimb
      end
    end
    super
  end

  alias pbUpdateVehicle_RockClimb pbUpdateVehicle
  def pbUpdateVehicle
    if $PokemonGlobal&.rockclimbing
      $game_player.set_movement_type(:rockclimbing)
    else
      pbUpdateVehicle_RockClimb
    end
  end
  
  alias refresh_charset_RockClimb refresh_charset
  def refresh_charset
    meta = GameData::PlayerMetadata.get($player&.character_ID || 1)
    if $PokemonGlobal&.rockclimbing
      new_charset = pbGetPlayerCharset(meta.surf_charset)
      new_charset ? @character_name = new_charset : refresh_charset_RockClimb
    else
      refresh_charset_RockClimb
    end
  end
end