#===============================================================================
# Particle Generation - ParticleEmitter
#
# A standalone emitter that manages a pool of sprites on its own viewport.
# Because it owns its viewport independently of any scene's spriteset, it
# works in the overworld, during menus, and on the title screen.
#
# All velocities/gravity are in pixels per second (px/sec).
# Positive Y = downward (screen coordinates).
#
# Options (all optional, shown with defaults):
#   x, y          — spawn origin in screen coordinates         (0, 0)
#   spread_x/y    — random offset range from origin            (0, 0)
#   max_count     — maximum simultaneous live particles         (30)
#   rate          — particles spawned per second                (6.0)
#   vx_min/max    — horizontal velocity range (px/sec)          (-10, 10)
#   vy_min/max    — vertical velocity range (px/sec)            (-50, -20)
#   life_min/max  — particle lifetime in seconds                (2.5, 5.0)
#   radius        — particle circle radius in pixels            (6)
#   color         — Color object for the particle               (grey)
#   gravity       — vertical acceleration (px/sec²)             (0.0)
#   wind          — horizontal acceleration (px/sec²)           (0.0)
#   z             — viewport z-value                            (210)
#===============================================================================
class ParticleEmitter
  Particle = Struct.new(:x, :y, :vx, :vy, :age, :life, :sprite)

  def initialize(opts = {})
    @x        = opts.fetch(:x,         0)
    @y        = opts.fetch(:y,         0)
    @spread_x = opts.fetch(:spread_x,  0)
    @spread_y = opts.fetch(:spread_y,  0)
    @max      = opts.fetch(:max_count, 30)
    @rate     = opts.fetch(:rate,      6.0)
    @vx_min   = opts.fetch(:vx_min,  -10.0);  @vx_max = opts.fetch(:vx_max,  10.0)
    @vy_min   = opts.fetch(:vy_min,  -50.0);  @vy_max = opts.fetch(:vy_max, -20.0)
    @lf_min   = opts.fetch(:life_min,  2.5);  @lf_max = opts.fetch(:life_max,  5.0)
    @radius   = opts.fetch(:radius,    6)
    @color    = opts.fetch(:color,     Color.new(200, 200, 200))
    @gravity  = opts.fetch(:gravity,   0.0)
    @wind     = opts.fetch(:wind,      0.0)

    @vp      = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @vp.z    = opts.fetch(:z, 210)
    @texture = _build_texture
    @pool    = []
    @active  = []
    @accum   = 0.0
    @last_t  = System.uptime
    @disposed = false
  end

  # Stop spawning new particles. Existing particles finish their path naturally.
  # ParticleSystem auto-disposes this emitter once all particles have faded out.
  def stop
    @rate  = 0
    @accum = 0.0
  end

  def stopped?
    @rate == 0
  end

  def empty?
    @active.empty?
  end

  def update
    return if @disposed
    # Keep the viewport screen-fixed regardless of any external ox/oy changes.
    @vp.ox = 0
    @vp.oy = 0
    now = System.uptime
    dt  = [now - @last_t, 0.05].min   # cap to avoid huge jumps after pauses
    @last_t = now

    # Spawn new particles up to max_count
    @accum += @rate * dt
    while @accum >= 1.0 && @active.size < @max
      @accum -= 1.0
      _spawn
    end
    @accum = 0.0 if @accum > @rate   # safety clamp

    # Move and age active particles
    @active.each do |p|
      p.vx  += @wind    * dt
      p.vy  += @gravity * dt
      p.x   += p.vx * dt
      p.y   += p.vy * dt
      p.age += dt

      frac = p.age / p.life   # 0.0 → 1.0 over the particle's life
      alpha = if frac < 0.15
                (255 * frac / 0.15).to_i          # fade in
              elsif frac > 0.65
                (255 * (1.0 - frac) / 0.35).to_i  # fade out
              else
                255
              end

      p.sprite.x       = p.x.round
      p.sprite.y       = p.y.round
      p.sprite.opacity = alpha.clamp(0, 255)
    end

    # Recycle dead particles back into the pool
    @active.delete_if do |p|
      next false if p.age < p.life
      p.sprite.visible = false
      @pool << p.sprite
      true
    end
  end

  def dispose
    return if @disposed
    @active.each { |p| p.sprite.dispose }
    @pool.each(&:dispose)
    @texture.dispose
    @vp.dispose
    @disposed = true
  end

  def disposed?
    @disposed
  end

  private

  def _spawn
    sprite = @pool.pop || _new_sprite
    sprite.visible = true
    sprite.opacity = 0
    x  = @x + rand * @spread_x
    y  = @y + rand * @spread_y
    vx = @vx_min + rand * (@vx_max - @vx_min)
    vy = @vy_min + rand * (@vy_max - @vy_min)
    lf = @lf_min  + rand * (@lf_max  - @lf_min)
    sprite.x = x.round
    sprite.y = y.round
    @active << Particle.new(x, y, vx, vy, 0.0, lf, sprite)
  end

  def _new_sprite
    s    = Sprite.new(@vp)
    s.bitmap = @texture
    s.ox = @texture.width / 2
    s.oy = @texture.height / 2
    s
  end

  # Builds a soft radial-gradient circle bitmap.
  # Generated once per emitter; all particle sprites share the same bitmap.
  def _build_texture
    r    = @radius
    size = r * 2 + 2
    bmp  = Bitmap.new(size, size)
    cx   = cy = r + 1.0
    cr   = @color.red.to_i
    cg   = @color.green.to_i
    cb   = @color.blue.to_i
    size.times do |py|
      size.times do |px|
        d = Math.sqrt((px - cx)**2 + (py - cy)**2)
        next if d >= r
        a = (255 * (1.0 - d / r)**1.5).to_i
        bmp.set_pixel(px, py, Color.new(cr, cg, cb, a))
      end
    end
    bmp
  end
end
