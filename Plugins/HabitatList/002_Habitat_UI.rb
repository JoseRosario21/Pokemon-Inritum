#===============================================================================
# Habitat List - UI
#
# Same two-screen shape and screen bands as Field Notes / Boss Dex:
#   Graphics/UI/HabitatList/bg.png   512x384  map list (list rect 94,64 - 324x272)
#   Graphics/UI/HabitatList/app.png  512x384  species page chrome
#===============================================================================
class Window_HabitatMapList < Window_DrawableCommand
  def initialize(x, y, width, height, viewport)
    @maps = []
    super(x, y, width, height, viewport)
    self.windowskin  = nil
    self.baseColor   = Color.new(248, 248, 248)
    self.shadowColor = Color.new(40, 40, 40)
  end

  def maps=(value)
    @maps = value
    self.index = 0
    self.top_row = 0
    refresh
  end

  def map_id
    return @maps[self.index]
  end

  def itemCount
    return [@maps.length, 1].max
  end

  def drawItem(index, _count, rect)
    rect = drawCursor(index, rect)
    if @maps.empty?
      drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width,
                          _INTL("No areas recorded yet."), self.baseColor, self.shadowColor)
      return
    end
    id = @maps[index]
    return if !id
    seen, owned, total = HabitatList.completion(id)
    tag = if total > 0 && owned >= total
            HabitatList.color_tag(HabitatList::COLOR_OWNED)
          elsif seen > 0
            HabitatList.color_tag(HabitatList::COLOR_SEEN)
          else
            HabitatList.color_tag(HabitatList::COLOR_UNSEEN)
          end
    drawFormattedTextEx(self.contents, rect.x, rect.y + 2, rect.width - 70,
                        tag + HabitatList.map_name(id) + "</c3>",
                        self.baseColor, self.shadowColor)
    drawFormattedTextEx(self.contents, rect.x + rect.width - 66, rect.y + 2, 62,
                        "<ar>" + sprintf("%d/%d", owned, total) + "</ar>",
                        self.baseColor, self.shadowColor)
  end
end

#===============================================================================
class Window_HabitatPage < Window_DrawableCommand
  INDENT      = { :header => 0, :note => 12 }.freeze
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

  def wrap_lines(source)
    return [] if source.nil?
    bitmap = self.contents
    return source if bitmap.nil?
    out = []
    source.each do |line|
      kind = line[:kind] || :note
      words = line[:text].to_s.split(/\s+/)
      if words.empty?
        out.push(line.merge({ :cont => false }))
        next
      end
      first = true
      current = ""
      words.each do |word|
        available = self.width - self.borderX - indent_for({ :kind => kind, :cont => !first }) - 8
        candidate = current.empty? ? word : current + " " + word
        if !current.empty? && bitmap.text_size(candidate).width > available
          out.push(line.merge({ :text => current, :cont => !first }))
          first = false
          current = word
        else
          current = candidate
        end
      end
      out.push(line.merge({ :text => current, :cont => !first })) if !current.empty?
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
    if line[:kind] == :header
      text = HabitatList.color_tag(HabitatList::COLOR_HEADER) + "<b>" + line[:text] + "</b></c3>"
    else
      tag = case line[:status]
            when :owned then HabitatList.color_tag(HabitatList::COLOR_OWNED)
            when :seen  then HabitatList.color_tag(HabitatList::COLOR_SEEN)
            when :unseen then HabitatList.color_tag(HabitatList::COLOR_UNSEEN)
            end
      text = tag ? tag + line[:text] + "</c3>" : line[:text]
    end
    x = rect.x + indent_for(line)
    drawFormattedTextEx(self.contents, x, rect.y + 2, rect.width - (x - rect.x),
                        text, self.baseColor, self.shadowColor)
  end
end

#===============================================================================
class HabitatList_Scene
  LIST_X = 94; LIST_Y = 64; LIST_W = 324; LIST_H = 272
  PAGE_X = 8;  PAGE_Y = 64; PAGE_W = 496; PAGE_H = 272
  # Optical centring. The system font renders ~32px (27pt at mkxp's fontScale
  # 1.20) and the small font ~25px, and RGSS centres glyphs inside the box
  # pbDrawTextPositions passes -- so a title at y=8 sits slightly above the
  # middle of the 0-46 header band. These two are the knobs for that.
  HEADER_Y = 12
  FOOTER_Y = Graphics.height - 30

  def pbUpdate; pbUpdateSpriteHash(@sprites); end

  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @maps = HabitatList.listed_map_ids

    @sprites["listbg"] = IconSprite.new(0, 0, @viewport)
    @sprites["listbg"].setBitmap("Graphics/UI/HabitatList/bg")
    @sprites["listbg"].z = 255

    @sprites["appbg"] = IconSprite.new(0, 0, @viewport)
    @sprites["appbg"].setBitmap("Graphics/UI/HabitatList/app")
    @sprites["appbg"].z = 255
    @sprites["appbg"].visible = false

    @sprites["list"] = Window_HabitatMapList.new(LIST_X, LIST_Y, LIST_W, LIST_H, @viewport)
    @sprites["list"].z = 256
    @sprites["list"].maps = @maps

    @sprites["page"] = Window_HabitatPage.new(PAGE_X, PAGE_Y, PAGE_W, PAGE_H, @viewport)
    @sprites["page"].z = 256
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
    base = Color.new(248, 248, 248); shadow = Color.new(40, 40, 40)
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
    total_owned = 0
    total_all = 0
    @maps.each { |id| _s, o, t = HabitatList.completion(id); total_owned += o; total_all += t }
    pbDrawTextPositions(bitmap, [
      [_INTL("Habitats"), 14, HEADER_Y, 0, base, shadow],
      [_INTL("{1}/{2} caught", total_owned, total_all), 498, HEADER_Y, 1, base, shadow]
    ])
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [
      [_INTL("USE  View"),   256, FOOTER_Y, 2, base, shadow],
      [_INTL("BACK  Exit"),  498, FOOTER_Y, 1, base, shadow]
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
      elsif Input.trigger?(Input::USE)
        id = @sprites["list"].map_id
        if id.nil?
          pbPlayBuzzerSE
        else
          pbPlayDecisionSE
          show_page(id)
        end
      end
    end
  end

  def show_page(map_id)
    @sprites["page"].lines = HabitatList.build_page(map_id)
    @sprites["list"].visible   = false
    @sprites["listbg"].visible = false
    @sprites["appbg"].visible  = true
    @sprites["page"].visible   = true
    refresh_chrome(HabitatList.map_name(map_id))
    loop do
      Graphics.update
      Input.update
      pbUpdate
      break if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
    end
    pbPlayCloseMenuSE
    @sprites["page"].visible   = false
    @sprites["appbg"].visible  = false
    @sprites["listbg"].visible = true
    @sprites["list"].visible   = true
    refresh_chrome
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
class HabitatList_Screen
  def initialize(scene); @scene = scene; end
  def pbStartScreen
    @scene.pbStartScene
    @scene.pbScene
    @scene.pbEndScene
  end
end

def pbViewHabitats
  scene = HabitatList_Scene.new
  screen = HabitatList_Screen.new(scene)
  screen.pbStartScreen
end

#===============================================================================
MenuHandlers.add(:pokegear_menu, :habitats, {
  "name"      => _INTL("Habitats"),
  "icon_name" => "habitats",
  "order"     => 37,
  "condition" => proc { next $player && $player.has_pokedex },
  "effect"    => proc { |_menu|
    pbPlayDecisionSE
    pbFadeOutIn { pbViewHabitats }
    next false
  }
})
