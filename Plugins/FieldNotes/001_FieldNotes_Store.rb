#===============================================================================
# Field Notes - Seen tracking
#
# Records which fields the player has actually battled on. Stored as an array of
# field id symbols on PokemonGlobalMetadata via a lazy getter, so existing saves
# pick it up on first access without needing a save conversion.
#===============================================================================
class PokemonGlobalMetadata
  def field_notes_seen
    @field_notes_seen = [] if !@field_notes_seen
    return @field_notes_seen
  end

  def field_notes_seen=(value)
    @field_notes_seen = value
  end
end

module FieldNotes
  module_function

  # Marks a field as encountered. Safe to call with anything -- a nil, the base
  # field, or an id that no longer exists in the registry are all ignored.
  def mark_seen(field_id)
    return if !$PokemonGlobal
    field_id = field_id.id if field_id.respond_to?(:id)
    return if field_id.nil? || field_id == :BASE
    return if !GameData::FieldEffect.exists?(field_id)
    return if $PokemonGlobal.field_notes_seen.include?(field_id)
    $PokemonGlobal.field_notes_seen.push(field_id)
  end

  def seen?(field_id)
    return true if !REQUIRE_SEEN
    return false if !$PokemonGlobal
    return $PokemonGlobal.field_notes_seen.include?(field_id)
  end

  def any_seen?
    return true if !REQUIRE_SEEN
    return false if !$PokemonGlobal
    return $PokemonGlobal.field_notes_seen.any? { |id| GameData::FieldEffect.exists?(id) }
  end

  # Every field the player is allowed to see in the list, already ordered by
  # category then name. Returns [category, [FieldEffect, ...]] pairs.
  def grouped_fields
    entries = []
    GameData::FieldEffect.each do |data|
      next if data.id == :BASE
      next if REQUIRE_SEEN && !SHOW_UNSEEN_AS_LOCKED && !seen?(data.id)
      entries.push(data)
    end
    groups = {}
    entries.each do |data|
      cat = data.category || "Neutral"
      groups[cat] ||= []
      groups[cat].push(data)
    end
    ordered = []
    # Known categories first, in the configured order...
    CATEGORY_ORDER.each do |cat|
      next if !groups[cat]
      ordered.push([cat, groups[cat].sort_by { |d| d.name }])
      groups.delete(cat)
    end
    # ...then anything new that PBS introduced, alphabetically.
    groups.keys.sort.each do |cat|
      ordered.push([cat, groups[cat].sort_by { |d| d.name }])
    end
    return ordered
  end
end

#===============================================================================
# Debug helpers. Call from a Script event command or the debug console.
#
#   pbUnlockAllFieldNotes    marks every field as encountered
#   pbResetFieldNotes        clears the record again
#
# Fields only occur on a handful of map IDs (see Battle::Field::DEFAULT_FIELD in
# the Field Effect plugin), so testing the catalogue by battling on each one is
# slow -- this is the shortcut.
#===============================================================================
def pbUnlockAllFieldNotes
  return if !$PokemonGlobal
  GameData::FieldEffect.each { |data| FieldNotes.mark_seen(data.id) }
  return $PokemonGlobal.field_notes_seen.length
end

def pbResetFieldNotes
  return if !$PokemonGlobal
  $PokemonGlobal.field_notes_seen = []
end

#===============================================================================
# Hook: every field that enters a battle passes through Battle#add_field, which
# makes it the one place worth tapping. Wrapped so a failure here can never take
# a battle down with it.
#===============================================================================
class Battle
  alias field_notes_add_field add_field unless method_defined?(:field_notes_add_field)

  def add_field(new_field)
    field_notes_add_field(new_field)
    begin
      FieldNotes.mark_seen(new_field)
    rescue StandardError => e
      echoln("[Field Notes] failed to record seen field: #{e.message}") if $DEBUG
    end
  end
end
