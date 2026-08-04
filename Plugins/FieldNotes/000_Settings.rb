#===============================================================================
# Field Notes - Settings
#
# An in-game encyclopedia of every field effect. Unlike Rejuvenation's version,
# which hand-authors a large static data blob, every line here is generated from
# GameData::FieldEffect at display time. Editing PBS/field_effects.txt is
# therefore the only thing you ever need to do -- the notes cannot drift out of
# sync with the mechanics, and new fields appear automatically.
#===============================================================================
module FieldNotes
  # Whether the Pokegear app is listed at all before any field has been seen.
  #
  # Kept true because fields only occur on a handful of maps -- a player can
  # easily be hours in without meeting one, and an app that silently doesn't
  # exist yet reads as a bug rather than as progression. This follows the
  # Pokedex pattern instead: the app is always there, the entries fill in.
  SHOW_APP_ALWAYS = true

  # When true, a field's page only becomes readable once the player has actually
  # battled on it. Set to false to make the whole catalogue readable from the
  # start (useful while testing).
  REQUIRE_SEEN = true

  # When REQUIRE_SEEN is true, fields not yet encountered are still listed but
  # greyed out and unreadable. Set to false to hide them entirely instead.
  SHOW_UNSEEN_AS_LOCKED = true

  # Order categories appear in. Anything not listed here is appended
  # alphabetically afterwards, so adding a new Category in PBS never breaks it.
  CATEGORY_ORDER = [
    "Terrain", "Natural", "Underground", "Artificial",
    "Magical", "Sacred", "Corrupted", "Mixed", "Neutral"
  ]

  # Colour used for each category header, as a <c2=> tag pair.
  CATEGORY_COLORS = {
    "Terrain"     => ["3898F8", "184878"],
    "Natural"     => ["38C838", "186818"],
    "Underground" => ["A08050", "503820"],
    "Artificial"  => ["9098A8", "484850"],
    "Magical"     => ["C838C8", "681868"],
    "Sacred"      => ["E8C038", "886018"],
    "Corrupted"   => ["B03838", "581818"],
    "Mixed"       => ["48B8B8", "205858"],
    "Neutral"     => ["888888", "404040"]
  }
  DEFAULT_CATEGORY_COLOR = ["788898", "384858"]

  # Colours for note values inside a field's page.
  COLOR_BOOST  = ["2878E8", "184878"]   # things that help
  COLOR_NERF   = ["E82020", "781010"]   # things that hurt
  COLOR_HEADER = ["404850", "A0A8B0"]   # section headings

  def self.category_color(category)
    return CATEGORY_COLORS[category] || DEFAULT_CATEGORY_COLOR
  end

  # Builds a <c3=base,shadow> tag from a ["RRGGBB", "RRGGBB"] pair. Matches the
  # tag DrawText's shadowc3tag emits, so it works anywhere formatted text does.
  def self.color_tag(pair)
    return sprintf("<c3=%s,%s>", pair[0], pair[1])
  end

  def self.category_tag(category)
    return color_tag(category_color(category))
  end
end
