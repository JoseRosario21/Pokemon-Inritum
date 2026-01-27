class Pokemon
  # @return [Boolean] whether this Pokemon is a Zeta Pokemon (boosted base stats)
  def zeta?
    if @zeta.nil?
      a = @personalID ^ @owner.id
      b = (a >> 8) & 0xFFFF
      c = (a >> 24) & 0xFF | ((a & 0xFF) << 8)
      d = b ^ c
      @zeta = d < Settings::ZETA_POKEMON_CHANCE
    end
    return @zeta
  end

  # @param value [Boolean] whether this Pokemon is a Zeta Pokemon
  def zeta=(value)
    @zeta = value
  end

  # Forces this Pokemon to be a Zeta Pokemon.
  def makeZeta
    @zeta = true
  end

  # Maxes the IVs of this Pokemon's 2 highest base stats and recalculates stats.
  # Call this after setting zeta = true on manually created Pokemon.
  def apply_zeta_ivs
    base = species_data.base_stats
    sorted = base.sort_by { |_k, v| -v }
    top_two = sorted.first(2).map { |s| s[0] }
    top_two.each { |stat| self.iv[stat] = Pokemon::IV_STAT_LIMIT }
    calc_stats
  end

  # Forces this Pokemon to not be a Zeta Pokemon.
  def makeNotZeta
    @zeta = false
  end
end
