#===============================================================================
# Particle Generation - Built-in Presets
#
# Pass a preset symbol to pbParticleEmitter to use one of these:
#   pbParticleEmitter(:smoke)
#   pbParticleEmitter(:ember)
#   pbParticleEmitter(:ash)
#   pbParticleEmitter(:sparkle)
#   pbParticleEmitter(:mist)
#
# Override individual keys by merging extra options:
#   pbParticleEmitter(:smoke, rate: 2.0, color: Color.new(100, 80, 80))
#===============================================================================
module ParticlePresets
  # Grey puffs rising from the bottom of the screen.
  SMOKE = {
    x: 0,    y: Graphics.height,
    spread_x: Graphics.width,
    max_count: 25,  rate: 5.0,
    vx_min: -15.0,  vx_max: 15.0,
    vy_min: -55.0,  vy_max: -20.0,
    life_min: 3.5,  life_max: 6.5,
    radius: 10,
    color: Color.new(175, 175, 175),
    gravity: -4.0,   # gentle upward pull
  }

  # Small orange embers drifting up with slight turbulence.
  EMBER = {
    x: 0,    y: Graphics.height,
    spread_x: Graphics.width,
    max_count: 30,  rate: 8.0,
    vx_min: -30.0,  vx_max: 30.0,
    vy_min: -90.0,  vy_max: -35.0,
    life_min: 2.0,  life_max: 4.5,
    radius: 4,
    color: Color.new(255, 130, 20),
    gravity: 6.0,
    wind: 12.0,
  }

  # Dark grey particles drifting down like falling ash.
  ASH = {
    x: 0,    y: -8,
    spread_x: Graphics.width,
    max_count: 35,  rate: 8.0,
    vx_min: -8.0,   vx_max: 8.0,
    vy_min: 18.0,   vy_max: 50.0,
    life_min: 4.0,  life_max: 8.0,
    radius: 3,
    color: Color.new(75, 75, 75),
    gravity: 2.0,
  }

  # Tiny bright specks scattered across the whole screen.
  SPARKLE = {
    x: 0,    y: 0,
    spread_x: Graphics.width,
    spread_y: Graphics.height,
    max_count: 20,  rate: 4.0,
    vx_min: -8.0,   vx_max: 8.0,
    vy_min: -12.0,  vy_max: 12.0,
    life_min: 1.5,  life_max: 3.0,
    radius: 3,
    color: Color.new(255, 240, 110),
  }

  # Large soft white blobs drifting slowly across the lower half.
  MIST = {
    x: 0,    y: Graphics.height / 2,
    spread_x: Graphics.width,
    spread_y: Graphics.height / 2,
    max_count: 12,  rate: 2.0,
    vx_min: -10.0,  vx_max: 10.0,
    vy_min: -10.0,  vy_max: -3.0,
    life_min: 5.0,  life_max: 9.0,
    radius: 18,
    color: Color.new(215, 220, 240),
  }
end
