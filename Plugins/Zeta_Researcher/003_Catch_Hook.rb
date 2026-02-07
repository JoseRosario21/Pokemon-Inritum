#===============================================================================
# Auto-award Research XP/Tokens when catching Pokemon + mission tracking
#===============================================================================
module Battle::CatchAndStoreMixin
  alias zeta_researcher_pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon
  def pbRecordAndStoreCaughtPokemon
    @caughtPokemon.each do |pkmn|
      # Track missions for ALL caught Pokemon (not just Zeta)
      pbTrackMission(:catch_pokemon, 1)
      # Track type-based missions for each of the Pokemon's types
      pkmn.types.each do |t|
        pbTrackMission(:catch_type, 1, t)
      end
      # Zeta-specific rewards
      if pkmn.zeta?
        tier = pbGetZetaTier(pkmn)
        xp = tier[:catch_xp]
        tokens = tier[:catch_tokens]
        pbZetaResearcher.add_xp(xp)
        pbZetaResearcher.add_tokens(tokens)
        pbZetaResearcher.zeta_caught_count += 1
        tier_name = pbGetZetaTierName(pkmn)
        pbDisplay(_INTL("Zeta {1} catalogued! +{2} XP, +{3} Token. [{4} tier]",
                        pkmn.name, xp, tokens, tier_name))
        # Track Zeta catch mission
        pbTrackMission(:catch_zeta, 1)
        # Check rank-up
        data = pbZetaResearcher
        current = data.rank_index
        if current > data.last_notified_rank
          data.last_notified_rank = current
          pbDisplay(_INTL("Promoted to {1} Researcher!", data.rank_name))
        end
      end
    end
    zeta_researcher_pbRecordAndStoreCaughtPokemon
  end
end
