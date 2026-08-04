#===============================================================================
# Advanced Battle AI - Debug Tools
# Testing and debugging utilities for the AI system
#===============================================================================

#===============================================================================
# Runtime Debug Settings (can be toggled during gameplay)
# These are separate from the compile-time constants in 001_Settings.rb
#===============================================================================
module AdvancedBattleAI
  # Runtime debug flags (use class variables so they can be modified)
  @runtime_debug_decisions = false
  @runtime_debug_memory = false
  @runtime_debug_scoring = false

  class << self
    attr_accessor :runtime_debug_decisions, :runtime_debug_memory, :runtime_debug_scoring
  end

  # Override the log method to check runtime flags
  def self.log(message, category = :general)
    return unless $DEBUG
    case category
    when :decisions
      return unless DEBUG_LOG_DECISIONS || @runtime_debug_decisions
    when :memory
      return unless DEBUG_LOG_MEMORY || @runtime_debug_memory
    when :scoring
      return unless DEBUG_LOG_SCORING || @runtime_debug_scoring
    end
    echoln "[AdvancedAI] #{message}"
    # Also persist to Data/debuglog.txt (via PBDebug's own $INTERNAL gate) so
    # AdvancedBattleAI's scoring/decision explanations show up in the same
    # reviewable log as the base AI's PBDebug.log_score_change calls, instead
    # of only being visible in a live console session.
    PBDebug.log("[AdvancedAI] #{message}")
  end
end

#===============================================================================
# Debug Menu Integration
# Add debug options to the game's debug menu
#===============================================================================
if defined?(MenuHandlers)
  MenuHandlers.add(:debug_menu, :advanced_ai_submenu, {
    "name"        => _INTL("Advanced Battle AI"),
    "parent"      => :battle_menu,
    "description" => _INTL("Debug tools for the Advanced Battle AI plugin."),
    "effect"      => proc { |sprites, viewport|
      commands = []
      commands.push(_INTL("View AI Memory"))
      commands.push(_INTL("Test Role Detection"))
      commands.push(_INTL("Toggle Debug Logging"))
      commands.push(_INTL("View AI Settings"))
      commands.push(_INTL("Test Setup Window"))

      loop do
        cmd = pbShowCommands(nil, commands, -1)
        break if cmd < 0

        case cmd
        when 0  # View AI Memory
          pbAdvancedAIViewMemory
        when 1  # Test Role Detection
          pbAdvancedAITestRoles
        when 2  # Toggle Debug Logging
          pbAdvancedAIToggleLogging
        when 3  # View AI Settings
          pbAdvancedAIViewSettings
        when 4  # Test Setup Window
          pbAdvancedAITestSetupWindow
        end
      end
    }
  })
end

#===============================================================================
# View AI Memory
# Shows what the AI knows about each battler
#===============================================================================
def pbAdvancedAIViewMemory
  if !$game_temp || !$game_temp.respond_to?(:battle) || !$game_temp.battle
    pbMessage(_INTL("No active battle. Start a battle first."))
    return
  end

  battle = $game_temp.battle
  ai = battle.ai rescue nil

  if !ai || !ai.memory
    pbMessage(_INTL("AI Memory not initialized."))
    return
  end

  memory = ai.memory
  text = "=== AI Memory ===\n\n"

  battle.battlers.each_with_index do |battler, idx|
    next unless battler && !battler.fainted?

    text += "--- Battler #{idx}: #{battler.name} ---\n"

    # Known moves
    known_moves = memory.get_known_moves(idx)
    if known_moves.empty?
      text += "Known Moves: None\n"
    else
      move_names = known_moves.map { |m| GameData::Move.try_get(m)&.name || m.to_s }
      text += "Known Moves: #{move_names.join(', ')}\n"
    end

    # Known ability
    known_ability = memory.get_known_ability(idx)
    if known_ability
      ability_name = GameData::Ability.try_get(known_ability)&.name || known_ability.to_s
      text += "Known Ability: #{ability_name}\n"
    else
      text += "Known Ability: Unknown\n"
    end

    # Known item
    known_item = memory.get_known_item(idx)
    if known_item
      item_name = GameData::Item.try_get(known_item)&.name || known_item.to_s
      text += "Known Item: #{item_name}\n"
    elsif memory.item_consumed?(idx)
      text += "Item: Consumed\n"
    else
      text += "Known Item: Unknown\n"
    end

    # Damage history
    damage_history = memory.get_damage_history(idx)
    if damage_history.length > 0
      text += "Damage History: #{damage_history.length} records\n"
    end

    # Switch count
    switches = memory.get_switch_count(idx)
    text += "Switch Count: #{switches}\n"

    # Threat indicators
    text += "Has Priority: #{memory.has_shown_priority?(idx) ? 'Yes' : 'No'}\n"
    text += "Has Setup: #{memory.has_shown_setup?(idx) ? 'Yes' : 'No'}\n"
    text += "Has Recovery: #{memory.has_shown_recovery?(idx) ? 'Yes' : 'No'}\n"
    text += "Has Hazards: #{memory.has_shown_hazards?(idx) ? 'Yes' : 'No'}\n"

    text += "\n"
  end

  # Pokemon seen per side
  [0, 1].each do |side|
    seen = memory.get_pokemon_seen(side)
    side_name = side == 0 ? "Player" : "Opponent"
    text += "#{side_name} Pokemon Seen: #{seen.length}\n"
  end

  pbMessage(text)
end

#===============================================================================
# Test Role Detection
# Shows detected roles for current party
#===============================================================================
def pbAdvancedAITestRoles
  if !$player || !$player.party || $player.party.empty?
    pbMessage(_INTL("No Pokemon in party."))
    return
  end

  text = "=== Party Role Detection ===\n\n"

  $player.party.each_with_index do |pkmn, idx|
    next unless pkmn && pkmn.able?

    text += "--- #{pkmn.name} (#{pkmn.species_data.name}) ---\n"

    # Create mock data for role detection
    role = estimate_pokemon_role_debug(pkmn)
    text += "Detected Role: #{role_to_string(role)}\n"

    # Show stat analysis
    stats = pkmn.baseStats
    offensive = [stats[:ATTACK], stats[:SPECIAL_ATTACK]].max
    defensive = stats[:DEFENSE] + stats[:SPECIAL_DEFENSE]
    text += "Offensive: #{offensive}, Defensive: #{defensive}\n"

    # Show relevant moves
    hazard_moves = []
    pivot_moves = []
    setup_moves = []
    recovery_moves = []

    pkmn.moves.each do |move|
      next unless move
      move_data = GameData::Move.try_get(move.id)
      next unless move_data

      case move_data.function_code
      when /AddSpikesToFoeSide|AddToxicSpikesToFoeSide|AddStealthRocksToFoeSide/
        hazard_moves.push(move_data.name)
      when /SwitchOutUser/
        pivot_moves.push(move_data.name)
      when /RaiseUser/
        setup_moves.push(move_data.name)
      when /HealUser/
        recovery_moves.push(move_data.name)
      end
    end

    text += "Hazards: #{hazard_moves.join(', ')}\n" unless hazard_moves.empty?
    text += "Pivots: #{pivot_moves.join(', ')}\n" unless pivot_moves.empty?
    text += "Setup: #{setup_moves.join(', ')}\n" unless setup_moves.empty?
    text += "Recovery: #{recovery_moves.join(', ')}\n" unless recovery_moves.empty?

    text += "\n"
  end

  pbMessage(text)
end

def estimate_pokemon_role_debug(pkmn)
  # Simplified role detection for debug
  stats = pkmn.baseStats
  offensive = [stats[:ATTACK], stats[:SPECIAL_ATTACK]].max
  defensive = stats[:DEFENSE] + stats[:SPECIAL_DEFENSE]

  # Check moves for role indicators
  pkmn.moves.each do |move|
    next unless move
    move_data = GameData::Move.try_get(move.id)
    next unless move_data

    return Battle::AI::Roles::HAZARD_SETTER if move_data.function_code.match?(/AddSpikesToFoeSide|AddStealthRocksToFoeSide/)
    return Battle::AI::Roles::PIVOT if move_data.function_code.match?(/SwitchOutUser/)
  end

  if offensive > defensive * 0.7
    if stats[:SPEED] >= 80
      return Battle::AI::Roles::SWEEPER
    else
      return Battle::AI::Roles::SETUP_SWEEPER
    end
  elsif defensive > offensive * 0.7
    if stats[:DEFENSE] > stats[:SPECIAL_DEFENSE] * 1.3
      return Battle::AI::Roles::PHYSICAL_WALL
    elsif stats[:SPECIAL_DEFENSE] > stats[:DEFENSE] * 1.3
      return Battle::AI::Roles::SPECIAL_WALL
    else
      return Battle::AI::Roles::MIXED_WALL
    end
  end

  return Battle::AI::Roles::UTILITY
end

def role_to_string(role)
  {
    Battle::AI::Roles::SWEEPER => "Sweeper",
    Battle::AI::Roles::PHYSICAL_WALL => "Physical Wall",
    Battle::AI::Roles::SPECIAL_WALL => "Special Wall",
    Battle::AI::Roles::MIXED_WALL => "Mixed Wall",
    Battle::AI::Roles::CLERIC => "Cleric",
    Battle::AI::Roles::HAZARD_SETTER => "Hazard Setter",
    Battle::AI::Roles::HAZARD_REMOVER => "Hazard Remover",
    Battle::AI::Roles::PIVOT => "Pivot",
    Battle::AI::Roles::SETUP_SWEEPER => "Setup Sweeper",
    Battle::AI::Roles::REVENGE_KILLER => "Revenge Killer",
    Battle::AI::Roles::STALLBREAKER => "Stallbreaker",
    Battle::AI::Roles::WEATHER_SETTER => "Weather Setter",
    Battle::AI::Roles::SCREEN_SETTER => "Screen Setter",
    Battle::AI::Roles::UTILITY => "Utility"
  }[role] || "Unknown"
end

#===============================================================================
# Toggle Debug Logging
#===============================================================================
def pbAdvancedAIToggleLogging
  commands = []
  commands.push(_INTL("Toggle Decision Logging"))
  commands.push(_INTL("Toggle Memory Logging"))
  commands.push(_INTL("Toggle Scoring Logging"))
  commands.push(_INTL("Enable All"))
  commands.push(_INTL("Disable All"))

  cmd = pbShowCommands(nil, commands, -1)
  return if cmd < 0

  case cmd
  when 0
    AdvancedBattleAI.runtime_debug_decisions = !AdvancedBattleAI.runtime_debug_decisions
    state = AdvancedBattleAI.runtime_debug_decisions ? "ON" : "OFF"
    pbMessage(_INTL("Decision logging: {1}", state))
  when 1
    AdvancedBattleAI.runtime_debug_memory = !AdvancedBattleAI.runtime_debug_memory
    state = AdvancedBattleAI.runtime_debug_memory ? "ON" : "OFF"
    pbMessage(_INTL("Memory logging: {1}", state))
  when 2
    AdvancedBattleAI.runtime_debug_scoring = !AdvancedBattleAI.runtime_debug_scoring
    state = AdvancedBattleAI.runtime_debug_scoring ? "ON" : "OFF"
    pbMessage(_INTL("Scoring logging: {1}", state))
  when 3
    AdvancedBattleAI.runtime_debug_decisions = true
    AdvancedBattleAI.runtime_debug_memory = true
    AdvancedBattleAI.runtime_debug_scoring = true
    pbMessage(_INTL("All logging enabled."))
  when 4
    AdvancedBattleAI.runtime_debug_decisions = false
    AdvancedBattleAI.runtime_debug_memory = false
    AdvancedBattleAI.runtime_debug_scoring = false
    pbMessage(_INTL("All logging disabled."))
  end
end

#===============================================================================
# View AI Settings
#===============================================================================
def pbAdvancedAIViewSettings
  text = "=== Advanced Battle AI Settings ===\n\n"

  text += "Feature Toggles:\n"
  text += "- Move Memory: #{AdvancedBattleAI::ENABLE_MOVE_MEMORY}\n"
  text += "- Team Synergy: #{AdvancedBattleAI::ENABLE_TEAM_SYNERGY}\n"
  text += "- Advanced Hazards: #{AdvancedBattleAI::ENABLE_ADVANCED_HAZARDS}\n"
  text += "- Setup Windows: #{AdvancedBattleAI::ENABLE_SETUP_WINDOWS}\n"
  text += "- Role Switching: #{AdvancedBattleAI::ENABLE_ROLE_SWITCHING}\n"
  text += "- Doubles Coordination: #{AdvancedBattleAI::ENABLE_DOUBLES_COORDINATION}\n"
  text += "- Sacrifice Awareness: #{AdvancedBattleAI::ENABLE_SACRIFICE_AWARENESS}\n"
  text += "- Field Integration: #{AdvancedBattleAI::ENABLE_FIELD_INTEGRATION}\n"

  text += "\nSkill Thresholds:\n"
  text += "- Basic: #{AdvancedBattleAI::SKILL_THRESHOLD_BASIC}\n"
  text += "- Memory: #{AdvancedBattleAI::SKILL_THRESHOLD_MEMORY}\n"
  text += "- Roles: #{AdvancedBattleAI::SKILL_THRESHOLD_ROLES}\n"
  text += "- Setup: #{AdvancedBattleAI::SKILL_THRESHOLD_SETUP}\n"
  text += "- Doubles: #{AdvancedBattleAI::SKILL_THRESHOLD_DOUBLES}\n"
  text += "- Full: #{AdvancedBattleAI::SKILL_THRESHOLD_FULL}\n"

  text += "\nScore Modifiers:\n"
  text += "- Memory Prediction Bonus: #{AdvancedBattleAI::MEMORY_PREDICTION_BONUS}\n"
  text += "- Setup Window Bonus: #{AdvancedBattleAI::SETUP_WINDOW_BONUS}\n"
  text += "- Setup Risky Penalty: #{AdvancedBattleAI::SETUP_RISKY_PENALTY}\n"
  text += "- Focus Fire Bonus: #{AdvancedBattleAI::DOUBLES_FOCUS_FIRE_BONUS}\n"
  text += "- Partner Synergy Bonus: #{AdvancedBattleAI::PARTNER_SYNERGY_BONUS}\n"

  text += "\nRuntime Debug Flags:\n"
  text += "- Decisions: #{AdvancedBattleAI.runtime_debug_decisions}\n"
  text += "- Memory: #{AdvancedBattleAI.runtime_debug_memory}\n"
  text += "- Scoring: #{AdvancedBattleAI.runtime_debug_scoring}\n"

  pbMessage(text)
end

#===============================================================================
# Test Setup Window
# Test setup window calculation for current battle
#===============================================================================
def pbAdvancedAITestSetupWindow
  if !$game_temp || !$game_temp.respond_to?(:battle) || !$game_temp.battle
    pbMessage(_INTL("No active battle. Start a battle first."))
    return
  end

  battle = $game_temp.battle
  ai = battle.ai rescue nil

  if !ai
    pbMessage(_INTL("AI not initialized."))
    return
  end

  text = "=== Setup Window Analysis ===\n\n"

  battle.battlers.each_with_index do |battler, idx|
    next unless battler && !battler.fainted?
    next if battle.opposes?(idx)  # Only show player's side

    ai_battler = ai.battlers[idx]
    next unless ai_battler

    text += "--- #{battler.name} ---\n"

    # Calculate setup window
    window = ai.calculate_full_setup_window(ai_battler, battle) rescue { turns: 0, safe: false }

    text += "Setup Window: #{window[:turns]} turns\n"
    text += "Safe to Setup: #{window[:safe] ? 'Yes' : 'No'}\n"
    text += "Priority Threat: #{window[:has_priority_threat] ? 'Yes' : 'No'}\n" if window[:has_priority_threat]
    text += "Max Incoming: #{window[:max_incoming]}\n" if window[:max_incoming]

    # Calculate sweep potential
    sweep = ai.calculate_sweep_potential(ai_battler, 2) rescue 0
    text += "Sweep Potential (+2): #{sweep}\n"

    text += "\n"
  end

  pbMessage(text)
end

#===============================================================================
# Console Commands
# Commands that can be run from the debug console
#===============================================================================

# View AI memory from console
def ai_memory
  return "No battle active" unless $game_temp&.battle
  ai = $game_temp.battle.ai rescue nil
  return "AI not initialized" unless ai&.memory

  result = {}
  $game_temp.battle.battlers.each_with_index do |b, i|
    next unless b && !b.fainted?
    result[i] = {
      name: b.name,
      moves: ai.memory.get_known_moves(i),
      ability: ai.memory.get_known_ability(i),
      item: ai.memory.get_known_item(i),
      switches: ai.memory.get_switch_count(i)
    }
  end
  return result
end

# View AI roles from console
def ai_roles
  return "No battle active" unless $game_temp&.battle
  ai = $game_temp.battle.ai rescue nil
  return "AI not initialized" unless ai

  result = {}
  ai.battlers.each_with_index do |b, i|
    next unless b
    result[i] = {
      role: b.detected_role,
      secondary: b.secondary_roles
    }
  end
  return result
end

# Enable all debug logging
def ai_debug_on
  AdvancedBattleAI.runtime_debug_decisions = true
  AdvancedBattleAI.runtime_debug_memory = true
  AdvancedBattleAI.runtime_debug_scoring = true
  return "Debug logging enabled"
end

# Disable all debug logging
def ai_debug_off
  AdvancedBattleAI.runtime_debug_decisions = false
  AdvancedBattleAI.runtime_debug_memory = false
  AdvancedBattleAI.runtime_debug_scoring = false
  return "Debug logging disabled"
end
