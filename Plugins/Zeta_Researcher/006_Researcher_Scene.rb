#===============================================================================
# Zeta Researcher Info Scene
#===============================================================================
class ZetaResearcherScene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    if pbResolveBitmap("Graphics/UI/Researcher/bg")
      @sprites["background"].setBitmap("Graphics/UI/Researcher/bg")
    end
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    pbDrawScene
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbDrawScene
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    data = pbZetaResearcher
    ranks = ZetaResearcher::RESEARCHER_RANKS
    base_color   = Color.new(248, 248, 248)
    shadow_color = Color.new(0, 0, 0)
    token_color  = Color.new(255, 220, 80)
    textpos = []
    # Title
    textpos.push([_INTL("Zeta Researcher"), Graphics.width / 2, 10, :center, base_color, shadow_color])
    # Rank
    textpos.push([_INTL("Rank: {1}", data.rank_name), 32, 60, :left, base_color, shadow_color])
    # Research XP
    textpos.push([_INTL("Research XP: {1}", data.total_xp.to_s_formatted), 32, 100, :left, base_color, shadow_color])
    # Next rank info
    if data.next_rank_name
      textpos.push([
        _INTL("Next Rank: {1} ({2} XP needed)", data.next_rank_name, data.xp_to_next_rank.to_s_formatted),
        32, 140, :left, base_color, shadow_color
      ])
    else
      textpos.push([_INTL("Max Rank Achieved!"), 32, 140, :left, base_color, shadow_color])
    end
    # Research Tokens
    textpos.push([_INTL("Research Tokens: {1}", data.tokens.to_s_formatted), 32, 200, :left, token_color, shadow_color])
    # Stats
    textpos.push([_INTL("Zeta Caught: {1}", data.zeta_caught_count), 32, 260, :left, base_color, shadow_color])
    textpos.push([_INTL("Zeta Donated: {1}", data.zeta_donated_count), 32, 300, :left, base_color, shadow_color])
    textpos.push([_INTL("Unique Species Donated: {1}", data.unique_donated_count), 32, 340, :left, base_color, shadow_color])
    pbDrawTextPositions(overlay, textpos)
    # XP Progress bar to next rank
    if data.next_rank_name
      current_rank_xp = ranks[data.rank_index][1]
      next_rank_xp = ranks[data.rank_index + 1][1]
      range = next_rank_xp - current_rank_xp
      progress = data.total_xp - current_rank_xp
      ratio = range > 0 ? progress.to_f / range : 1.0
      ratio = [ratio, 1.0].min
      bar_x = 32
      bar_y = 175
      bar_w = Graphics.width - 64
      bar_h = 12
      # Background
      overlay.fill_rect(bar_x, bar_y, bar_w, bar_h, Color.new(80, 80, 80))
      # Fill
      fill_w = (bar_w * ratio).to_i
      overlay.fill_rect(bar_x, bar_y, fill_w, bar_h, Color.new(0, 200, 120)) if fill_w > 0
    end
  end

  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        pbPlayCloseMenuSE
        break
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
class ZetaResearcherScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbScene
    @scene.pbEndScene
  end
end
