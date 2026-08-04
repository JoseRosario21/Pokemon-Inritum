#===============================================================================
# AI Battle Test - Runner
#
# Builds parties, runs real battles against the silent scene, and records
# anything that goes wrong.
#
# Two things make a failure here actionable rather than just alarming:
#
#  * Every battle is seeded, and the seed is logged. A crash can be replayed
#    exactly with "Repeat a seed" from the debug menu.
#  * The last dozen battle messages are captured, so the log shows what was
#    happening when it broke rather than just a backtrace.
#===============================================================================
module AIBattleTest
  # Raised by the silent scene when a battle runs past MAX_TURNS.
  class StalledBattle < StandardError; end

  module_function

  #-----------------------------------------------------------------------------
  # Data pools
  #-----------------------------------------------------------------------------
  def usable_species
    return @usable_species if @usable_species
    pool = SPECIES_POOL.dup
    if pool.empty?
      GameData::Species.each_species do |sp|
        next if sp.form != 0            # base forms only; forms are reached via species data
        pool.push(sp.species)
      end
    end
    @usable_species = pool.uniq
    return @usable_species
  end

  def usable_moves
    return @usable_moves if @usable_moves
    moves = []
    GameData::Move.each do |m|
      next if EXCLUDED_MOVES.include?(m.id)
      moves.push(m.id)
    end
    @usable_moves = moves
    return @usable_moves
  end

  def clear_caches
    @usable_species = nil
    @usable_moves = nil
  end

  #-----------------------------------------------------------------------------
  # Party building
  #-----------------------------------------------------------------------------

  # Builds one Pokemon. `moves` overrides its learnset when given, which is how
  # the sweep reaches moves nothing legitimately learns.
  def build_pokemon(species = nil, moves = nil, level = LEVEL)
    species ||= usable_species.sample
    pkmn = Pokemon.new(species, level, $player, false)
    if moves && !moves.empty?
      pkmn.moves = moves.compact.map { |id| Pokemon::Move.new(id) }
    end
    if pkmn.moves.empty?
      # A Pokemon with no moves would only ever Struggle, which tests nothing.
      pkmn.reset_moves
      pkmn.moves = [Pokemon::Move.new(usable_moves.sample)] if pkmn.moves.empty?
    end
    pkmn.calc_stats
    pkmn.heal
    return pkmn
  end

  def build_party(size = PARTY_SIZE, moves = nil)
    return Array.new(size) { build_pokemon(nil, moves) }
  end

  #-----------------------------------------------------------------------------
  # Running one battle
  #-----------------------------------------------------------------------------

  # Returns a hash describing the outcome. Never raises -- a harness that dies
  # on the first failure cannot report the other 400.
  def run_battle(party1, party2, doubles = false, seed = nil)
    seed ||= rand(1_000_000_000)
    srand(seed)
    scene = SilentScene.new
    result = { :seed => seed, :doubles => doubles, :status => :ok,
               :error => nil, :backtrace => nil, :messages => [], :rounds => 0 }

    begin
      foe_trainer = NPCTrainer.new("AI Test", :POKEMONTRAINER_Brendan)
      foe_trainer.party = party2

      battle = Battle.new(scene, party1, party2, [$player], [foe_trainer])
      battle.internalBattle = false       # no Exp, no money, no Pokedex writes
      battle.controlPlayer  = true        # AI drives both sides; no menus needed
      battle.debug          = true
      battle.setBattleMode(doubles ? "double" : "single")
      battle.pbStartBattle
    rescue StalledBattle => e
      result[:status] = :stalled
      result[:error]  = e.message
    rescue Exception => e
      result[:status]    = :error
      result[:error]     = "#{e.class}: #{e.message}"
      result[:backtrace] = e.backtrace ? e.backtrace.first(8) : []
    end

    result[:messages] = scene.messages.dup
    result[:rounds]   = scene.rounds
    return result
  end

  #-----------------------------------------------------------------------------
  # Runs
  #-----------------------------------------------------------------------------

  # Every move in the dex, four at a time, on both sides so the AI both uses and
  # faces each one.
  def run_move_sweep(doubles = false, progress = nil)
    results = []
    moves = usable_moves
    batches = (moves.length / 4.0).ceil
    batches.times do |i|
      batch = moves[i * 4, 4]
      party1 = build_party(1, batch)
      party2 = build_party(1, batch)
      party1 += build_party(1) if doubles
      party2 += build_party(1) if doubles
      res = run_battle(party1, party2, doubles)
      res[:label] = batch.map(&:to_s).join(", ")
      results.push(res)
      progress&.call(i + 1, batches, res)
    end
    return results
  end

  # Random teams, which is what finds ability/item/field interactions the sweep
  # never assembles.
  def run_random_battles(count, doubles = false, progress = nil)
    results = []
    count.times do |i|
      party1 = build_party
      party2 = build_party
      res = run_battle(party1, party2, doubles)
      res[:label] = _INTL("random #{doubles ? 'double' : 'single'} #{i + 1}")
      results.push(res)
      progress&.call(i + 1, count, res)
    end
    return results
  end

  # Replays a single seed, for chasing down something the log reported.
  def replay_seed(seed, doubles = false)
    srand(seed)
    party1 = build_party
    party2 = build_party
    return run_battle(party1, party2, doubles, seed)
  end

  #-----------------------------------------------------------------------------
  # Reporting
  #-----------------------------------------------------------------------------
  def write_log(results, title)
    failures = results.select { |r| r[:status] != :ok }
    File.open(LOG_FILE, "ab") do |f|
      f.puts("=" * 78)
      f.puts("#{title} - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
      f.puts("=" * 78)
      f.puts("battles: #{results.length}   ok: #{results.length - failures.length}   " \
             "errors: #{results.count { |r| r[:status] == :error }}   " \
             "stalled: #{results.count { |r| r[:status] == :stalled }}")
      f.puts
      failures.each do |r|
        f.puts("-" * 78)
        f.puts("[#{r[:status].to_s.upcase}] #{r[:label]}")
        f.puts("  seed:   #{r[:seed]}   (#{r[:doubles] ? 'double' : 'single'}, #{r[:rounds]} rounds)")
        f.puts("  error:  #{r[:error]}")
        (r[:backtrace] || []).each { |line| f.puts("          #{line}") }
        if !r[:messages].empty?
          f.puts("  last messages:")
          r[:messages].each { |m| f.puts("          #{m}") }
        end
      end
      if !missing_scene_methods.empty?
        f.puts
        f.puts("Scene methods the harness does not implement (add to SilentScene):")
        missing_scene_methods.each { |m| f.puts("  #{m}") }
      end
      f.puts
    end
    return failures
  end

  def summarise(results)
    errors  = results.count { |r| r[:status] == :error }
    stalled = results.count { |r| r[:status] == :stalled }
    return _INTL("{1} battles: {2} ok, {3} errors, {4} stalled.",
                 results.length, results.length - errors - stalled, errors, stalled)
  end
end
