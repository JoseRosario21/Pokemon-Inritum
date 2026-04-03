#===============================================================================
# Daily Rifts - Rewards
# Weighted random reward selection from tier-specific pools.
#===============================================================================
module DailyRifts
  module_function

  # Selects and gives reward items to the player.
  # Uses a seeded RNG so reward selection is deterministic per rift/day.
  def give_rewards(tier, rift_id)
    cfg  = TIER_CONFIG[tier]
    pool = REWARD_POOLS[tier] || REWARD_POOLS[1]

    time  = Time.now
    seed  = stable_hash("reward_#{rift_id}") + encode_day(time) * 999
    rng   = Random.new(seed)

    count = cfg[:rewards_min] + rng.rand(cfg[:rewards_max] - cfg[:rewards_min] + 1)

    # Build a simple weighted pool
    weighted = []
    pool.each { |entry| entry[:weight].times { weighted << entry[:item] } }

    pbMessage(_INTL("The rift releases its essence..."))

    count.times do
      item = weighted[rng.rand(weighted.length)]
      next unless GameData::Item.exists?(item)
      $bag.add(item)
      pbMessage(_INTL("\\me[Pkmn get]Got {1}!", GameData::Item.get(item).name))
    end
  end

end
