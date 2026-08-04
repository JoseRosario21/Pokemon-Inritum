#===============================================================================
# Achievements and Records - Unlock toast
#
# A small non-blocking pop-up in the top-left corner. Deliberately NOT a message
# box: unlocks are flavour, so they must never interrupt walking, a cutscene, or
# a conversation, and missing one is fine.
#
# It rides on :on_frame_update, which Scene_Map fires once per frame, so it
# animates only while the player is on the map and costs nothing anywhere else.
# Anything unlocked mid-battle simply shows once the player is back outside.
#
# Everything is drawn at runtime -- no art asset -- so it can't break if a
# graphic is missing, and it inherits nothing that needs reskinning.
#===============================================================================
module AchievementToast
  WIDTH        = 236
  HEIGHT       = 46
  MARGIN_X     = 8
  MARGIN_Y     = 8
  SLIDE_FRAMES = 8      # slide in from the left
  HOLD_FRAMES  = 150    # roughly 2.5 seconds on screen
  FADE_FRAMES  = 24     # fade out
  MAX_QUEUED   = 4      # drop extras rather than nagging

  BACK_COLOR   = Color.new(26, 32, 44, 225)
  EDGE_COLOR   = Color.new(150, 170, 205, 255)
  ACCENT_COLOR = Color.new(232, 192, 56, 255)
  TEXT_COLOR   = Color.new(248, 248, 248)
  SHADOW_COLOR = Color.new(40, 40, 40)
  LABEL_COLOR  = Color.new(198, 210, 230)

  module_function

  def queue
    @queue ||= []
    return @queue
  end

  # Adds a toast. Safe to call from anywhere, including mid-battle.
  def push(title, subtitle = "")
    return if queue.length >= MAX_QUEUED
    queue.push([title.to_s, subtitle.to_s])
  end

  # Tears down any visible toast and empties the queue.
  def clear
    dispose_sprite
    queue.clear
    @phase = nil
  end

  def dispose_sprite
    @sprite.dispose if @sprite && !@sprite.disposed?
    @sprite = nil
    @viewport.dispose if @viewport && !@viewport.disposed?
    @viewport = nil
  end

  #-----------------------------------------------------------------------------
  # Called once per map frame.
  #-----------------------------------------------------------------------------
  def update
    if @phase.nil?
      return if queue.empty?
      start_next
      return
    end
    @timer += 1
    case @phase
    when :slide
      ratio = @timer.to_f / SLIDE_FRAMES
      ratio = 1.0 if ratio > 1.0
      @sprite.x = (-WIDTH + ((WIDTH + MARGIN_X) * ratio)).round
      @sprite.opacity = (255 * ratio).round
      if @timer >= SLIDE_FRAMES
        @sprite.x = MARGIN_X
        @sprite.opacity = 255
        @phase = :hold
        @timer = 0
      end
    when :hold
      if @timer >= HOLD_FRAMES
        @phase = :fade
        @timer = 0
      end
    when :fade
      @sprite.opacity = (255 * (1.0 - (@timer.to_f / FADE_FRAMES))).round
      if @timer >= FADE_FRAMES
        dispose_sprite
        @phase = nil
        @timer = 0
      end
    end
  rescue StandardError => e
    # A cosmetic pop-up must never take the overworld down with it.
    echoln("[Achievement toast] #{e.message}") if $DEBUG
    clear
  end

  def start_next
    title, subtitle = queue.shift
    return if title.nil?
    build_sprite
    draw(title, subtitle)
    @sprite.x = -WIDTH
    @sprite.y = MARGIN_Y
    @sprite.opacity = 0
    @phase = :slide
    @timer = 0
  end

  def build_sprite
    dispose_sprite
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    # Above the map and its weather, below message boxes and menus.
    @viewport.z = 99_000
    @sprite = BitmapSprite.new(WIDTH, HEIGHT, @viewport)
  end

  def draw(title, subtitle)
    bitmap = @sprite.bitmap
    bitmap.clear
    # Panel with a 1px edge and a gold accent bar down the left.
    bitmap.fill_rect(0, 0, WIDTH, HEIGHT, EDGE_COLOR)
    bitmap.fill_rect(1, 1, WIDTH - 2, HEIGHT - 2, BACK_COLOR)
    bitmap.fill_rect(1, 1, 4, HEIGHT - 2, ACCENT_COLOR)
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [_INTL("Achievement unlocked"), 14, 3, 0, LABEL_COLOR, SHADOW_COLOR]
    ])
    pbSetSystemFont(bitmap)
    text = subtitle.empty? ? title : _INTL("{1} - {2}", title, subtitle)
    pbDrawTextPositions(bitmap, [
      [text, 14, 19, 0, TEXT_COLOR, SHADOW_COLOR]
    ])
  end
end

#===============================================================================
# Hooks
#===============================================================================
EventHandlers.add(:on_frame_update, :achievement_toast,
  proc { AchievementToast.update }
)

# A toast left mid-animation would otherwise hang on screen for the whole battle,
# since :on_frame_update only fires on the map.
EventHandlers.add(:on_start_battle, :clear_achievement_toast,
  proc { AchievementToast.clear }
)

EventHandlers.add(:on_leave_map, :clear_achievement_toast,
  proc { |_new_map_id, _new_map| AchievementToast.clear }
)
