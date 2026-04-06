#===============================================================================
# Particle Generation - ParticleSystem
#
# Global manager for active emitters in the overworld.
# Hooks into EventHandlers :on_frame_update, which fires every frame inside
# Scene_Map#updateSpritesets — the same hook used by ScreenAura.
#
# For title screen usage, add the emitter directly as a user sprite:
#   scene.addUserSprite(ParticleEmitter.new(opts))
# The EventScene update loop will call emitter.update automatically.
#===============================================================================
module ParticleSystem
  @emitters = []
  @hooked   = false

  # Add an emitter to the global system and return it.
  def self.add(emitter)
    _hook unless @hooked
    @emitters << emitter
    emitter
  end

  # Stop all emitters gracefully — they finish spawning live particles,
  # then auto-dispose once every particle has faded out.
  def self.clear
    @emitters.each { |e| e.stop unless e.disposed? }
  end

  # Immediately dispose all emitters with no fade-out.
  def self.kill
    @emitters.each { |e| e.dispose unless e.disposed? }
    @emitters.clear
  end

  # Called every frame by the on_frame_update hook (overworld only).
  def self.update
    @emitters.each(&:update)
    # Auto-dispose emitters that are stopped and have no remaining particles.
    @emitters.each { |e| e.dispose if e.stopped? && e.empty? && !e.disposed? }
    @emitters.delete_if(&:disposed?)
  end

  def self._hook
    EventHandlers.add(:on_frame_update, :particle_system,
      proc { ParticleSystem.update }
    )
    @hooked = true
  end
  private_class_method :_hook
end
