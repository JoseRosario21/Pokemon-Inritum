#===============================================================================
# Daily Rifts - Generation
# Seeded daily Pokémon selection per rift ID.
# Same rift + same calendar day → same Pokémon.
#===============================================================================
module DailyRifts
  module_function

  # Stable string hash independent of Ruby's randomised Hash#hash.
  def stable_hash(str)
    str.to_s.bytes.inject(0) { |h, b| h * 31 + b }
  end

  # Day encoding that survives the MKXP clock quirks (mirrors Zeta Researcher).
  def encode_day(time)
    return time.yday + time.year * 1000
  end

  # Returns the tier (1–5) for a given badge count.
  def current_tier(badge_count)
    tier = 1
    TIER_CONFIG.each do |t, cfg|
      tier = t if badge_count >= cfg[:min_badges]
    end
    return tier
  end

  # Interpolates a level within the tier's range based on badge progress,
  # then adds a small random variation (±3) seeded by the RNG.
  def calculate_level(tier, badge_count, rng)
    cfg = TIER_CONFIG[tier]
    next_cfg = TIER_CONFIG[tier + 1]
    tier_min_badges = cfg[:min_badges]
    tier_max_badges = next_cfg ? next_cfg[:min_badges] - 1 : 8

    badges_in_tier = [tier_max_badges - tier_min_badges, 1].max
    progress = ((badge_count - tier_min_badges).clamp(0, badges_in_tier)).to_f / badges_in_tier

    base = cfg[:level_min] + (progress * (cfg[:level_max] - cfg[:level_min])).round
    variation = rng.rand(7) - 3   # -3..+3
    return (base + variation).clamp(cfg[:level_min], cfg[:level_max])
  end

  # Builds a new entry Hash for a rift. This is the authoritative generation path.
  def generate(rift_id, badge_count)
    time = Time.now   # Always use real time, bypassing FL's Unreal Time
    seed = stable_hash(rift_id.to_s) + encode_day(time) * 1000
    rng  = Random.new(seed)

    tier    = current_tier(badge_count)
    pool    = TIER_POKEMON_POOLS[tier] || TIER_POKEMON_POOLS[1]
    species = pool[rng.rand(pool.length)]
    level   = calculate_level(tier, badge_count, rng)

    return {
      species:          species,
      tier:             tier,
      level:            level,
      generated_at:     Time.now.to_i,
      state:            :available,
      silhouette_shown: false,
    }
  end

  # Returns true when a rift entry's cooldown has elapsed.
  def expired?(entry)
    return true if entry.nil?
    elapsed_hours = (Time.now.to_i - entry[:generated_at]) / 3600.0
    return elapsed_hours >= COOLDOWN_HOURS
  end

  # Returns a star rating string for the given tier (e.g. "★★★☆☆").
  def tier_stars(tier, total = 5)
    filled = tier.clamp(0, total)
    return "★" * filled + "☆" * (total - filled)
  end

end
