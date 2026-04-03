##─────────────────────────────────────────────────────────────────────────────
## Item Upgrade System — Save Data & Battle Effect Overrides
##─────────────────────────────────────────────────────────────────────────────

#-------------------------------------------------------------------------------
# Player save data — stores the current upgrade level for each upgradable item.
# Lazy-initialised so old saves default to level 1 for everything.
#-------------------------------------------------------------------------------
class Player
  def item_upgrade_levels
    @item_upgrade_levels ||= {}
  end

  def item_upgrade_levels=(val)
    @item_upgrade_levels = val
  end
end

#-------------------------------------------------------------------------------
# Module helpers
#-------------------------------------------------------------------------------
module ItemUpgradeSystem
  # Returns the current upgrade level (1-based) for an item on the save.
  def self.level_for(item_id)
    return 1 unless $player
    $player.item_upgrade_levels[item_id] || 1
  end

  # Returns the tier hash for an item at its current level.
  def self.current_tier(item_id)
    data  = UPGRADES[item_id]
    return nil unless data
    level = level_for(item_id)
    data[:tiers][level - 1]
  end

  # Returns the multiplier for an item at its current level.
  def self.multiplier_for(item_id)
    tier = current_tier(item_id)
    tier ? tier[:multiplier] : 1
  end

  # Returns the tier hash for the next upgrade level, or nil if maxed.
  def self.next_tier(item_id)
    data  = UPGRADES[item_id]
    return nil unless data
    level = level_for(item_id)
    return nil if level >= data[:tiers].length
    data[:tiers][level]   # level is 1-based, so this is the next index
  end

  # Returns true if the player can afford the next upgrade cost from their bag.
  def self.can_afford_next?(item_id)
    tier = next_tier(item_id)
    return false unless tier
    return true if tier[:cost].nil?
    tier[:cost].all? { |item_sym, qty| $bag.has?(item_sym, qty) }
  end

  # Deducts the cost and increments the level. Call only after confirming.
  def self.apply_upgrade!(item_id)
    tier = next_tier(item_id)
    return false unless tier
    unless tier[:cost].nil?
      tier[:cost].each { |item_sym, qty| $bag.remove(item_sym, qty) }
    end
    $player.item_upgrade_levels[item_id] = level_for(item_id) + 1
    return true
  end

  def self.lucky_egg_multiplier
    multiplier_for(:LUCKYEGG)
  end

  def self.macho_brace_multiplier
    multiplier_for(:MACHOBRACE)
  end

  def self.amulet_coin_multiplier
    multiplier_for(:AMULETCOIN)
  end

  def self.power_item_ev_bonus
    multiplier_for(:POWERITEMS)
  end
end

#-------------------------------------------------------------------------------
# Override Power item EV handlers — replaces the vanilla +8 flat bonus with
# the upgradeable value. All 6 items share the same upgrade level (:POWERITEMS).
#-------------------------------------------------------------------------------
{
  :POWERANKLET => :SPEED,
  :POWERBAND   => :SPECIAL_DEFENSE,
  :POWERBELT   => :DEFENSE,
  :POWERBRACER => :ATTACK,
  :POWERLENS   => :SPECIAL_ATTACK,
  :POWERWEIGHT => :HP,
}.each do |item_sym, stat|
  Battle::ItemEffects::EVGainModifier.add(item_sym,
    proc { |item, battler, evYield|
      evYield[stat] += ItemUpgradeSystem.power_item_ev_bonus
    }
  )
end

#-------------------------------------------------------------------------------
# Override Battle#pbGainMoney to use the upgraded Amulet Coin multiplier
# instead of the hardcoded × 2.  Luck Incense shares the same upgrade level
# since it triggers the same PBEffects::AmuletCoin flag.
# HappyHour is intentionally left at its vanilla × 2 (not upgradeable).
#-------------------------------------------------------------------------------
class Battle
  alias_method :pbGainMoney_vanilla, :pbGainMoney

  def pbGainMoney
    return if !@internalBattle || !@moneyGain
    amulet_active = @field.effects[PBEffects::AmuletCoin]
    amulet_mult   = amulet_active ? ItemUpgradeSystem.amulet_coin_multiplier : 1
    happy_mult    = @field.effects[PBEffects::HappyHour] ? 2 : 1
    # Trainer battle prize money
    if trainerBattle?
      tMoney = 0
      @opponent.each_with_index { |t, i| tMoney += pbMaxLevelInTeam(1, i) * t.base_money }
      tMoney = (tMoney * amulet_mult * happy_mult).round
      oldMoney = pbPlayer.money
      pbPlayer.money += tMoney
      moneyGained = pbPlayer.money - oldMoney
      if moneyGained > 0
        $stats.battle_money_gained += moneyGained
        pbDisplayPaused(_INTL("You got ${1} for winning!", moneyGained.to_s_formatted))
      end
    end
    # Pay Day money
    if @field.effects[PBEffects::PayDay] > 0
      payday = (@field.effects[PBEffects::PayDay] * amulet_mult * happy_mult).round
      oldMoney = pbPlayer.money
      pbPlayer.money += payday
      moneyGained = pbPlayer.money - oldMoney
      if moneyGained > 0
        $stats.battle_money_gained += moneyGained
        pbDisplayPaused(_INTL("You picked up ${1}!", moneyGained.to_s_formatted))
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Override Lucky Egg battle effect — replaces the vanilla 1.5× handler.
# The multiplier is looked up live from the save so it always reflects the
# current upgrade level without needing a restart.
#-------------------------------------------------------------------------------
Battle::ItemEffects::ExpGainModifier.add(:LUCKYEGG,
  proc { |item, battler, exp|
    mult = ItemUpgradeSystem.lucky_egg_multiplier
    next (exp * mult).round
  }
)

#-------------------------------------------------------------------------------
# Override Macho Brace EV handler — replaces the vanilla 2× handler.
# Speed halving (SpeedCalc) is intentionally left unchanged at all levels.
#-------------------------------------------------------------------------------
Battle::ItemEffects::EVGainModifier.add(:MACHOBRACE,
  proc { |item, battler, evYield|
    mult = ItemUpgradeSystem.macho_brace_multiplier
    evYield.each_key { |stat| evYield[stat] *= mult }
  }
)
