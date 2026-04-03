#===============================================================================
# Boss Battles - Charge Attack
#
# At the end of each round, each active boss battler's charge turn counter is
# incremented. When the counter reaches :interval the boss fires its charge
# move at a random opposing target, then the counter resets to 0.
#
# The optional :warning message is shown at the START of the interval window
# (i.e. when counter resets to 0 after firing), giving the player one round
# of notice before the next charge.
#===============================================================================

class Battle
  alias_method :boss_orig_pbEndOfRoundPhase, :pbEndOfRoundPhase

  def pbEndOfRoundPhase
    boss_orig_pbEndOfRoundPhase

    allBattlers.each do |b|
      next unless b.boss? && !b.fainted?
      cfg = BossBattle::BOSS_DATA[b.pokemon.instance_variable_get(:@boss_id)]
      next unless cfg
      charge = cfg[:charge_attack]
      next unless charge

      b.boss_charge_turn = (b.boss_charge_turn || 0) + 1

      if b.boss_charge_turn >= charge[:interval]
        # Fire charge move against a random opponent.
        target_idx = -1
        allOtherSideBattlers(b.index).reject(&:fainted?).tap do |foes|
          target_idx = foes.sample&.index || -1
        end

        if target_idx >= 0
          # specialUsage=true prevents PP depletion on the moveset copy;
          # without it, repeated charge attacks drain PP and the boss
          # eventually falls back to Struggle for its normal action.
          b.pbUseMoveSimple(charge[:move].to_sym, target_idx, -1, true) rescue nil
          # Handle any faint caused by the charge attack IMMEDIATELY.
          # The original pbEORSwitch inside boss_orig_pbEndOfRoundPhase
          # ran before the charge hit; without a second call the next
          # turn starts with an empty player slot and the boss defaults
          # to Struggle because there is no valid target.
          pbEORSwitch
          return if @decision > 0
        end

        b.boss_charge_turn = 0

        # Warning for next interval
        if charge[:warning] && !charge[:warning].empty?
          raw = charge[:warning]
          msg = raw.include?("{1}") ? _INTL(raw, b.pbThis) : _INTL(raw)
          pbDisplayBrief(msg)
        end
      end
    end
  end
end
