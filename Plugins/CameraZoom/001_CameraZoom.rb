#===============================================================================
# Camera Zoom
# Fake "camera zoom" for cutscenes. RGSS/mkxp has no way to scale the whole
# screen, so instead this takes a full-screen snapshot each frame and scales
# that as a sprite -- the same trick Pokémon Rejuvenation uses for its
# prologue cutscenes. Because the snapshot refreshes every frame, walking/
# animation/dialogue all keep playing normally underneath the zoom.
#
# Usage (event Script command):
#   pbCameraZoom(1.5, 0.04)        # zoom in to 150%, ~0.04 zoom/frame
#   pbCameraZoom(1.0, 20, true)    # zoom back to 100% over ~20 frames
#
# Combine with the message box's \sh and \w[] control codes (see
# 007_Objects and windows/011_Messages.rb) for a full "dramatic beat":
# zoom in, then show a \sh line.
#===============================================================================

class Game_Temp
  attr_accessor :camera_zoom_state, :message_window
end

class CameraZoomState
  attr_accessor :goal, :speed

  def initialize(goal, speed, by_frames = false)
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99_999
    @sprite = Sprite.new(@viewport)
    @sprite.zoom_x = 1.0
    @sprite.zoom_y = 1.0
    refresh_snapshot
    self.goal = goal
    set_speed(speed, by_frames)
  end

  def set_speed(speed, by_frames = false)
    @speed = by_frames ? 1.0 / (speed * 2) : speed
  end

  def refresh_snapshot
    old_bitmap = @sprite.bitmap
    @sprite.bitmap = Graphics.snap_to_bitmap
    old_bitmap&.dispose
    @sprite.ox = @sprite.bitmap.width / 2
    @sprite.oy = @sprite.bitmap.height / 2
    @sprite.x = Graphics.width / 2
    @sprite.y = Graphics.height / 2
  end

  def update
    return if disposed?
    msgwindow = $game_temp.message_window
    msgwindow.visible = false if msgwindow
    refresh_snapshot
    msgwindow.visible = true if msgwindow

    return if @sprite.zoom_x == goal
    diff = (goal - @sprite.zoom_x).abs
    step = [speed, diff].min
    @sprite.zoom_x += (@sprite.zoom_x < goal) ? step : -step
    @sprite.zoom_y = @sprite.zoom_x
  end

  def at_goal?
    @sprite.zoom_x == goal
  end

  def dispose
    @sprite.bitmap&.dispose
    @sprite.dispose
    @viewport.dispose
  end

  def disposed?
    @viewport.disposed?
  end
end

def pbCameraZoom(goal, speed, by_frames = false)
  state = $game_temp.camera_zoom_state
  if state && !state.disposed?
    state.goal = goal
    state.set_speed(speed, by_frames)
  else
    $game_temp.camera_zoom_state = CameraZoomState.new(goal, speed, by_frames)
  end
end

# Convenience wrapper: zoom back out to 1.0x.
def pbCameraZoomReset(speed = nil, by_frames = false)
  state = $game_temp.camera_zoom_state
  return unless state
  pbCameraZoom(1.0, speed || state.speed, by_frames)
end

EventHandlers.add(:on_frame_update, :camera_zoom_update,
  proc {
    state = $game_temp&.camera_zoom_state
    next unless state
    if state.disposed?
      $game_temp.camera_zoom_state = nil
      next
    end
    state.update
    if state.at_goal? && state.goal == 1.0
      state.dispose
      $game_temp.camera_zoom_state = nil
    end
  }
)

#-------------------------------------------------------------------------------
# Track the active message window so the zoom snapshot can hide it each frame.
# Otherwise the message text gets baked into the frozen snapshot and shows
# doubled-up against the live window drawn on top of it.
#-------------------------------------------------------------------------------
alias __camerazoom_pbCreateMessageWindow pbCreateMessageWindow
def pbCreateMessageWindow(viewport = nil, skin = nil)
  msgwindow = __camerazoom_pbCreateMessageWindow(viewport, skin)
  $game_temp.message_window = msgwindow if $game_temp
  msgwindow
end

alias __camerazoom_pbDisposeMessageWindow pbDisposeMessageWindow
def pbDisposeMessageWindow(msgwindow)
  $game_temp.message_window = nil if $game_temp
  __camerazoom_pbDisposeMessageWindow(msgwindow)
end
