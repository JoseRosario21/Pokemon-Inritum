#===============================================================================
# Boss Battles - UI: Shield Pip Overlay
#
# Extends Battle::Scene::PokemonDataBox to draw shield pips for boss battlers.
# Shield pips are drawn inside the databox bitmap — no extra sprites needed.
#
# The boss uses the standard foe databox (same as any wild Pokémon).  A custom
# databox graphic can be added later by placing a replacement image at
# Graphics/UI/Battle/boss_foeBoxS.png — uncomment the custom-bar block below.
#
# Also adds Battle::Scene#pbUpdateBossShields so the shield system can tell
# the scene to refresh the display after a break.
#===============================================================================

class Battle::Scene::PokemonDataBox
  # Colours for the shield pips
  SHIELD_ACTIVE_FILL   = Color.new(255, 195, 0)      # gold
  SHIELD_ACTIVE_BORDER = Color.new(180, 120, 0)
  SHIELD_BROKEN_FILL   = Color.new(60,  60,  60)
  SHIELD_BROKEN_BORDER = Color.new(30,  30,  30)

  # Pip dimensions and layout
  SHIELD_PIP_W   = 14
  SHIELD_PIP_H   = 8
  SHIELD_PIP_GAP = 3
  SHIELD_ROW_X   = 16
  SHIELD_ROW_Y   = 3   # from the top of the databox bitmap

  #-----------------------------------------------------------------------------
  # Hook refresh to draw shield pips after the normal databox content.
  #-----------------------------------------------------------------------------
  alias_method :boss_orig_refresh, :refresh

  def refresh
    boss_orig_refresh
    refresh_boss_shields if @battler.respond_to?(:boss?) && @battler.boss?
  end

  # Draws (or redraws) the shield pip row onto the databox bitmap.
  def refresh_boss_shields
    bmp = self.bitmap
    return unless bmp && !bmp.disposed?

    total = BossBattle::BOSS_DATA.dig(
              @battler.pokemon&.instance_variable_get(:@boss_id),
              :shield_count
            ).to_i
    return if total == 0

    remaining = (@battler.respond_to?(:boss_shields) ? @battler.boss_shields : total).to_i

    # Clear the pip row area first.
    row_w = total * (SHIELD_PIP_W + SHIELD_PIP_GAP) - SHIELD_PIP_GAP
    bmp.clear_rect(SHIELD_ROW_X - 1, SHIELD_ROW_Y - 1, row_w + 2, SHIELD_PIP_H + 2)

    total.times do |i|
      x = SHIELD_ROW_X + i * (SHIELD_PIP_W + SHIELD_PIP_GAP)
      y = SHIELD_ROW_Y

      active = (i < remaining)
      fill   = active ? SHIELD_ACTIVE_FILL   : SHIELD_BROKEN_FILL
      border = active ? SHIELD_ACTIVE_BORDER : SHIELD_BROKEN_BORDER

      # Border
      bmp.fill_rect(x - 1, y - 1, SHIELD_PIP_W + 2, SHIELD_PIP_H + 2, border)
      # Fill
      bmp.fill_rect(x, y, SHIELD_PIP_W, SHIELD_PIP_H, fill)

      # Inner highlight for active shields
      if active
        highlight = Color.new(255, 230, 100, 150)
        bmp.fill_rect(x + 1, y + 1, SHIELD_PIP_W - 2, 2, highlight)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Battle::Scene — hook for the shield system to call after a break
#-------------------------------------------------------------------------------
class Battle::Scene
  def pbUpdateBossShields(battler)
    databox = @sprites["dataBox_#{battler.index}"]
    return unless databox && !databox.disposed?
    databox.refresh
  end
end
