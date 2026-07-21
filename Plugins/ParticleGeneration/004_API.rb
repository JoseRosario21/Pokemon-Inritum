#===============================================================================
# Particle Generation - Public API
#
# ── Overworld ────────────────────────────────────────────────────────────────
#
#   # Start a preset emitter (returns the emitter so you can dispose it later)
#   @emitter = pbParticleEmitter(:smoke)
#   @emitter = pbParticleEmitter(:ember)
#   @emitter = pbParticleEmitter(:ash)
#   @emitter = pbParticleEmitter(:sparkle)
#   @emitter = pbParticleEmitter(:mist)
#   @emitter = pbParticleEmitter(:snow)
#   @emitter = pbParticleEmitter(:leaves)        # needs Graphics/Particles/leaf.png
#   @emitter = pbParticleEmitter(:petals)        # needs Graphics/Particles/petal.png
#   @emitter = pbParticleEmitter(:petals_dance)  # needs Graphics/Particles/petal_strip.png
#   @emitter = pbParticleEmitter(:stars)         # needs Graphics/Particles/star.png
#
#   # Start a custom circle emitter
#   @emitter = pbParticleEmitter(
#     x: 100, y: 200, radius: 5, color: Color.new(200, 100, 50), rate: 4.0
#   )
#
#   # Start a custom graphic emitter
#   @emitter = pbParticleEmitter(
#     graphic: "Graphics/Particles/leaf.png",
#     x: 0, y: -16, spread_x: Graphics.width,
#     vy_min: 30.0, vy_max: 60.0,
#     scale_min: 0.5, scale_max: 1.2,
#     spin_min: -90.0, spin_max: 90.0
#   )
#
#   # Override specific keys on a preset
#   @emitter = pbParticleEmitter(:ash, rate: 3.0, color: Color.new(60, 40, 40))
#   @emitter = pbParticleEmitter(:stars, rate: 6.0, scale_min: 0.4, scale_max: 0.8)
#
#   # Dispose a specific emitter
#   @emitter.dispose
#
#   # Stop all emitters gracefully (particles finish their path, then auto-dispose)
#   pbParticlesClear
#
#   # Immediately remove all emitters with no fade-out
#   pbParticlesKill
#
# ── Graphic file guidelines ───────────────────────────────────────────────────
#
#   Place particle graphics in Graphics/Particles/.
#   Recommended sizes:
#     star.png   — 16×16 px  (small; scale_min/max handles depth variation)
#     leaf.png   — 16×20 px  (asymmetric to make rotation visible)
#     petal.png        — 14×14 px
#     petal_strip.png  — 60×20 px  (3 frames of 20×20; use frames: 3)
#   Use PNG with transparency. The image is used as-is — no colour tinting is
#   applied in graphic mode. scale_min/max and spin_min/max add variety.
#   For spritesheets, set frames: N to divide the image into N equal-width
#   cells — each particle picks one randomly at spawn.
#
# ── Title screen ─────────────────────────────────────────────────────────────
#
#   Add emitters directly as user sprites on the IntroEventScene:
#
#   class IntroEventScene
#     alias_method :my_orig_open_title_screen, :open_title_screen
#     def open_title_screen(*args)
#       my_orig_open_title_screen(*args)
#       addUserSprite(ParticleEmitter.new(ParticlePresets::SPARKLE))
#     end
#   end
#
#===============================================================================

# Creates a ParticleEmitter, registers it with the global ParticleSystem, and
# returns it.  Pass a Symbol to use a built-in preset, a Hash for a fully
# custom emitter, or a Symbol + extra Hash to override preset keys.
def pbParticleEmitter(preset_or_opts = {}, overrides = {})
  base = case preset_or_opts
         when Symbol
           const = preset_or_opts.upcase
           (ParticlePresets.const_defined?(const) ? ParticlePresets.const_get(const) : {}).dup
         when Hash
           preset_or_opts.dup
         else
           {}
         end
  ParticleSystem.add(ParticleEmitter.new(base.merge(overrides)))
end

# Stops all emitters gracefully — live particles finish their path, then
# each emitter auto-disposes once it's empty.
def pbParticlesClear
  ParticleSystem.clear
end

# Immediately disposes all emitters with no fade-out.
def pbParticlesKill
  ParticleSystem.kill
end
