#===============================================================================
# Boss Battles - On-Break Effects
#
# Applies the effect bundle defined in :on_break for the broken shield tier.
# Called from 003_BossShieldSystem.rb after the break message/animation.
#===============================================================================

module BossBattle
  module_function

  # Applies all defined effect keys from a single on_break entry.
  # battle  — the active Battle instance
  # battler — the boss Battle::Battler
  # data    — the on_break hash for this shield tier (may be nil)
  # boss_id — boss symbol key in BOSS_DATA (for context)
  def apply_break_effects(battle, battler, data, boss_id)
    return unless data

    # --- Form change ---
    if data.key?(:form_change)
      battler.pbChangeForm(data[:form_change], nil)
    end

    # --- Type change ---
    if data[:type_change]
      types = Array(data[:type_change]).map(&:to_sym)
      battler.types = types
      battle.pbDisplay(_INTL("{1}'s type changed!", battler.pbThis))
    end

    # --- Ability change ---
    if data[:ability]
      battler.ability_id = data[:ability].to_sym
      battler.pokemon.ability = data[:ability].to_sym
      battle.pbDisplay(_INTL("{1} gained a new ability!", battler.pbThis))
    end

    # --- Moveset replacement ---
    if data[:moves]
      new_moves = Array(data[:moves]).first(4)
      battler.pokemon.moves = []
      new_moves.each_with_index do |move_sym, i|
        battler.pokemon.moves[i] = Pokemon::Move.new(move_sym.to_sym)
      end
      battler.moves = []
      battler.pokemon.moves.compact.each_with_index do |m, i|
        battler.moves[i] = Battle::Move.from_pokemon_move(battle, m)
      end
    end

    # --- Stat stage changes ---
    if data[:stat_changes]
      data[:stat_changes].each do |stat_key, stages|
        stat_id = stat_key.to_sym
        if stages > 0
          battler.pbRaiseStatStageBasic(stat_id, stages)
          battle.pbCommonAnimation("StatUp", battler) rescue nil
          battle.pbDisplay(_INTL("{1}'s {2} rose!", battler.pbThis,
                                  GameData::Stat.get(stat_id).name)) rescue nil
        elsif stages < 0
          battler.pbLowerStatStageBasic(stat_id, stages.abs)
          battle.pbCommonAnimation("StatDown", battler) rescue nil
          battle.pbDisplay(_INTL("{1}'s {2} fell!", battler.pbThis,
                                  GameData::Stat.get(stat_id).name)) rescue nil
        end
      end
    end

    # --- Status cure ---
    if data[:status_cure] && battler.status != :NONE
      battler.status      = :NONE
      battler.statusCount = 0
      battle.pbDisplay(_INTL("{1} shook off its status ailment!", battler.pbThis))
    end

    # --- Stat stage reset ---
    if data[:stat_reset]
      GameData::Stat.each_battle { |s| battler.stages[s.id] = 0 }
      battle.pbDisplay(_INTL("{1}'s stat changes were reset!", battler.pbThis))
    end

    # --- Weather change ---
    if data[:weather]
      battle.field.weather         = data[:weather].to_sym
      battle.field.weatherDuration = (data[:weather_turns] || 5)
      weather_data = GameData::BattleWeather.try_get(battle.field.weather)
      battle.pbCommonAnimation(weather_data.animation) if weather_data
    end

    # --- BGM change ---
    if data[:bgm] && !data[:bgm].empty?
      pbBGMPlay(data[:bgm]) rescue nil
    end

    # --- Ally call ---
    if data[:ally_call]
      ac = data[:ally_call]
      battle.pbBossCallAlly(battler, ac[:species].to_sym, (ac[:level] || battler.level))
    end
  end

end
