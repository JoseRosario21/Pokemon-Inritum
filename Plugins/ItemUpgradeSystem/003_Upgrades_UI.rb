##─────────────────────────────────────────────────────────────────────────────
## Item Upgrade System — NPC Upgrade Shop UI
##─────────────────────────────────────────────────────────────────────────────
## Call `pbItemUpgradeShop` from any NPC event script to open the menu.
## The NPC only shows items the player currently has in their bag.
##─────────────────────────────────────────────────────────────────────────────

#-------------------------------------------------------------------------------
# Builds a human-readable cost string for a tier's cost array.
# e.g. "3 Big Pearls" or "2 Pearl Strings + 1 Everstone"
#-------------------------------------------------------------------------------
def pbUpgradeCostString(cost)
  return _INTL("Free") if cost.nil?
  parts = cost.map do |item_sym, qty|
    item_name = GameData::Item.get(item_sym).name
    qty == 1 ? item_name : _INTL("{1} {2}", qty, item_name)
  end
  parts.join(" + ")
end

#-------------------------------------------------------------------------------
# Shows the detail screen for one upgradable item and handles the upgrade.
#-------------------------------------------------------------------------------
def pbItemUpgradeDetail(item_id)
  data = ItemUpgradeSystem::UPGRADES[item_id]
  return unless data

  loop do
    level      = ItemUpgradeSystem.level_for(item_id)
    max_level  = data[:tiers].length
    cur_tier   = ItemUpgradeSystem.current_tier(item_id)
    next_tier  = ItemUpgradeSystem.next_tier(item_id)

    if next_tier.nil?
      # Maxed out
      pbMessage(_INTL("\\c[1]{1}\\c[0] is already at its maximum level!\\n" \
                      "Current effect: {2}", data[:name], cur_tier[:label]))
      return
    end

    cost_str    = pbUpgradeCostString(next_tier[:cost])
    can_afford  = ItemUpgradeSystem.can_afford_next?(item_id)
    afford_note = can_afford ? "" : _INTL(" \\c[2](not enough items)\\c[0]")

    msg = _INTL(
      "\\c[1]{1}\\c[0]  —  Lv.{2} / {3}\n" \
      "Current: {4}\n" \
      "Next (Lv.{5}): {6}\n" \
      "Cost: {7}{8}",
      data[:name], level, max_level,
      cur_tier[:label],
      level + 1, next_tier[:label],
      cost_str, afford_note
    )

    if can_afford
      choice = pbMessage(msg, [_INTL("Upgrade"), _INTL("Cancel")], -1)
      if choice == 0
        pbMessage(_INTL("You paid {1}.", cost_str)) unless next_tier[:cost].nil?
        ItemUpgradeSystem.apply_upgrade!(item_id)
        new_level = ItemUpgradeSystem.level_for(item_id)
        new_tier  = ItemUpgradeSystem.current_tier(item_id)
        pbMessage("\\me[Item get]" +
          _INTL("\\c[1]{1}\\c[0] was upgraded to Lv.{2}!\\n" \
                "Effect: {3}", data[:name], new_level, new_tier[:label]) +
          "\\wtnp[60]")
        # Loop back to show the updated state; player may keep upgrading.
      else
        return
      end
    else
      pbMessage(msg + "\n" + _INTL("Come back when you have the required items."))
      return
    end
  end
end

#-------------------------------------------------------------------------------
# Main upgrade shop entry point. Shows all upgradable items the player owns.
#-------------------------------------------------------------------------------
POWER_ITEM_IDS = [:POWERANKLET, :POWERBAND, :POWERBELT, :POWERBRACER, :POWERLENS, :POWERWEIGHT]

# Maps every individual item symbol to its upgrade key in ItemUpgradeSystem::UPGRADES.
# Used by the bag display and any other UI that calls getDisplayName.
module ItemUpgradeSystem
  ITEM_TO_UPGRADE_KEY = {
    :LUCKYEGG    => :LUCKYEGG,
    :MACHOBRACE  => :MACHOBRACE,
    :AMULETCOIN  => :AMULETCOIN,
    :LUCKINCENSE => :AMULETCOIN,
    :POWERANKLET => :POWERITEMS,
    :POWERBAND   => :POWERITEMS,
    :POWERBELT   => :POWERITEMS,
    :POWERBRACER => :POWERITEMS,
    :POWERLENS   => :POWERITEMS,
    :POWERWEIGHT => :POWERITEMS,
  }
end

#-------------------------------------------------------------------------------
# Append "Lv.X" to the bag display name for any upgraded item.
# Only shown when level > 1 so base items look unchanged.
#-------------------------------------------------------------------------------
class PokemonMartAdapter
  alias_method :getDisplayName_before_upgrade, :getDisplayName

  def getDisplayName(item)
    name = getDisplayName_before_upgrade(item)
    return name unless $player
    upgrade_key = ItemUpgradeSystem::ITEM_TO_UPGRADE_KEY[item]
    return name unless upgrade_key
    level = ItemUpgradeSystem.level_for(upgrade_key)
    return name if level <= 1
    sprintf("%s Lv.%d", name, level)
  end
end

#-------------------------------------------------------------------------------
# Single-item NPC entry points. Call these from map events for dedicated NPCs.
#   pbUpgradeLuckyEgg     — Lucky Egg NPC
#   pbUpgradeMachoBrace   — Macho Brace NPC
#   pbUpgradeAmuletCoin   — Amulet Coin / Luck Incense NPC
#   pbUpgradePowerItems   — Power Items NPC (all 6 at once)
#-------------------------------------------------------------------------------
def pbUpgradeLuckyEgg
  unless $bag.has?(:LUCKYEGG)
    pbMessage(_INTL("You don't have a Lucky Egg to upgrade."))
    return
  end
  pbItemUpgradeDetail(:LUCKYEGG)
end

def pbUpgradeMachoBrace
  unless $bag.has?(:MACHOBRACE)
    pbMessage(_INTL("You don't have a Macho Brace to upgrade."))
    return
  end
  pbItemUpgradeDetail(:MACHOBRACE)
end

def pbUpgradeAmuletCoin
  unless $bag.has?(:AMULETCOIN) || $bag.has?(:LUCKINCENSE)
    pbMessage(_INTL("You don't have an Amulet Coin or Luck Incense to upgrade."))
    return
  end
  pbItemUpgradeDetail(:AMULETCOIN)
end

def pbUpgradePowerItems
  unless POWER_ITEM_IDS.any? { |id| $bag.has?(id) }
    pbMessage(_INTL("You don't have any Power items to upgrade."))
    return
  end
  pbItemUpgradeDetail(:POWERITEMS)
end

def pbItemUpgradeShop
  available = ItemUpgradeSystem::UPGRADES.keys.select do |id|
    next true if $bag.has?(id)
    # Luck Incense shares the Amulet Coin upgrade level.
    next true if id == :AMULETCOIN && $bag.has?(:LUCKINCENSE)
    # :POWERITEMS is virtual — show if the player has any Power item.
    next true if id == :POWERITEMS && POWER_ITEM_IDS.any? { |pi| $bag.has?(pi) }
    false
  end

  if available.empty?
    pbMessage(_INTL("You don't have any items I can upgrade right now."))
    return
  end

  loop do
    commands = available.map do |id|
      data  = ItemUpgradeSystem::UPGRADES[id]
      level = ItemUpgradeSystem.level_for(id)
      max   = data[:tiers].length
      tier  = ItemUpgradeSystem.current_tier(id)
      maxed = level >= max
      label = maxed ? _INTL("{1}  Lv.{2} MAX  ({3})", data[:name], level, tier[:label])
                    : _INTL("{1}  Lv.{2}/{3}  ({4})", data[:name], level, max, tier[:label])
      label
    end
    commands.push(_INTL("Leave"))

    choice = pbMessage(_INTL("Which item would you like to upgrade?"), commands, -1)
    break if choice < 0 || choice == commands.length - 1

    pbItemUpgradeDetail(available[choice])
  end
end
