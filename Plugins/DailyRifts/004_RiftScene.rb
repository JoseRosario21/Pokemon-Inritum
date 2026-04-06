#===============================================================================
# Daily Rifts - Silhouette Scene
# Shows an atmospheric full-screen silhouette of the upcoming rift Pokémon.
# Uses a pulsing glow tinted by tier color; Pokémon rendered in pure black.
#===============================================================================
module DailyRifts
  class SilhouetteScene

    FADE_FRAMES_IN  = 25
    FADE_FRAMES_OUT = 20

    def pbShow(species, tier)
      setup_viewport
      # Start black so the fade-in reads cleanly
      @viewport.color = Color.new(0, 0, 0, 255)

      setup_background
      setup_glow(tier)
      setup_pokemon(species)
      setup_text(species, tier)

      # Fade in
      FADE_FRAMES_IN.times do |i|
        @viewport.color = Color.new(0, 0, 0, 255 - ((i.to_f / FADE_FRAMES_IN) * 255).to_i)
        @aura_frame = i
        update_aura
        Graphics.update
        Input.update
      end
      @viewport.color = Color.new(0, 0, 0, 0)

      # Hold until player presses A or B
      loop do
        @aura_frame += 1
        update_aura
        Graphics.update
        Input.update
        break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
      end

      # Fade out
      FADE_FRAMES_OUT.times do |i|
        @viewport.color = Color.new(0, 0, 0, ((i.to_f / FADE_FRAMES_OUT) * 255).to_i)
        Graphics.update
      end

      dispose
    end

    private

    def setup_viewport
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      @aura_frame = 0
    end

    def setup_background
      @bg = Sprite.new(@viewport)
      @bg.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      # Deep dark background
      @bg.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(8, 4, 20))
      # Subtle radial lightening toward the center using stacked transparent rects
      cx = Graphics.width / 2
      cy = Graphics.height / 2 - 10
      [5, 4, 3, 2, 1].each_with_index do |factor, i|
        alpha = 6 + i * 5
        rw = Graphics.width / (factor + 1)
        rh = Graphics.height / (factor + 1)
        @bg.bitmap.fill_rect(cx - rw / 2, cy - rh / 2, rw, rh, Color.new(25, 12, 55, alpha))
      end
    end

    def setup_glow(tier)
      idx   = (tier - 1).clamp(0, TIER_COLORS.length - 1)
      r, g, b = TIER_COLORS[idx]

      glow_size = 240
      @glow_bitmap = Bitmap.new(glow_size, glow_size)
      cx = glow_size / 2
      # Concentric rects: outer = transparent, inner = higher alpha
      steps = 12
      steps.times do |i|
        radius = ((glow_size / 2) * (steps - i).to_f / steps).to_i
        alpha  = (i.to_f / steps * 55).to_i + 3
        @glow_bitmap.fill_rect(cx - radius, cx - radius, radius * 2, radius * 2,
                               Color.new(r, g, b, alpha))
      end

      @glow = Sprite.new(@viewport)
      @glow.bitmap  = @glow_bitmap
      @glow.ox      = glow_size / 2
      @glow.oy      = glow_size / 2
      @glow.x       = Graphics.width / 2
      @glow.y       = Graphics.height / 2 - 10
      @glow.opacity = 80
    end

    def setup_pokemon(species)
      @pokemon_anim_bmp = GameData::Species.front_sprite_bitmap(species)
      return if @pokemon_anim_bmp.nil?

      @pokemon_sprite = Sprite.new(@viewport)
      @pokemon_sprite.bitmap = @pokemon_anim_bmp.bitmap
      @pokemon_sprite.zoom_x = 2.0
      @pokemon_sprite.zoom_y = 2.0
      @pokemon_sprite.ox = @pokemon_sprite.bitmap.width / 2
      @pokemon_sprite.oy = @pokemon_sprite.bitmap.height / 2
      @pokemon_sprite.x = Graphics.width / 2
      @pokemon_sprite.y = Graphics.height / 2 - 10
      # Full black silhouette: subtract 255 from every channel
      @pokemon_sprite.tone = Tone.new(-255, -255, -255, 0)
    end

    def setup_text(species, tier)
      stars = DailyRifts.tier_stars(tier)
      idx   = (tier - 1).clamp(0, TIER_COLORS.length - 1)
      r, g, b = TIER_COLORS[idx]

      bar_h = 58
      @text_bg = Sprite.new(@viewport)
      @text_bg.bitmap = Bitmap.new(Graphics.width, bar_h)
      @text_bg.bitmap.fill_rect(0, 0, Graphics.width, bar_h, Color.new(0, 0, 0, 185))
      @text_bg.y = Graphics.height - bar_h

      @text_sprite = Sprite.new(@viewport)
      @text_sprite.bitmap = Bitmap.new(Graphics.width, bar_h)
      @text_sprite.y = Graphics.height - bar_h

      bmp = @text_sprite.bitmap
      shadow = Color.new(0, 0, 0)

      # Stars rating
      bmp.font.size = 20
      bmp.font.bold = true
      bmp.font.color = shadow
      bmp.draw_text(17, 7, Graphics.width - 32, 24, stars)
      bmp.font.color = Color.new(r, g, b)
      bmp.draw_text(16, 6, Graphics.width - 32, 24, stars)

      # Prompt
      bmp.font.size = 15
      bmp.font.bold = false
      bmp.font.color = shadow
      bmp.draw_text(17, 33, Graphics.width - 32, 20, _INTL("Press A to approach..."))
      bmp.font.color = Color.new(170, 160, 200)
      bmp.draw_text(16, 32, Graphics.width - 32, 20, _INTL("Press A to approach..."))
    end

    def update_aura
      pulse = (Math.sin(@aura_frame * 0.045) * 0.5 + 0.5)   # 0.0–1.0
      @glow.opacity = (45 + pulse * 90).to_i
      @glow.zoom_x  = 1.0 + pulse * 0.07
      @glow.zoom_y  = 1.0 + pulse * 0.07
    end

    def dispose
      @bg.bitmap.dispose
      @bg.dispose
      @glow_bitmap.dispose
      @glow.dispose
      @pokemon_anim_bmp&.dispose
      @pokemon_sprite&.dispose
      @text_bg.bitmap.dispose
      @text_bg.dispose
      @text_sprite.bitmap.dispose
      @text_sprite.dispose
      @viewport.dispose
    end
  end

  # Convenience wrapper called from the API.
  def self.show_silhouette(species, tier)
    SilhouetteScene.new.pbShow(species, tier)
  end
end
