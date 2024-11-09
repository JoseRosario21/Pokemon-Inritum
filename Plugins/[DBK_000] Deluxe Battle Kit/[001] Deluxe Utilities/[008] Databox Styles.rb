#===============================================================================
# Game data for databox styles.
#===============================================================================
module GameData
  class DataboxStyle
    attr_reader :id            # :Symbol              : ID for a style.
    attr_reader :real_name     # "String"             : Name of a style.
    attr_reader :sprite_x      # [ally, foe]          : Array of databox base x values. Ally side subtracts from Graphics.width.
    attr_reader :sprite_y      # [ally, foe]          : Array of databox base y values. Ally side subtracts from Graphics.height.
    attr_reader :sprite_base_x # [ally, foe]          : Array of x values to shift databox elements by based on side size.
    attr_reader :offset_x      # [[double], [triple]] : Arrays of x values to shift databox values by in double/triple battles.
    attr_reader :offset_y      # [[double], [triple]] : Arrays of y values to shift databox values by in double/triple battles.
    attr_reader :hp_offset     # [[ally], [foe]]      : Arrays of [x, y] values to shift HP bar positioning.
    attr_reader :exp_offset    # [x, y]               : Array of [x, y] values to shift Exp. bar positioning. Foe side doesn't use this.
    attr_reader :name_pos      # [[ally], [foe]]      : Arrays of [x, y, alignment] values for positioning a battler's name.
    attr_reader :owned_icon    # [x, y]               : Array of [x, y] values for ownership icon positioning. Ally side doesn't use this.
    attr_reader :shiny_icon    # [[ally], [foe]]      : Arrays of [x, y] values for shiny icon positioning.
    attr_reader :status_icon   # [[ally], [foe]]      : Arrays of [x, y] values for status icon positioning.
    attr_reader :special_icon  # [[ally], [foe]]      : Arrays of [x, y] values for Mega Evolution icon positioning (and others).
    attr_reader :vertical_anim # true/false           : When true, databox slides on/off screen vertically rather than horizontally.
    attr_reader :max_side_size # Integer (1-3)        : Sets the max side size this style is compatible with.
    
    DATA = {}

    extend ClassMethodsSymbols
    include InstanceMethods

    def self.load; end
    def self.save; end

    def initialize(hash)
      @id            = hash[:id]
      @real_name     = hash[:name]          || "Unnamed"
      @sprite_x      = hash[:sprite_x]      || [0, 0]
      @sprite_y      = hash[:sprite_y]      || [0, 0]
      @sprite_base_x = hash[:sprite_base_x] || [0, 0]
      @offset_x      = hash[:offset_x]      || [[0, 0, 0, 0], [0, 0, 0, 0, 0, 0]]
      @offset_y      = hash[:offset_y]      || [[0, 0, 0, 0], [0, 0, 0, 0, 0, 0]]
      @hp_offset     = hash[:hp_offset]     || [[0, 0], [0, 0]]
      @exp_offset    = hash[:exp_offset]    || [0, 0]
      @name_pos      = hash[:name_pos]      || [[0, 0], [0, 0]]
      @owned_icon    = hash[:owned_icon]    || [0, 0]
      @shiny_icon    = hash[:shiny_icon]    || [[0, 0], [0, 0]]
      @status_icon   = hash[:status_icon]   || [[0, 0], [0, 0]]
      @special_icon  = hash[:special_icon]  || [[0, 0], [0, 0]]
      @vertical_anim = hash[:vertical_anim] || false
      @max_side_size = hash[:max_side_size] || 3
    end

    def name
      return _INTL(@real_name)
    end
  end
end

#===============================================================================

# Basic databox style.
GameData::DataboxStyle.register({
  :id            => :Basic,
  :name          => _INTL("Basic"),
  :sprite_x      => [262, -16],
  :sprite_y      => [154, 12],
  :sprite_base_x => [34, 16],
  :offset_x      => [[0, 8, -8, 0],    [0, 16, -8, 8, -16, 0]],
  :offset_y      => [[-38, -8, 8, 38], [-80, -10, -34, 36, 12, 82]],
  :hp_offset     => [[46, 30], [90, 26]],
  :exp_offset    => [114, 40],
  :name_pos      => [[138, 6, :right], [22, 2, :left]],
  :owned_icon    => [2, 3],
  :shiny_icon    => [[154, 5],  [2, 23]],
  :status_icon   => [[182, 28], [18, 24]],
  :special_icon  => [[-34, 12], [276, 20]]
})

# Long databox style.
GameData::DataboxStyle.register({
  :id            => :Long,
  :name          => _INTL("Long"),
  :hp_offset     => [[0, 0], [50, 30]],
  :name_pos      => [[0, 0], [256, 4, :center]],
  :owned_icon    => [10, 27],
  :shiny_icon    => [[0, 0], [10, 25]],
  :status_icon   => [[0, 0], [4, 4]],
  :special_icon  => [[0, 0], [478, 16]],
  :vertical_anim => true,
  :max_side_size => 1
})



#===============================================================================
# Battle databox styles.
#===============================================================================
class Battle::Scene::PokemonDataBox
  attr_reader :style, :spriteX, :spriteY
  
  #-----------------------------------------------------------------------------
  # Text colors for stylized databoxes.
  #-----------------------------------------------------------------------------
  STYLE_BASE_COLOR     = Color.new(248, 248, 248)
  STYLE_SHADOW_COLOR   = Color.new(32, 32, 32)
  DYNAMAX_SHADOW_COLOR = Color.new(248, 32, 32)
  
  #-----------------------------------------------------------------------------
  # Aliases for setting databox style properties if battle rule is enabled.
  #-----------------------------------------------------------------------------
  alias dx_initializeDataBoxGraphic initializeDataBoxGraphic
  def initializeDataBoxGraphic(sideSize)
    rule = @battler.battle.databoxStyle
    if rule.is_a?(Array)
      @style = GameData::DataboxStyle.try_get(rule.first)
      case @battler.index
      when 1 then @title = rule[1]
      when 3 then @title = rule[2]
      when 5 then @title = rule[3]
      end
    else
      @style = GameData::DataboxStyle.try_get(rule)
    end
    if @style
      @path = Settings::DELUXE_GRAPHICS_PATH + "Databoxes"
      @databoxBitmap&.dispose
      box = (@battler.index.even?) ? "databox" : "databox_foe"
      try_file = sprintf("%s/%s/%s", @path, @style.id, box)
      if sideSize > @style.max_side_size || !pbResolveBitmap(try_file)
        @style = GameData::DataboxStyle.get(:Basic) 
      end
      @databoxBitmap = AnimatedBitmap.new(sprintf("%s/%s/%s", @path, @style.id, box))
      set_style_properties(sideSize)
    else
      dx_initializeDataBoxGraphic(sideSize)
    end
  end
  
  alias dx_initializeOtherGraphics initializeOtherGraphics
  def initializeOtherGraphics(viewport)
    if @style
      @numbersBitmap = AnimatedBitmap.new("Graphics/UI/Battle/icon_numbers")
      @hpNumbers = BitmapSprite.new(124, 16, viewport)
      @sprites["hpNumbers"] = @hpNumbers
      try_file = sprintf("%s/%s/overlay_exp", @path, @style.id)
      expPath = (pbResolveBitmap(try_file)) ? @style.id : :Basic
      @expBarBitmap = AnimatedBitmap.new(sprintf("%s/%s/overlay_exp", @path, expPath))
      @expBar = Sprite.new(viewport)
      @expBar.bitmap = @expBarBitmap.bitmap
      @sprites["expBar"] = @expBar
      overlay = (@battler.index.even?) ? "overlay_hp" : "overlay_hp_foe"
      @hpBarBitmap = AnimatedBitmap.new(sprintf("%s/%s/%s", @path, @style.id, overlay))
      @hpBar = Sprite.new(viewport)
      @hpBar.bitmap = @hpBarBitmap.bitmap
      @hpBar.src_rect.height = @hpBarBitmap.height / 3
      @sprites["hpBar"] = @hpBar
      @contents = Bitmap.new(@databoxBitmap.width, @databoxBitmap.height)
      self.bitmap  = @contents
      self.visible = false
      self.z       = 150 + ((@battler.index / 2) * 5)
      pbSetSmallFont(self.bitmap)
    else
      dx_initializeOtherGraphics(viewport)
    end
  end
  
  alias :dx_x= :x=
  def x=(value)
    self.dx_x=(value)
    @hpBar.x  = value + @hpOffsetXY[0]  if @hpOffsetXY
    @expBar.x = value + @expOffsetXY[0] if @expOffsetXY
  end

  alias :dx_y= :y=
  def y=(value)
    self.dx_y=(value)
    @hpBar.y  = value + @hpOffsetXY[1]  if @hpOffsetXY
    @expBar.y = value + @expOffsetXY[1] if @expOffsetXY
  end
  
  alias dx_refresh refresh
  def refresh
    return if !@battler.pokemon
    if @style
      self.bitmap.clear
      refresh_style
      draw_background
      draw_style_text
      draw_style_icons
      draw_plugin_elements
      refresh_hp
      refresh_exp
    else
      dx_refresh
    end
  end
  
  #-----------------------------------------------------------------------------
  # Used to set a databox's style to default in case the side size is changed mid-battle.
  #-----------------------------------------------------------------------------
  def refresh_style
    return if !@battler.index.odd?
    sideSize = @battler.battle.pbSideSize(@battler.index)
    if sideSize > @style.max_side_size
      @style = GameData::DataboxStyle.get(:Basic)
      set_style_properties(sideSize)
      @databoxBitmap&.dispose
      @databoxBitmap = AnimatedBitmap.new(sprintf("%s/%s/databox_foe", @path, @style.id))
      @hpBarBitmap = AnimatedBitmap.new(sprintf("%s/%s/overlay_hp_foe", @path, @style.id))
      @hpBar.bitmap = @hpBarBitmap.bitmap
      @hpBar.src_rect.height = @hpBarBitmap.height / 3
      @sprites["hpBar"] = @hpBar
      @contents = Bitmap.new(@databoxBitmap.width, @databoxBitmap.height)
      self.bitmap = @contents
      pbSetSmallFont(self.bitmap)
    end
  end

  #-----------------------------------------------------------------------------
  # Utility for setting values for each databox element based on style.
  #-----------------------------------------------------------------------------
  def set_style_properties(sideSize)
    shadow = (@battler.dynamax?) ? DYNAMAX_SHADOW_COLOR : STYLE_SHADOW_COLOR
    @nameColors = [STYLE_BASE_COLOR, shadow, :outline]
    if @battler.index.even?
      @spriteX = Graphics.width - @style.sprite_x[0]
      @spriteY = Graphics.height - @style.sprite_y[0]
    else
      @spriteX = @style.sprite_x[1].clone
      @spriteY = @style.sprite_y[1].clone
    end
    if sideSize > 1
      @spriteX += @style.offset_x[sideSize - 2][@battler.index]
      @spriteY += @style.offset_y[sideSize - 2][@battler.index]
    end
    side = (@battler.index.even?) ? 0 : 1
    @spriteBaseX  = @style.sprite_base_x[side].clone
    @hpOffsetXY   = @style.hp_offset[side].clone
    @expOffsetXY  = @style.exp_offset.clone
    @show_exp_bar = @battler.index.even?
    @displayPos   = {
      :name    => @style.name_pos[side].clone,
      :owned   => @style.owned_icon.clone,
      :shiny   => @style.shiny_icon[side].clone,
      :status  => @style.status_icon[side].clone,
      :special => @style.special_icon[side].clone
    }
    if @style.id == :Long
      @displayPos[:owned][0] = 2  if @battler.shiny?
      @displayPos[:shiny][0] = 18 if @battler.owned? && @battler.opposes?(0)
    end
    @displayPos.each_key { |k| @displayPos[k][0] += @spriteBaseX }
  end

  #-----------------------------------------------------------------------------
  # Draws plugin elements on a databox. Placeholder to be used by plugins.
  #-----------------------------------------------------------------------------
  def draw_plugin_elements; end
  
  #-----------------------------------------------------------------------------
  # Draws all text elements on a databox based on style.
  #-----------------------------------------------------------------------------
  def draw_style_text
    textpos = []
    namePos = @displayPos[:name]
    if @battler.index.even?
      case @battler.gender
      when 0 then textpos.push(["♂", *namePos, MALE_BASE_COLOR, STYLE_SHADOW_COLOR, @nameColors[2]])
      when 1 then textpos.push(["♀", *namePos, FEMALE_BASE_COLOR, STYLE_SHADOW_COLOR, @nameColors[2]])
      end
      textpos.push([@battler.name, namePos[0] - 16, namePos[1], namePos[2], *@nameColors])
      textpos.push([@battler.level.to_s, namePos[0] + 58, namePos[1], :left, STYLE_BASE_COLOR, STYLE_SHADOW_COLOR])
    elsif 
      if !@battler.wild?
        display_name = @battler.name
      elsif @title
        display_name = _INTL(@title, @battler.name)
      elsif defined?(@battler.pokemon.memento)
        display_name = @battler.name_title(false)
      else
        display_name = @battler.name
      end
      textpos.push([display_name, *namePos, *@nameColors])
    end
    pbDrawTextPositions(self.bitmap, textpos)
  end

  #-----------------------------------------------------------------------------
  # Draws all images on a databox based on style.
  #-----------------------------------------------------------------------------
  def draw_style_icons
    imagepos = []
    namePos = @displayPos[:name]
    imagepos.push([@path + "/overlay_lv", namePos[0] + 34, namePos[1] + 2]) if @battler.index.even?
    imagepos.push([@path + "/icon_own", *@displayPos[:owned]]) if @battler.owned? && @battler.opposes?(0)
    imagepos.push([@path + "/shiny", *@displayPos[:shiny]]) if @battler.shiny?
    if @battler.status != :NONE
      if @battler.status == :POISON && @battler.statusCount > 0
        s = GameData::Status.count - 1
      else
        s = GameData::Status.get(@battler.status).icon_position
      end
      imagepos.push([_INTL("Graphics/UI/Battle/icon_statuses"), *@displayPos[:status], 0, s * STATUS_ICON_HEIGHT, -1, STATUS_ICON_HEIGHT])
    end
    specialPos = @displayPos[:special]
    if @battler.mega?
      base_file = "Graphics/UI/Battle/icon_mega"
      try_file = base_file + "_" + @battler.pokemon.speciesName
      filename = (pbResolveBitmap(try_file)) ? try_file : base_file
      imagepos.push([filename, specialPos[0] + 4, specialPos[1] + 4]) if filename
    elsif @battler.primal?
      base_file = "Graphics/UI/Battle/icon_primal"
      try_file = base_file + "_" + @battler.pokemon.speciesName
      filename = (pbResolveBitmap(try_file)) ? try_file : base_file
      imagepos.push([filename, *specialPos]) if filename
    elsif @battler.ultra?
      filename = Settings::ZMOVE_GRAPHICS_PATH + "icon_ultra"
      imagepos.push([filename, specialPos[0], specialPos[1] + 2])
    elsif @battler.dynamax?
      filename = Settings::DYNAMAX_GRAPHICS_PATH + "icon_dynamax"
      imagepos.push([filename, *specialPos])
    elsif @battler.tera?
      filename = Settings::TERASTAL_GRAPHICS_PATH + "tera_types"
      type_number = GameData::Type.get(@battler.tera_type).icon_position
      imagepos.push([filename, specialPos[0], specialPos[1] + 2, 0, type_number * 32, 32, 32])
    elsif @battler.hasZCrystal? && @battler.battle.raidBattle?
      filename = _INTL("Graphics/Items/#{@battler.item_id}")
      offsetX = (@battler.index.even?) ? 0   : (@style.id == :Basic) ? -12 : -16
      offsetY = (@battler.index.even?) ? -12 : (@style.id == :Basic) ? -24 : -24
      imagepos.push([filename, specialPos[0] + offsetX, specialPos[1] + offsetY])
    end
    pbDrawImagePositions(self.bitmap, imagepos)
  end
end


#===============================================================================
# Aliases to the show/hide animations for certain databox styles.
#===============================================================================
class Battle::Scene::Animation::DataBoxAppear < Battle::Scene::Animation
  alias dx_createProcesses createProcesses
  def createProcesses
    sprite = @sprites["dataBox_#{@idxBox}"]
    return if !sprite
    if sprite.style && GameData::DataboxStyle.get(sprite.style).vertical_anim
      box = addSprite(sprite)
      box.setVisible(0, true)
      box.setDelta(0, 0, -sprite.height)
      box.moveDelta(0, 8, 0, sprite.height)
    else
      dx_createProcesses
    end
  end
end

class Battle::Scene::Animation::DataBoxDisappear < Battle::Scene::Animation
  alias dx_createProcesses createProcesses
  def createProcesses
    sprite = @sprites["dataBox_#{@idxBox}"]
    return if !sprite
    if sprite.style && GameData::DataboxStyle.get(sprite.style).vertical_anim
      box = addSprite(sprite)
      box.setDelta(0, 0, 0)
      box.moveDelta(0, 8, 0, -sprite.height)
      box.setVisible(8, false)
    else
      dx_createProcesses
    end
  end
end