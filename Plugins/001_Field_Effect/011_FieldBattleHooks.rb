#===============================================================================
# Battle Hooks for Field Transformation System
# Integrates field transformations with the battle move execution flow
#===============================================================================

#===============================================================================
# Hook into pbEffectsAfterMove to check for field transformations and status
#===============================================================================
class Battle::Battler
  alias_method :pbEffectsAfterMove_field_transform, :pbEffectsAfterMove

  def pbEffectsAfterMove(user, targets, move, numHits)
    # Call original method first
    pbEffectsAfterMove_field_transform(user, targets, move, numHits)

    # Check for field transformations after the move completes
    Battle::FieldTransformations.check_after_move(@battle, user, move, targets)

    # Apply field-based status effects to targets that were hit
    apply_field_status_to_targets(user, targets, move, numHits)
  end

  #-----------------------------------------------------------------------------
  # Apply field-based status effects to all targets hit by the move
  #-----------------------------------------------------------------------------
  def apply_field_status_to_targets(user, targets, move, numHits)
    return unless @battle.has_field?
    return if numHits == 0  # Move didn't hit anything

    # Get field status info for this move
    status_info = @battle.field_status_for_move(move)
    return unless status_info

    # Check chance
    return unless rand(100) < status_info[:chance]

    # Apply to each target that was actually hit
    targets.each do |target|
      next if target.fainted?
      next unless target.damageState.calcDamage > 0  # Only if damage was dealt

      case status_info[:status]
      when :BURN
        next unless target.pbCanBurn?(user, false, move)
        target.pbBurn(user)
        @battle.pbDisplay(_INTL("The {1} caused {2} to be burned!", @battle.field_name, target.pbThis(true)))
      when :PARALYSIS
        next unless target.pbCanParalyze?(user, false, move)
        target.pbParalyze(user)
        @battle.pbDisplay(_INTL("The {1} caused {2} to be paralyzed!", @battle.field_name, target.pbThis(true)))
      when :POISON
        next unless target.pbCanPoison?(user, false, move)
        target.pbPoison(user)
        @battle.pbDisplay(_INTL("The {1} caused {2} to be poisoned!", @battle.field_name, target.pbThis(true)))
      when :TOXIC
        next unless target.pbCanPoison?(user, false, move)
        target.pbPoison(user, nil, true)
        @battle.pbDisplay(_INTL("The {1} caused {2} to be badly poisoned!", @battle.field_name, target.pbThis(true)))
      when :FREEZE
        next unless target.pbCanFreeze?(user, false, move)
        target.pbFreeze(user)
        @battle.pbDisplay(_INTL("The {1} caused {2} to be frozen!", @battle.field_name, target.pbThis(true)))
      when :SLEEP
        next unless target.pbCanSleep?(user, false, move)
        target.pbSleep(user)
        @battle.pbDisplay(_INTL("The {1} caused {2} to fall asleep!", @battle.field_name, target.pbThis(true)))
      when :CONFUSION
        next if target.effects[PBEffects::Confusion] > 0
        target.pbConfuse
        @battle.pbDisplay(_INTL("The {1} caused {2} to become confused!", @battle.field_name, target.pbThis(true)))
      when :FLINCH
        target.effects[PBEffects::Flinch] = true
      end
    end
  end
end

#===============================================================================
# Initialize field counters and combo history at battle start
#===============================================================================
class Battle
  alias_method :initialize_field_counters_original, :initialize

  def initialize(*args)
    initialize_field_counters_original(*args)
    # Initialize field transformation tracking
    @field_counters = {}
    @field_combo_history = []
  end
end

#===============================================================================
# Hook into battle initialization to set up field stack
#===============================================================================
class Battle
  alias_method :pbStartBattle_field_init, :pbStartBattle if method_defined?(:pbStartBattle)

  def pbStartBattle
    # Ensure counters and combo history are initialized
    @field_counters ||= {}
    @field_combo_history ||= []

    # Ensure stacked_fields is initialized
    @stacked_fields ||= []

    # Call original if it exists
    if respond_to?(:pbStartBattle_field_init, true)
      pbStartBattle_field_init
    end
  end
end

#===============================================================================
# Additional valid effect keys
#===============================================================================
class Battle::Field
  # Add :end_of_move as a valid effect key
  BASE_KEYS_EXTENDED = BASE_KEYS + [:end_of_move]
end

#===============================================================================
# Add helper method to Battle for applying end-of-move field effects
#===============================================================================
class Battle
  def apply_field_end_of_move(user, move, targets)
    apply_field_effect(:end_of_move, user, move, targets)
    apply_field_effect(:end_of_move_universal, user, move, targets)
  end
end

#===============================================================================
# NOTE: Field-specific move power modifications are handled by:
# 1. Field.rb's @effects[:calc_damage] proc (for data-driven fields via @multipliers)
# 2. DBK's pbCalcDamageMultipliers which calls apply_field_effect(:calc_damage)
#
# No additional hook needed here - Field.rb already handles multipliers AND messages
#===============================================================================

#===============================================================================
# Hook for field-specific status immunity
# This enhances the existing status immunity check with PBS data
#===============================================================================
class Battle::Battler
  alias_method :pbCanInflictStatus_field_enhanced, :pbCanInflictStatus?

  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    # Check PBS-defined status immunities first
    field_data = GameData::FieldEffect.try_get(@battle.field_id)
    if field_data && !field_data.status_immunities.empty?
      field_data.status_immunities.each do |imm|
        # Check if this status matches
        status_matches = case imm[:status]
                         when :SLEEP
                           newStatus == :SLEEP
                         when :ALL, :ANY
                           true
                         else
                           newStatus == imm[:status]
                         end
        next unless status_matches

        # Check condition
        if imm[:condition].nil? || Battle::FieldConditions.met?(@battle, self, imm[:condition])
          if showMessages
            @battle.pbDisplay(_INTL("{1} is protected by the {2}!",
                                    pbThis, @battle.field_name))
          end
          return false
        end
      end
    end

    # Call original method
    pbCanInflictStatus_field_enhanced(newStatus, user, showMessages, move, ignoreStatus)
  end
end
