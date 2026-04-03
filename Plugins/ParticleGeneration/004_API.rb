#===============================================================================
# Particle Generation - Public API
#
# ── Overworld ────────────────────────────────────────────────────────────────
#
#   # Start a preset emitter (returns the emitter so you can dispose it later)
#   @emitter = pbParticleEmitter(:smoke)
#   @emitter = pbParticleEmitter(:ember)
#
#   # Start a custom emitter
#   @emitter = pbParticleEmitter(
#     x: 100, y: 200, radius: 5, color: Color.new(200, 100, 50), rate: 4.0
#   )
#
#   # Override specific keys on a preset
#   @emitter = pbParticleEmitter(:ash, rate: 3.0, color: Color.new(60, 40, 40))
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
