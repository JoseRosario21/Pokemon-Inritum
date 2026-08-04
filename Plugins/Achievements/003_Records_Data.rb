#===============================================================================
# Achievements and Records - Records page
#
# v21.1 keeps 49 counters in $stats and never shows the player any of them; the
# Trainer Card covers name, badges and playtime only. This surfaces the rest.
#
# Entries are [label, proc, formatter]. Anything raising is shown as "-" rather
# than blanking the page, so a stat added by a future plugin can't break it.
#===============================================================================
module Achievements
  module_function

  def commafy(number)
    return number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end

  def format_number(value)
    return commafy(value.to_i)
  end

  def format_money(value)
    return _INTL("${1}", commafy(value.to_i))
  end

  def format_time(seconds)
    seconds = seconds.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    return _INTL("{1}h {2}m", hours, minutes)
  end

  def format_distance(steps)
    return _INTL("{1} steps", commafy(steps.to_i))
  end

  # [section title, [[label, value proc, formatter], ...]]
  RECORD_SECTIONS = [
    [_INTL("Play"), [
      [_INTL("Time played"),        proc { $stats.play_time },              :time],
      [_INTL("Play sessions"),      proc { $stats.play_sessions },          :number],
      [_INTL("Times saved"),        proc { $stats.save_count },             :number],
      [_INTL("Hall of Fame entries"), proc { $stats.hall_of_fame_entry_count }, :number]
    ]],
    [_INTL("Travel"), [
      [_INTL("Walked"),             proc { $stats.distance_walked },        :distance],
      [_INTL("Cycled"),             proc { $stats.distance_cycled },        :distance],
      [_INTL("Surfed"),             proc { $stats.distance_surfed },        :distance],
      [_INTL("Slid on ice"),        proc { $stats.distance_slid_on_ice },   :distance],
      [_INTL("Walked into things"), proc { $stats.bump_count },             :number],
      [_INTL("Times flown"),        proc { $stats.fly_count },              :number]
    ]],
    [_INTL("Battling"), [
      [_INTL("Wild battles won"),   proc { $stats.wild_battles_won },       :number],
      [_INTL("Wild battles lost"),  proc { $stats.wild_battles_lost },      :number],
      [_INTL("Trainers defeated"),  proc { $stats.trainer_battles_won },    :number],
      [_INTL("Losses to trainers"), proc { $stats.trainer_battles_lost },   :number],
      [_INTL("Blacked out"),        proc { $stats.blacked_out_count },      :number],
      [_INTL("Exp. earned"),        proc { $stats.total_exp_gained },       :number],
      [_INTL("Mega Evolutions"),    proc { $stats.mega_evolution_count },   :number],
      [_INTL("Failed Poke Balls"),  proc { $stats.failed_poke_ball_count }, :number]
    ]],
    [_INTL("Pokemon"), [
      [_INTL("Species seen"),       proc { $player.pokedex.seen_count },    :number],
      [_INTL("Species owned"),      proc { $player.pokedex.owned_count },   :number],
      [_INTL("Shinies encountered"), proc { $stats.shinies_encountered },   :number],
      [_INTL("Eggs hatched"),       proc { $stats.eggs_hatched },           :number],
      [_INTL("Evolutions"),         proc { $stats.evolution_count },        :number],
      [_INTL("Evolutions stopped"), proc { $stats.evolutions_cancelled },   :number],
      [_INTL("Pokemon traded"),     proc { $stats.trade_count },            :number],
      [_INTL("Pokerus infections"), proc { $stats.pokerus_infections },     :number],
      [_INTL("Shadow Pokemon purified"), proc { $stats.shadow_pokemon_purified }, :number]
    ]],
    [_INTL("Money"), [
      [_INTL("Spent in shops"),     proc { $stats.money_spent_at_marts },   :money],
      [_INTL("Earned in shops"),    proc { $stats.money_earned_at_marts },  :money],
      [_INTL("Items bought"),       proc { $stats.mart_items_bought },      :number],
      [_INTL("Won in battle"),      proc { $stats.battle_money_gained },    :money],
      [_INTL("Lost in battle"),     proc { $stats.battle_money_lost },      :money]
    ]],
    [_INTL("The world"), [
      [_INTL("Pokemon Center visits"), proc { $stats.poke_center_count },   :number],
      [_INTL("Hidden items found"), proc { $stats.itemfinder_count },       :number],
      [_INTL("Times fished"),       proc { $stats.fishing_count },          :number],
      [_INTL("Berries harvested"),  proc { $stats.berry_plants_picked },    :number],
      [_INTL("Berries planted"),    proc { $stats.berries_planted },        :number],
      [_INTL("Repels used"),        proc { $stats.repel_count },            :number],
      [_INTL("Rocks smashed"),      proc { $stats.rock_smash_count },       :number],
      [_INTL("Trees headbutted"),   proc { $stats.headbutt_count },         :number],
      [_INTL("Fossils revived"),    proc { $stats.revived_fossil_count },   :number]
    ]]
  ]

  def format_record(value, formatter)
    case formatter
    when :time     then return format_time(value)
    when :money    then return format_money(value)
    when :distance then return format_distance(value)
    end
    return format_number(value)
  end

  # Flattens the sections into display lines for the Records tab.
  def record_lines
    lines = []
    return lines if !$stats
    RECORD_SECTIONS.each do |title, entries|
      lines.push({ :kind => :header, :text => title })
      entries.each do |label, getter, formatter|
        value = begin
          format_record(getter.call, formatter)
        rescue StandardError
          "-"
        end
        lines.push({ :kind => :record, :text => label, :value => value })
      end
    end
    return lines
  end
end
