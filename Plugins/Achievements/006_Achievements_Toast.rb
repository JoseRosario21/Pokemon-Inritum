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
  # The panel is sized to its text rather than fixed. "Wildlife Management" and
  # "Learning Experience" are 19 characters before the tier is added, and a
  # fixed width wide enough for those would look empty for "Angler".
  MIN_WIDTH    = 180
  MAX_WIDTH    = 340    # past this it starts to feel like a message box
  PADDING_X    = 12
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
      # Width varies per toast now, so read it from the sprite rather than a
      # constant.
      w = @sprite.bitmap ? @sprite.bitmap.width : MIN_WIDTH
      @sprite.x = (-w + ((w + MARGIN_X) * ratio)).round
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
    # The tier goes on the small-font label line, not appended to the name.
    # "Well Travelled - Bronze" on one system-font line is wider than a corner
    # pop-up should be; splitting it puts the long half in the smaller font.
    label = subtitle.to_s.empty? ? _INTL("Achievement unlocked") :
                                   _INTL("{1} achievement unlocked", subtitle)
    width = measure_width(label, title)
    build_sprite(width)
    draw(width, label, title)
    @sprite.x = -width
    @sprite.y = MARGIN_Y
    @sprite.opacity = 0
    @phase = :slide
    @timer = 0
  end

  # Scratch bitmap, because the panel has to be sized before the sprite that
  # will hold it exists.
  def measure_width(label, title)
    scratch = Bitmap.new(MAX_WIDTH, HEIGHT)
    begin
      pbSetSmallFont(scratch)
      label_w = scratch.text_size(label).width
      pbSetSystemFont(scratch)
      title_w = scratch.text_size(title).width
    ensure
      scratch.dispose
    end
    widest = [label_w, title_w].max + (PADDING_X * 2)
    return widest.clamp(MIN_WIDTH, MAX_WIDTH)
  end

  # Trims to fit, with an ellipsis, so an unusually long name can never spill
  # outside the panel the way a fixed width let it.
  def fit_text(bitmap, text, available)
    return text if bitmap.text_size(text).width <= available
    trimmed = text.dup
    while trimmed.length > 1 && bitmap.text_size(trimmed + "...").width > available
      trimmed.chop!
    end
    return trimmed + "..."
  end

  def build_sprite(width)
    dispose_sprite
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    # Above the map and its weather, below message boxes and menus.
    @viewport.z = 99_000
    @sprite = BitmapSprite.new(width, HEIGHT, @viewport)
  end

  def draw(width, label, title)
    bitmap = @sprite.bitmap
    bitmap.clear
    # Panel with a 1px edge and a gold accent bar down the left.
    bitmap.fill_rect(0, 0, width, HEIGHT, EDGE_COLOR)
    bitmap.fill_rect(1, 1, width - 2, HEIGHT - 2, BACK_COLOR)
    bitmap.fill_rect(1, 1, 4, HEIGHT - 2, ACCENT_COLOR)
    available = width - PADDING_X - 6
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [fit_text(bitmap, label, available), PADDING_X, 3, 0, LABEL_COLOR, SHADOW_COLOR]
    ])
    pbSetSystemFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [fit_text(bitmap, title, available), PADDING_X, 19, 0, TEXT_COLOR, SHADOW_COLOR]
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
