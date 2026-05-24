#===============================================================================
# Particle Generation - Built-in Presets
#
# Pass a preset symbol to pbParticleEmitter to use one of these:
#   pbParticleEmitter(:smoke)
#   pbParticleEmitter(:ember)
#   pbParticleEmitter(:ash)
#   pbParticleEmitter(:sparkle)
#   pbParticleEmitter(:mist)
#   pbParticleEmitter(:snow)
#   pbParticleEmitter(:leaves)   # requires "Graphics/Particles/leaf.png"
#   pbParticleEmitter(:petals)        # requires "Graphics/Particles/petal.png"
#   pbParticleEmitter(:petals_dance)  # requires "Graphics/Particles/petal_strip.png"
#   pbParticleEmitter(:stars)         # requires "Graphics/Particles/star.png"
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

  # Soft white circles drifting down like snowflakes, with gentle side drift
  # and size variation.
  SNOW = {
    x: 0,    y: -12,
    spread_x: Graphics.width,
    max_count: 40,  rate: 7.0,
    vx_min: -18.0,  vx_max: 18.0,
    vy_min: 25.0,   vy_max: 60.0,
    life_min: 5.0,  life_max: 10.0,
    radius: 4,
    color: Color.new(230, 240, 255),
    gravity: 1.5,
    scale_min: 0.5, scale_max: 1.4,
    spin_min: -20.0, spin_max: 20.0,
  }

  # Falling leaves using a graphic. Requires "Graphics/Particles/leaf.png".
  # Leaves tumble and drift side-to-side on the way down.
  LEAVES = {
    graphic: "Graphics/Particles/leaf.png",
    x: 0,    y: -16,
    spread_x: Graphics.width,
    max_count: 20,  rate: 3.0,
    vx_min: -35.0,  vx_max: 35.0,
    vy_min: 30.0,   vy_max: 70.0,
    life_min: 5.0,  life_max: 9.0,
    gravity: 3.0,
    wind: 8.0,
    scale_min: 0.6, scale_max: 1.1,
    spin_min: -120.0, spin_max: 120.0,
  }

  # Falling flower petals using a graphic. Requires "Graphics/Particles/petal.png".
  # Lighter and slower than leaves, drifts gently.
  PETALS = {
    graphic: "Graphics/Particles/petal.png",
    x: 0,    y: -16,
    spread_x: Graphics.width,
    max_count: 25,  rate: 4.0,
    vx_min: -20.0,  vx_max: 20.0,
    vy_min: 18.0,   vy_max: 45.0,
    life_min: 6.0,  life_max: 11.0,
    gravity: 1.5,
    wind: 5.0,
    scale_min: 0.5, scale_max: 1.0,
    spin_min: -80.0, spin_max: 80.0,
  }

  # Falling cherry blossom petals using a 3-frame spritesheet — each particle
  # picks a random petal shape (sakura, slim, or wide flat).
  # Requires "Graphics/Particles/petal_strip.png" (60x20 px, 3 frames of 20x20).
  PETALS_DANCE = {
    graphic:   "Graphics/Particles/petal_strip.png",
    frames:    3,
    x: 0,    y: -16,
    spread_x: Graphics.width,
    max_count: 25,  rate: 4.0,
    vx_min: -20.0,  vx_max: 20.0,
    vy_min: 18.0,   vy_max: 45.0,
    life_min: 6.0,  life_max: 11.0,
    gravity: 1.5,
    wind: 5.0,
    scale_min: 0.5, scale_max: 1.0,
    spin_min: -80.0, spin_max: 80.0,
  }

  # Slowly falling stars for space/cosmic maps. Requires "Graphics/Particles/star.png".
  # Recommended star.png size: 16x16 px. Stars drift diagonally downward,
  # rotate slowly, and vary in size to create depth.
  STARS = {
    graphic: "Graphics/Particles/star.png",
    x: 0,    y: -16,
    spread_x: Graphics.width,
    max_count: 30,  rate: 3.5,
    vx_min: -12.0,  vx_max: 12.0,
    vy_min: 15.0,   vy_max: 40.0,
    life_min: 6.0,  life_max: 12.0,
    gravity: 0.0,
    wind: 0.0,
    scale_min: 0.3, scale_max: 1.2,
    spin_min: -30.0, spin_max: 30.0,
  }
end
