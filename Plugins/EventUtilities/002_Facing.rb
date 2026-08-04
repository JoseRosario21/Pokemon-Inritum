#===============================================================================
# Facing helpers for cutscenes
#
# v21.1 ships turn_toward_player / turn_away_from_player on Game_Character, but
# nothing for turning one event toward another event or toward a bare tile —
# which is most of what choreographing a conversation needs.
#
# Usage (event Script command):
#   pbTurnToward(37, 43)          # event 37 faces event 43
#   pbTurnToward(37, :player)     # event 37 faces the player
#   pbTurnToward(:player, 37)     # player faces event 37
#   pbTurnTowardXY(37, 12, 8)     # event 37 faces tile (12, 8)
#   pbFaceEachOther(37, 43)       # both turn to face one another
#   pbTurnAwayFrom(37, 43)
#
# Characters may be given as an event ID, :player, or a Game_Character object,
# so these compose with anything else already holding a character reference.
#===============================================================================

class Game_Character
  # Generalised form of the built-in turn_toward_player. Uses the same
  # centre-of-sprite maths so multi-tile events face correctly, and the same
  # axis tie-break (vertical wins) so behaviour matches the vanilla helper.
  def turn_toward_character(other)
    return if !other
    sx = @x + (@width / 2.0) - (other.x + (other.width / 2.0))
    sy = @y - (@height / 2.0) - (other.y - (other.height / 2.0))
    return if sx == 0 && sy == 0
    if sx.abs > sy.abs
      (sx > 0) ? turn_left : turn_right
    else
      (sy > 0) ? turn_up : turn_down
    end
  end

  def turn_away_from_character(other)
    return if !other
    sx = @x + (@width / 2.0) - (other.x + (other.width / 2.0))
    sy = @y - (@height / 2.0) - (other.y - (other.height / 2.0))
    return if sx == 0 && sy == 0
    if sx.abs > sy.abs
      (sx > 0) ? turn_right : turn_left
    else
      (sy > 0) ? turn_down : turn_up
    end
  end

  # Faces a map tile rather than a character.
  def turn_toward_xy(target_x, target_y)
    sx = @x + (@width / 2.0) - target_x
    sy = @y - (@height / 2.0) - target_y
    return if sx == 0 && sy == 0
    if sx.abs > sy.abs
      (sx > 0) ? turn_left : turn_right
    else
      (sy > 0) ? turn_up : turn_down
    end
  end
end

#-------------------------------------------------------------------------------
# Resolves an event ID, :player, or Game_Character into a Game_Character.
# Returns nil if the event doesn't exist on this map, so a cutscene referencing
# a stand-in that isn't placed yet fails quietly instead of crashing.
#-------------------------------------------------------------------------------
def pbResolveCharacter(character)
  return nil if character.nil?
  return $game_player if character == :player || character == 0
  return character if character.is_a?(Game_Character)
  return $game_map.events[character] if character.is_a?(Integer) && $game_map
  return nil
end

def pbTurnToward(character, target)
  char = pbResolveCharacter(character)
  targ = pbResolveCharacter(target)
  return if !char || !targ
  char.turn_toward_character(targ)
end

def pbTurnAwayFrom(character, target)
  char = pbResolveCharacter(character)
  targ = pbResolveCharacter(target)
  return if !char || !targ
  char.turn_away_from_character(targ)
end

def pbTurnTowardXY(character, x, y)
  char = pbResolveCharacter(character)
  return if !char
  char.turn_toward_xy(x, y)
end

def pbFaceEachOther(character_a, character_b)
  pbTurnToward(character_a, character_b)
  pbTurnToward(character_b, character_a)
end
