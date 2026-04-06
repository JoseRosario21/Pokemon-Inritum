#===============================================================================
# Boss Battles - Shield System
#
# Intercepts pbFaint on the boss battler. When a shield remains:
#   1. Display shield-break message / animation from config.
#   2. Apply on_break effects for this shield tier.
#   3. Recover the boss to full HP.
#   4. Decrement shield count and update UI.
#
# When shields run out, pbFaint proceeds normally — boss is defeated.
#===============================================================================

class Battle::Battler
  alias_method :boss_orig_pbFaint, :pbFaint

  def pbFaint(showMessage = true)
    # Only intercept when this battler is a boss with shields remaining.
    if boss? && @boss_shields.to_i > 0

      boss_id    = @pokemon.instance_variable_get(:@boss_id)
      cfg        = BossBattle::BOSS_DATA[boss_id]
      cur_shield = @boss_shields

      # --- Break message / animation ---
      break_data = cfg.dig(:on_break, cur_shield)
      if break_data && break_data[:message] && !break_data[:message].empty?
        raw = break_data[:message]
        msg = raw.include?("{1}") ? _INTL(raw, pbThis) : _INTL(raw)
        @battle.pbDisplayPaused(msg)
      else
        @battle.pbDisplayPaused(_INTL("{1}'s shield shattered!", pbThis))
      end

      anim = break_data&.fetch(:animation, nil)
      @battle.scene.pbCommonAnimation(anim.to_s, self) rescue nil if anim

      # --- On-break effects ---
      BossBattle.apply_break_effects(@battle, self, break_data, boss_id) if break_data

      # --- Recover HP ---
      pbRecoverHP(@totalhp)

      # --- Decrement shields and update UI ---
      @boss_shields -= 1
      @battle.scene.pbUpdateBossShields(self)

      return
    end

    boss_orig_pbFaint(showMessage)
  end
end
