#===============================================================================
# Overworld Battle Animation Player
# Plays battle animations (from PkmnAnimations.rxdata) on the map.
#===============================================================================

#===============================================================================
# Lightweight animation player adapted from PBAnimationPlayerX for use outside
# of battle. Strips out battler sprite dependencies and renders directly to
# the given viewport.
#===============================================================================
class PBAnimationPlayerOverworld
  MAX_SPRITES = 60

  def initialize(animation, viewport)
    @animation   = animation
    @viewport    = viewport
    @looping     = false
    @animbitmap  = nil
    @old_frame   = -1
    @frame       = -1
    @timer_start = nil
    @oldbg       = []
    @oldfo       = []
    @center_x    = viewport.rect.width / 2
    @center_y    = viewport.rect.height / 2
    initializeSprites
  end

  def initializeSprites
    @animsprites = []
    @animsprites[0] = nil
    @animsprites[1] = nil
    (2...MAX_SPRITES).each do |i|
      @animsprites[i] = Sprite.new(@viewport)
      @animsprites[i].bitmap  = nil
      @animsprites[i].visible = false
    end
    @bgColor = ColoredPlane.new(Color.black, @viewport)
    @bgColor.z       = 5
    @bgColor.opacity = 0
    @bgColor.refresh
    @bgGraphic = AnimatedPlane.new(@viewport)
    @bgGraphic.setBitmap(nil)
    @bgGraphic.z       = 5
    @bgGraphic.opacity = 0
    @bgGraphic.refresh
    @foColor = ColoredPlane.new(Color.black, @viewport)
    @foColor.z       = 85
    @foColor.opacity = 0
    @foColor.refresh
    @foGraphic = AnimatedPlane.new(@viewport)
    @foGraphic.setBitmap(nil)
    @foGraphic.z       = 85
    @foGraphic.opacity = 0
    @foGraphic.refresh
  end

  def dispose
    @animbitmap&.dispose
    (2...MAX_SPRITES).each { |i| @animsprites[i]&.dispose }
    @bgGraphic.dispose
    @bgColor.dispose
    @foGraphic.dispose
    @foColor.dispose
  end

  def start
    @frame = 0
    @timer_start = System.uptime
  end

  def animDone?
    return @frame < 0
  end

  def update
    return if @frame < 0
    @frame = ((System.uptime - @timer_start) * 20).to_i
    if @frame >= @animation.length
      if @looping
        @frame %= @animation.length
        @timer_start += @animation.length / 20.0
      else
        @frame = -1
        @animbitmap&.dispose
        @animbitmap = nil
        return
      end
    end
    if !@animbitmap || @animbitmap.disposed?
      @animbitmap = AnimatedBitmap.new("Graphics/Animations/" + @animation.graphic,
                                       @animation.hue).deanimate
      MAX_SPRITES.times do |i|
        @animsprites[i].bitmap = @animbitmap if @animsprites[i]
      end
    end
    @bgGraphic.update
    @bgColor.update
    @foGraphic.update
    @foColor.update
    return if @frame == @old_frame
    @old_frame = @frame
    thisframe = @animation[@frame]
    MAX_SPRITES.times { |i| @animsprites[i].visible = false if @animsprites[i] }
    thisframe.length.times do |i|
      cel = thisframe[i]
      next if !cel
      sprite = @animsprites[i]
      next if !sprite
      next if cel[AnimFrame::PATTERN] < 0
      sprite.bitmap = @animbitmap
      pbSpriteSetAnimFrame(sprite, cel)
      case cel[AnimFrame::FOCUS]
      when 1   # Target-focused -> center of screen
        sprite.x = cel[AnimFrame::X] + @center_x - Battle::Scene::FOCUSTARGET_X
        sprite.y = cel[AnimFrame::Y] + @center_y - Battle::Scene::FOCUSTARGET_Y
      when 2   # User-focused -> center of screen
        sprite.x = cel[AnimFrame::X] + @center_x - Battle::Scene::FOCUSUSER_X
        sprite.y = cel[AnimFrame::Y] + @center_y - Battle::Scene::FOCUSUSER_Y
      end
    end
    @animation.playTiming(@frame, @bgGraphic, @bgColor, @foGraphic, @foColor, @oldbg, @oldfo)
  end
end

#===============================================================================
# Public API - call these from map events via Script commands
#===============================================================================

# Play a battle animation on the overworld by animation name.
# Blocks until the animation finishes. The animation renders above
# all map tiles, while events and the player remain visible on top.
#
# Usage (in event Script command):
#   pbPlayBattleAnim("Move:BLIZZARD")
#
def pbPlayBattleAnim(anim_name)
  animations = pbLoadBattleAnimations
  return if !animations
  anim = animations.get_from_name(anim_name)
  if !anim
    Console.echoln_li("Overworld Battle Anim: animation '#{anim_name}' not found.")
    return
  end
  _pbPlayBattleAnimInternal(anim)
end

# Play a battle animation by its index in PkmnAnimations.rxdata.
#
# Usage:
#   pbPlayBattleAnimByID(42)
#
def pbPlayBattleAnimByID(anim_id)
  animations = pbLoadBattleAnimations
  return if !animations
  anim = animations[anim_id]
  if !anim
    Console.echoln_li("Overworld Battle Anim: animation ID #{anim_id} not found.")
    return
  end
  _pbPlayBattleAnimInternal(anim)
end

def _pbPlayBattleAnimInternal(anim)
  # Create a viewport above everything for the animation
  anim_viewport = Viewport.new(0, 0, Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
  anim_viewport.z = 999
  player = PBAnimationPlayerOverworld.new(anim, anim_viewport)
  player.start
  loop do
    Graphics.update
    Input.update
    pbUpdateSceneMap
    player.update
    break if player.animDone?
  end
  player.dispose
  anim_viewport.dispose
end

def pbAnim(anim_name)
  pbPlayBattleAnim(anim_name)
end
