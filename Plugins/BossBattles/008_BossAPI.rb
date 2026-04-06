#===============================================================================
# Boss Battles - Public API
#
# Call pbBossBattle(:BOSS_ID) from a map event Script command.
#
# Example:
#   pbBossBattle(:CHANDELURE_BOSS)
#
# The player can always lose (canLose is set).
# Exp and money are not awarded regardless.
# Poké Balls are disabled unless :catchable is true in the boss config.
# If caught, the Pokémon is nicknamed and stored normally.
#===============================================================================

module BossBattle
  module_function

  # Builds the boss Pokémon from the config entry.
  def build_boss_pokemon(cfg, boss_id)
    species = cfg[:species].to_sym
    level   = cfg[:level]   || 50
    form    = cfg[:form]    || 0

    pkmn = pbGenerateWildPokemon(species, level)
    pkmn.form = form

    # IVs
    iv = cfg.fetch(:iv, 31)
    GameData::Stat.each_main { |s| pkmn.iv[s.id] = iv }

    # Nature
    pkmn.nature = cfg[:nature].to_sym if cfg[:nature]

    # Moves
    if cfg[:moves]
      pkmn.moves.clear
      cfg[:moves].first(4).each_with_index do |m, i|
        pkmn.moves[i] = Pokemon::Move.new(m.to_sym)
      end
    end

    # Item
    pkmn.item = cfg[:item].to_sym if cfg[:item]

    # Ability
    pkmn.ability = cfg[:ability].to_sym if cfg[:ability]

    pkmn.calc_stats

    # Tag the Pokémon as a boss so the battler can detect it.
    pkmn.instance_variable_set(:@boss_id, boss_id.to_sym)

    return pkmn
  end
end

# ---------------------------------------------------------------------------
# Entry point called from map events
# ---------------------------------------------------------------------------
def pbBossBattle(boss_id)
  boss_id = boss_id.to_sym
  cfg = BossBattle::BOSS_DATA[boss_id]
  unless cfg
    raise ArgumentError, "Boss '#{boss_id}' not found in BossBattle::BOSS_DATA"
  end

  # Show entry message if configured.
  if cfg[:entry_text] && !cfg[:entry_text].empty?
    pbMessage(cfg[:entry_text])
  end

  # Build the boss Pokémon.
  pkmn = BossBattle.build_boss_pokemon(cfg, boss_id)

  # Battle rules.
  setBattleRule("canLose")
  setBattleRule("noExp")
  setBattleRule("noMoney")
  # When not catchable, block all Poké Balls so the player can't throw during
  # shield phases or when boss health is up.  When catchable, normal ball use
  # is allowed and Essentials handles the full catch sequence automatically.
  setBattleRule("disablePokeBalls") unless cfg[:catchable]

  # Run the battle.
  outcome = WildBattle.start_core(pkmn)

  return outcome
end
