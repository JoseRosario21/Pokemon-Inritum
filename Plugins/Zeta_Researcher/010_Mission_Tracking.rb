#===============================================================================
# Mission Tracking - core tracking logic and reward distribution
#===============================================================================

# Called by hooks (catch, donate, battle win) to increment mission progress.
# track_type: :catch_pokemon, :catch_zeta, :catch_type, :donate_zeta, :win_trainer
# amount: how much to increment (usually 1)
# param: extra data (e.g. type symbol for :catch_type)
def pbTrackMission(track_type, amount = 1, param = nil)
  return if !$PokemonGlobal
  data = pbZetaResearcher
  data.check_daily_reset
  rank = data.rank_index
  ZetaResearcher::RESEARCHER_MISSIONS.each do |id, defn|
    next if defn[:auto_track] != track_type
    next if data.mission_completed?(id)
    next if rank < defn[:tier]
    # For :catch_type missions, check that the param matches
    if track_type == :catch_type && defn[:type_param]
      next if param != defn[:type_param]
    end
    data.add_mission_progress(id, amount)
    # Check if goal reached
    if data.mission_progress_for(id) >= defn[:goal]
      pbCompleteMissionReward(id)
    end
  end
end

# Manual completion from event scripts.
def pbCompleteMission(mission_id)
  return if !$PokemonGlobal
  data = pbZetaResearcher
  return if data.mission_completed?(mission_id)
  defn = ZetaResearcher::RESEARCHER_MISSIONS[mission_id]
  return if !defn
  data.add_mission_progress(mission_id, defn[:goal])
  pbCompleteMissionReward(mission_id)
end

# Check if a mission has been completed (for event conditional branches).
def pbMissionCompleted?(mission_id)
  return false if !$PokemonGlobal
  return pbZetaResearcher.mission_completed?(mission_id)
end

# Internal: distribute rewards and mark mission as completed.
def pbCompleteMissionReward(mission_id)
  data = pbZetaResearcher
  return if data.mission_completed?(mission_id)
  defn = ZetaResearcher::RESEARCHER_MISSIONS[mission_id]
  return if !defn
  data.complete_mission(mission_id)
  rewards = defn[:rewards]
  if rewards
    # Award tokens
    if rewards[:tokens] && rewards[:tokens] > 0
      data.add_tokens(rewards[:tokens])
    end
    # Award items
    if rewards[:items]
      rewards[:items].each do |item_entry|
        item, qty = item_entry
        qty = 1 if !qty
        $bag.add(item, qty) if $bag
      end
    end
  end
  # Show completion message
  token_text = (rewards && rewards[:tokens]) ? _INTL(" +{1} Tokens", rewards[:tokens]) : ""
  pbMessage(_INTL("\\se[Item get]Mission Complete: {1}!{2}", defn[:name], token_text))
end
