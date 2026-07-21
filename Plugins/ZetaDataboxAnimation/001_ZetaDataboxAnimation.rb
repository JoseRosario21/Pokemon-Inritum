#===============================================================================
# Animated background for the Zeta Pokémon battle databox.
#
# Place a horizontal sprite strip PNG at:
#   Graphics/UI/Battle/battleZetaPlayerBoxS_anim.png  (player side)
#   Graphics/UI/Battle/battleZetaFoeBoxS_anim.png     (foe side)
#
# Each frame is the same width/height as the static Zeta box.
# The strip is N frames wide: total width = frame_width * ZETA_ANIM_FRAME_COUNT.
# Example: if the static box is 240x80 and you want 8 frames, the strip is 1920x80.
#===============================================================================
class Battle::Scene::PokemonDataBox
  # Number of frames in each horizontal strip PNG.
  ZETA_ANIM_FRAME_COUNT = 3
  # Seconds each frame is held before advancing.
  ZETA_ANIM_FRAME_TIME = 0.1

  #-----------------------------------------------------------------------------
  # Flag whether this databox instance uses the animated Zeta background.
  # Stored during initializeDataBoxGraphic so initializeOtherGraphics can read it.
  #-----------------------------------------------------------------------------
  alias zeta_anim_orig_initializeDataBoxGraphic initializeDataBoxGraphic
  def initializeDataBoxGraphic(sideSize)
    zeta_anim_orig_initializeDataBoxGraphic(sideSize)
    @zeta_animated = @battler.zeta? && sideSize == 1
  end

  #-----------------------------------------------------------------------------
  # Create the animated background sprite after the main graphics are ready.
  # The bg sprite sits one z-level behind self, which holds text/icons on a
  # transparent bitmap — so the animation shows through cleanly.
  #-----------------------------------------------------------------------------
  alias zeta_anim_orig_initializeOtherGraphics initializeOtherGraphics
  def initializeOtherGraphics(viewport)
    zeta_anim_orig_initializeOtherGraphics(viewport)
    return if !@zeta_animated
    onPlayerSide = @battler.index.even?
    strip_file = onPlayerSide ?
      "Graphics/UI/Battle/battleZetaPlayerBoxS_anim.png" :
      "Graphics/UI/Battle/battleZetaFoeBoxS_anim.png"
    unless File.exist?(strip_file)
      @zeta_animated = false
      return
    end
    @zeta_strip_bitmap = Bitmap.new(strip_file)
    @zeta_frame_width  = @zeta_strip_bitmap.width / ZETA_ANIM_FRAME_COUNT
    @zeta_frame_height = @zeta_strip_bitmap.height
    @zeta_anim_frame   = 0
    @zeta_anim_timer   = System.uptime
    @zeta_bg_sprite = Sprite.new(viewport)
    @zeta_bg_sprite.bitmap   = @zeta_strip_bitmap
    @zeta_bg_sprite.src_rect = Rect.new(0, 0, @zeta_frame_width, @zeta_frame_height)
    @zeta_bg_sprite.z        = self.z - 1
    @zeta_bg_sprite.visible  = false  # starts hidden; visible= will sync it
    @sprites["zetaBg"] = @zeta_bg_sprite
  end

  #-----------------------------------------------------------------------------
  # When the animated bg sprite is active, skip baking the static graphic into
  # @contents. The text/icon layer (@contents) stays transparent at the back,
  # letting the animated sprite show through underneath.
  #-----------------------------------------------------------------------------
  alias zeta_anim_orig_draw_background draw_background
  def draw_background
    return if @zeta_animated
    zeta_anim_orig_draw_background
  end

  #-----------------------------------------------------------------------------
  # Propagate position and depth to the background sprite.
  # visibility/opacity/color already propagate via the @sprites hash iteration.
  #-----------------------------------------------------------------------------
  alias zeta_anim_orig_x= x=
  def x=(value)
    send(:zeta_anim_orig_x=, value)
    @zeta_bg_sprite.x = value if @zeta_bg_sprite
  end

  alias zeta_anim_orig_y= y=
  def y=(value)
    send(:zeta_anim_orig_y=, value)
    @zeta_bg_sprite.y = value if @zeta_bg_sprite
  end

  alias zeta_anim_orig_z= z=
  def z=(value)
    send(:zeta_anim_orig_z=, value)
    @zeta_bg_sprite.z = value - 1 if @zeta_bg_sprite
  end

  #-----------------------------------------------------------------------------
  # Dispose the raw strip bitmap. The sprite itself is in @sprites so it gets
  # disposed by pbDisposeSpriteHash inside the original dispose.
  #-----------------------------------------------------------------------------
  alias zeta_anim_orig_dispose dispose
  def dispose
    @zeta_strip_bitmap&.dispose
    @zeta_strip_bitmap = nil
    zeta_anim_orig_dispose
  end

  #-----------------------------------------------------------------------------
  # Advance the animation frame based on elapsed time.
  # The loop is purely timer-driven so it stays in sync even while the box is
  # hidden (moves, cutscenes, entry slide). When the box reappears it picks up
  # at the correct frame naturally.
  #-----------------------------------------------------------------------------
  def update_zeta_animation
    return if !@zeta_animated || !@zeta_bg_sprite
    new_frame = ((System.uptime - @zeta_anim_timer) / ZETA_ANIM_FRAME_TIME).floor % ZETA_ANIM_FRAME_COUNT
    return if new_frame == @zeta_anim_frame
    @zeta_anim_frame = new_frame
    @zeta_bg_sprite.src_rect.x = @zeta_anim_frame * @zeta_frame_width
  end

  alias zeta_anim_orig_update update
  def update
    zeta_anim_orig_update
    update_zeta_animation
  end
end
