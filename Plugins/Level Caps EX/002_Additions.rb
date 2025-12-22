#-------------------------------------------------------------------------------
# Rare Candy edits for Level Caps
#-------------------------------------------------------------------------------
ItemHandlers::UseOnPokemonMaximum.add(:RARECANDY, proc { |item, pkmn|
  # Calculate maximum based on level caps
  if LevelCapsEX.hard_cap? || LevelCapsEX.soft_cap?
    max_lv = LevelCapsEX.level_cap
    # Don't allow any if already at or above cap
    next 0 if pkmn.level >= max_lv
    next max_lv - pkmn.level
  else
    # No level cap active, use game maximum
    max_lv = GameData::GrowthRate.max_level
    next max_lv - pkmn.level
  end
})

ItemHandlers::UseOnPokemon.add(:RARECANDY, proc { |item, qty, pkmn, scene|
  if pkmn.shadowPokemon?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  elsif pkmn.level >= GameData::GrowthRate.max_level
    new_species = pkmn.check_evolution_on_level_up
    if !Settings::RARE_CANDY_USABLE_AT_MAX_LEVEL || !new_species
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    # Check for evolution
    pbFadeOutInWithMusic do
      evo = PokemonEvolutionScene.new
      evo.pbStartScreen(pkmn, new_species)
      evo.pbEvolution
      evo.pbEndScreen
      scene.pbRefresh if scene.is_a?(PokemonPartyScreen)
    end
    next true
  elsif pkmn.crosses_level_cap?
    scene.pbDisplay(_INTL("{1} refuses to eat the {2}.", pkmn.name, GameData::Item.get(item).name))
    next false
  end
  # Level up - respect level caps by leveling one at a time
  pbSEPlay("Pkmn level up")
  target_level = pkmn.level + qty
  actual_levels_gained = 0
  
  # Debug output
  echoln "[Level Caps EX] DEBUG - Starting level: #{pkmn.level}, Target: #{target_level}, Qty: #{qty}"
  echoln "[Level Caps EX] DEBUG - Hard cap: #{LevelCapsEX.hard_cap?}, Soft cap: #{LevelCapsEX.soft_cap?}"
  echoln "[Level Caps EX] DEBUG - Level cap: #{LevelCapsEX.level_cap}, Bypass switch: #{$game_switches[LevelCapsEX::LEVEL_CAP_BYPASS_SWITCH]}"
  echoln "[Level Caps EX] DEBUG - Level cap mode: #{LevelCapsEX.level_cap_mode}"
  echoln "[Level Caps EX] DEBUG - Variable #{LevelCapsEX::LEVEL_CAP_VARIABLE}: #{$game_variables[LevelCapsEX::LEVEL_CAP_VARIABLE]}, Variable #{LevelCapsEX::LEVEL_CAP_MODE_VARIABLE}: #{$game_variables[LevelCapsEX::LEVEL_CAP_MODE_VARIABLE]}"
  # Debug: Check if constants exist and their values
  if defined?(LevelCapsEX::LEVEL_CAP_VARIABLE)
    echoln "[Level Caps EX] DEBUG - LEVEL_CAP_VARIABLE defined as: #{LevelCapsEX::LEVEL_CAP_VARIABLE}"
  else
    echoln "[Level Caps EX] DEBUG - LEVEL_CAP_VARIABLE not defined!"
  end
  if defined?(LevelCapsEX::LEVEL_CAP_MODE_VARIABLE)
    echoln "[Level Caps EX] DEBUG - LEVEL_CAP_MODE_VARIABLE defined as: #{LevelCapsEX::LEVEL_CAP_MODE_VARIABLE}"
  else
    echoln "[Level Caps EX] DEBUG - LEVEL_CAP_MODE_VARIABLE not defined!"
  end
  
  # Debug: Show what the level_cap method is actually using
  echoln "[Level Caps EX] DEBUG - level_cap method result: #{LevelCapsEX.level_cap}"
  echoln "[Level Caps EX] DEBUG - level_cap_mode method result: #{LevelCapsEX.level_cap_mode}"
  
  # Level up one at a time to respect level caps
  qty.times do |i|
    break if pkmn.level >= target_level
    # Check level cap for both hard and soft caps
    if LevelCapsEX.hard_cap? && pkmn.level >= LevelCapsEX.level_cap
      echoln "[Level Caps EX] DEBUG - Stopped by hard cap at level #{pkmn.level}"
      break
    elsif LevelCapsEX.soft_cap? && pkmn.level >= LevelCapsEX.level_cap
      echoln "[Level Caps EX] DEBUG - Stopped by soft cap at level #{pkmn.level}"
      break  
    end
    
    old_level = pkmn.level
    echoln "[Level Caps EX] DEBUG - Attempt #{i+1}: Level #{old_level} -> #{old_level + 1}"
    # Use direct level assignment to trigger level cap checks
    pkmn.level = pkmn.level + 1
    pkmn.calc_stats
    echoln "[Level Caps EX] DEBUG - After level assignment: #{pkmn.level}"
    actual_levels_gained += 1 if pkmn.level > old_level
    
    # Learn all moves learned at this level
    moveList = pkmn.getMoveList
    moveList.each do |m|
      next if m[0] != pkmn.level
      pbLearnMove(pkmn, m[1]) { scene.pbUpdate if scene.respond_to?(:pbUpdate) }
    end
    
    # Check for evolution at new level
    new_species = pkmn.check_evolution_on_level_up
    if new_species
      pbFadeOutInWithMusic do
        evo = PokemonEvolutionScene.new
        evo.pbStartScreen(pkmn, new_species)
        evo.pbEvolution
        evo.pbEndScreen
        scene.pbRefresh if scene.respond_to?(:pbRefresh)
      end
    end
  end
  
  # Show single message about total levels gained if multiple were used
  if qty > 1 && actual_levels_gained > 0
    scene.pbDisplay(_INTL("{1} gained {2} level(s) from {3} Rare Candies!", pkmn.name, actual_levels_gained, qty)) if scene.respond_to?(:pbDisplay)
  end
  
  scene.pbHardRefresh
  next true
})

#-------------------------------------------------------------------------------
# EXP Candy Edits for Level Caps
#-------------------------------------------------------------------------------
ItemHandlers::UseOnPokemonMaximum.add(:EXPCANDYXS, proc { |item, pkmn|
  gain_amount = 100
  max_exp = LevelCapsEX.soft_cap? ? pkmn.growth_rate.minimum_exp_for_level(LevelCapsEX.level_cap) : pkmn.growth_rate.maximum_exp
  next ((max_exp - pkmn.exp) / gain_amount.to_f).ceil
})

ItemHandlers::UseOnPokemon.add(:EXPCANDYXS, proc { |item, qty, pkmn, scene|
  next pbGainExpFromExpCandy(pkmn, 100, qty, scene, item)
})

ItemHandlers::UseOnPokemonMaximum.add(:EXPCANDYS, proc { |item, pkmn|
  gain_amount = 800
  max_exp = LevelCapsEX.soft_cap? ? pkmn.growth_rate.minimum_exp_for_level(LevelCapsEX.level_cap) : pkmn.growth_rate.maximum_exp
  next ((max_exp - pkmn.exp) / gain_amount.to_f).ceil
})

ItemHandlers::UseOnPokemon.add(:EXPCANDYS, proc { |item, qty, pkmn, scene|
  next pbGainExpFromExpCandy(pkmn, 800, qty, scene, item)
})

ItemHandlers::UseOnPokemonMaximum.add(:EXPCANDYM, proc { |item, pkmn|
  gain_amount = 3_000
  max_exp = LevelCapsEX.soft_cap? ? pkmn.growth_rate.minimum_exp_for_level(LevelCapsEX.level_cap) : pkmn.growth_rate.maximum_exp
  next ((max_exp - pkmn.exp) / gain_amount.to_f).ceil
})

ItemHandlers::UseOnPokemon.add(:EXPCANDYM, proc { |item, qty, pkmn, scene|
  next pbGainExpFromExpCandy(pkmn, 3_000, qty, scene, item)
})

ItemHandlers::UseOnPokemonMaximum.add(:EXPCANDYL, proc { |item, pkmn|
  gain_amount = 10_000
  max_exp = LevelCapsEX.soft_cap? ? pkmn.growth_rate.minimum_exp_for_level(LevelCapsEX.level_cap) : pkmn.growth_rate.maximum_exp
  next ((max_exp - pkmn.exp) / gain_amount.to_f).ceil
})

ItemHandlers::UseOnPokemon.add(:EXPCANDYL, proc { |item, qty, pkmn, scene|
  next pbGainExpFromExpCandy(pkmn, 10_000, qty, scene, item)
})

ItemHandlers::UseOnPokemonMaximum.add(:EXPCANDYXL, proc { |item, pkmn|
  gain_amount = 30_000
  max_exp = LevelCapsEX.soft_cap? ? pkmn.growth_rate.minimum_exp_for_level(LevelCapsEX.level_cap) : pkmn.growth_rate.maximum_exp
  next ((max_exp - pkmn.exp) / gain_amount.to_f).ceil
})

ItemHandlers::UseOnPokemon.add(:EXPCANDYXL, proc { |item, qty, pkmn, scene|
  next pbGainExpFromExpCandy(pkmn, 30_000, qty, scene, item)
})

def pbGainExpFromExpCandy(pkmn, base_amt, qty, scene, item)
  if pkmn.level >= GameData::GrowthRate.max_level || pkmn.shadowPokemon?
    scene.pbDisplay(_INTL("It won't have any effect."))
    return false
  end
  
  # Hard cap check - completely prevent exp gain if level cap is reached
  if LevelCapsEX.hard_cap? && pkmn.level >= LevelCapsEX.level_cap
    scene.pbDisplay(_INTL("{1} refuses to eat the {2}.", pkmn.name, GameData::Item.get(item).name))
    return false
  end
  
  # Calculate the maximum Exp the Pokemon can receive
  # For both hard cap and soft cap, limit to level cap EXP
  if LevelCapsEX.hard_cap? || LevelCapsEX.soft_cap?
    max_exp = pkmn.growth_rate.minimum_exp_for_level(LevelCapsEX.level_cap)
  else
    max_exp = pkmn.growth_rate.maximum_exp
  end
  exp_gain = base_amt * qty
  new_exp = pkmn.exp + exp_gain
  
  # If the new Exp would exceed the level cap, limit the Exp gain
  if new_exp > max_exp
    exp_gain = max_exp - pkmn.exp
    if exp_gain <= 0
      scene.pbDisplay(_INTL("{1} refuses to eat the {2}.", pkmn.name, GameData::Item.get(item).name))
      return false
    end
  end
  
  pbSEPlay("Pkmn level up")
  scene.scene.pbSetHelpText("") if scene.is_a?(PokemonPartyScreen)
  if qty > 1
    (qty - 1).times { pkmn.changeHappiness("vitamin") }
  end
  pbChangeExp(pkmn, pkmn.exp + exp_gain, scene)
  scene.pbHardRefresh
  return true
end

#-------------------------------------------------------------------------------
# Additions to Game Variables to log Level Cap changes and set defaults
#-------------------------------------------------------------------------------
class Game_Variables
  alias __level_caps__set_variable []= unless method_defined?(:__level_caps__set_variable)
  def []=(variable_id, value)
    old_value = self[variable_id]
    ret = __level_caps__set_variable(variable_id, value)
    
    # Logging for level cap variables
    if value != old_value && LevelCapsEX::LOG_LEVEL_CAP_CHANGES
      # Use direct numbers to avoid constant issues
      if variable_id == LevelCapsEX::LEVEL_CAP_VARIABLE
        echoln "Current Level Cap updated from Lv. #{old_value} to Lv. #{value}"
      elsif variable_id == LevelCapsEX::LEVEL_CAP_MODE_VARIABLE
        mode_names = [
          "None",
          "Hard Cap", 
          "EXP Cap",
          "Obedience Cap"
        ]
        old_name = mode_names[old_value] || "None"
        new_name = mode_names[value] || "None"
        echoln "Current Level Cap Mode updated from \"#{old_name}\" to \"#{new_name}\""
      end
    end
    return ret
  end
end

module Game
  class << self
    alias __level_caps__start_new start_new unless method_defined?(:__level_caps__start_new)
  end

  def self.start_new(*args)
    __level_caps__start_new(*args)
    $game_variables[LevelCapsEX::LEVEL_CAP_MODE_VARIABLE] = LevelCapsEX::DEFAULT_LEVEL_CAP_MODE
  end
end

#-------------------------------------------------------------------------------
# Main Level Cap Module
#-------------------------------------------------------------------------------
module LevelCapsEX
  # The constants should be loaded from 000_Config.rb
  # Don't redefine them here - they come from the config file
  
  module_function

  def level_cap
    return $game_variables[LEVEL_CAP_VARIABLE] if $game_variables && $game_variables[LEVEL_CAP_VARIABLE] > 0
    return Settings::MAXIMUM_LEVEL
  end

  def level_cap_mode
    lv_cap_mode = $game_variables[LEVEL_CAP_MODE_VARIABLE]
    return lv_cap_mode if $game_variables && [1, 2, 3].include?(lv_cap_mode)
    return 0
  end

  def hard_cap?
    result = level_cap_mode == 1 && $game_variables[LEVEL_CAP_VARIABLE] > 0
    echoln "[Level Caps EX] hard_cap? called: mode=#{level_cap_mode}, cap=#{$game_variables[LEVEL_CAP_VARIABLE]}, result=#{result}"
    return result
  end

  def soft_cap?
    return [2, 3].include?(level_cap_mode) && $game_variables[LEVEL_CAP_VARIABLE] > 0
  end

  def hard_level_cap
    max_lv = Settings::MAXIMUM_LEVEL
    return max_lv if !$game_variables
    lv_cap_mode = $game_variables[LEVEL_CAP_MODE_VARIABLE]
    lv_cap = $game_variables[LEVEL_CAP_VARIABLE]
    return max_lv if lv_cap > max_lv 
    return lv_cap if lv_cap > 0 && lv_cap_mode == 1
    return max_lv
  end
  
  # Add a new method to check if a Pokemon can gain EXP
  def can_gain_exp?(pokemon)
    return false if hard_cap? && pokemon.level >= level_cap
    return true
  end
  
  # Helper method for compatibility
  def current_level_cap
    cap_value = $game_variables ? $game_variables[LEVEL_CAP_VARIABLE] : nil
    return cap_value if cap_value && cap_value > 0
    return Settings::MAXIMUM_LEVEL
  end
  
  # Check if Voltseon's Pause Menu exists
  def voltseons_pause_menu_exists?
    return defined?(VoltseonsPauseMenu_Scene)
  end
end

#-------------------------------------------------------------------------------
# Voltseon's Pause Menu Integration (if available)
#-------------------------------------------------------------------------------
if LevelCapsEX.voltseons_pause_menu_exists?
  class VPM_LevelCapHud < Component
    def start_component(viewport, menu)
      super(viewport, menu)
      @sprites["overlay"] = BitmapSprite.new(Graphics.width / 2, 32, viewport)
      @sprites["overlay"].ox = @sprites["overlay"].bitmap.width
      @sprites["overlay"].x = Graphics.width
      @sprites["overlay"].y = 90
      @base_color = $PokemonSystem.from_current_menu_theme(MENU_TEXTCOLOR, Color.new(248, 248, 248))
      @shdw_color = $PokemonSystem.from_current_menu_theme(MENU_TEXTOUTLINE, Color.new(48, 48, 48))
    end

    def should_draw?; return true; end

    def refresh
      level_cap = LevelCapsEX.current_level_cap
      text = _INTL("Current Lvl Cap: {1}", level_cap)
      @sprites["overlay"].bitmap.clear
      pbSetSystemFont(@sprites["overlay"].bitmap)
      pbDrawTextPositions(@sprites["overlay"].bitmap, [
        [text, (Graphics.width / 2) - 8, 12, 1, @base_color, @shdw_color]
      ])
    end
  end

  # Add the component to the menu if MENU_COMPONENTS is defined
  MENU_COMPONENTS << :VPM_LevelCapHud if defined?(MENU_COMPONENTS)
end