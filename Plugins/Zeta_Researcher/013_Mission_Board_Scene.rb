#===============================================================================
# Mission Board Scene - displays available, completed, and locked missions
#===============================================================================
class MissionBoardScene
  SECTION_DAILY_AVAILABLE  = 0
  SECTION_DAILY_COMPLETED  = 1
  SECTION_ONE_TIME         = 2
  SECTION_LOCKED           = 3

  def pbStartScene
    pbZetaResearcher.check_daily_reset
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    if pbResolveBitmap("Graphics/UI/Researcher/mission_bg")
      @sprites["background"].setBitmap("Graphics/UI/Researcher/mission_bg")
    end
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    @sprites["descwindow"] = Window_AdvancedTextPokemon.new("")
    @sprites["descwindow"].viewport = @viewport
    @sprites["descwindow"].x = 0
    @sprites["descwindow"].y = Graphics.height - 80
    @sprites["descwindow"].width = Graphics.width
    @sprites["descwindow"].height = 80
    @sprites["descwindow"].baseColor = Color.new(248, 248, 248)
    @sprites["descwindow"].shadowColor = Color.new(0, 0, 0)
    @sprites["descwindow"].visible = true
    build_mission_list
    @index = 0
    @index = 0 if @entries.empty?
    pbDrawScene
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def build_mission_list
    @entries = []
    rank = pbZetaResearcher.rank_index
    all = pbGetAllMissions
    # Daily available
    daily_avail = all.select { |m| m.daily? && m.available?(rank) && !m.completed? }
    if !daily_avail.empty?
      @entries.push({ :type => :header, :text => "Daily Missions" })
      daily_avail.each { |m| @entries.push({ :type => :mission, :mission => m, :state => :available }) }
    end
    # Daily completed
    daily_done = all.select { |m| m.daily? && m.available?(rank) && m.completed? }
    if !daily_done.empty?
      @entries.push({ :type => :header, :text => "Daily (Completed)" })
      daily_done.each { |m| @entries.push({ :type => :mission, :mission => m, :state => :completed }) }
    end
    # One-time available
    ot_avail = all.select { |m| m.one_time? && m.available?(rank) && !m.completed? }
    if !ot_avail.empty?
      @entries.push({ :type => :header, :text => "One-Time Missions" })
      ot_avail.each { |m| @entries.push({ :type => :mission, :mission => m, :state => :available }) }
    end
    # One-time completed
    ot_done = all.select { |m| m.one_time? && m.available?(rank) && m.completed? }
    if !ot_done.empty?
      @entries.push({ :type => :header, :text => "One-Time (Completed)" })
      ot_done.each { |m| @entries.push({ :type => :mission, :mission => m, :state => :completed }) }
    end
    # Locked
    locked = all.select { |m| m.locked?(rank) }
    if !locked.empty?
      @entries.push({ :type => :header, :text => "Locked" })
      locked.each { |m| @entries.push({ :type => :mission, :mission => m, :state => :locked }) }
    end
  end

  def pbDrawScene
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    base_color    = Color.new(248, 248, 248)
    shadow_color  = Color.new(0, 0, 0)
    green_color   = Color.new(80, 220, 80)
    gray_color    = Color.new(160, 160, 160)
    yellow_color  = Color.new(255, 220, 80)
    header_color  = Color.new(180, 200, 255)
    textpos = []
    # Title
    textpos.push([_INTL("Mission Board"), Graphics.width / 2, 4, :center, base_color, shadow_color])
    # Token balance
    textpos.push([_INTL("Tokens: {1}", pbZetaResearcher.tokens.to_s_formatted),
                  Graphics.width - 32, 4, :right, yellow_color, shadow_color])
    # Scrollable list area
    list_y = 36
    line_h = 28
    max_visible = (Graphics.height - 80 - list_y) / line_h
    # Calculate scroll offset so selected item is visible
    @scroll ||= 0
    if @index < @scroll
      @scroll = @index
    elsif @index >= @scroll + max_visible
      @scroll = @index - max_visible + 1
    end
    visible_start = @scroll
    visible_end = [visible_start + max_visible, @entries.length].min
    (visible_start...visible_end).each_with_index do |ei, vi|
      entry = @entries[ei]
      y = list_y + vi * line_h
      if entry[:type] == :header
        textpos.push([entry[:text], 16, y, :left, header_color, shadow_color])
      else
        m = entry[:mission]
        state = entry[:state]
        # Selection cursor
        if ei == @index
          overlay.fill_rect(8, y - 2, Graphics.width - 16, line_h, Color.new(60, 60, 100))
        end
        # Color based on state
        name_color = case state
                     when :completed then green_color
                     when :locked    then gray_color
                     else base_color
                     end
        # Mission name
        prefix = case state
                 when :completed then "[OK] "
                 when :locked then "[??] "
                 else ""
                 end
        textpos.push([prefix + m.name, 24, y, :left, name_color, shadow_color])
        # Progress / reward on the right
        if state == :locked
          req_rank = ZetaResearcher::RESEARCHER_RANKS[m.tier_required][0]
          textpos.push([_INTL("Req: {1}", req_rank), Graphics.width - 32, y, :right, gray_color, shadow_color])
        elsif state == :completed
          textpos.push([_INTL("Complete"), Graphics.width - 32, y, :right, green_color, shadow_color])
        else
          progress = m.progress
          goal = m.goal
          # Progress bar drawn below, show text
          progress_text = _INTL("{1}/{2}  +{3}T", progress, goal, m.token_reward)
          textpos.push([progress_text, Graphics.width - 32, y, :right, base_color, shadow_color])
        end
      end
    end
    pbDrawTextPositions(overlay, textpos)
    # Draw progress bars for available missions
    (visible_start...visible_end).each_with_index do |ei, vi|
      entry = @entries[ei]
      next if entry[:type] == :header
      next if entry[:state] != :available
      m = entry[:mission]
      y = list_y + vi * line_h
      bar_x = Graphics.width - 200
      bar_y = y + line_h - 6
      bar_w = 80
      bar_h = 4
      ratio = m.goal > 0 ? [m.progress.to_f / m.goal, 1.0].min : 0
      overlay.fill_rect(bar_x, bar_y, bar_w, bar_h, Color.new(80, 80, 80))
      fill_w = (bar_w * ratio).to_i
      overlay.fill_rect(bar_x, bar_y, fill_w, bar_h, Color.new(0, 200, 120)) if fill_w > 0
    end
    # Update description window
    update_description
  end

  def update_description
    if @entries.empty?
      @sprites["descwindow"].text = _INTL("No missions available.")
      return
    end
    entry = @entries[@index]
    if entry[:type] == :header
      @sprites["descwindow"].text = ""
    else
      m = entry[:mission]
      if entry[:state] == :locked
        req_rank = ZetaResearcher::RESEARCHER_RANKS[m.tier_required][0]
        @sprites["descwindow"].text = _INTL("Reach {1} rank to unlock this mission.", req_rank)
      else
        @sprites["descwindow"].text = m.description
      end
    end
  end

  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      end
      if @entries.length > 0
        old_index = @index
        if Input.repeat?(Input::UP)
          @index -= 1
          @index = @entries.length - 1 if @index < 0
          # Skip headers
          @index -= 1 while @index >= 0 && @entries[@index][:type] == :header
          @index = old_index if @index < 0
          pbPlayCursorSE if @index != old_index
          pbDrawScene if @index != old_index
        elsif Input.repeat?(Input::DOWN)
          @index += 1
          @index = 0 if @index >= @entries.length
          # Skip headers
          @index += 1 while @index < @entries.length && @entries[@index][:type] == :header
          @index = old_index if @index >= @entries.length
          pbPlayCursorSE if @index != old_index
          pbDrawScene if @index != old_index
        end
      end
    end
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

#===============================================================================
# Screen wrapper
#===============================================================================
class MissionBoardScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbScene
    @scene.pbEndScene
  end
end

#===============================================================================
# Entry point (call from pause menu or event script)
#===============================================================================
def pbOpenMissionBoard
  pbFadeOutIn {
    scene = MissionBoardScene.new
    screen = MissionBoardScreen.new(scene)
    screen.pbStartScreen
  }
end
