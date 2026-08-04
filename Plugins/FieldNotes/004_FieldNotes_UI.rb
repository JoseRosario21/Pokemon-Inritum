#===============================================================================
# Field Notes - UI
#
# Layout follows Pokemon Rejuvenation's Field Notes app so custom art drops
# straight in:
#
#   Graphics/UI/FieldNotes/bg.png   512x384  list screen background
#                                            (list rect is 94,64 - 324x288)
#   Graphics/UI/FieldNotes/app.png  512x384  detail screen chrome; keep the
#                                            middle translucent so the field's
#                                            own artwork shows through
#
# The detail screen fades the field's real battle background in behind the notes
# -- the same touch Rejuvenation uses. Those come from Graphics/Fieldbacks/
# (<Fieldback>_battlebg.png), which the Field Effect plugin already ships, so it
# works for every field without any new art.
#
# Placeholder art ships with the plugin; replacing those two files reskins it.
#===============================================================================

#===============================================================================
# Scrolling list of field names within one category.
#===============================================================================
class Window_FieldNoteList < Window_DrawableCommand
  def initialize(x, y, width, height, viewport)
    @fields = []
    super(x, y, width, height, viewport)
    self.windowskin  = nil
    self.baseColor   = Color.new(248, 248, 248)
    self.shadowColor = Color.new(40, 40, 40)
  end

  def fields=(value)
    @fields = value
    self.index = 0
    refresh
  end

  def field
    return @fields[self.index]
  end

  def itemCount
    return [@fields.length, 1].max   # keep one row so the empty message shows
  end

  def drawItem(index, _count, rect)
    # The base class expects drawItem to draw the selection arrow itself and use
    # the inset rect it returns -- refresh never calls drawCursor for us.
    rect = drawCursor(index, rect)
    if @fields.empty?
      drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width,
                          _INTL("Nothing recorded yet."), self.baseColor, self.shadowColor)
      return
    end
    data = @fields[index]
    return if !data
    seen = FieldNotes.seen?(data.id)
    name = seen ? data.name : _INTL("- - - - -")
    tag = seen ? FieldNotes.category_tag(data.category) : FieldNotes.color_tag(FieldNotes::DEFAULT_CATEGORY_COLOR)
    drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width,
                        tag + name + "</c3>", self.baseColor, self.shadowColor)
  end
end

#===============================================================================
# Scrolling view of one field's notes. Cursor is suppressed: this is a document,
# not a menu, but Window_DrawableCommand gives us row scrolling for free.
#===============================================================================
class Window_FieldNotePage < Window_DrawableCommand
  def initialize(x, y, width, height, viewport)
    @lines = []
    super(x, y, width, height, viewport)
    self.windowskin  = nil
    self.baseColor   = Color.new(248, 248, 248)
    self.shadowColor = Color.new(40, 40, 40)
  end

  # Indent per line kind, and how much further a wrapped continuation sits in.
  INDENT      = { :header => 0, :flavour => 16, :note => 8 }.freeze
  CONT_INDENT = 12

  def lines=(value)
    # Rows are a fixed height, so a line long enough to wrap would spill over the
    # row below it. Pre-splitting into row-sized pieces is what keeps the page
    # readable -- a grouped move list can easily run to three lines.
    @lines = wrap_lines(value)
    self.index = 0
    self.top_row = 0
    refresh
  end

  #-----------------------------------------------------------------------------
  # Scrolling
  #
  # This is a document, not a menu: there is no visible cursor, so the default
  # behaviour -- a hidden index walking down off-screen rows before the view
  # moves at all -- just reads as "the button did nothing" for the first several
  # presses. Treating the index AS the top row makes every press scroll exactly
  # one line, and clamping it to the last full page removes the same dead
  # presses at the bottom.
  #
  # The index is kept live (rather than setting active = false and scrolling by
  # hand) because the up/down arrow sprites only appear while the window is
  # active, and those arrows are what tell the player there is more to read.
  #-----------------------------------------------------------------------------
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

  def indent_for(line)
    base = INDENT[line[:kind]] || INDENT[:note]
    base += CONT_INDENT if line[:cont]
    return base
  end

  # Greedy wrap measured against the window's own font, so it stays correct if
  # the font or the window width changes.
  def wrap_lines(source)
    return [] if source.nil?
    bitmap = self.contents
    return source if bitmap.nil?
    out = []
    source.each do |line|
      kind = line[:kind] || :note
      words = line[:text].to_s.split(/\s+/)
      if words.empty?
        out.push({ :kind => kind, :text => "", :cont => false })
        next
      end
      first = true
      current = ""
      words.each do |word|
        probe = { :kind => kind, :cont => !first }
        available = self.width - self.borderX - indent_for(probe) - 8
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

  # Read-only view: drawItem never calls this, and overriding it to a no-op
  # keeps it that way if the drawing code is ever edited.
  def drawCursor(_index, _rect); end

  def drawItem(index, _count, rect)
    return if @lines.empty?
    line = @lines[index]
    return if !line
    # Styling is applied here rather than baked into the text, so the builder
    # emits plain strings and wrapping never has to split a formatting tag.
    case line[:kind]
    when :header
      text = FieldNotes.color_tag(FieldNotes::COLOR_HEADER) + "<b>" + line[:text] + "</b></c3>"
    when :flavour
      text = "<i>" + line[:text] + "</i>"
    else
      text = line[:text]
    end
    x = rect.x + indent_for(line)
    drawFormattedTextEx(self.contents, x, rect.y + 2, rect.width - (x - rect.x),
                        text, self.baseColor, self.shadowColor)
  end
end

#===============================================================================
# Scene
#===============================================================================
class FieldNotes_Scene
  # Content stops at y=336 so the footer band (344-384 in the background art) is
  # left clear -- hints drawn any lower collide with the panel edge.
  LIST_X      = 94
  LIST_Y      = 64
  LIST_WIDTH  = 324
  LIST_HEIGHT = 272

  NOTES_X      = 8
  NOTES_Y      = 64
  NOTES_HEIGHT = 272

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @groups = FieldNotes.grouped_fields
    @groups = [[_INTL("Fields"), []]] if @groups.empty?
    @category = 0

    # Faded field artwork, only shown on a field's page.
    @sprites["fieldback"] = IconSprite.new(0, 48, @viewport)
    @sprites["fieldback"].z = 254
    @sprites["fieldback"].opacity = 55
    @sprites["fieldback"].visible = false

    @sprites["listbg"] = IconSprite.new(0, 0, @viewport)
    @sprites["listbg"].setBitmap("Graphics/UI/FieldNotes/bg")
    @sprites["listbg"].z = 255

    @sprites["appbg"] = IconSprite.new(0, 0, @viewport)
    @sprites["appbg"].setBitmap("Graphics/UI/FieldNotes/app")
    @sprites["appbg"].z = 255
    @sprites["appbg"].visible = false

    @sprites["list"] = Window_FieldNoteList.new(LIST_X, LIST_Y, LIST_WIDTH, LIST_HEIGHT, @viewport)
    @sprites["list"].z = 256
    @sprites["list"].fields = @groups[@category][1]

    @sprites["page"] = Window_FieldNotePage.new(NOTES_X, NOTES_Y, Graphics.width - NOTES_X,
                                                NOTES_HEIGHT, @viewport)
    @sprites["page"].z = 256
    @sprites["page"].visible = false

    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].z = 260
    pbSetSystemFont(@sprites["overlay"].bitmap)

    refresh_chrome
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  # Header and footer. Passing a title switches to the detail-screen layout.
  #
  # Titles use the system font, hints the small one -- three hints in the system
  # font do not fit across 512px and run into each other. The header is kept to a
  # single line for the same reason: the system font's line height is taller than
  # the gap between two stacked lines would allow.
  # Optical centring. The system font renders ~32px (27pt at mkxp's fontScale
  # 1.20) and the small font ~25px, and RGSS centres glyphs inside the box
  # pbDrawTextPositions passes -- so a title at y=8 sits slightly above the
  # middle of the 0-46 header band. These two are the knobs for that.
  HEADER_Y = 12
  FOOTER_Y = Graphics.height - 30

  def refresh_chrome(page_title = nil)
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base   = Color.new(248, 248, 248)
    shadow = Color.new(40, 40, 40)

    pbSetSystemFont(bitmap)
    if page_title
      pbDrawTextPositions(bitmap, [[page_title, 14, HEADER_Y, 0, base, shadow]])
      pbSetSmallFont(bitmap)
      pbDrawTextPositions(bitmap, [
        [_INTL("UP/DOWN  Scroll"), 14,  FOOTER_Y, 0, base, shadow],
        [_INTL("BACK  Return"),    498, FOOTER_Y, 1, base, shadow]
      ])
      return
    end

    category = @groups[@category][0]
    count = @groups[@category][1].count { |d| FieldNotes.seen?(d.id) }
    total = @groups[@category][1].length
    pbDrawTextPositions(bitmap, [
      [_INTL("Field Notes"), 14, HEADER_Y, 0, base, shadow],
      [_INTL("{1}  {2}/{3}", category, count, total), 498, HEADER_Y, 1, base, shadow]
    ])

    # Rather than a modal on a locked entry, the footer says why it can't be
    # opened. A message box would sit at the same z as this scene's viewport.
    selected = @sprites["list"] ? @sprites["list"].field : nil
    action = if selected.nil?
               ""
             elsif FieldNotes.seen?(selected.id)
               _INTL("Read")
             else
               _INTL("Locked")
             end
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [_INTL("< >  Category"), 14,  FOOTER_Y, 0, base, shadow],
      [action,                 256, FOOTER_Y, 2, base, shadow],
      [_INTL("BACK  Exit"),    498, FOOTER_Y, 1, base, shadow]
    ])
  end

  def pbScene
    @last_index = -1
    loop do
      Graphics.update
      Input.update
      pbUpdate
      # The list window handles its own cursor, so watch its index rather than
      # the arrow keys to know when the footer hint needs redrawing.
      if @sprites["list"].index != @last_index
        @last_index = @sprites["list"].index
        refresh_chrome
      end
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        data = @sprites["list"].field
        if data.nil?
          pbPlayBuzzerSE
        elsif !FieldNotes.seen?(data.id)
          pbPlayBuzzerSE
        else
          pbPlayDecisionSE
          show_page(data)
        end
      elsif Input.trigger?(Input::RIGHT) && @groups.length > 1
        pbPlayCursorSE
        @category = (@category + 1) % @groups.length
        @sprites["list"].fields = @groups[@category][1]
        refresh_chrome
      elsif Input.trigger?(Input::LEFT) && @groups.length > 1
        pbPlayCursorSE
        @category = (@category - 1) % @groups.length
        @sprites["list"].fields = @groups[@category][1]
        refresh_chrome
      end
    end
  end

  # The field's own battle background, if it has one.
  def apply_fieldback(data)
    sprite = @sprites["fieldback"]
    path = nil
    if data.fieldback && !data.fieldback.empty?
      candidate = sprintf("Graphics/Fieldbacks/%s_battlebg", data.fieldback)
      path = candidate if pbResolveBitmap(candidate)
    end
    if path
      sprite.setBitmap(path)
      sprite.visible = true
    else
      sprite.visible = false
    end
  end

  def show_page(data)
    @sprites["page"].lines = FieldNotes.build_page(data)
    apply_fieldback(data)
    @sprites["list"].visible  = false
    @sprites["listbg"].visible = false
    @sprites["appbg"].visible  = true
    @sprites["page"].visible   = true
    refresh_chrome(data.name)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        pbPlayCloseMenuSE
        break
      end
    end
    @sprites["page"].visible      = false
    @sprites["appbg"].visible     = false
    @sprites["fieldback"].visible = false
    @sprites["listbg"].visible    = true
    @sprites["list"].visible      = true
    refresh_chrome
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
class FieldNotes_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbScene
    @scene.pbEndScene
  end
end

# Opens the Field Notes catalogue. Safe to call from an event Script command.
def pbViewFieldNotes
  scene = FieldNotes_Scene.new
  screen = FieldNotes_Screen.new(scene)
  screen.pbStartScreen
end
