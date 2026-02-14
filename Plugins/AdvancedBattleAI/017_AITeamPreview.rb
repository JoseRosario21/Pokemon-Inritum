#===============================================================================
# Advanced Battle AI - Team Preview Analysis
# Analyzes opponent's full team at battle start for strategic decisions
# Uses species-based move prediction for opponent — does NOT read actual moves.
#===============================================================================

class Battle::AI
  attr_reader :opponent_team_analysis
  attr_reader :opponent_win_condition
  attr_reader :threat_map
  attr_reader :opponent_coverage_gaps
  attr_reader :opponent_has_hazard_removal
  attr_reader :opponent_has_priority
  attr_reader :opponent_has_setup
  attr_reader :opponent_is_stall

  #-----------------------------------------------------------------------------
  # Initialize team preview variables
  #-----------------------------------------------------------------------------
  alias advanced_ai_teampreview_initialize initialize
  def initialize(battle)
    advanced_ai_teampreview_initialize(battle)
    @opponent_team_analysis = nil
    @opponent_win_condition = nil
    @threat_map = {}
    @opponent_coverage_gaps = []
    @opponent_has_hazard_removal = false
    @opponent_has_priority = false
    @opponent_has_setup = false
    @opponent_is_stall = false
    @team_preview_analyzed = false
    @predicted_opponent_moves = {}  # Cache: party_index => [move_id, ...]
  end

  #-----------------------------------------------------------------------------
  # Get moves to analyze for a party Pokemon.
  # For the AI's own party: uses actual moves (the AI knows its own moveset).
  # For the player's party: uses species-based prediction.
  #-----------------------------------------------------------------------------
  def get_analysis_moves(pkmn, is_opponent = false)
    return [] unless pkmn
    if is_opponent
      # Use cached prediction or generate new one
      key = pkmn.personalID rescue pkmn.object_id
      unless @predicted_opponent_moves[key]
        @predicted_opponent_moves[key] = Battle::AI::AIMemory.predict_moves_for_species(pkmn)
      end
      return @predicted_opponent_moves[key]
    else
      # AI's own moves — read directly
      return pkmn.moves.map { |m| m ? m.id : nil }.compact
    end
  end

  #-----------------------------------------------------------------------------
  # Analyze opponent team (lazy, called once)
  #-----------------------------------------------------------------------------
  def analyze_opponent_team
    return if @team_preview_analyzed
    return unless AdvancedBattleAI.feature_enabled?(:win_condition, @trainer)

    @team_preview_analyzed = true

    # Determine AI battler index (first AI-side battler)
    ai_battler_index = nil
    @battle.battlers.each do |b|
      next unless b && !b.fainted? && b.pbOwnedByPlayer? == false
      ai_battler_index = b.index
      break
    end
    return unless ai_battler_index

    player_party = @battle.pbOpposingParty(ai_battler_index)
    our_party = @battle.pbParty(ai_battler_index)
    return unless player_party && player_party.length > 0
    return unless our_party && our_party.length > 0

    # Analyze opponent team using predicted moves (not actual)
    @opponent_team_analysis = analyze_team_composition_predicted(player_party)
    @opponent_win_condition = determine_win_condition(@opponent_team_analysis)
    @opponent_is_stall = (@opponent_win_condition == AdvancedBattleAI::WinCondition::STALL)

    # Scan predicted moves for hazard removal, priority, and setup
    player_party.each do |pkmn|
      next unless pkmn && pkmn.able?
      predicted_move_ids = get_analysis_moves(pkmn, true)
      predicted_move_ids.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data

        # Hazard removal: Rapid Spin or Defog
        if ["RemoveUserBindingAndEntryHazards",
            "LowerTargetEvasion1RemoveSideEffects"].include?(move_data.function_code)
          @opponent_has_hazard_removal = true
        end

        # Priority attacking moves
        if move_data.priority > 0 && move_data.power > 0
          @opponent_has_priority = true
        end

        # Setup moves
        if is_setup_move?(move_data)
          @opponent_has_setup = true
        end
      end
    end

    # Coverage gaps and threat map (using predicted moves)
    @opponent_coverage_gaps = calculate_opponent_coverage_gaps_predicted(player_party)
    @threat_map = build_threat_map(player_party, our_party)

    AdvancedBattleAI.log(
      "Opponent team analysis complete: win_cond=#{@opponent_win_condition}, " \
      "removal=#{@opponent_has_hazard_removal}, priority=#{@opponent_has_priority}, " \
      "setup=#{@opponent_has_setup}, coverage_gaps=#{@opponent_coverage_gaps.length}, " \
      "threat_map_entries=#{@threat_map.length}",
      :decisions
    )
  end

  #-----------------------------------------------------------------------------
  # Analyze team composition using predicted moves (for opponent team)
  #-----------------------------------------------------------------------------
  def analyze_team_composition_predicted(party)
    analysis = {
      sweepers: [],
      walls: [],
      setup_sweepers: [],
      pivots: [],
      hazard_setters: [],
      clerics: [],
      stallbreakers: [],
      total_recovery: 0,
      total_priority: 0,
      total_setup: 0,
      total_hazards: 0,
      average_speed: 0,
      speed_control: false
    }

    total_speed = 0
    party.each_with_index do |pkmn, idx|
      next unless pkmn && pkmn.able?

      # Classify using predicted moves
      predicted_move_ids = get_analysis_moves(pkmn, true)
      role = classify_pokemon_role_with_moves(pkmn, predicted_move_ids)
      case role
      when :sweeper
        analysis[:sweepers].push(idx)
      when :setup_sweeper
        analysis[:setup_sweepers].push(idx)
        analysis[:total_setup] += 1
      when :physical_wall, :special_wall, :mixed_wall
        analysis[:walls].push(idx)
      when :pivot
        analysis[:pivots].push(idx)
      when :hazard_setter
        analysis[:hazard_setters].push(idx)
      when :cleric
        analysis[:clerics].push(idx)
      when :stallbreaker
        analysis[:stallbreakers].push(idx)
      end

      # Count move types from predicted moves
      predicted_move_ids.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data

        analysis[:total_recovery] += 1 if is_recovery_move?(move_data)
        if move_data.priority > 0 && move_data.power > 0
          analysis[:total_priority] += 1
        end
        analysis[:total_setup] += 1 if is_setup_move?(move_data)
        analysis[:total_hazards] += 1 if is_hazard_move?(move_data)
        analysis[:speed_control] = true if is_speed_control_move?(move_data)
      end

      total_speed += pkmn.speed
    end

    able_count = party.count { |p| p && p.able? }
    analysis[:average_speed] = able_count > 0 ? total_speed / able_count : 0

    return analysis
  end

  #-----------------------------------------------------------------------------
  # Classify a Pokemon role given a set of move IDs (predicted or actual)
  #-----------------------------------------------------------------------------
  def classify_pokemon_role_with_moves(pkmn, move_ids)
    return :unknown unless pkmn

    has_setup = false
    has_pivot = false
    has_hazards = false
    has_recovery = false
    has_stallbreak = false

    move_ids.each do |move_id|
      move_data = GameData::Move.try_get(move_id)
      next unless move_data
      has_setup = true if is_setup_move?(move_data)
      has_pivot = true if is_pivot_move?(move_data)
      has_hazards = true if is_hazard_move?(move_data)
      has_recovery = true if is_recovery_move?(move_data)
      has_stallbreak = true if is_stallbreak_move?(move_data)
    end

    # Stat-based classification (same thresholds as classify_pokemon_role)
    offensive = [pkmn.attack, pkmn.spatk].max
    defensive = (pkmn.defense + pkmn.spdef) / 2
    speed = pkmn.speed

    pkmn_ability = pkmn.ability_id rescue nil
    wall_threshold = pkmn_ability == :INTIMIDATE ? 1.1 : 1.3

    return :setup_sweeper if has_setup && offensive >= 80
    return :pivot if has_pivot
    return :hazard_setter if has_hazards
    return :stallbreaker if has_stallbreak && offensive >= 80

    if defensive >= offensive * wall_threshold
      return :physical_wall if pkmn.defense > pkmn.spdef * 1.3
      return :special_wall if pkmn.spdef > pkmn.defense * 1.3
      return :mixed_wall
    end

    return :cleric if has_recovery && defensive >= 80
    return :sweeper if offensive >= 90 && speed >= 75
    return :utility
  end

  #-----------------------------------------------------------------------------
  # Calculate coverage gaps using predicted moves (for opponent team)
  #-----------------------------------------------------------------------------
  def calculate_opponent_coverage_gaps_predicted(player_party)
    attacking_types = []
    player_party.each do |pkmn|
      next unless pkmn && pkmn.able?
      predicted_move_ids = get_analysis_moves(pkmn, true)
      predicted_move_ids.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data && move_data.power > 0
        attacking_types.push(move_data.type) unless attacking_types.include?(move_data.type)
      end
    end

    gaps = []
    GameData::Type.each do |type_data|
      next if type_data.pseudo_type
      next if type_data.id == :SHADOW
      covered = attacking_types.any? do |atk_type|
        Effectiveness.super_effective_type?(atk_type, type_data.id)
      end
      gaps.push(type_data.id) unless covered
    end

    return gaps
  end

  #-----------------------------------------------------------------------------
  # Build threat map: for each opponent Pokemon, which of ours it threatens
  # and which of ours counter it.
  # Uses predicted moves for opponent, actual moves for our party.
  #-----------------------------------------------------------------------------
  def build_threat_map(player_party, our_party)
    map = {}

    # Check if our team has a hazard setter (AI knows its own moves)
    our_has_hazard_setter = our_party.any? do |pkmn|
      next false unless pkmn && pkmn.able?
      pkmn.moves.any? do |move|
        next false unless move
        md = GameData::Move.try_get(move.id)
        md && is_hazard_move?(md)
      end
    end

    player_party.each_with_index do |opp_pkmn, opp_idx|
      next unless opp_pkmn && opp_pkmn.able?

      predicted_move_ids = get_analysis_moves(opp_pkmn, true)
      entry = {
        threatens: [],
        countered_by: [],
        role: classify_pokemon_role_with_moves(opp_pkmn, predicted_move_ids)
      }

      our_party.each_with_index do |our_pkmn, our_idx|
        next unless our_pkmn && our_pkmn.able?

        # How much does opp threaten our Pokemon? (using predicted moves)
        opp_damage_frac = calculate_party_threat_score_with_moves(opp_pkmn, our_pkmn, predicted_move_ids)
        # How much does our Pokemon threaten opp? (using actual moves)
        our_damage_frac = calculate_party_threat_score(our_pkmn, opp_pkmn)

        # Hazard vulnerability adjustment
        if our_has_hazard_setter
          opp_types = opp_pkmn.types rescue [:NORMAL]
          rock_eff = Effectiveness.calculate(:ROCK, *opp_types)
          if rock_eff >= Effectiveness::SUPER_EFFECTIVE_MULTIPLIER * 2
            our_damage_frac += 0.5
          elsif rock_eff >= Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
            our_damage_frac += 0.25
          end
        end

        if opp_damage_frac >= 0.5
          entry[:threatens].push(our_idx)
        end

        if our_damage_frac >= 0.4 && opp_damage_frac < 1.0
          entry[:countered_by].push({ index: our_idx, score: our_damage_frac })
        end
      end

      map[opp_idx] = entry
    end

    return map
  end

  #-----------------------------------------------------------------------------
  # Calculate best move damage fraction using actual Pokemon moves (AI's own)
  #-----------------------------------------------------------------------------
  def calculate_party_threat_score(attacker_pkmn, defender_pkmn)
    best_fraction = 0.0

    attacker_pkmn.moves.each do |move|
      next unless move
      move_data = GameData::Move.try_get(move.id)
      next unless move_data && move_data.power > 0

      damage = AdvancedBattleAI.estimate_damage_party(move_data, attacker_pkmn, defender_pkmn)
      fraction = defender_pkmn.totalhp > 0 ? damage.to_f / defender_pkmn.totalhp : 0.0
      best_fraction = fraction if fraction > best_fraction
    end

    return best_fraction
  end

  #-----------------------------------------------------------------------------
  # Calculate best move damage fraction from a list of move IDs (predicted)
  #-----------------------------------------------------------------------------
  def calculate_party_threat_score_with_moves(attacker_pkmn, defender_pkmn, move_ids)
    best_fraction = 0.0

    move_ids.each do |move_id|
      move_data = GameData::Move.try_get(move_id)
      next unless move_data && move_data.power > 0

      damage = AdvancedBattleAI.estimate_damage_party(move_data, attacker_pkmn, defender_pkmn)
      fraction = defender_pkmn.totalhp > 0 ? damage.to_f / defender_pkmn.totalhp : 0.0
      best_fraction = fraction if fraction > best_fraction
    end

    return best_fraction
  end

  #-----------------------------------------------------------------------------
  # Enhanced replacement rating with threat map awareness
  #-----------------------------------------------------------------------------
  alias advanced_ai_teampreview_rate_replacement rate_replacement_pokemon
  def rate_replacement_pokemon(idxBattler, pkmn, party_index)
    score = advanced_ai_teampreview_rate_replacement(idxBattler, pkmn, party_index)

    # Only apply if team preview has been analyzed
    return score unless @team_preview_analyzed

    # Check threat map: reward Pokemon that counter many opponents
    @threat_map.each do |opp_idx, entry|
      entry[:countered_by].each do |counter_info|
        if counter_info[:index] == party_index
          # Scale bonus by counter score (max +30 per opponent countered)
          bonus = (counter_info[:score] * 30).to_i
          bonus = [bonus, 30].min
          score += bonus
          AdvancedBattleAI.log(
            "Team preview: #{pkmn.name} counters opponent ##{opp_idx} (+#{bonus})",
            :scoring
          )
        end
      end
    end

    return score
  end
end

#===============================================================================
# Team Preview Score Handlers
#===============================================================================

#-------------------------------------------------------------------------------
# Boost hazard moves when opponent lacks hazard removal
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:team_preview_hazard_boost,
  proc { |score, move, user, ai, battle|
    ai.analyze_opponent_team if ai.respond_to?(:analyze_opponent_team)
    next score unless ai.instance_variable_get(:@team_preview_analyzed)

    move_data = GameData::Move.try_get(move.id)
    next score unless move_data && ai.is_hazard_move?(move_data)

    unless ai.opponent_has_hazard_removal
      score += 20
      AdvancedBattleAI.log("Team preview: hazard boost +20 (no opponent removal)", :scoring)
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Boost setup moves when opponent lacks priority
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:team_preview_setup_safety,
  proc { |score, move, user, ai, battle|
    ai.analyze_opponent_team if ai.respond_to?(:analyze_opponent_team)
    next score unless ai.instance_variable_get(:@team_preview_analyzed)

    move_data = GameData::Move.try_get(move.id)
    next score unless move_data && ai.is_setup_move?(move_data)

    unless ai.opponent_has_priority
      score += AdvancedBattleAI::SCORE_MINOR_BONUS
      AdvancedBattleAI.log("Team preview: setup safety +#{AdvancedBattleAI::SCORE_MINOR_BONUS} (no opponent priority)", :scoring)
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Counter stall teams: boost stallbreak and high-power moves
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:team_preview_counter_stall,
  proc { |score, move, user, target, ai, battle|
    ai.analyze_opponent_team if ai.respond_to?(:analyze_opponent_team)
    next score unless ai.opponent_is_stall

    move_data = GameData::Move.try_get(move.id)
    next score unless move_data

    # Boost stallbreak moves (Taunt, Trick, etc.)
    if ai.is_stallbreak_move?(move_data)
      score += 20
      AdvancedBattleAI.log("Team preview: counter-stall stallbreak +20", :scoring)
    end

    # Boost high-power moves against walls
    target_defensive = (target.defense + target.spdef) / 2
    target_offensive = [target.attack, target.spatk].max
    if target_defensive > target_offensive * 1.2
      if move_data.power >= 90
        score += 10
        AdvancedBattleAI.log("Team preview: counter-stall high-power vs wall +10", :scoring)
      end
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Counter setup teams: boost phazing and Haze
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:team_preview_counter_setup,
  proc { |score, move, user, ai, battle|
    ai.analyze_opponent_team if ai.respond_to?(:analyze_opponent_team)
    next score unless ai.opponent_has_setup

    move_data = GameData::Move.try_get(move.id)
    next score unless move_data

    # Phazing moves (Roar, Whirlwind, Dragon Tail, Circle Throw)
    phazing_functions = [
      "SwitchOutTargetStatusMove",     # Roar, Whirlwind
      "SwitchOutTargetDamagingMove"    # Dragon Tail, Circle Throw
    ]
    if phazing_functions.include?(move_data.function_code)
      if move_data.power > 0
        score += 12  # Damaging phaze
      else
        score += 20  # Status phaze (more reliable)
      end
      AdvancedBattleAI.log("Team preview: counter-setup phazing +#{move_data.power > 0 ? 12 : 20}", :scoring)
    end

    # Haze
    if move_data.function_code == "ResetAllBattlersStatStages"
      score += 15
      AdvancedBattleAI.log("Team preview: counter-setup Haze +15", :scoring)
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Exploit coverage gaps: boost setup if user's type is in opponent's gap
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:team_preview_coverage_exploit,
  proc { |score, move, user, ai, battle|
    ai.analyze_opponent_team if ai.respond_to?(:analyze_opponent_team)
    next score unless ai.opponent_coverage_gaps && ai.opponent_coverage_gaps.length > 0

    move_data = GameData::Move.try_get(move.id)
    next score unless move_data && ai.is_setup_move?(move_data)

    # Check if user has a type in the coverage gap
    user_in_gap = false
    user_types = user.battler.types rescue nil
    next score unless user_types
    user_types.each do |t|
      if ai.opponent_coverage_gaps.include?(t)
        user_in_gap = true
        break
      end
    end

    if user_in_gap
      score += AdvancedBattleAI::SCORE_SMALL_BONUS
      AdvancedBattleAI.log("Team preview: coverage exploit setup +#{AdvancedBattleAI::SCORE_SMALL_BONUS} (type in gap)", :scoring)
    end

    next score
  }
)

#-------------------------------------------------------------------------------
# Lead awareness: set correct screen type based on opponent team composition
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:team_preview_lead_awareness,
  proc { |score, move, user, ai, battle|
    ai.analyze_opponent_team if ai.respond_to?(:analyze_opponent_team)
    next score unless ai.opponent_team_analysis
    next score unless battle.turnCount <= 1

    move_data = GameData::Move.try_get(move.id)
    next score unless move_data

    # Count physical vs special threat from opponent team
    analysis = ai.opponent_team_analysis
    phys_threats = (analysis[:sweepers] || []).length + (analysis[:setup_sweepers] || []).length
    spec_threats = 0

    # Approximate: if opponent has more sweepers, they tend physical;
    # walls/clerics tend special or mixed. Use priority count as physical indicator.
    total_priority = analysis[:total_priority] || 0
    phys_threats += total_priority

    # Reflect (physical screen)
    if move_data.function_code == "StartWeakenPhysicalDamageAgainstUserSide"
      if phys_threats >= 2
        score += 15
        AdvancedBattleAI.log("Team preview: lead Reflect +15 (opponent mostly physical)", :scoring)
      end
    end

    # Light Screen (special screen)
    if move_data.function_code == "StartWeakenSpecialDamageAgainstUserSide"
      # If few physical threats, team is likely more special
      if phys_threats < 2
        score += 15
        AdvancedBattleAI.log("Team preview: lead Light Screen +15 (opponent mostly special)", :scoring)
      end
    end

    next score
  }
)
