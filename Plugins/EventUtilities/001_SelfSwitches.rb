#===============================================================================
# Bulk self-switch control
#
# Sets or clears self-switches across every event on a map in one call, instead
# of hand-writing a Control Self Switch command per event. The usual need is
# resetting a cutscene map back to its "before" state so it can be replayed, or
# clearing the A-switches that hid a crowd of stand-in NPCs.
#
# Usage (event Script command):
#   pbSetSelfSwitches(nil, "A", false)      # clear A on every event, this map
#   pbSetSelfSwitches(27, "A", false)       # ...on map 27 instead
#   pbSetSelfSwitches(nil, nil, false)      # clear A-E on every event
#   pbSetSelfSwitches(nil, ["A", "B"], true)
#   pbClearSelfSwitches(27)                 # shorthand for "clear A-E on map 27"
#
# Arguments
#   map_id  Integer or nil. nil means the map the player is currently on.
#   letters String, Array of Strings, or nil. nil means all of A-E.
#   value   true to switch on, false to switch off.
#
# Notes
# - Turning switches OFF works on any map without touching the disk: self-switch
#   keys that were never set are already false, so we only need to walk the keys
#   that exist. Turning them ON does need the event list, which for a map other
#   than the current one means reading that map's data.
# - The map is flagged for refresh afterwards so events re-evaluate their pages
#   immediately rather than on the next player step.
#===============================================================================

#===============================================================================
# Lets us enumerate what has actually been set, so clearing a map doesn't need
# to know which events exist (or still exist).
#===============================================================================
class Game_SelfSwitches
  def keys
    return @data.keys
  end
end

DEFAULT_SELF_SWITCH_LETTERS = ["A", "B", "C", "D", "E"]

#-------------------------------------------------------------------------------
# Normalises the letters argument into an array of uppercase strings.
#-------------------------------------------------------------------------------
def pbNormalizeSelfSwitchLetters(letters)
  return DEFAULT_SELF_SWITCH_LETTERS.clone if letters.nil?
  letters = [letters] if !letters.is_a?(Array)
  return letters.map { |l| l.to_s.upcase }
end

#-------------------------------------------------------------------------------
# Every event ID on the given map. Uses the live map when possible so that a
# cutscene resetting its own map never hits the disk.
#-------------------------------------------------------------------------------
def pbEventIDsOnMap(map_id)
  return $game_map.events.keys if $game_map && $game_map.map_id == map_id
  begin
    map = load_data(sprintf("Data/Map%03d.rxdata", map_id))
    return map ? map.events.keys : []
  rescue StandardError
    # A missing or unreadable map shouldn't take a cutscene down with it.
    return []
  end
end

#-------------------------------------------------------------------------------
# Main entry point. See the header comment for usage.
#-------------------------------------------------------------------------------
def pbSetSelfSwitches(map_id = nil, letters = nil, value = false)
  map_id = $game_map.map_id if map_id.nil?
  letters = pbNormalizeSelfSwitchLetters(letters)
  return if letters.empty?

  if value
    # Switching on: we have to name every key, so the event list is required.
    pbEventIDsOnMap(map_id).each do |event_id|
      letters.each { |letter| $game_self_switches[[map_id, event_id, letter]] = true }
    end
  else
    # Switching off: only keys that were actually set can be true, so walking
    # the existing keys covers everything and costs nothing on other maps.
    $game_self_switches.keys.each do |key|
      next if !key.is_a?(Array) || key.length != 3
      next if key[0] != map_id
      next if !letters.include?(key[2])
      $game_self_switches[key] = false
    end
  end

  $game_map.need_refresh = true if $game_map && $game_map.map_id == map_id
end

#-------------------------------------------------------------------------------
# Shorthand: clear A-E across a whole map.
#-------------------------------------------------------------------------------
def pbClearSelfSwitches(map_id = nil)
  pbSetSelfSwitches(map_id, nil, false)
end
