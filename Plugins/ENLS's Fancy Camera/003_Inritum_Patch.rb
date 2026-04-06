#==============================================================================
# Fancy Camera — Pokémon Inritum patch
#
# Fixes the laggy player-following by snapping the camera instantly during
# normal play. Smooth lerp is preserved for scripted moves (pbCameraScrollTo,
# pbCameraToEvent, pbCameraScroll, etc.).
#==============================================================================
class Game_Player < Game_Character
  def update_screen_position(_last_real_x, _last_real_y)
    return if self.map.scrolling?

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
      if distance < 0.75
        self.map.display_x = target[0]
        self.map.display_y = target[1]
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
