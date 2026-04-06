#===============================================================================
# Boss Battles - Battler Extensions
#
# Hooks into Battle::Battler#pbInitialize to load boss config onto the battler
# whenever the underlying Pokémon has the @boss_id flag set.
#===============================================================================

class Battle::Battler
  # Current shield count for this battler (decrements on each break).
  attr_accessor :boss_shields
  # Turn counter used by the charge attack system (incremented end-of-round).
  attr_accessor :boss_charge_turn
  # How many SOS allies have been summoned so far.
  attr_accessor :boss_sos_count

  alias_method :boss_orig_pbInitialize, :pbInitialize

  def pbInitialize(pkmn, idxParty, batonPass = false)
    boss_orig_pbInitialize(pkmn, idxParty, batonPass)
    pbInitBoss if @pokemon&.instance_variable_defined?(:@boss_id)
  end

  # Reads the boss config and sets up boss-specific battler state.
  def pbInitBoss
    boss_id = @pokemon.instance_variable_get(:@boss_id)
    cfg = BossBattle::BOSS_DATA[boss_id]
    return unless cfg

    @boss_shields     = cfg[:shield_count] || 0
    @boss_charge_turn = 0
    @boss_sos_count   = 0

    # Apply the boss's custom name if defined.
    @name = cfg[:name] if cfg[:name] && !cfg[:name].empty?
  end

  # True when this battler is a boss Pokémon.
  def boss?
    return @pokemon&.instance_variable_defined?(:@boss_id) &&
           @pokemon.instance_variable_get(:@boss_id) != nil
  end
end
