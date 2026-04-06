class Pokemon
  alias zeta_defaults_initialize initialize
  def initialize(species, level, owner = $player, withMoves = true, recheck_form = true)
    zeta_defaults_initialize(species, level, owner, withMoves, recheck_form)
    # Lock starters out of being Zeta only while switch 003 (giving starter) is ON.
    makeNotZeta if $game_switches&.[](3)
    # Apply IV boost if this Pokemon rolled as Zeta (handles gift Pokemon;
    # wild Pokemon are covered separately by on_wild_pokemon_created).
    apply_zeta_ivs if zeta?
  end
end
