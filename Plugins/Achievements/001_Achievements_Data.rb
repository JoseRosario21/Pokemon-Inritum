#===============================================================================
# Achievements and Records - Definitions
#
# Adding an achievement is one `register` call. `value` is a proc returning the
# player's current raw number; `thresholds` are the tier boundaries.
#
# Every value below reads something v21.1 already counts, with a single
# exception (shinies encountered, added in 002 with the one clean hook that
# existed for it). That is deliberate -- see the note in 000_Settings.rb.
#===============================================================================
module Achievements
  ACHIEVEMENTS = {}
  ORDER   = []

  module_function

  def register(id, hash)
    ACHIEVEMENTS[id] = hash
    ORDER.push(id) if !ORDER.include?(id)
  end

  def all
    return ORDER.map { |id| [id, ACHIEVEMENTS[id]] }
  end

  def categories
    cats = []
    ORDER.each do |id|
      cat = ACHIEVEMENTS[id][:category] || "General"
      cats.push(cat) if !cats.include?(cat)
    end
    return cats
  end

  # Current raw value, guarded so a nil $stats (title screen, corrupt save)
  # never takes a screen down.
  def value_of(id)
    data = ACHIEVEMENTS[id]
    return 0 if !data || !data[:value]
    begin
      return data[:value].call.to_i
    rescue StandardError
      return 0
    end
  end

  # 0 when not yet started, otherwise the 1-based tier reached.
  def level_of(id)
    data = ACHIEVEMENTS[id]
    return 0 if !data
    value = value_of(id)
    level = 0
    data[:thresholds].each { |t| level += 1 if value >= t }
    return level
  end

  def max_level(id)
    data = ACHIEVEMENTS[id]
    return 0 if !data
    return data[:thresholds].length
  end

  # Threshold for the next tier, or nil when maxed.
  def next_threshold(id)
    data = ACHIEVEMENTS[id]
    return nil if !data
    level = level_of(id)
    return nil if level >= data[:thresholds].length
    return data[:thresholds][level]
  end

  def complete?(id)
    return level_of(id) >= max_level(id)
  end
end

#===============================================================================
# Travel
#===============================================================================
Achievements.register(:distance_walked, {
  :name        => _INTL("Well Travelled"),
  :category    => _INTL("Travel"),
  :description => _INTL("Steps taken on foot."),
  :thresholds  => [1000, 10_000, 50_000, 200_000],
  :value       => proc { $stats ? $stats.distance_walked : 0 }
})

Achievements.register(:distance_cycled, {
  :name        => _INTL("Saddle Sore"),
  :category    => _INTL("Travel"),
  :description => _INTL("Distance covered by bicycle."),
  :thresholds  => [1000, 10_000, 50_000],
  :value       => proc { $stats ? $stats.distance_cycled : 0 }
})

Achievements.register(:distance_surfed, {
  :name        => _INTL("Sea Legs"),
  :category    => _INTL("Travel"),
  :description => _INTL("Distance covered while surfing."),
  :thresholds  => [500, 5000, 25_000],
  :value       => proc { $stats ? $stats.distance_surfed : 0 }
})

Achievements.register(:bump_count, {
  :name        => _INTL("Wall Enthusiast"),
  :category    => _INTL("Travel"),
  :description => _INTL("Times you walked into something solid."),
  :thresholds  => [50, 500, 2500],
  :value       => proc { $stats ? $stats.bump_count : 0 }
})

Achievements.register(:fly_count, {
  :name        => _INTL("Frequent Flyer"),
  :category    => _INTL("Travel"),
  :description => _INTL("Times you travelled by Fly."),
  :thresholds  => [10, 50, 200],
  :value       => proc { $stats ? $stats.fly_count : 0 }
})

#===============================================================================
# Battling
#===============================================================================
Achievements.register(:wild_battles_won, {
  :name        => _INTL("Wildlife Management"),
  :category    => _INTL("Battling"),
  :description => _INTL("Wild Pokemon defeated."),
  :thresholds  => [50, 250, 1000, 5000],
  :value       => proc { $stats ? $stats.wild_battles_won : 0 }
})

Achievements.register(:trainer_battles_won, {
  :name        => _INTL("Contender"),
  :category    => _INTL("Battling"),
  :description => _INTL("Trainers defeated."),
  :thresholds  => [25, 100, 400, 1000],
  :value       => proc { $stats ? $stats.trainer_battles_won : 0 }
})

Achievements.register(:total_exp_gained, {
  :name        => _INTL("Experience Counts"),
  :category    => _INTL("Battling"),
  :description => _INTL("Total Exp. Points earned."),
  :thresholds  => [50_000, 500_000, 2_500_000],
  :value       => proc { $stats ? $stats.total_exp_gained : 0 }
})

Achievements.register(:blacked_out_count, {
  :name        => _INTL("Learning Experience"),
  :category    => _INTL("Battling"),
  :description => _INTL("Times you blacked out. It happens."),
  :thresholds  => [1, 10, 50],
  :value       => proc { $stats ? $stats.blacked_out_count : 0 }
})

Achievements.register(:failed_poke_ball_count, {
  :name        => _INTL("So Close"),
  :category    => _INTL("Battling"),
  :description => _INTL("Poke Balls that failed to catch."),
  :thresholds  => [25, 200, 1000],
  :value       => proc { $stats ? $stats.failed_poke_ball_count : 0 }
})

Achievements.register(:mega_evolution_count, {
  :name        => _INTL("Beyond Evolution"),
  :category    => _INTL("Battling"),
  :description => _INTL("Times you Mega Evolved a Pokemon."),
  :thresholds  => [1, 25, 100],
  :value       => proc { $stats ? $stats.mega_evolution_count : 0 }
})

Achievements.register(:fields_seen, {
  :name        => _INTL("Field Researcher"),
  :category    => _INTL("Battling"),
  :description => _INTL("Different battle fields encountered."),
  :thresholds  => [1, 5, 10, 20],
  :value       => proc {
    next 0 if !$PokemonGlobal || !defined?(FieldNotes)
    next $PokemonGlobal.field_notes_seen.count { |id| GameData::FieldEffect.exists?(id) }
  }
})

#===============================================================================
# Pokemon
#===============================================================================
Achievements.register(:owned_count, {
  :name        => _INTL("Collector"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Species registered as owned in the Pokedex."),
  :thresholds  => [10, 50, 150, 300],
  :value       => proc { ($player && $player.pokedex) ? $player.pokedex.owned_count : 0 }
})

Achievements.register(:seen_count, {
  :name        => _INTL("Observer"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Species registered as seen in the Pokedex."),
  :thresholds  => [25, 100, 250, 450],
  :value       => proc { ($player && $player.pokedex) ? $player.pokedex.seen_count : 0 }
})

Achievements.register(:shinies_encountered, {
  :name        => _INTL("Glint in the Grass"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Shiny wild Pokemon encountered."),
  :thresholds  => [1, 5, 15, 40],
  :value       => proc { $stats ? $stats.shinies_encountered : 0 }
})

Achievements.register(:eggs_hatched, {
  :name        => _INTL("Hatchery"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Eggs hatched."),
  :thresholds  => [1, 10, 50, 200],
  :value       => proc { $stats ? $stats.eggs_hatched : 0 }
})

Achievements.register(:evolution_count, {
  :name        => _INTL("Growing Up"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Pokemon evolved."),
  :thresholds  => [5, 25, 100],
  :value       => proc { $stats ? $stats.evolution_count : 0 }
})

Achievements.register(:trade_count, {
  :name        => _INTL("Fair Exchange"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Pokemon traded."),
  :thresholds  => [1, 10, 50],
  :value       => proc { $stats ? $stats.trade_count : 0 }
})

Achievements.register(:pokerus_infections, {
  :name        => _INTL("Contagious"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Pokemon that caught Pokerus."),
  :thresholds  => [1, 5, 20],
  :value       => proc { $stats ? $stats.pokerus_infections : 0 }
})

Achievements.register(:shadow_pokemon_purified, {
  :name        => _INTL("Opened Hearts"),
  :category    => _INTL("Pokemon"),
  :description => _INTL("Shadow Pokemon purified."),
  :thresholds  => [1, 10, 40],
  :value       => proc { $stats ? $stats.shadow_pokemon_purified : 0 }
})

#===============================================================================
# The world
#===============================================================================
Achievements.register(:poke_center_count, {
  :name        => _INTL("Regular"),
  :category    => _INTL("World"),
  :description => _INTL("Visits to a Pokemon Center."),
  :thresholds  => [10, 100, 500],
  :value       => proc { $stats ? $stats.poke_center_count : 0 }
})

Achievements.register(:mart_items_bought, {
  :name        => _INTL("Valued Customer"),
  :category    => _INTL("World"),
  :description => _INTL("Items bought from shops."),
  :thresholds  => [25, 250, 1000],
  :value       => proc { $stats ? $stats.mart_items_bought : 0 }
})

Achievements.register(:money_spent_at_marts, {
  :name        => _INTL("Big Spender"),
  :category    => _INTL("World"),
  :description => _INTL("Money spent in shops."),
  :thresholds  => [10_000, 100_000, 1_000_000],
  :value       => proc { $stats ? $stats.money_spent_at_marts : 0 }
})

Achievements.register(:berry_plants_picked, {
  :name        => _INTL("Green Fingers"),
  :category    => _INTL("World"),
  :description => _INTL("Berries harvested."),
  :thresholds  => [10, 100, 500],
  :value       => proc { $stats ? $stats.berry_plants_picked : 0 }
})

Achievements.register(:fishing_count, {
  :name        => _INTL("Angler"),
  :category    => _INTL("World"),
  :description => _INTL("Times you cast a fishing rod."),
  :thresholds  => [10, 100, 500],
  :value       => proc { $stats ? $stats.fishing_count : 0 }
})

Achievements.register(:itemfinder_count, {
  :name        => _INTL("Treasure Hunter"),
  :category    => _INTL("World"),
  :description => _INTL("Hidden items found."),
  :thresholds  => [5, 50, 200],
  :value       => proc { $stats ? $stats.itemfinder_count : 0 }
})

Achievements.register(:play_time, {
  :name        => _INTL("Time Served"),
  :category    => _INTL("World"),
  :description => _INTL("Hours played."),
  :thresholds  => [3600, 36_000, 180_000, 360_000],
  :value       => proc { $stats ? $stats.play_time.to_i : 0 }
})
