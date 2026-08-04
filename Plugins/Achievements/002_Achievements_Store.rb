#===============================================================================
# Achievements and Records - State and hooks
#
# The save stores only which tier the player has already been shown, keyed by
# achievement id. Progress itself is always recomputed from $stats, so:
#   * existing saves are credited retroactively the first time they open it,
#   * a missed hook can never lose progress permanently,
#   * removing an achievement from the definitions leaves no orphan data.
#===============================================================================
class PokemonGlobalMetadata
  def achievements_notified
    @achievements_notified = {} if !@achievements_notified
    return @achievements_notified
  end

  def achievements_notified=(value)
    @achievements_notified = value
  end

  # Explicit flag rather than inferring "new save" from an empty notified hash.
  # On a brand-new game every tier is 0, so nothing gets written to that hash and
  # it stays empty -- which would make the very first achievement the player
  # earns look like pre-existing progress and be swallowed silently.
  def achievements_initialised
    return @achievements_initialised || false
  end

  def achievements_initialised=(value)
    @achievements_initialised = value
  end
end

#===============================================================================
# The one counter v21.1 doesn't already keep. Added here rather than in the
# achievement definitions so the Records screen can show it too.
#===============================================================================
class GameStats
  def shinies_encountered
    @shinies_encountered = 0 if !@shinies_encountered
    return @shinies_encountered
  end

  def shinies_encountered=(value)
    @shinies_encountered = value
  end
end

EventHandlers.add(:on_wild_pokemon_created, :count_shiny_encounters,
  proc { |pokemon|
    next if !$stats || !pokemon
    $stats.shinies_encountered += 1 if pokemon.shiny?
  }
)

#===============================================================================
module Achievements
  module_function

  def notified_level(id)
    return 0 if !$PokemonGlobal
    return $PokemonGlobal.achievements_notified[id] || 0
  end

  def set_notified_level(id, level)
    return if !$PokemonGlobal
    $PokemonGlobal.achievements_notified[id] = level
  end

  # Total tiers earned across everything, used for the header count.
  def total_earned
    return ORDER.sum { |id| level_of(id) }
  end

  def total_available
    return ORDER.sum { |id| max_level(id) }
  end

  def any_earned?
    return ORDER.any? { |id| level_of(id) > 0 }
  end

  #-----------------------------------------------------------------------------
  # Compares current tiers against what the player has been told and announces
  # anything new. Silent on the very first call of a save that already had
  # progress, so an existing save doesn't dump twenty messages at once -- those
  # tiers are simply marked as already known.
  #-----------------------------------------------------------------------------
  def check_all(silent = false)
    return if !$PokemonGlobal || !$stats
    first_run = !$PokemonGlobal.achievements_initialised
    newly = []
    ORDER.each do |id|
      level = level_of(id)
      next if level <= notified_level(id)
      newly.push([id, level]) if !first_run
      set_notified_level(id, level)
    end
    $PokemonGlobal.achievements_initialised = true
    return if silent || first_run || newly.empty? || !ANNOUNCE_UNLOCKS
    newly.each { |id, level| announce(id, level) }
  end

  # Non-blocking corner pop-up rather than a message box: unlocks are flavour and
  # must never interrupt walking or a cutscene. Missing one is acceptable.
  def announce(id, level)
    data = ACHIEVEMENTS[id]
    return if !data
    tier = TIER_NAMES[level - 1] || _INTL("Tier {1}", level)
    if UNLOCK_SE
      begin
        pbSEPlay(UNLOCK_SE)
      rescue StandardError
        nil   # a missing SE shouldn't cost the player the notification
      end
    end
    AchievementToast.push(data[:name], tier)
  end
end

#===============================================================================
# Where the check runs. Battle end and map entry between them cover essentially
# every way a tracked number moves, without adding per-frame work.
#===============================================================================
EventHandlers.add(:on_end_battle, :check_achievements,
  proc { |_result, _canLose| Achievements.check_all }
)

EventHandlers.add(:on_enter_map, :check_achievements,
  proc { |_old_map_id| Achievements.check_all }
)

# Walking is the one tracked activity that triggers neither of the above. With
# only battle-end and map-entry checks, "Well Travelled" could be earned in the
# middle of a long map and go unannounced until the player happened to leave it.
#
# Throttled rather than run every step: the check is 27 integer comparisons, so
# it is cheap, but there is no reason to pay it on every tile.
EventHandlers.add(:on_player_step_taken, :check_achievements,
  proc {
    @step_counter = (@step_counter || 0) + 1
    next if @step_counter < Achievements::STEPS_PER_CHECK
    @step_counter = 0
    Achievements.check_all
  }
)
