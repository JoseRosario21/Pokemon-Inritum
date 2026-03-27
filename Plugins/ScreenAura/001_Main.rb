#==============================================================================
# Screen Aura — animated colored vignette for cutscenes
#
# Usage (in map events via Script command):
#   pbAuraOn                    # default :giratina preset
#   pbAuraOn(:flashback)        # warm amber glow
#   pbAuraOn(:dream)            # icy blue glow
#   pbAuraOn(:giratina)         # deep purple glow
#   pbAuraOn(:giratina, animated: false)  # instant
#   pbAuraOff                   # fade out
#   pbAuraOff(animated: false)  # instant
#==============================================================================
module ScreenAura
  DEPTH     = 96       # how deep the gradient reaches inward (pixels)
  STEPS     = DEPTH    # one pixel per step for smoothest gradient
  Z_LEVEL   = 99985    # just below Letterbox (99990) and fade overlays (99999)
  FADE_SECS = 0.4      # fade in/out duration

  # Built-in presets — color is the base vignette color
  PRESETS = {
    giratina:  { color: Color.new(90,  10,  210), speed: 0.35, swing: 55 },
    flashback: { color: Color.new(230, 160,  20), speed: 0.28, swing: 40 },
    dream:     { color: Color.new(80,  200, 255), speed: 0.50, swing: 50 },
  }.freeze

  def self.on?
    @visible == true
  end

  # preset_or_color — a preset Symbol or a Color instance
  def self.show(preset_or_color = :giratina, animated: true)
    return if on?
    cfg = preset_or_color.is_a?(Symbol) ? (PRESETS[preset_or_color] || PRESETS[:giratina]) : nil
    if cfg
      @base_color = cfg[:color]
      @speed      = cfg[:speed]
      @swing      = cfg[:swing]
    else
      @base_color = preset_or_color
      @speed      = 0.4
      @swing      = 50
    end
    _create_sprite
    if animated
      _fade(:in)
    else
      @sprite.opacity = 200
    end
    @visible    = true
    @start_time = System.uptime
  end

  def self.hide(animated: true)
    return unless on?
    _fade(:out) if animated
    _dispose_sprite
    @visible = false
  end

  # Called every frame by the on_frame_update hook
  def self.update
    return unless on?
    return if !@sprite || @sprite.disposed?
    t = System.uptime - (@start_time || 0.0)
    # Pulse opacity with a sine wave
    pulse = Math.sin(t * @speed * Math::PI) * @swing
    @sprite.opacity = (200 + pulse).clamp(0, 255).to_i
    # Subtle warm/cool hue oscillation via tone
    shift = Math.sin(t * @speed * 0.6 * Math::PI) * 22
    @sprite.tone = Tone.new(shift.to_i, (shift * 0.4).to_i, (-shift * 0.5).to_i, 0)
  end

  # Call this if a scene change disposes the sprites unexpectedly
  def self.force_dispose
    _dispose_sprite
    @visible = false
  end

  #---------------------------------------------------------------------------
  private_class_method def self._create_sprite
    @vp      = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @vp.z    = Z_LEVEL
    @sprite         = Sprite.new(@vp)
    @sprite.bitmap  = _make_vignette(@base_color)
    @sprite.opacity = 0
  end

  # Builds a vignette bitmap: transparent center, colored glow on all edges.
  # Draws concentric border lines from the inside out; each line is more opaque
  # the closer it is to the screen edge.
  private_class_method def self._make_vignette(color)
    bmp = Bitmap.new(Graphics.width, Graphics.height)
    r, g, b = color.red.to_i, color.green.to_i, color.blue.to_i
    STEPS.times do |i|
      # i=0 is innermost (transparent), i=STEPS-1 is outermost edge (opaque)
      progress = i.to_f / (STEPS - 1)
      alpha    = (progress**1.8 * 255).to_i   # power curve — gentle inner falloff
      c        = Color.new(r, g, b, alpha)
      inset    = STEPS - 1 - i                 # pixel offset from screen edge
      x = inset
      y = inset
      w = Graphics.width  - 2 * inset
      h = Graphics.height - 2 * inset
      next if w <= 0 || h <= 0
      bmp.fill_rect(x,         y,         w, 1, c)   # top
      bmp.fill_rect(x,         y + h - 1, w, 1, c)   # bottom
      bmp.fill_rect(x,         y + 1,     1, h - 2, c)   # left
      bmp.fill_rect(x + w - 1, y + 1,     1, h - 2, c)   # right
    end
    bmp
  end

  private_class_method def self._fade(dir)
    target = (dir == :in) ? 200 : 0
    start  = @sprite.opacity
    t0     = System.uptime
    loop do
      progress = [(System.uptime - t0) / FADE_SECS, 1.0].min
      @sprite.opacity = lerp(start, target, FADE_SECS, t0, System.uptime).to_i
      Graphics.update
      Input.update
      break if progress >= 1.0
    end
    @sprite.opacity = target
  end

  private_class_method def self._dispose_sprite
    @sprite&.bitmap&.dispose
    @sprite&.dispose
    @vp&.dispose
    @sprite = @vp = nil
  end
end

#==============================================================================
# Per-frame hook — updates pulse animation while on the overworld
#==============================================================================
EventHandlers.add(:on_frame_update, :screen_aura_update,
  proc { ScreenAura.update }
)

#==============================================================================
# Global helpers for use in map event Script commands
#==============================================================================
def pbAuraOn(preset = :giratina, animated: true)
  ScreenAura.show(preset, animated: animated)
end

def pbAuraOff(animated: true)
  ScreenAura.hide(animated: animated)
end
