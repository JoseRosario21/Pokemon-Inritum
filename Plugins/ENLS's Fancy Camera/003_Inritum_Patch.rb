#==============================================================================
# Fancy Camera — Pokémon Inritum patch
#
# Fixes the laggy player-following by snapping the camera instantly during
# normal play. Smooth lerp is preserved for scripted moves (pbCameraScrollTo,
# pbCameraToEvent, pbCameraScroll, etc.).
#==============================================================================
class Game_Temp
  attr_accessor :camera_panning

  def camera_panning
    @camera_panning || false
  end
end

class Game_Player < Game_Character
  def update_screen_position(_last_real_x, _last_real_y)
    return if self.map.scrolling?
    return if $game_temp.camera_panning

    # "Follow player" mode = no custom position and no locked event
    scripted = ($game_temp.camera_pos[0] != 0 || $game_temp.camera_pos[1] != 0) ||
               ($game_temp.camera_target_event != 0)

    # Build target position
    target = [@real_x - SCREEN_CENTER_X, @real_y - SCREEN_CENTER_Y]
    if scripted
      if $game_temp.camera_pos[0] != 0 || $game_temp.camera_pos[1] != 0
        target = $game_temp.camera_pos
      end
      if $game_temp.camera_target_event != 0
        event = $game_map.events[$game_temp.camera_target_event]
        target = [event.real_x - SCREEN_CENTER_X, event.real_y - SCREEN_CENTER_Y] if event
      end
    end

    # Apply shake and offset on top of target
    if $game_temp.camera_shake > 0
      power = $game_temp.camera_shake * 25
      target = [target[0] + rand(-power..power), target[1] + rand(-power..power)]
    end
    if $game_temp.camera_offset != [0, 0]
      target = [target[0] + ($game_temp.camera_offset[0] * Game_Map::REAL_RES_X),
                target[1] + ($game_temp.camera_offset[1] * Game_Map::REAL_RES_Y)]
    end

    if scripted
      # Smooth lerp for scripted camera moves
      distance = Math.sqrt((target[0] - self.map.display_x)**2 + (target[1] - self.map.display_y)**2)
      speed = $game_temp.camera_speed * 0.2
      if distance < 2.0
        self.map.display_x = target[0]
        self.map.display_y = target[1]
        if $game_temp.camera_resetting
          $game_temp.camera_resetting = false
          $game_temp.camera_pos = [0, 0]
        end
      else
        self.map.display_x = ease_in_out(self.map.display_x, target[0], speed)
        self.map.display_y = ease_in_out(self.map.display_y, target[1], speed)
      end
    else
      # Snap instantly when just following the player — no lag
      self.map.display_x = target[0]
      self.map.display_y = target[1]
    end
  end
end

# Blocking panoramic pan with cubic ease-in-out over a fixed duration
# proportional to distance. No pbCameraWait needed after this.
#
#   pbCameraPan(8, 35, 2)   # pan up 35 tiles, slow cinematic speed
#
# Speed scale (1–6), frames per tile:
#   1 = 12 f/t  very slow crawl
#   2 =  6 f/t  slow cinematic  (35 tiles ≈ 3.5 s)
#   3 =  3.5 f/t cinematic default
#   4 =  2.2 f/t moderate
#   5 =  1.5 f/t brisk
#   6 =  1.0 f/t fast pan
#
def pbCameraPan(direction, distance, speed = 3)
  x = ($game_temp.camera_x == 0) ? $game_player.x : $game_temp.camera_x
  y = ($game_temp.camera_y == 0) ? $game_player.y : $game_temp.camera_y
  case direction
  when 2 then y += distance
  when 4 then x -= distance
  when 6 then x += distance
  when 8 then y -= distance
  end

  target_x = (x * Game_Map::REAL_RES_X) - Game_Player::SCREEN_CENTER_X
  target_y = (y * Game_Map::REAL_RES_Y) - Game_Player::SCREEN_CENTER_Y
  start_x  = $game_map.display_x
  start_y  = $game_map.display_y

  frames_per_tile = [12.0, 6.0, 3.5, 2.2, 1.5, 1.0][speed.clamp(1, 6) - 1]
  duration = (distance * frames_per_tile).round.clamp(10, 600)

  $game_temp.camera_panning = true
  frame = 0
  loop do
    frame += 1
    t     = [frame.to_f / duration, 1.0].min
    eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    $game_map.display_x = start_x + (target_x - start_x) * eased
    $game_map.display_y = start_y + (target_y - start_y) * eased
    Graphics.update
    Input.update
    pbUpdateSceneMap
    break if frame >= duration
  end
  $game_map.display_x = target_x
  $game_map.display_y = target_y
  $game_temp.camera_panning = false
  $game_temp.camera_pos = [x, y]
end

# Blocking pan to an event with cubic ease-in-out. Same speed scale as pbCameraPan.
# Duration is based on the pixel distance to the event at call time.
#
#   pbCameraPanToEvent(12, 2)   # pan to event 12 at slow cinematic speed
#
def pbCameraPanToEvent(event_id, speed = 3)
  event = $game_map.events[event_id]
  return if !event

  target_x = event.real_x - Game_Player::SCREEN_CENTER_X
  target_y = event.real_y - Game_Player::SCREEN_CENTER_Y
  start_x  = $game_map.display_x
  start_y  = $game_map.display_y

  pixel_distance = Math.sqrt((target_x - start_x)**2 + (target_y - start_y)**2)
  tile_distance   = pixel_distance / Game_Map::REAL_RES_X.to_f

  frames_per_tile = [12.0, 6.0, 3.5, 2.2, 1.5, 1.0][speed.clamp(1, 6) - 1]
  duration = (tile_distance * frames_per_tile).round.clamp(10, 600)

  $game_temp.camera_panning = true
  frame = 0
  loop do
    frame += 1
    t     = [frame.to_f / duration, 1.0].min
    eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    $game_map.display_x = start_x + (target_x - start_x) * eased
    $game_map.display_y = start_y + (target_y - start_y) * eased
    Graphics.update
    Input.update
    pbUpdateSceneMap
    break if frame >= duration
  end
  $game_map.display_x = target_x
  $game_map.display_y = target_y
  $game_temp.camera_panning = false
  $game_temp.camera_target_event = event_id
end

# Blocks until the camera finishes lerping to its current target.
# Not needed after pbCameraPan (which is already blocking), but useful
# after pbCameraScrollTo or pbCameraToEvent.
def pbCameraWait
  loop do
    Graphics.update
    Input.update
    pbUpdateSceneMap
    pos = $game_temp.camera_pos
    break if pos[0] == 0 && pos[1] == 0
    break if ($game_map.display_x - pos[0]).abs < 2.0 &&
             ($game_map.display_y - pos[1]).abs < 2.0
  end
end
