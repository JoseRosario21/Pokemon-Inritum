#===============================================================================
# Boss Dex - Progress tracking
#
# Two sets on PokemonGlobalMetadata via lazy getters, so existing saves pick them
# up on first access with no save conversion.
#
# The hook is pbBossBattle, the single entry point every boss fight goes through
# (Plugins/BossBattles/008_BossAPI.rb). Encountering is recorded before the
# battle so a loss still unlocks the entry; the win is recorded from the outcome
# afterwards.
#===============================================================================
class PokemonGlobalMetadata
  def bosses_encountered
    @bosses_encountered = [] if !@bosses_encountered
    return @bosses_encountered
  end

  def bosses_encountered=(value)
    @bosses_encountered = value
  end

  def bosses_defeated
    @bosses_defeated = [] if !@bosses_defeated
    return @bosses_defeated
  end

  def bosses_defeated=(value)
    @bosses_defeated = value
  end
end

module BossDex
  module_function

  def all_ids
    return [] if !defined?(BossBattle::BOSS_DATA)
    return BossBattle::BOSS_DATA.keys
  end

  def data_for(boss_id)
    return nil if !defined?(BossBattle::BOSS_DATA)
    return BossBattle::BOSS_DATA[boss_id]
  end

  def mark_encountered(boss_id)
    return if !$PokemonGlobal || boss_id.nil?
    boss_id = boss_id.to_sym
    return if !data_for(boss_id)
    $PokemonGlobal.bosses_encountered.push(boss_id) if !encountered?(boss_id)
  end

  def mark_defeated(boss_id)
    return if !$PokemonGlobal || boss_id.nil?
    boss_id = boss_id.to_sym
    return if !data_for(boss_id)
    mark_encountered(boss_id)
    $PokemonGlobal.bosses_defeated.push(boss_id) if !defeated?(boss_id)
  end

  def encountered?(boss_id)
    return true if REVEAL_EVERYTHING
    return false if !$PokemonGlobal
    return $PokemonGlobal.bosses_encountered.include?(boss_id)
  end

  def defeated?(boss_id)
    return true if REVEAL_EVERYTHING
    return false if !$PokemonGlobal
    return $PokemonGlobal.bosses_defeated.include?(boss_id)
  end

  def any_encountered?
    return true if REVEAL_EVERYTHING
    return all_ids.any? { |id| encountered?(id) }
  end

  # Registry order, which is the order they were authored in -- more meaningful
  # than alphabetical for a story codex.
  def listed_bosses
    return all_ids
  end

  def counts
    total = all_ids.length
    met   = all_ids.count { |id| encountered?(id) }
    won   = all_ids.count { |id| defeated?(id) }
    return [met, won, total]
  end
end

#===============================================================================
# Debug helpers, for checking the dex without grinding every boss.
#   pbUnlockAllBosses / pbResetBossDex
#===============================================================================
def pbUnlockAllBosses
  return if !$PokemonGlobal
  BossDex.all_ids.each { |id| BossDex.mark_defeated(id) }
  return $PokemonGlobal.bosses_defeated.length
end

def pbResetBossDex
  return if !$PokemonGlobal
  $PokemonGlobal.bosses_encountered = []
  $PokemonGlobal.bosses_defeated = []
end

#===============================================================================
# Hook: pbBossBattle is the one path into a boss fight.
#===============================================================================
# pbBossBattle is a top-level def, i.e. a private method on Object, so the guard
# has to ask Object rather than use defined?, which would resolve the bare name
# as a method call.
unless Object.private_method_defined?(:boss_dex_pbBossBattle)
  alias boss_dex_pbBossBattle pbBossBattle
end

def pbBossBattle(boss_id)
  begin
    BossDex.mark_encountered(boss_id)
  rescue StandardError => e
    echoln("[Boss Dex] failed to record encounter: #{e.message}") if $DEBUG
  end
  outcome = boss_dex_pbBossBattle(boss_id)
  begin
    # 1 is a win in Essentials' battle outcomes; 4 is "caught", which for a
    # catchable boss is also a resolution worth recording.
    BossDex.mark_defeated(boss_id) if [1, 4].include?(outcome)
  rescue StandardError => e
    echoln("[Boss Dex] failed to record victory: #{e.message}") if $DEBUG
  end
  return outcome
end
