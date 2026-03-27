class EventIndicator
    attr_accessor :type
    attr_accessor :event
    attr_accessor :visible
    attr_accessor :movement_counter
    attr_accessor :movement_speed
    attr_accessor :animation_counter
    attr_accessor :animation_speed
    attr_accessor :animation_frame_amount
    attr_accessor :indicator
    attr_accessor :text_bubble
    attr_accessor :last_refresh

    def initialize(params, event, viewport, map)
        @type = params[0][0]
        @event = event
        @viewport = viewport
        @map = map
        @last_refresh = Time.now
        @alwaysvisible = false
        @ignoretimeshade = false
        @x_adj = Settings::EVENT_INDICATOR_X_ADJ
        @y_adj = Settings::EVENT_INDICATOR_Y_ADJ
        @x_adj += params[0][1] if params[0][1] && params[0][1].is_a?(Integer)
        @y_adj += params[0][2] if params[0][2] && params[0][2].is_a?(Integer)
        @text = params[1] || nil
        @text = nil if @text == ""

        data = Settings::EVENT_INDICATORS[@type]
        if !data
            @disposed = true
            return
        end
        @x_adj += data[:x_adjustment] if data[:x_adjustment]
        @y_adj += data[:y_adjustment] if data[:y_adjustment]
        @min_distance = data[:min_distance] if data[:min_distance]
        @max_distance = data[:max_distance] if data[:max_distance]
        @must_face = data[:must_face] if data[:must_face]
        @must_look_away = data[:must_look_away] if data[:must_look_away]
        @text_bubble = data[:text] if data[:text]
        @show_end_arrow = data[:text_show_pause_indicator] if data[:text_show_pause_indicator]

        if can_vertical_move?
            @movement_speed = data[:movement_speed] || Settings::EVENT_INDICATOR_DEFAULT_MOVEMENT_SPEED
            @movement_speed = 1 if @movement_speed < 1
            @movement_counter = 0
        end 
        if data[:animation_frames]
            @animation_frame_amount = data[:animation_frames]
            @animation_counter = 0
            @animation_speed = data[:animation_speed] || Settings::EVENT_INDICATOR_DEFAULT_ANIMATION_SPEED
        end

        @alwaysvisible = true if data[:always_visible]
        @ignoretimeshade = true if data[:ignore_time_shading]
        @condition = data[:condition]
        if @animation_frame_amount && @animation_frame_amount > 1
            @indicator = IndicatorIconSprite.new(data[:graphic], @animation_frame_amount, viewport)
            @indicator.oy = @indicator.bitmap.height
        elsif @text_bubble && @text
            #start_time = Time.now # Performance testing
            @x_adj += Settings::EVENT_INDICATOR_TEXT_X_ADJ
            @y_adj += Settings::EVENT_INDICATOR_TEXT_Y_ADJ
            @hide_text_arrow = data[:hide_text_arrow] if data[:hide_text_arrow]
            @flair_positions = []
            if data[:text_bubble_flair]
                val = data[:text_bubble_flair] 
                if val.is_a?(Hash)
                    @flair = val.to_a
                    @flair.each {|f| @flair_positions.push(f[0])}
                else
                    pos = data[:text_bubble_flair_position] || Settings::EVENT_INDICATOR_DEFAULT_TEXT_FLAIR_POSITION
                    @flair = [[pos, val]]
                    @flair_positions.push(pos)
                end
            end
            @flair_pad_top = (@flair && !([1,2,3]&@flair_positions).empty? ? 8 : 0)
            @flair_pad_bottom = (@flair && !([6,7]&@flair_positions).empty? ? 8 : (@hide_text_arrow ? 0 : 8))
            @flair_pad_bottom = 8 if Settings::EVENT_INDICATOR_TEXT_CONSISTENT_Y
            @flair_pad_sides = (@flair ? 8 : 0)
            @text = text_replacements(@text)
            @text += "   " if @show_end_arrow
            max_segments = ((data[:text_max_width] ? data[:text_max_width] : Settings::EVENT_INDICATOR_MAX_TEXT_WIDTH) / 16).floor
            max_lines = Settings::EVENT_INDICATOR_MAX_TEXT_LINES
            lines = 0
            @indicator = BitmapSprite.new(80, 40, viewport)
            pbSetSmallFont(@indicator.bitmap)
            text_width = @indicator.bitmap.text_size(@text).width
            text_segments = (text_width / 16).ceil
            text_segments = 1 if text_segments <= 0
            text_segments = max_segments if text_segments > max_segments
            if text_width > max_segments * 16 || @text.include?("\\n")
                split_text = getLineBrokenText(@indicator.bitmap, @text, max_segments * 16, nil)
                if @text.include?("\\n")
                    split_text.each do |s|
                        next unless s[0].include?("\\n")
                        s[0].gsub!(/\\n/i, "")
                        s[2] += 1
                    end
                end
                new_text = []
                split_text.each_with_index do |t, i|
                    if i == 0
                        new_text.push(t[0])
                    else
                        if t[2] > split_text[i-1][2]
                            new_text[lines].rstrip!
                            lines += 1
                            new_text.push("")
                        end
                        new_text[lines] += t[0]
                    end
                end
                new_width = 0
                new_text.each do |i|
                    w = @indicator.bitmap.text_size(i).width
                    new_width = (w / 16).ceil if (w / 16).ceil > new_width
                end
                text_segments = new_width if new_width < text_segments
                @text = new_text
            end
            lines += 1
            lines = max_lines if lines > max_lines
            @indicator = BitmapSprite.new(text_segments * 16 + 32 + @flair_pad_sides*2, 
                32 + lines * 16 + @flair_pad_top + @flair_pad_bottom, viewport)
            pbSetSmallFont(@indicator.bitmap)
            corner_tl = [data[:graphic], @flair_pad_sides, @flair_pad_top, 0, 0, 16, 16]
            corner_tr = [data[:graphic], 16 + text_segments * 16 + @flair_pad_sides, @flair_pad_top, 32, 0, 16, 16]
            corner_bl = [data[:graphic], @flair_pad_sides, 16 + lines * 16 + @flair_pad_top, 0, 32, 16, 16]
            corner_br = [data[:graphic], 16 + text_segments * 16 + @flair_pad_sides, 16 + lines * 16 + @flair_pad_top, 32, 32, 16, 16]
            imgpos = [ corner_tl, corner_tr, corner_bl, corner_br]
            text_segments.times do |i|
                imgpos.push([data[:graphic], 16 + i * 16 + @flair_pad_sides, @flair_pad_top, 16, 0, 16, 16]) # top
                imgpos.push([data[:graphic], 16 + i * 16 + @flair_pad_sides, 16 + lines * 16 + @flair_pad_top, 16, 32, 16, 16]) # bottom
                lines.times do |j|
                    imgpos.push([data[:graphic], 16 + i * 16 + @flair_pad_sides, 16 + j * 16 + @flair_pad_top, 16, 16, 16, 16]) # center
                    next if i > 0
                    imgpos.push([data[:graphic], @flair_pad_sides, 16 + j * 16 + @flair_pad_top, 0, 16, 16, 16]) # left
                    imgpos.push([data[:graphic], 16 + text_segments * 16 + @flair_pad_sides, 16 + j * 16 + @flair_pad_top, 32, 16, 16, 16]) # right
                end
            end
            unless @hide_text_arrow
                imgpos.push([data[:graphic] + "_arrow", @indicator.width / 2 - 8 , @indicator.bitmap.height - 24])
            end
            if @flair
                @flair.each do |f|
                    case f[0]
                    when 1 # Top Left
                        imgpos.push([f[1], 0, 0])
                    when 2 # Top Center
                        imgpos.push([f[1], (@indicator.width - 28) / 2, 0])
                    when 3 # Top Right
                        imgpos.push([f[1], @indicator.width - 28, 0])
                    when 4 # Center Left
                        imgpos.push([f[1], 0, (@indicator.height - 28 - @flair_pad_bottom) / 2])
                    when 5 # Center Right
                        imgpos.push([f[1], @indicator.width - 28, (@indicator.height - 28 - @flair_pad_bottom) / 2])
                    when 6 # Bot Left
                        imgpos.push([f[1], 0, @indicator.height - 28])
                    when 7 # Bot Right
                        imgpos.push([f[1], @indicator.width - 28, @indicator.height - 28])
                    end
                end
            end
            pbDrawImagePositions(@indicator.bitmap, imgpos)
            window_color = @indicator.bitmap.get_pixel(@indicator.width / 2, @indicator.height / 2)
            if ((window_color.red * 0.299) + (window_color.green * 0.587) + (window_color.blue * 0.114)) < 160
                text_colors = [MessageConfig::LIGHT_TEXT_MAIN_COLOR, MessageConfig::LIGHT_TEXT_SHADOW_COLOR]
                if @show_end_arrow
                  s = "Graphics/UI/Event Indicators/pause_light"
                  s = data[:graphic] + "_pause" if pbResolveBitmap(data[:graphic] + "_pause")
                  pbDrawImagePositions(@indicator.bitmap, [[s, @indicator.width - 32, @indicator.height - 28]]) 
                end
            else
                text_colors = [MessageConfig::DARK_TEXT_MAIN_COLOR, MessageConfig::DARK_TEXT_SHADOW_COLOR]
                if @show_end_arrow
                  s = "Graphics/UI/Event Indicators/pause"
                  s = data[:graphic] + "_pause" if pbResolveBitmap(data[:graphic] + "_pause")
                  pbDrawImagePositions(@indicator.bitmap, [[s, @indicator.width - 32, @indicator.height - 28]])
                end
            end
            if @text.is_a?(Array)
                textpos = []
                lines.times do |i|
                    break if @text[i].nil?
                    textpos.push([@text[i], @indicator.width / 2, 16 + i * 16 + @flair_pad_top, 2, *text_colors])
                end
            else
                textpos = [
                    [@text, @indicator.width / 2, 16 + @flair_pad_top, 2, *text_colors],
                ]
            end
            pbDrawTextPositions(@indicator.bitmap, textpos)
            @indicator.ox = @indicator.bitmap.width / 2
            @indicator.oy = @indicator.bitmap.height
            #echoln "Event #{@event.id} Setup Time: #{Time.now - start_time}" # Performance testing
        else
            @indicator = IconSprite.new(0, 0, viewport)
            @indicator.setBitmap(data[:graphic])
            @indicator.ox = @indicator.bitmap.width / 2
            @indicator.oy = @indicator.bitmap.height
        end
        @indicator.z = 1000
        @disposed = false
    end
  
    def disposed?
        @disposed
    end
  
    def dispose
        @indicator&.dispose
        @disposed = true
    end
  
    def update
        if @alwaysvisible
            @visible = true
        elsif pbMapInterpreterRunning? && pbMapInterpreter.get_self && @event && pbMapInterpreter.get_self.id == @event.id
            @visible = false
        else
            @visible = true
        end
        @visible = @alwaysvisible || !(pbMapInterpreterRunning? && pbMapInterpreter&.get_self&.id == @event&.id)
        @visible = false if @condition && !@condition.call
        if @visible && (@min_distance || @max_distance)
            if $map_factory
                rel_distance = $map_factory.getThisAndOtherEventRelativePos(@event, $game_player)
            else
                rel_distance = [$game_player.x - @event.x, $game_player.y - @event.y]
            end
            rel_distance[0] = rel_distance[0].abs
            rel_distance[1] = rel_distance[1].abs
            rel_distance.push(Math.hypot(*rel_distance).floor)
            @visible = false if @min_distance && rel_distance[2] > @min_distance
            @visible = false if @max_distance && rel_distance[2] < @max_distance
        end
        if @visible && (@must_face || @must_look_away)
            case $game_player.direction
            when 2 #Down
                facing = @event.y > $game_player.y
            when 4 #Left
                facing = @event.x < $game_player.x
            when 6 #Right
                facing = @event.x > $game_player.x
            when 8 #Up
                facing = @event.y < $game_player.y
            end
            @visible = false if (@must_face && !facing) || (@must_look_away && facing)
        end
        @indicator.update
        @indicator.visible = @visible
        pbDayNightTint(@indicator) unless @ignoretimeshade
        @indicator.x = @event.screen_x + @x_adj
        @indicator.y = @event.screen_y - Game_Map::TILE_HEIGHT + @y_adj
        if @movement_speed
            @movement_counter += 1
            @movement_counter = 0 if @movement_counter >= @movement_speed * 4
            case @movement_counter
            when @movement_speed...@movement_speed * 2
                @indicator.y += 2
            when @movement_speed*3...@movement_speed * 4
                @indicator.y -= 2
            end
        end
        if @animation_frame_amount && @animation_frame_amount > 1 && @visible
            @animation_counter += 1
            if @animation_counter >= @animation_speed
                @indicator.advanceFrame
                @animation_counter = 0
            end
        end
    end

    def can_vertical_move?
        return false if $PokemonSystem.eventindicatorsmove == 1
        return false if Settings::EVENT_INDICATORS[@type][:no_movement]
        return Settings::EVENT_INDICATOR_VERTICAL_MOVEMENT
    end

    def text_replacements(text)
        text.gsub!(/\\pn/i,  $player.name) if $player
        text.gsub!(/\\pm/i,  _INTL("${1}", $player.money.to_s_formatted)) if $player
        text.gsub!(/\\n/i,   " \\n")
        old_text = text.clone
        text.gsub!(/\\1/i,   "")
        @show_end_arrow = true if text != old_text
        text.gsub!(/\\sc\[(.*?)\]/i) {(eval($1) rescue "").to_s}
        loop do
            last_text = text.clone
            text.gsub!(/\\v\[([0-9]+)\]/i) { $game_variables[$1.to_i] }
            break if text == last_text
        end
        return text
    end
end

class Scene_Map
    attr_reader :spritesets
end

class Spriteset_Map
    attr_accessor :event_indicator_sprites
            
    alias event_indicator_spriteset_init initialize 
    def initialize(map = nil)
        @event_indicator_sprites = []
        event_indicator_spriteset_init(map)
    end
    
    def addEventIndicator(new_sprite, forced = false)
        return false if Settings::EVENT_INDICATOR_ALLOW_HIDE_OPTION && $PokemonSystem.showeventindicators == 1
        return false if !Settings::EVENT_INDICATORS[new_sprite.type]
        return false if !forced && @event_indicator_sprites[new_sprite.event.id] && !@event_indicator_sprites[new_sprite.event.id].disposed?
        return false if new_sprite.event.map_id != @map.map_id
        old_move_counter = nil
        old_anim_counter = nil
        old_anim_frame = nil
        old_type = nil
        old_sprite = @event_indicator_sprites[new_sprite.event.id]
        if old_sprite
            old_type = old_sprite.type
            old_move_counter = old_sprite.movement_counter if old_sprite.movement_counter
            if old_sprite.animation_counter
                old_anim_counter = old_sprite.animation_counter 
                old_anim_frame = old_sprite.indicator.currentFrame 
            end
            old_sprite.dispose
        end
        @event_indicator_sprites[new_sprite.event.id] = new_sprite
        if @event_indicator_sprites[new_sprite.event.id].type == old_type
            @event_indicator_sprites[new_sprite.event.id].movement_counter = old_move_counter if old_move_counter
            if old_anim_counter
                @event_indicator_sprites[new_sprite.event.id].animation_counter = old_anim_counter 
                @event_indicator_sprites[new_sprite.event.id].indicator.setFrame(old_anim_frame)
            end
        end
        return true
    end

    def refreshEventIndicator(event)
        params = event.pbCheckForActiveIndicator
        if params
            return if @event_indicator_sprites[event.id] && @event_indicator_sprites[event.id].text_bubble && map.map_id == event.map_id &&
                    Time.now - @event_indicator_sprites[event.id].last_refresh < 0.3 # Try to prevent excessive refreshes
            new_sprite = EventIndicator.new(params, event, @@viewport1, map)
            ret = addEventIndicator(new_sprite, true)
            new_sprite.dispose if !ret # Try and prevent orphaned indicators
            @event_indicator_sprites[event.id].dispose if @event_indicator_sprites[event.id] && !ret
        elsif @event_indicator_sprites[event.id] && map.map_id == event.map_id
            @event_indicator_sprites[event.id].dispose
        end
    end
    
    alias event_indicator_spriteset_dispose dispose
    def dispose
        event_indicator_spriteset_dispose
        @event_indicator_sprites.each do |sprite| 
            next if sprite.nil?
            sprite.dispose
        end
        @event_indicator_sprites.clear
    end
    
    alias event_indicator_spriteset_update update 
    def update
        event_indicator_spriteset_update
        @event_indicator_sprites.each do |sprite| 
            next if sprite.nil?
            sprite.update if !sprite.disposed?
        end
    end
end

class Game_Event < Game_Character
    attr_accessor :event_indicator_refresh

    def pbCheckForActiveIndicator
        #ret = pbEventCommentInput(self, 5, "Event Indicator")
        # pg_num = page_number
        # if $game_temp.event_indicators[[@map_id, @id, pg_num]]
        #     ret = $game_temp.event_indicators[[@map_id, @id, pg_num]]
        # elsif $game_temp.event_indicators[[@map_id, @id, pg_num]] == false
        # else
            ret = pbEventCommentInputIndicator(self)
        #     $game_temp.event_indicators[[@map_id, @id, pg_num]] = ret || false
        # end
        if ret
            params = ret[0].split.map { |x| x.match?(/^-?\d+$/) ? x.to_i : x }
            text = ""
            ret.each_with_index do |line, i|
                next if i == 0
                break if line.nil?
                text += line
            end
            text = _MAPINTL(@map_id, text) unless text == ""
            ret = [params, text]
        end
        return ret 
    end

    alias event_indicator_e_refresh refresh
    def refresh
        event_indicator_e_refresh
        if $scene.is_a?(Scene_Map) && $scene.spritesets && $scene.spriteset
            $scene.spriteset.refreshEventIndicator(self)
        end
    end
  
    def page_number
        @event.pages.each_with_index do |p, i|
            return i if p == @page
        end
        return nil
    end

end

class IndicatorIconSprite < Sprite
    attr_accessor :currentFrame

    def initialize(path, numFrames = 1, viewport = nil)
      super(viewport)
      @numFrames = numFrames 
      @currentFrame = 0
      @animBitmap = AnimatedBitmap.new(path)
      self.bitmap = @animBitmap.bitmap
      self.src_rect.height = @animBitmap.height
      self.src_rect.width  = @animBitmap.width / @numFrames
      self.ox = self.src_rect.width / 2
    end

    def setFrame(frame)
        @currentFrame = frame
        @currentFrame = 0 if @currentFrame >= @numFrames
        self.src_rect.x = self.src_rect.width * @currentFrame
    end

    def advanceFrame
        return if @numFrames <= 1
        setFrame(@currentFrame + 1)
    end

end
  
EventHandlers.add(:on_new_spriteset_map, :add_event_indicators,
    proc do |spriteset, viewport|
        map = spriteset.map
        map.events.each_key do |i|
            event = map.events[i]
            params = event.pbCheckForActiveIndicator
            spriteset.addEventIndicator(EventIndicator.new(params, event, viewport, map)) if params
        end
    end
)

class PokemonSystem
    attr_accessor :showeventindicators
    attr_accessor :eventindicatorsmove

    alias event_indicator_syst_init initialize
    def initialize
        event_indicator_syst_init
        @showeventindicators = 0
        @eventindicatorsmove = 0
    end
end

def pbEventCommentInputIndicator(event)
  parameters = []
  list = event.list
  trigger = "Event Indicator"
  return nil if list.nil?
  return nil unless list.is_a?(Array)
  list.each do |item|
    next if ![108, 408].include?(item.code)
    next if item.parameters[0] != trigger
    id = list.index(item) + 1
    loop do
      if list[id] && [108, 408].include?(list[id].code)
        parameters.push(list[id].parameters[0]) 
        id += 1
      else
        break
      end
    end
    return parameters
  end
  return nil
end

# class Game_Temp
#     attr_accessor :event_indicators

#     alias event_indicators_temp_init initialize
#     def initialize
#         event_indicators_temp_init
#         @event_indicators            = {}
#     end

# end