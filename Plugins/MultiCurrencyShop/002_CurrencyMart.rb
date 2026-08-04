#===============================================================================
# Multi-Currency Shop - Mart
#
# The shop screen only talks to its adapter through six methods, so charging in
# a different currency needs a subclass, not a second copy of the UI.
#
# Usage from an event Script command:
#
#   pbCurrencyMart([:POTION, :SUPERPOTION], :BATTLE_POINTS,
#                  { :POTION => 5, :SUPERPOTION => 12 })
#
# Prices are per-item and required: an item's PBS price is in money and means
# nothing in Shards. Anything missing a price is dropped from the stock rather
# than sold for its money value by accident.
#
# Selling is disabled by default. A shop that buys back in a custom currency is
# an economy exploit waiting to happen unless it is deliberate, so it has to be
# asked for.
#===============================================================================
class CurrencyMartAdapter < PokemonMartAdapter
  def initialize(currency_id, prices, sell_prices = nil)
    @currency_id = currency_id.to_sym
    @prices      = prices || {}
    @sell_prices = sell_prices
  end

  attr_reader :currency_id

  #-----------------------------------------------------------------------------
  # Wallet
  #-----------------------------------------------------------------------------
  def getMoney
    return MultiCurrency.amount(@currency_id)
  end

  def setMoney(value)
    MultiCurrency.set_amount(@currency_id, value)
  end

  def getMoneyString
    return MultiCurrency.format_amount(@currency_id, getMoney)
  end

  #-----------------------------------------------------------------------------
  # Prices
  #-----------------------------------------------------------------------------
  def getPrice(item, selling = false)
    if selling
      return 0 if !@sell_prices
      return @sell_prices[item].to_i
    end
    return @prices[item].to_i
  end

  def getDisplayPrice(item, selling = false)
    return MultiCurrency.format_amount(@currency_id, getPrice(item, selling))
  end

  def canSell?(item)
    return false if !@sell_prices
    return getPrice(item, true) > 0 && !GameData::Item.get(item).is_important?
  end
end

#===============================================================================
# PokemonMartScreen hardcodes `@adapter = PokemonMartAdapter.new` in its
# constructor, and hands that adapter to the scene as a parameter. A subclass
# that swaps it after `super` is all that is needed -- and unlike poking at the
# ivar from outside, this keeps working if the base constructor grows.
#===============================================================================
class CurrencyMartScreen < PokemonMartScreen
  def initialize(scene, stock, adapter)
    super(scene, stock)
    @adapter = adapter
  end
end

#===============================================================================
# Entry point.
#
#   stock        Array of item symbols
#   currency     Registered currency id, e.g. :BATTLE_POINTS
#   prices       Hash of item => cost in that currency
#   sell_prices  Optional hash; omit to make the shop buy-only
#===============================================================================
def pbCurrencyMart(stock, currency, prices, sell_prices = nil, speech = nil)
  currency = currency.to_sym
  if !MultiCurrency.exists?(currency)
    raise ArgumentError, "Unknown currency #{currency.inspect} -- register it with MultiCurrency.register"
  end

  stock = stock.map { |i| GameData::Item.try_get(i)&.id }.compact
  # Anything without a price would otherwise fall through to its money price,
  # which in a Shards shop would be nonsense.
  priced = stock.select { |item| prices[item].to_i > 0 }
  missing = stock - priced
  if !missing.empty? && $DEBUG
    Console.echo_warn("[Currency Mart] no #{currency} price for: #{missing.join(', ')} -- omitted")
  end
  priced.delete_if { |item| GameData::Item.get(item).is_important? && $bag.has?(item) }

  if priced.empty?
    pbMessage(_INTL("Sorry, we're out of stock."))
    return
  end

  adapter = CurrencyMartAdapter.new(currency, prices, sell_prices)
  commands = []
  cmd_buy  = -1
  cmd_sell = -1
  cmd_quit = -1
  commands[cmd_buy = commands.length] = _INTL("I'm here to buy")
  commands[cmd_sell = commands.length] = _INTL("I'm here to sell") if sell_prices
  commands[cmd_quit = commands.length] = _INTL("No, thanks")
  cmd = pbMessage(speech || _INTL("Welcome! How may I help you?"), commands, cmd_quit + 1)

  loop do
    if cmd_buy >= 0 && cmd == cmd_buy
      screen = CurrencyMartScreen.new(PokemonMart_Scene.new, priced, adapter)
      screen.pbBuyScreen
    elsif cmd_sell >= 0 && cmd == cmd_sell
      screen = CurrencyMartScreen.new(PokemonMart_Scene.new, priced, adapter)
      screen.pbSellScreen
    else
      pbMessage(_INTL("Please come again!"))
      break
    end
    cmd = pbMessage(_INTL("Is there anything else I can help you with?"),
                    commands, cmd_quit + 1)
  end
  $game_temp.clear_mart_prices if $game_temp.respond_to?(:clear_mart_prices)
end
