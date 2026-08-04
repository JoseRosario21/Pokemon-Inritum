#===============================================================================
# Text Log - UI
#
# A single scrolling screen, newest entry at the bottom and the view opening
# there -- the reason you open a log is almost always "what did that last line
# say", so starting at the top would mean scrolling the whole history every time.
#
#   Graphics/UI/TextLog/bg.png  512x384  background; content band 58-340
#
# Uses the same bands and the same one-line-per-press scrolling as Field Notes
# and the Boss Dex.
#===============================================================================
class Window_TextLog < Window_DrawableCommand
  INDENT      = { :message => 4, :choice => 20, :system => 4 }.freeze
  CONT_INDENT = 12

  def initialize(x, y, width, height, viewport)
    @lines = []
    super(x, y, width, height, viewport)
    self.windowskin  = nil
    self.baseColor   = Color.new(248, 248, 248)
    self.shadowColor = Color.new(40, 40, 40)
  end

  def entries=(value)
    @lines = wrap_entries(value)
    self.index = max_top_row
    self.top_row = max_top_row
    refresh
  end

  def indent_for(line)
    base = INDENT[line[:kind]] || INDENT[:message]
    base += CONT_INDENT if line[:cont]
    return base
  end

  # Rows are a fixed height, so entries must be split before drawing or a long
  # line spills onto the row below it.
  def wrap_entries(source)
    return [] if source.nil?
    bitmap = self.contents
    return [] if bitmap.nil?
    out = []
    source.each do |entry|
      kind = entry[:kind] || :message
      text = entry[:text].to_s
      text = _INTL("> {1}", text) if kind == :choice
      words = text.split(/\s+/)
      next if words.empty?
      first = true
      current = ""
      words.each do |word|
        available = self.width - self.borderX - indent_for({ :kind => kind, :cont => !first }) - 8
        candidate = current.empty? ? word : current + " " + word
        if !current.empty? && bitmap.text_size(candidate).width > available
          out.push({ :kind => kind, :text => current, :cont => !first })
          first = false
          current = word
        else
          current = candidate
        end
      end
      out.push({ :kind => kind, :text => current, :cont => !first }) if !current.empty?
    end
    return out
  end

  def itemCount
    return [@lines.length, 1].max
  end

  def drawCursor(_index, _rect); end

  def max_top_row
    return [itemCount - page_row_max, 0].max
  end

  # Index is the top row, so every press scrolls exactly one line and neither
  # end has dead presses.
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
      drawFormattedTextEx(self.contents, rect.x + 4, rect.y + 2, rect.width - 8,
                          _INTL("Nothing has been said yet."), self.baseColor, self.shadowColor)
      return
    end
    line = @lines[index]
    return if !line
    text = line[:text]
    case line[:kind]
    when :choice then text = TextLog.color_tag(TextLog::COLOR_CHOICE) + text + "</c3>"
    when :system then text = TextLog.color_tag(TextLog::COLOR_SYSTEM) + text + "</c3>"
    end
    x = rect.x + indent_for(line)
    drawFormattedTextEx(self.contents, x, rect.y + 2, rect.width - (x - rect.x),
                        text, self.baseColor, self.shadowColor)
  end
end

#===============================================================================
class TextLog_Scene
  CONTENT_Y      = 64
  CONTENT_HEIGHT = 272
  # Optical centring. The system font renders ~32px (27pt at mkxp's fontScale
  # 1.20) and the small font ~25px, and RGSS centres glyphs inside the box
  # pbDrawTextPositions passes -- so a title at y=8 sits slightly above the
  # middle of the 0-46 header band. These two are the knobs for that.
  HEADER_Y       = 12
  FOOTER_Y       = Graphics.height - 30

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}

    @sprites["bg"] = IconSprite.new(0, 0, @viewport)
    @sprites["bg"].setBitmap("Graphics/UI/TextLog/bg")
    @sprites["bg"].z = 255

    @sprites["log"] = Window_TextLog.new(8, CONTENT_Y, Graphics.width - 16,
                                         CONTENT_HEIGHT, @viewport)
    @sprites["log"].z = 256
    @sprites["log"].entries = TextLog.entries

    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].z = 260
    pbSetSystemFont(@sprites["overlay"].bitmap)

    refresh_chrome
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def refresh_chrome
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base   = Color.new(248, 248, 248)
    shadow = Color.new(40, 40, 40)
    pbSetSystemFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [_INTL("Text Log"),                            14,  HEADER_Y, 0, base, shadow],
      [_INTL("{1} entries", TextLog.entries.length), 498, HEADER_Y, 1, base, shadow]
    ])
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [_INTL("UP/DOWN  Scroll"), 14,  FOOTER_Y, 0, base, shadow],
      [_INTL("BACK  Exit"),      498, FOOTER_Y, 1, base, shadow]
    ])
  end

  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      break if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
    end
    pbPlayCloseMenuSE
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
class TextLog_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbScene
    @scene.pbEndScene
  end
end

# Opens the Text Log. Safe to call from an event Script command.
def pbViewTextLog
  scene = TextLog_Scene.new
  screen = TextLog_Screen.new(scene)
  screen.pbStartScreen
end
