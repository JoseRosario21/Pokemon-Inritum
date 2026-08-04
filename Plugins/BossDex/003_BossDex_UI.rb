#===============================================================================
# Boss Dex - UI
#
# Same two-screen shape as Field Notes, which in turn follows Rejuvenation's
# app layout, so the three screens feel like one system:
#
#   Graphics/UI/BossDex/bg.png   512x384  list background (list rect 94,64 - 324x288)
#   Graphics/UI/BossDex/app.png  512x384  entry chrome; centre stays translucent
#
# The entry screen shows the boss's actual battler sprite, pulled from the
# species graphics the game already has, so it needs no per-boss art.
#
# Screen bands match Field Notes: header 0-46, content 58-340, footer 344-384.
#===============================================================================

#===============================================================================
class Window_BossDexList < Window_DrawableCommand
  def initialize(x, y, width, height, viewport)
    @bosses = []
    super(x, y, width, height, viewport)
    self.windowskin  = nil
    self.baseColor   = Color.new(248, 248, 248)
    self.shadowColor = Color.new(40, 40, 40)
  end

  def bosses=(value)
    @bosses = value
    self.index = 0
    self.top_row = 0
    refresh
  end

  def boss
    return @bosses[self.index]
  end

  def itemCount
    return [@bosses.length, 1].max
  end

  def drawItem(index, _count, rect)
    rect = drawCursor(index, rect)
    if @bosses.empty?
      drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width,
                          _INTL("No bosses recorded yet."), self.baseColor, self.shadowColor)
      return
    end
    boss_id = @bosses[index]
    return if !boss_id
    if !BossDex.encountered?(boss_id)
      tag  = BossDex.color_tag(BossDex::COLOR_LOCKED)
      text = _INTL("- - - - -")
    else
      tag  = BossDex.defeated?(boss_id) ? BossDex.color_tag(BossDex::COLOR_DEFEATED)
                                        : BossDex.color_tag(BossDex::COLOR_ENCOUNTERED)
      text = BossDex.name_of(boss_id)
    end
    drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width,
                        tag + text + "</c3>", self.baseColor, self.shadowColor)
  end
end

#===============================================================================
# The entry page. Read-only, so it scrolls a line per press rather than moving a
# cursor nobody can see -- same reasoning as the Field Notes page.
#===============================================================================
class Window_BossDexPage < Window_DrawableCommand
  INDENT      = { :header => 0, :note => 8, :subnote => 24, :flavour => 16 }.freeze
  CONT_INDENT = 12

  def initialize(x, y, width, height, viewport)
    @lines = []
    super(x, y, width, height, viewport)
    self.windowskin  = nil
    self.baseColor   = Color.new(248, 248, 248)
    self.shadowColor = Color.new(40, 40, 40)
  end

  def lines=(value)
    @lines = wrap_lines(value)
    self.index = 0
    self.top_row = 0
    refresh
  end

  def indent_for(line)
    base = INDENT[line[:kind]] || INDENT[:note]
    base += CONT_INDENT if line[:cont]
    return base
  end

  # Rows are a fixed height, so long lines must be split before drawing or they
  # spill onto the row below.
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
    return if @lines.empty?
    line = @lines[index]
    return if !line
    case line[:kind]
    when :header
      text = BossDex.color_tag(BossDex::COLOR_HEADER) + "<b>" + line[:text] + "</b></c3>"
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
class BossDex_Scene
  LIST_X      = 94
  LIST_Y      = 64
  LIST_WIDTH  = 324
  LIST_HEIGHT = 272

  PAGE_X      = 8
  PAGE_Y      = 64
  PAGE_WIDTH  = 340      # leaves room for the boss sprite on the right
  PAGE_HEIGHT = 272

  # Optical centring. The system font renders ~32px (27pt at mkxp's fontScale
  # 1.20) and the small font ~25px, and RGSS centres glyphs inside the box
  # pbDrawTextPositions passes -- so a title at y=8 sits slightly above the
  # middle of the 0-46 header band. These two are the knobs for that.
  HEADER_Y = 12
  FOOTER_Y = Graphics.height - 30

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @bosses = BossDex.listed_bosses

    @sprites["listbg"] = IconSprite.new(0, 0, @viewport)
    @sprites["listbg"].setBitmap("Graphics/UI/BossDex/bg")
    @sprites["listbg"].z = 255

    @sprites["appbg"] = IconSprite.new(0, 0, @viewport)
    @sprites["appbg"].setBitmap("Graphics/UI/BossDex/app")
    @sprites["appbg"].z = 255
    @sprites["appbg"].visible = false

    @sprites["battler"] = PokemonSprite.new(@viewport)
    @sprites["battler"].setOffset(PictureOrigin::CENTER)
    @sprites["battler"].x = 424
    @sprites["battler"].y = 190
    @sprites["battler"].z = 256
    @sprites["battler"].visible = false

    @sprites["list"] = Window_BossDexList.new(LIST_X, LIST_Y, LIST_WIDTH, LIST_HEIGHT, @viewport)
    @sprites["list"].z = 257
    @sprites["list"].bosses = @bosses

    @sprites["page"] = Window_BossDexPage.new(PAGE_X, PAGE_Y, PAGE_WIDTH, PAGE_HEIGHT, @viewport)
    @sprites["page"].z = 257
    @sprites["page"].visible = false

    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].z = 260
    pbSetSystemFont(@sprites["overlay"].bitmap)

    refresh_chrome
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

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

    met, won, total = BossDex.counts
    pbDrawTextPositions(bitmap, [
      [_INTL("Boss Dex"),                        14,  HEADER_Y, 0, base, shadow],
      [_INTL("{1} met  {2} beaten  /{3}", met, won, total), 498, HEADER_Y, 1, base, shadow]
    ])

    selected = @sprites["list"] ? @sprites["list"].boss : nil
    action = if selected.nil?
               ""
             elsif BossDex.encountered?(selected)
               _INTL("Read")
             else
               _INTL("Locked")
             end
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [action,              256, FOOTER_Y, 2, base, shadow],
      [_INTL("BACK  Exit"), 498, FOOTER_Y, 1, base, shadow]
    ])
  end

  def pbScene
    @last_index = -1
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if @sprites["list"].index != @last_index
        @last_index = @sprites["list"].index
        refresh_chrome
      end
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        boss_id = @sprites["list"].boss
        if boss_id.nil? || !BossDex.encountered?(boss_id)
          pbPlayBuzzerSE
        else
          pbPlayDecisionSE
          show_page(boss_id)
        end
      end
    end
  end

  # Uses the species' own battler graphic, so no per-boss art is needed. A boss
  # whose form has no sprite simply shows nothing rather than erroring.
  def apply_battler(boss_id)
    data = BossDex.data_for(boss_id)
    sprite = @sprites["battler"]
    sprite.visible = false
    return if !data || !data[:species]
    begin
      pkmn = Pokemon.new(data[:species], data[:level] || 50, $player, false)
      pkmn.form = data[:form] if data[:form]
      sprite.setPokemonBitmap(pkmn, false)
      sprite.visible = true
    rescue StandardError => e
      echoln("[Boss Dex] no battler sprite for #{boss_id}: #{e.message}") if $DEBUG
      sprite.visible = false
    end
  end

  def show_page(boss_id)
    @sprites["page"].lines = BossDex.build_page(boss_id)
    apply_battler(boss_id)
    @sprites["list"].visible   = false
    @sprites["listbg"].visible = false
    @sprites["appbg"].visible  = true
    @sprites["page"].visible   = true
    refresh_chrome(BossDex.name_of(boss_id))
    loop do
      Graphics.update
      Input.update
      pbUpdate
      break if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
    end
    pbPlayCloseMenuSE
    @sprites["page"].visible    = false
    @sprites["appbg"].visible   = false
    @sprites["battler"].visible = false
    @sprites["listbg"].visible  = true
    @sprites["list"].visible    = true
    refresh_chrome
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
class BossDex_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbScene
    @scene.pbEndScene
  end
end

# Opens the Boss Dex. Safe to call from an event Script command.
def pbViewBossDex
  scene = BossDex_Scene.new
  screen = BossDex_Screen.new(scene)
  screen.pbStartScreen
end
