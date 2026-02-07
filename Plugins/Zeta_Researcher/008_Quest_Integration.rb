#===============================================================================
# Quest Integration - helpers for map events and quest rewards
#===============================================================================

# Award Research XP from a quest or event script. Shows a message and checks for rank-up.
def pbAwardResearchXP(amount, message = nil)
  pbZetaResearcher.add_xp(amount)
  if message
    pbMessage(message)
  else
    pbMessage(_INTL("You earned {1} Research XP!", amount))
  end
  pbCheckResearcherRankUp
end

# Award Research Tokens from a quest or event script.
def pbAwardResearchTokens(amount, message = nil)
  pbZetaResearcher.add_tokens(amount)
  if message
    pbMessage(message)
  else
    pbMessage(_INTL("You earned {1} Research Tokens!", amount))
  end
end

# Backward compatibility alias.
alias pbAwardResearchRP pbAwardResearchXP

# Checks if the player ranked up and shows a notification.
def pbCheckResearcherRankUp
  data = pbZetaResearcher
  current = data.rank_index
  return if current <= data.last_notified_rank
  data.last_notified_rank = current
  rank_name = data.rank_name
  pbMessage(_INTL("\\se[Item get]Congratulations! You've been promoted to {1} Researcher!", rank_name))
end

# For event conditional branches: check if player has a specific rank unlock.
def pbHasResearcherUnlock?(key)
  return pbZetaResearcher.has_unlock?(key)
end

# Returns the current researcher rank index (0-based).
def pbResearcherRankIndex
  return pbZetaResearcher.rank_index
end
