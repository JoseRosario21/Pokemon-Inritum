#===============================================================================
# Habitat List - Data
#
# A B2W2-style area dex: for each map with wild encounters, which species live
# there and whether the player has seen or caught them.
#
# Everything is derived from GameData::Encounter at read time, so editing
# PBS/encounters.txt is the only thing needed -- there is no habitat table to
# keep in sync, which is what goes stale in hand-authored versions.
#===============================================================================
module HabitatList
  # Encounter methods grouped under a friendlier heading than their raw ids.
  # Anything not listed falls through to its own name, so a new method type
  # still shows up rather than vanishing.
  METHOD_GROUPS = {
    _INTL("Grass")   => [:Land, :LandDay, :LandNight, :LandMorning, :LandAfternoon, :LandEvening],
    _INTL("Cave")    => [:Cave, :CaveDay, :CaveNight, :CaveMorning, :CaveAfternoon, :CaveEvening],
    _INTL("Surfing") => [:Water, :WaterDay, :WaterNight],
    _INTL("Fishing") => [:OldRod, :GoodRod, :SuperRod],
    _INTL("Rock Smash") => [:RockSmash],
    _INTL("Headbutt")   => [:HeadbuttLow, :HeadbuttHigh],
    _INTL("Special")    => [:BugContest]
  }

  # Only show maps the player could plausibly know about.
  REQUIRE_VISITED = true

  COLOR_OWNED = ["58C858", "1C6A1C"]
  COLOR_SEEN  = ["E8C038", "886018"]
  COLOR_UNSEEN = ["808890", "404448"]
  COLOR_HEADER = ["404850", "A0A8B0"]

  def self.color_tag(pair)
    return sprintf("<c3=%s,%s>", pair[0], pair[1])
  end

  module_function

  # Every map id that has encounter data, in map-id order.
  def all_map_ids
    ids = []
    GameData::Encounter.each { |enc| ids.push(enc.map) if !ids.include?(enc.map) }
    return ids.sort
  end

  # Maps the player is allowed to browse.
  def listed_map_ids
    ids = all_map_ids
    return ids if !REQUIRE_VISITED
    return ids.select { |id| visited?(id) }
  end

  # Essentials records visited maps for the Town Map; reuse that rather than
  # inventing a second notion of "have I been here".
  def visited?(map_id)
    return true if !$PokemonGlobal
    return true if $game_map && $game_map.map_id == map_id
    visited = $PokemonGlobal.visitedMaps
    return false if !visited
    return visited[map_id] == true
  end

  def map_name(map_id)
    name = pbGetMapNameFromId(map_id) rescue nil
    return (name && !name.empty?) ? name : _INTL("Map {1}", map_id)
  end

  # All encounter data for a map, merged across versions so a map with a
  # post-game encounter table still lists both sets.
  def encounters_for(map_id)
    out = {}
    GameData::Encounter.each do |enc|
      next if enc.map != map_id
      next if !enc.types
      enc.types.each do |method, slots|
        next if slots.nil? || slots.empty?
        out[method] ||= []
        slots.each do |slot|
          species = slot[1]
          next if species.nil?
          out[method].push(species) if !out[method].include?(species)
        end
      end
    end
    return out
  end

  # [heading, [species...]] pairs, in METHOD_GROUPS order then anything else.
  def grouped_species(map_id)
    raw = encounters_for(map_id)
    return [] if raw.empty?
    used = []
    groups = []
    METHOD_GROUPS.each do |heading, methods|
      species = []
      methods.each do |m|
        next if !raw[m]
        used.push(m)
        raw[m].each { |s| species.push(s) if !species.include?(s) }
      end
      groups.push([heading, species]) if !species.empty?
    end
    # Any encounter method not covered by a group keeps its own heading.
    raw.each do |method, species|
      next if used.include?(method)
      groups.push([method.to_s, species.uniq])
    end
    return groups
  end

  def all_species(map_id)
    return grouped_species(map_id).flat_map { |_h, s| s }.uniq
  end

  # [seen, owned, total] for a map.
  def completion(map_id)
    species = all_species(map_id)
    return [0, 0, 0] if species.empty?
    dex = ($player && $player.pokedex) ? $player.pokedex : nil
    return [0, 0, species.length] if !dex
    seen  = species.count { |s| dex.seen?(s) }
    owned = species.count { |s| dex.owned?(s) }
    return [seen, owned, species.length]
  end

  def status_of(species)
    dex = ($player && $player.pokedex) ? $player.pokedex : nil
    return :unseen if !dex
    return :owned if dex.owned?(species)
    return :seen if dex.seen?(species)
    return :unseen
  end

  # Page lines for one map, in the shape the shared page window expects.
  def build_page(map_id)
    lines = []
    groups = grouped_species(map_id)
    if groups.empty?
      lines.push({ :kind => :note, :text => _INTL("No wild Pokemon are found here.") })
      return lines
    end
    seen, owned, total = completion(map_id)
    lines.push({ :kind => :header, :text => _INTL("Overview") })
    lines.push({ :kind => :note,
                 :text => _INTL("{1} species: {2} seen, {3} caught.", total, seen, owned) })
    groups.each do |heading, species|
      lines.push({ :kind => :header, :text => heading })
      species.each do |s|
        data = GameData::Species.try_get(s) rescue nil
        name = data ? data.name : s.to_s
        case status_of(s)
        when :owned  then text = _INTL("{1}  (caught)", name)
        when :seen   then text = _INTL("{1}  (seen)", name)
        else              text = _INTL("- - - - -")
        end
        lines.push({ :kind => :note, :text => text, :status => status_of(s) })
      end
    end
    return lines
  end
end
