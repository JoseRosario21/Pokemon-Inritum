#==============================================================================
# Letterbox — cinematic black bars for cutscenes
#
# Usage (in map events via Script command):
#   pbLetterboxOn          # slide bars in, default height (64px)
#   pbLetterboxOn(96)      # slide bars in, 96px tall
#   pbLetterboxOn(96, false) # 96px tall, instant
#   pbLetterboxOff         # slide bars out
#   pbLetterboxOff(false)  # instant
#==============================================================================
module Letterbox
  BAR_HEIGHT     = 64            # default bar height in pixels
  MAX_BAR_HEIGHT = 96            # cap — beyond this the content area gets too cramped
  ANIM_SECS      = 0.3           # slide animation duration in seconds
  Z_LEVEL        = 99990         # below fade overlays (99999) but above everything else
  BAR_COLOR      = Color.new(0, 0, 0)  # bar color — RGB (default black)
  BAR_OPACITY    = 255           # bar opacity — 0 (invisible) to 255 (fully opaque)

  def self.on?
    @visible == true
  end

  def self.show(height = BAR_HEIGHT, animated = true)
    return if on?
    @bar_height = height.is_a?(Integer) && height > 0 ? [height, MAX_BAR_HEIGHT].min : BAR_HEIGHT
    _create_bars
    if animated
      _slide(:in)
    else
      @top.y    = 0
      @bottom.y = Graphics.height - @bar_height
    end
    @visible = true
  end

  def self.hide(animated = true)
    return unless on?
    _slide(:out) if animated
    _dispose_bars
    @visible = false
  end

  # Call this if a scene change destroys the sprites unexpectedly
  def self.force_dispose
    _dispose_bars
    @visible = false
  end

  #-----------------------------------------------------------------------------

  def self._create_bars
    @vp   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @vp.z = Z_LEVEL
    @top      = _make_bar
    @top.y    = -@bar_height
    @bottom   = _make_bar
    @bottom.y = Graphics.height
  end

  def self._make_bar
    s = Sprite.new(@vp)
    s.bitmap = Bitmap.new(Graphics.width, @bar_height)
    s.bitmap.fill_rect(0, 0, Graphics.width, @bar_height, BAR_COLOR)
    s.opacity = BAR_OPACITY
    s
  end

  def self._slide(dir)
    top_from = (dir == :in) ? -@bar_height                  : 0
    top_to   = (dir == :in) ? 0                             : -@bar_height
    bot_from = (dir == :in) ? Graphics.height               : Graphics.height - @bar_height
    bot_to   = (dir == :in) ? Graphics.height - @bar_height : Graphics.height
    t0 = System.uptime
    loop do
      now = System.uptime
      @top.y    = lerp(top_from, top_to, ANIM_SECS, t0, now).to_i
      @bottom.y = lerp(bot_from, bot_to, ANIM_SECS, t0, now).to_i
      Graphics.update
      Input.update
      break if @top.y == top_to
    end
  end

  def self._dispose_bars
    @top&.bitmap&.dispose
    @top&.dispose
    @bottom&.bitmap&.dispose
    @bottom&.dispose
    @vp&.dispose
    @top = @bottom = @vp = nil
  end
end

#==============================================================================
# Global helpers for use in map event Script commands
#==============================================================================
def pbLetterboxOn(height = Letterbox::BAR_HEIGHT, animated = true)
  Letterbox.show(height, animated)
end

def pbLetterboxOff(animated = true)
  Letterbox.hide(animated)
end
