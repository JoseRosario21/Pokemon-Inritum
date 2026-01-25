#===============================================================================
# Advanced Battle AI - Double Battle Coordination
# Partner synergy, threat assessment, and coordinated targeting
#===============================================================================

#===============================================================================
# Partner Synergy Detection
# Detects beneficial ability interactions for doubles
#===============================================================================
module AdvancedBattleAI
  # Abilities that benefit from being hit by specific types
  ABSORPTION_ABILITIES = {
    :FLASHFIRE      => :FIRE,
    :VOLTABSORB     => :ELECTRIC,
    :LIGHTNINGROD   => :ELECTRIC,
    :MOTORDRIVE     => :ELECTRIC,
    :WATERABSORB    => :WATER,
    :STORMDRAIN     => :WATER,
    :DRYSKIN        => :WATER,
    :SAPSIPPER      => :GRASS,
    :EARTHEATER     => :GROUND
  }

  # Abilities that are immune to specific types
  IMMUNITY_ABILITIES = {
    :LEVITATE       => :GROUND,
    :FLASHFIRE      => :FIRE,
    :HEATPROOF      => :FIRE,  # Partial
    :WATERABSORB    => :WATER,
    :DRYSKIN        => :WATER,
    :VOLTABSORB     => :ELECTRIC,
    :MOTORDRIVE     => :ELECTRIC,
    :LIGHTNINGROD   => :ELECTRIC,
    :SAPSIPPER      => :GRASS,
    :SOUNDPROOF     => :SOUND,  # Sound-based moves
    :BULLETPROOF    => :BULLET  # Ball/bomb moves
  }

  # Check if partner benefits from being hit by a move type
  def self.partner_benefits_from_type?(partner, move_type)
    return false unless partner && partner.ability
    ability = partner.ability_id
    return ABSORPTION_ABILITIES[ability] == move_type
  end

  # Check if partner is immune to a move type via ability
  def self.partner_immune_to_type?(partner, move_type)
    return false unless partner && partner.ability
    ability = partner.ability_id
    return IMMUNITY_ABILITIES[ability] == move_type
  end
end

#===============================================================================
# Partner Synergy Move Scoring
# Boost moves that benefit partner through ability
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_partner_synergy,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:team_synergy, ai.trainer)

    # Get partner
    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    move_type = move.type

    # Check if targeting partner for beneficial effect
    if target.index == partner_idx
      if AdvancedBattleAI.partner_benefits_from_type?(partner, move_type)
        score += AdvancedBattleAI::PARTNER_SYNERGY_BONUS
        AdvancedBattleAI.log("Partner synergy: #{partner.ability_id} + #{move_type}", :scoring)
      end
    end

    # Check for spread moves hitting partner
    if move.move.target == :AllNonUsers || move.move.target == :AllBattlers
      if AdvancedBattleAI.partner_immune_to_type?(partner, move_type) ||
         AdvancedBattleAI.partner_benefits_from_type?(partner, move_type)
        score += 15  # Safe to use spread move
        AdvancedBattleAI.log("Spread move safe: partner immune/benefits", :scoring)
      elsif !partner.pbHasType?(move_type) && move.damagingMove?
        # Partner will take damage
        type_mod = Effectiveness.calculate(move_type, *partner.types)
        if Effectiveness.super_effective?(type_mod)
          score -= 30  # Big penalty for super effective on partner
        elsif type_mod > 0
          score -= 10  # Small penalty for hitting partner
        end
      end
    end

    next score
  }
)

#===============================================================================
# Telepathy Awareness
# Don't hesitate to use spread moves if partner has Telepathy
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_telepathy_awareness,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.move.target == :AllNonUsers || move.move.target == :BothFoes

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    if partner.hasActiveAbility?(:TELEPATHY)
      score += 20  # Free to use spread moves
      AdvancedBattleAI.log("Telepathy: free spread move", :scoring)
    end

    next score
  }
)

#===============================================================================
# Threat Assessment in Doubles
# Evaluates combined threat from both opponents
#===============================================================================
class Battle::AI
  # Calculate threat level of a battler
  def calculate_threat_level(battler, perspective_battler)
    return 0 unless battler && !battler.fainted?

    threat = 0

    # Base threat from stats
    offensive = [battler.attack, battler.spatk].max
    speed = battler.speed

    # Speed advantage
    if speed > perspective_battler.speed
      threat += 15
    end

    # Check for super-effective coverage
    battler.moves.each do |move|
      next unless move && move.damagingMove?
      type_mod = Effectiveness.calculate(move.type, *perspective_battler.types)
      if Effectiveness.super_effective?(type_mod)
        threat += 20 + (move.power / 5)
      end
    end

    # Boost threat based on known dangerous moves
    if @memory
      known = @memory.get_known_moves(battler.index)
      known.each do |move_id|
        move_data = GameData::Move.try_get(move_id)
        next unless move_data

        # High power moves are scary
        if move_data.power >= 100
          threat += 10
        end

        # Priority moves are scarier
        if move_data.priority > 0 && move_data.power > 0
          threat += 15
        end

        # Setup moves mean they could become a bigger threat
        if move_data.function_code.match?(/RaiseUser/)
          threat += 10
        end
      end
    end

    # Current HP affects threat (low HP = less threat)
    threat = (threat * battler.hp.to_f / battler.totalhp).to_i

    return threat
  end

  # Get the more threatening opponent
  def get_primary_threat(user)
    return nil unless @battle.doubleBattle?

    threats = []
    @battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = @battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      threat_level = calculate_threat_level(opp, user.battler)
      threats.push({ index: opp_idx, threat: threat_level })
    end

    threats.sort_by! { |t| -t[:threat] }
    return threats.first
  end
end

#===============================================================================
# Coordinated Targeting Handler
# Prefer focusing down the higher threat
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:advanced_threat_targeting,
  proc { |score, move, user, target, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)
    next score unless move.damagingMove?

    primary_threat = ai.get_primary_threat(user)
    next score unless primary_threat

    if target.index == primary_threat[:index]
      score += 10  # Prefer targeting primary threat
      AdvancedBattleAI.log("Targeting primary threat", :scoring)
    end

    next score
  }
)

#===============================================================================
# Protect Coordination in Doubles
# Coordinate protect with partner's actions
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_doubles_protect,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?

    protect_functions = [
      "ProtectUser", "ProtectUserFromTargetingMovesSpikyShield",
      "ProtectUserBanefulBunker", "ProtectUserFromDamagingMovesKingsShield"
    ]
    next score unless protect_functions.include?(move.function_code)

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Bonus if partner is likely using a spread move
    partner.moves.each do |m|
      next unless m
      if m.target == :AllNonUsers && m.damagingMove?
        score += 15
        AdvancedBattleAI.log("Protect while partner uses spread", :scoring)
        break
      end
    end

    # Check if opponent has Dynamax (protect is valuable)
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?
      is_dynamaxed = (opp.dynamax? rescue false)
      if is_dynamaxed
        score += 20
        AdvancedBattleAI.log("Protect vs Dynamax", :scoring)
        break
      end
    end

    next score
  }
)

#===============================================================================
# Follow Me / Rage Powder Coordination
# Use redirection to protect partner
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_redirection,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless AdvancedBattleAI.feature_enabled?(:doubles, ai.trainer)

    redirect_functions = ["RedirectAllMovesToUser", "RedirectAllMovesToUserSleepTarget"]
    next score unless redirect_functions.include?(move.function_code)

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Value based on protecting partner
    partner_ai = ai.battlers[partner_idx]
    if partner_ai
      # Protect sweepers trying to set up
      if partner_ai.has_role?(Battle::AI::Roles::SETUP_SWEEPER) ||
         partner_ai.has_role?(Battle::AI::Roles::SWEEPER)
        score += 25
        AdvancedBattleAI.log("Redirect to protect sweeper", :scoring)
      end

      # Protect boosted partners
      if count_positive_stat_stages(partner_ai) >= 2
        score += 20
        AdvancedBattleAI.log("Redirect to protect boosted partner", :scoring)
      end

      # Protect low HP partner
      if partner.hp < partner.totalhp * 0.3
        score += 15
      end
    end

    # Penalty if user is low HP (might faint from redirected attacks)
    if user.hp < user.totalhp * 0.25
      score -= 20
    end

    next score
  }
)

#===============================================================================
# Helping Hand Coordination
# Use Helping Hand when partner is attacking
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_helping_hand,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "PowerUpAllyMove"

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Check if partner has strong attacks
    best_power = 0
    partner.moves.each do |m|
      next unless m && m.damagingMove?
      best_power = [best_power, m.power].max
    end

    if best_power >= 80
      score += 25
      AdvancedBattleAI.log("Helping Hand for strong attacker", :scoring)
    elsif best_power >= 60
      score += 15
    else
      score -= 10  # Partner doesn't have good attacks
    end

    # Bonus if partner is boosted
    partner_ai = ai.battlers[partner_idx]
    if partner_ai && count_positive_stat_stages(partner_ai) >= 2
      score += 15
    end

    next score
  }
)

#===============================================================================
# Mat Block / Wide Guard Coordination
# Use team protection moves appropriately
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_wide_guard,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "ProtectUserSideFromMultiTargetDamagingMoves"

    # Check if opponents have spread moves
    has_spread_threat = false
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      opp.moves.each do |m|
        next unless m && m.damagingMove?
        if m.target == :AllNonUsers || m.target == :AllFoes || m.target == :AllBattlers
          has_spread_threat = true
          score += 15
          AdvancedBattleAI.log("Wide Guard vs spread move threat", :scoring)
          break
        end
      end
      break if has_spread_threat
    end

    # Check memory for known spread moves
    if ai.memory && !has_spread_threat
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        known_moves = ai.memory.get_known_moves(opp_idx)
        known_moves.each do |move_id|
          move_data = GameData::Move.try_get(move_id)
          next unless move_data && move_data.power > 0
          if [:AllNonUsers, :AllFoes, :AllBattlers].include?(move_data.target)
            score += 25
            has_spread_threat = true
            AdvancedBattleAI.log("Wide Guard vs known spread: #{move_id}", :scoring)
            break
          end
        end
        break if has_spread_threat
      end
    end

    # Penalty if no spread threat
    score -= 30 unless has_spread_threat

    next score
  }
)

#===============================================================================
# Quick Guard Coordination
# Protect team from priority moves
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_quick_guard,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "ProtectUserSideFromPriorityMoves"

    # Check if opponents have priority moves
    has_priority_threat = false
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      opp.moves.each do |m|
        next unless m && m.damagingMove?
        if m.priority > 0
          has_priority_threat = true
          score += 10 + m.power / 5
          AdvancedBattleAI.log("Quick Guard vs priority threat", :scoring)
          break
        end
      end
      break if has_priority_threat
    end

    # Check memory for known priority
    if ai.memory && !has_priority_threat
      battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
        if ai.memory.has_shown_priority?(opp_idx)
          score += 20
          has_priority_threat = true
          break
        end
      end
    end

    # Penalty if no priority threat
    score -= 30 unless has_priority_threat

    next score
  }
)

#===============================================================================
# Ally Switch Coordination
# Strategic position swapping
#===============================================================================
Battle::AI::Handlers::GeneralMoveScore.add(:advanced_ally_switch,
  proc { |score, move, user, ai, battle|
    next score unless battle.doubleBattle?
    next score unless move.function_code == "UserSwapsPositionsWithAlly"

    partner_idx = user.index.even? ? user.index + 1 : user.index - 1
    partner = battle.battlers[partner_idx]
    next score unless partner && !partner.fainted?

    # Check if switching positions would help
    # (e.g., redirect attacks to bulkier mon)

    # If partner is about to be hit by super-effective and user resists
    battle.pbGetOpposingIndicesInOrder(user.index).each do |opp_idx|
      opp = battle.battlers[opp_idx]
      next unless opp && !opp.fainted?

      opp.moves.each do |m|
        next unless m && m.damagingMove?

        partner_mod = Effectiveness.calculate(m.type, *partner.types)
        user_mod = Effectiveness.calculate(m.type, *user.types)

        # Ally Switch valuable if user resists what threatens partner
        if Effectiveness.super_effective?(partner_mod) && !Effectiveness.super_effective?(user_mod)
          score += 20
          AdvancedBattleAI.log("Ally Switch: take super-effective for partner", :scoring)
          break
        end
      end
    end

    # Also useful for disruption/mindgames at high skill
    if ai.trainer.best_skill?
      score += 5
    end

    next score
  }
)
