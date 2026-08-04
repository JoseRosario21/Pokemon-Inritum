#===============================================================================
# Multi-Currency Shop - Currencies
#
# v21.1 ships two hardcoded currencies: money (PokeMart) and Battle Points
# (BattlePointShop), each with its own copy of the shop screen. This adds a
# registry so any shop can charge in anything, without a third copy.
#
# A currency is just a name and a pair of procs, which means one can be backed
# by whatever suits it -- a Game Variable, $Unidata for something that should
# persist across saves, or a plugin's own store.
#
#   MultiCurrency.register(:SHARDS,
#     name:   _INTL("Shards"),
#     format: proc { |n| _INTL("{1} Shards", n) },
#     get:    proc { $game_variables[71] },
#     set:    proc { |v| $game_variables[71] = v }
#   )
#===============================================================================
module MultiCurrency
  CURRENCIES = {}

  module_function

  # `format` is optional; without it the amount is shown followed by the name.
  def register(id, name:, get:, set:, format: nil, max: 999_999)
    CURRENCIES[id.to_sym] = {
      :id     => id.to_sym,
      :name   => name,
      :get    => get,
      :set    => set,
      :format => format,
      :max    => max
    }
  end

  def get(id)
    return CURRENCIES[id.to_sym]
  end

  def exists?(id)
    return CURRENCIES.key?(id.to_sym)
  end

  def amount(id)
    data = get(id)
    return 0 if !data
    value = data[:get].call
    return value.is_a?(Numeric) ? value.to_i : 0
  end

  def set_amount(id, value)
    data = get(id)
    return if !data
    value = value.to_i.clamp(0, data[:max])
    data[:set].call(value)
  end

  def format_amount(id, value)
    data = get(id)
    return value.to_s if !data
    return data[:format].call(value) if data[:format]
    return _INTL("{1} {2}", value.to_s_formatted, data[:name])
  end
end

#===============================================================================
# The built-ins, so an existing shop can be converted without defining anything.
#===============================================================================
MultiCurrency.register(:MONEY,
  name:   _INTL("Money"),
  format: proc { |n| _INTL("$ {1}", n.to_s_formatted) },
  get:    proc { $player.money },
  set:    proc { |v| $player.money = v },
  max:    Settings::MAX_MONEY
)

MultiCurrency.register(:COINS,
  name:   _INTL("Coins"),
  format: proc { |n| _INTL("{1} Coins", n.to_s_formatted) },
  get:    proc { $player.coins },
  set:    proc { |v| $player.coins = v },
  max:    Settings::MAX_COINS
)

MultiCurrency.register(:BATTLE_POINTS,
  name:   _INTL("BP"),
  format: proc { |n| _INTL("{1} BP", n.to_s_formatted) },
  get:    proc { $player.battle_points },
  set:    proc { |v| $player.battle_points = v },
  max:    Settings::MAX_BATTLE_POINTS
)
