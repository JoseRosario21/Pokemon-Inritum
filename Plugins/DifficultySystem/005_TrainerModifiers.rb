#===============================================================================
# Difficulty System — Trainer Party Modifiers
#
# Aliases GameData::Trainer#to_trainer to apply:
#   - IV/EV defaults (when PBS has no explicit values)
#   - Dynamic level scaling (Story mode only)
#   - Team size reduction for boss trainers (Story mode only: removes slot index 4)
#===============================================================================
module GameData
  class Trainer
    alias difficulty_to_trainer_original to_trainer unless method_defined?(:difficulty_to_trainer_original)

    def to_trainer
      # Pre-scan which Pokémon have IVs/EVs explicitly set in PBS.
      # We check this before calling the original because @pokemon (pkmn_data)
      # is the raw PBS data array, and the original method doesn't expose it.
      explicit_iv = @pokemon.map { |p| !p[:iv].nil? }
      explicit_ev = @pokemon.map { |p| !p[:ev].nil? }

      trainer = difficulty_to_trainer_original

      tier        = DifficultySystem.trainer_tier(@trainer_type)
      iv_val, ev_val = DifficultySystem.iv_ev_for(tier)

      trainer.party.each_with_index do |pkmn, i|
        changed = false

        unless explicit_iv[i]
          DifficultySystem.apply_iv(pkmn, iv_val)
          changed = true
        end

        unless explicit_ev[i]
          DifficultySystem.apply_ev(pkmn, ev_val)
          changed = true
        end

        pkmn.calc_stats if changed
      end

      # Story only: remove index 4 (5th slot) from boss trainers with a full team of 6.
      # Convention: Classic rosters are always 6 mons; slot 6 is the ace, slot 5 is the
      # secondary threat that Story mode removes.
      if pbStoryMode? && tier == :boss && trainer.party.size >= 6
        trainer.party.delete_at(4)
      end

      # Story only: scale all remaining Pokémon levels to the player's party.
      DifficultySystem.scale_levels(trainer) if pbStoryMode?

      trainer
    end
  end
end

#-------------------------------------------------------------------------------
# IV / EV / Level helpers
#-------------------------------------------------------------------------------
module DifficultySystem
  def self.apply_iv(pkmn, iv_value)
    GameData::Stat.each_main { |s| pkmn.iv[s.id] = iv_value }
  end

  def self.apply_ev(pkmn, ev_value)
    return if ev_value == 0
    if ev_value == :boss_spread
      apply_boss_ev_spread(pkmn)
    else
      GameData::Stat.each_main { |s| pkmn.ev[s.id] = ev_value }
    end
  end

  # 252 EVs in the stronger offensive stat, 252 in Speed, 4 in HP.
  def self.apply_boss_ev_spread(pkmn)
    base  = pkmn.species_data.base_stats
    off   = base[:ATTACK] >= base[:SPECIAL_ATTACK] ? :ATTACK : :SPECIAL_ATTACK
    GameData::Stat.each_main { |s| pkmn.ev[s.id] = 0 }
    pkmn.ev[off]    = 252
    pkmn.ev[:SPEED] = 252
    pkmn.ev[:HP]    = 4
  end

  # Scales each Pokémon's level to be at most the player's highest level,
  # but never below 80% of the PBS level.
  def self.scale_levels(trainer)
    return if !$player || $player.party.empty?
    player_max = $player.party.map(&:level).max

    trainer.party.each do |pkmn|
      pbs_level  = pkmn.level
      floor      = (pbs_level * 0.80).floor.clamp(1, pbs_level)
      target     = [player_max, pbs_level].min
      new_level  = [target, floor].max
      next if new_level == pbs_level
      pkmn.level = new_level
      pkmn.calc_stats
    end
  end
end
