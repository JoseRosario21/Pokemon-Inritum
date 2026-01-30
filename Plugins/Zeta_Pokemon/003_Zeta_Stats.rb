class Pokemon
  alias _zeta_baseStats baseStats
  def baseStats
    ret = _zeta_baseStats
    if self.zeta?
      # Find the 2 stats with the highest base values
      sorted = ret.sort_by { |_k, v| -v }
      top_two = sorted.first(2).map { |s| s[0] }
      top_two.each { |stat| ret[stat] = (ret[stat] * 1.2).floor }
    end
    return ret
  end
end
