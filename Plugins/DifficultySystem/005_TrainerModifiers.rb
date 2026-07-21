#===============================================================================
# Difficulty System — Classic Mode Filler IV/EV Injection
#
# In Classic mode, applies level-based IVs and EVs to any Pokémon with no
# explicit values set in PBS:
#   IVs: (level * 0.75).round.clamp(0, 31)
#   EVs: (level * 2).clamp(0, 85) per stat
# Both always higher than Story (Essentials native: level/2 IVs, level*3/2 EVs).
#
# Story mode is left untouched — Essentials' native formula runs for fillers.
# Important fights with explicit IVs/EVs in PBS are never touched.
#===============================================================================
module GameData
  class Trainer
    alias difficulty_to_trainer_original to_trainer unless method_defined?(:difficulty_to_trainer_original)

    def to_trainer
      explicit_iv = @pokemon.map { |p| !p[:iv].nil? }
      explicit_ev = @pokemon.map { |p| !p[:ev].nil? }
      trainer     = difficulty_to_trainer_original
      return trainer if pbStoryMode?

      trainer.party.each_with_index do |pkmn, i|
        changed = false
        unless explicit_iv[i]
          iv = (pkmn.level * 0.75).round.clamp(0, 31)
          pkmn.iv.each_key { |s| pkmn.iv[s] = iv }
          changed = true
        end
        unless explicit_ev[i]
          ev = (pkmn.level * 2).clamp(0, 85)
          pkmn.ev.each_key { |s| pkmn.ev[s] = ev }
          changed = true
        end
        pkmn.calc_stats if changed
      end

      trainer
    end
  end
end
