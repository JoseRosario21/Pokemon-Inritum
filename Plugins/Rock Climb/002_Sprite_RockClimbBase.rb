class Game_Temp
  attr_accessor :rock_climb_base_coords  # [x, y] while jumping on/off rock climb base
  attr_accessor :rock_climb_base_dir     # direction of base
end

#===
# Overwrites functions locally to add Rock Climb base pattern
#===
class Game_Player < Game_Character
  alias update_pattern_rockclimb update_pattern
  def update_pattern
    if $PokemonGlobal&.rockclimbing
      bob_pattern = (4 * System.uptime / RockClimbSettings::ROCK_CLIMB_BOB_DURATION).to_i % 4
      @pattern = bob_pattern if !@lock_pattern
      @pattern_rockclimb = bob_pattern
      @bob_height = (bob_pattern >= 2) ? 2 : 0
      @anime_count = 0
    else
      update_pattern_rockclimb
    end
  end
end

#===
# Creates a new Rock Climb base when $PokemonGlobal.rockclimbing is toggled
#===
class Sprite_RockClimbBase
  attr_reader   :visible

  def initialize(parent_sprite, viewport = nil)
    @parent_sprite = parent_sprite
    @sprite = nil
    @viewport = viewport
    @disposed = false
    @rockclimbbitmap = AnimatedBitmap.new("Graphics/Characters/" + RockClimbSettings::ROCKCLIMB_BASE)
    RPG::Cache.retain("Graphics/Characters/" + RockClimbSettings::ROCKCLIMB_BASE)
    @cw = @rockclimbbitmap.width / 4
    @ch = @rockclimbbitmap.height / 4
    update
  end

  def dispose
    return if @disposed
    @sprite.dispose if @sprite
    @sprite   = nil
    @rockclimbbitmap.dispose
    @disposed = true
  end

  def disposed?
    return @disposed
  end

  def event
    return @parent_sprite.character
  end

  def visible=(value)
    @visible = value
    @sprite.visible = value if @sprite && !@sprite.disposed?
  end

  def update
    return if disposed?
    if !$PokemonGlobal.rockclimbing
      # Just-in-time disposal of sprite
      if @sprite
        @sprite.dispose
        @sprite = nil
      end
      return
    end
    # Just-in-time creation of sprite
    @sprite = Sprite.new(@viewport) if !@sprite
    return if !@sprite
    @sprite.bitmap = @rockclimbbitmap.bitmap if $PokemonGlobal.rockclimbing
    event.direction = $game_temp.rock_climb_base_dir if $game_temp.rock_climb_base_dir
    sx = event.pattern_rockclimb * @cw
    sy = ((event.direction - 2) / 2) * @ch
    @sprite.src_rect.set(sx, sy, @cw, @ch)
    if $game_temp.rock_climb_base_coords
      spr_x = ((($game_temp.rock_climb_base_coords[0] * Game_Map::REAL_RES_X) - event.map.display_x).to_f / Game_Map::X_SUBPIXELS).round
      spr_x += (Game_Map::TILE_WIDTH / 2)
      spr_x = ((spr_x - (Graphics.width / 2)) * TilemapRenderer::ZOOM_X) + (Graphics.width / 2) if TilemapRenderer::ZOOM_X != 1
      @sprite.x = spr_x
      spr_y = ((($game_temp.rock_climb_base_coords[1] * Game_Map::REAL_RES_Y) - event.map.display_y).to_f / Game_Map::Y_SUBPIXELS).round
      spr_y += (Game_Map::TILE_HEIGHT / 2) + 16
      spr_y = ((spr_y - (Graphics.height / 2)) * TilemapRenderer::ZOOM_Y) + (Graphics.height / 2) if TilemapRenderer::ZOOM_Y != 1
      @sprite.y = spr_y
    else
      @sprite.x = @parent_sprite.x
      @sprite.y = @parent_sprite.y
    end
    @sprite.ox      = @cw / 2
    @sprite.oy      = @ch - 16   # Assume base needs offsetting
    @sprite.oy      -= event.bob_height
    @sprite.z       = event.screen_z(@ch) - 1
    @sprite.zoom_x  = @parent_sprite.zoom_x
    @sprite.zoom_y  = @parent_sprite.zoom_y
    @sprite.tone    = @parent_sprite.tone
    @sprite.color   = @parent_sprite.color
    @sprite.opacity = @parent_sprite.opacity
  end
end