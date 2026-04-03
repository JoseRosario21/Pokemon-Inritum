#===============================================================================
# Daily Rifts - Public API
# Call pbDailyRift(rift_id) from a map event to trigger a rift interaction.
#
# rift_id (String or Symbol): unique identifier for this rift object.
#   Each rift_id gets its own daily Pokémon, independent of all others.
#
# Example event call (Script command):
#   pbDailyRift("cave_rift_1")
#===============================================================================
def pbDailyRift(rift_id)
  rift_id     = rift_id.to_s
  data        = pbDailyRifts
  entry       = data.get(rift_id)
  badge_count = $player.badge_count

  # --- Expiry / first visit: generate a new cycle ---
  if entry.nil? || DailyRifts.expired?(entry)
    entry = DailyRifts.generate(rift_id, badge_count)
    data.set(rift_id, entry)
  end

  stars        = DailyRifts.tier_stars(entry[:tier])
  species_name = GameData::Species.get(entry[:species]).name

  # --- Dormant: already completed this cycle ---
  if entry[:state] == :complete
    hours_left = (DailyRifts::COOLDOWN_HOURS - (Time.now.to_i - entry[:generated_at]) / 3600.0).ceil
    pbMessage(_INTL("The {1} rift lies dormant.\nIt will stir again in about {2} hour(s).",
                    stars, hours_left))
    return
  end

  # --- Show silhouette (once per cycle) ---
  unless entry[:silhouette_shown]
    DailyRifts.show_silhouette(entry[:species], entry[:tier])
    entry[:silhouette_shown] = true
    data.set(rift_id, entry)
  end

  # --- Challenge prompt ---
  pbMessage(_INTL("{1}\nA powerful presence stirs within the rift...", stars))
  choice = pbMessage(_INTL("A wild {1} lurks inside.", species_name),
                     [_INTL("Challenge it!"), _INTL("Retreat")], 1)

  if choice != 0
    pbMessage(_INTL("The rift hums with restless energy..."))
    return
  end

  # --- Battle ---
  outcome = DailyRifts.start_rift_battle(entry)

  caught_pkmn = DailyRifts.rift_caught_pokemon
  DailyRifts.rift_caught_pokemon = nil

  case outcome
  when 1   # Player won (KO'd the rift Pokémon; catch prompt was shown mid-battle)
    entry[:state] = :complete
    data.set(rift_id, entry)

    DailyRifts.give_rewards(entry[:tier], rift_id)

    if caught_pkmn
      pbMEPlay("Pkmn get")
      $player.pokedex.set_seen(caught_pkmn.species)
      $player.pokedex.set_owned(caught_pkmn.species)
      pbNickname(caught_pkmn)
      pbStorePokemon(caught_pkmn)
    end

  when 2, 5   # Lost / draw
    pbMessage(_INTL("The rift still awaits your challenge..."))
    # state stays :available — player can retry

  when 3   # Fled
    pbMessage(_INTL("You retreat from the rift..."))
    # state stays :available
  end
end

# Returns true if the rift is available to be challenged (not dormant).
# Useful for conditional event branches (e.g. to show/hide an overworld animation).
def pbRiftAvailable?(rift_id)
  entry = pbDailyRifts.get(rift_id.to_s)
  return true  if entry.nil?
  return true  if DailyRifts.expired?(entry)
  return entry[:state] != :complete
end

# Returns the hours remaining until the rift resets, or 0 if already reset.
def pbRiftHoursRemaining(rift_id)
  entry = pbDailyRifts.get(rift_id.to_s)
  return 0 if entry.nil? || DailyRifts.expired?(entry)
  elapsed = (Time.now.to_i - entry[:generated_at]) / 3600.0
  return [DailyRifts::COOLDOWN_HOURS - elapsed, 0].max.ceil
end
