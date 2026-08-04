#===============================================================================
# Achievements and Records - UI
#
# Layout follows Pokemon Rejuvenation's achievements screen so custom art drops
# straight in. Asset sizes match theirs exactly:
#
#   Graphics/UI/Achievements/bg.png      512x384  full-screen background
#   Graphics/UI/Achievements/button.png  496x104  ONE row, two states stacked:
#                                                   y  0- 51 = unselected
#                                                   y 52-103 = selected
#   Graphics/UI/Achievements/text.png    496x82   description panel
#
# Rows are 50px apart starting at y=46, five visible at a time, with the
# description panel at y=296 -- the same geometry Rejuvenation uses. Placeholder
# art ships with the plugin; replacing those three files reskins the screen.
#
# One deliberate difference: Rejuvenation drives the cursor with a hidden
# Window_CommandPokemon. Input is handled directly here instead, because the
# scroll offset has to be managed by hand anyway and the hidden window was only
# ever standing in for that.
#===============================================================================

#===============================================================================
# A single achievement row. The bitmap holds both states; src_rect picks one.
#===============================================================================
class AchievementButton < Sprite
  attr_reader   :index
  attr_accessor :selected

  def initialize(x, y, name = "", level = "", index = 0, viewport = nil)
    super(viewport)
    @index    = index
    @name     = name
    @level    = level
    @selected = false
    @button   = AnimatedBitmap.new("Graphics/UI/Achievements/button")
    @contents = BitmapWrapper.new(@button.width, @button.height)
    self.bitmap = @contents
    self.x = x
    self.y = y
    refresh
    update
  end

  def dispose
    @button.dispose
    @contents.dispose
    super
  end

  def half_height
    return self.bitmap.height / 2
  end

  # Text is drawn into both halves so it reads correctly in whichever state is
  # showing -- the same trick Rejuvenation uses.
  def refresh
    self.bitmap.clear
    self.bitmap.blt(0, 0, @button.bitmap, Rect.new(0, 0, @button.width, @button.height))
    pbSetSystemFont(self.bitmap)
    base   = Color.new(248, 248, 248)
    shadow = Color.new(40, 40, 40)
    h = half_height
    pbDrawTextPositions(self.bitmap, [
      [@name,  14,  10,     0, base, shadow],
      [@name,  14,  10 + h, 0, base, shadow],
      [@level, 482, 10,     1, base, shadow],
      [@level, 482, 10 + h, 1, base, shadow]
    ])
  end

  def set_text(name, level)
    @name  = name
    @level = level
    refresh
  end

  def update
    h = half_height
    if self.selected
      self.src_rect.set(0, h, self.bitmap.width, h)
    else
      self.src_rect.set(0, 0, self.bitmap.width, h)
    end
    super
  end
end

#===============================================================================
# The description panel under the list.
#===============================================================================
class AchievementText < Sprite
  def initialize(x, y, description = "", progress = "", viewport = nil)
    super(viewport)
    @description = description
    @progress    = progress
    @panel       = AnimatedBitmap.new("Graphics/UI/Achievements/text")
    @contents    = BitmapWrapper.new(@panel.width, @panel.height)
    self.bitmap = @contents
    self.x = x
    self.y = y
    refresh
  end

  def dispose
    @panel.dispose
    @contents.dispose
    super
  end

  # Greedy word wrap across two lines.
  def wrap(text, width)
    lines = ["", ""]
    row = 0
    text.to_s.split(/\s+/).each do |word|
      candidate = lines[row].empty? ? word : lines[row] + " " + word
      if row < 1 && self.bitmap.text_size(candidate).width >= width
        row += 1
        lines[row] = word
      else
        lines[row] = candidate
      end
    end
    return lines
  end

  def refresh
    self.bitmap.clear
    self.bitmap.blt(0, 0, @panel.bitmap, Rect.new(0, 0, @panel.width, @panel.height))
    pbSetSystemFont(self.bitmap)
    base   = Color.new(248, 248, 248)
    shadow = Color.new(40, 40, 40)
    line_h = self.bitmap.text_size("X").height
    lines = wrap(@description, 470)
    pbDrawTextPositions(self.bitmap, [
      [lines[0],  14,  10,          0, base, shadow],
      [lines[1],  14,  10 + line_h, 0, base, shadow],
      [@progress, 482, 10 + line_h, 1, base, shadow]
    ])
  end

  def change(description, progress)
    @description = description
    @progress    = progress
    refresh
  end
end

#===============================================================================
# Records page: a scrolling list drawn over the same background.
#===============================================================================
class Window_RecordList < Window_DrawableCommand
  def initialize(x, y, width, height, viewport)
    @lines = []
    super(x, y, width, height, viewport)
    self.windowskin  = nil
    self.baseColor   = Color.new(248, 248, 248)
    self.shadowColor = Color.new(40, 40, 40)
  end

  def lines=(value)
    @lines = value
    self.index = 0
    self.top_row = 0
    refresh
  end

  def itemCount
    return [@lines.length, 1].max
  end

  # Read-only view -- no selection arrow.
  def drawCursor(_index, _rect); end

  # Same treatment as the Field Notes page: with no visible cursor, the default
  # behaviour makes the first several presses look like nothing happened. Index
  # is the top row here, so every press scrolls exactly one line.
  def max_top_row
    return [itemCount - page_row_max, 0].max
  end

  def update
    super
    limit = max_top_row
    self.index = limit if self.index > limit
    self.index = 0 if self.index < 0
    return if top_row == self.index
    self.top_row = self.index
    refresh
  end

  def drawItem(index, _count, rect)
    if @lines.empty?
      drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width,
                          _INTL("No records available."), self.baseColor, self.shadowColor)
      return
    end
    line = @lines[index]
    return if !line
    if line[:kind] == :header
      text = Achievements.color_tag(Achievements::COLOR_HEADER) + "<b>" + line[:text] + "</b></c3>"
      drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width,
                          text, self.baseColor, self.shadowColor)
      return
    end
    drawFormattedTextEx(self.contents, rect.x + 12, rect.y + 2, rect.width - 160,
                        line[:text], self.baseColor, self.shadowColor)
    drawFormattedTextEx(self.contents, rect.x + rect.width - 148, rect.y + 2, 144,
                        "<ar>" + line[:value] + "</ar>", self.baseColor, self.shadowColor)
  end
end

#===============================================================================
class Achievements_Scene
  ROW_HEIGHT   = 50
  ROW_TOP      = 46
  VISIBLE_ROWS = 5
  PANEL_Y      = 296

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @tab    = 0
    @index  = 0
    @offset = 0
    @ids    = Achievements::ORDER

    addBackgroundPlane(@sprites, "background", "Achievements/bg", @viewport)

    @ids.each_with_index do |id, i|
      button = AchievementButton.new(8, ROW_TOP + (i * ROW_HEIGHT),
                                     Achievements::ACHIEVEMENTS[id][:name],
                                     tier_label(id), i, @viewport)
      button.z = 256
      button.visible = false
      @sprites["button#{i}"] = button
    end

    @sprites["panel"] = AchievementText.new(8, PANEL_Y, "", "", @viewport)
    @sprites["panel"].z = 256

    @sprites["records"] = Window_RecordList.new(4, ROW_TOP, Graphics.width - 8,
                                                Graphics.height - ROW_TOP - 28, @viewport)
    @sprites["records"].z = 256
    @sprites["records"].lines = Achievements.record_lines
    @sprites["records"].visible = false

    # Created last so addBackgroundPlane's windowskin sweep can't touch it.
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].z = 260
    pbSetSystemFont(@sprites["overlay"].bitmap)

    refresh_rows
    refresh_chrome
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def tier_label(id)
    return sprintf("%d/%d", Achievements.level_of(id), Achievements.max_level(id))
  end

  # Repositions rows for the current scroll offset and updates selection state.
  def refresh_rows
    @ids.each_with_index do |_id, i|
      sprite = @sprites["button#{i}"]
      next if !sprite
      visible = (i >= @offset && i < @offset + VISIBLE_ROWS)
      sprite.visible  = visible && @tab == 0
      sprite.y        = ROW_TOP + ((i - @offset) * ROW_HEIGHT)
      sprite.selected = (i == @index)
      sprite.update
    end
    id = @ids[@index]
    return if !id
    data = Achievements::ACHIEVEMENTS[id]
    goal = Achievements.next_threshold(id)
    progress = if goal.nil?
                 _INTL("Complete")
               else
                 _INTL("{1} / {2}", Achievements.commafy(Achievements.value_of(id)),
                       Achievements.commafy(goal))
               end
    description = data[:description]
    description = _INTL("{1} - {2}", data[:category], description) if data[:category]
    @sprites["panel"].change(description, progress)
  end

  def refresh_chrome
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base   = Color.new(248, 248, 248)
    shadow = Color.new(40, 40, 40)
    if @tab == 0
      title = _INTL("Achievements")
      right = _INTL("{1} / {2} tiers", Achievements.total_earned, Achievements.total_available)
    else
      title = _INTL("Records")
      right = _INTL("Lifetime totals")
    end
    # No footer band on this screen: Rejuvenation's geometry runs the rows to
    # y=296 and the description panel from there to y=378, so anything drawn
    # along the bottom lands on top of the panel. The page arrows are folded into
    # the title instead, which is what needed announcing -- LEFT/RIGHT switching
    # is the only non-obvious control here.
    pbSetSystemFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [_INTL("< {1} >", title), 14,  8, 0, base, shadow],
      [right,                   498, 8, 1, base, shadow]
    ])
  end

  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        pbPlayCursorSE
        switch_tab
      elsif @tab == 0 && !@ids.empty?
        if Input.repeat?(Input::DOWN)
          pbPlayCursorSE
          move_cursor(1)
        elsif Input.repeat?(Input::UP)
          pbPlayCursorSE
          move_cursor(-1)
        end
      end
    end
  end

  def move_cursor(delta)
    @index = (@index + delta) % @ids.length
    # Keep the cursor inside the visible window, clamped to the list bounds.
    @offset = @index - VISIBLE_ROWS + 1 if @index >= @offset + VISIBLE_ROWS
    @offset = @index if @index < @offset
    @offset = @offset.clamp(0, [@ids.length - VISIBLE_ROWS, 0].max)
    refresh_rows
  end

  def switch_tab
    @tab = 1 - @tab
    @sprites["records"].visible = (@tab == 1)
    @sprites["panel"].visible   = (@tab == 0)
    refresh_rows
    refresh_chrome
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
class Achievements_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbScene
    @scene.pbEndScene
  end
end

# Opens the Achievements / Records screen. Safe to call from an event Script.
def pbViewAchievements
  Achievements.check_all(true)   # sync tiers quietly before showing them
  scene = Achievements_Scene.new
  screen = Achievements_Screen.new(scene)
  screen.pbStartScreen
end
