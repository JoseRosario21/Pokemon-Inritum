#===============================================================================
# Field Effect Move Info UI - Helper Methods
# Data-gathering helpers for field effect indicators in the Enhanced Battle UI
#===============================================================================
class Battle::Scene
  # All multiplier keys that affect damage output
  FIELD_DAMAGE_KEYS = [:power, :power_multiplier, :final_damage, :final_damage_multiplier,
                       :attack, :attack_multiplier, :defense, :defense_multiplier]

  #-----------------------------------------------------------------------------
  # Returns combined field power multiplier for a move.
  # Returns a float > 1.0 if boosted, < 1.0 if nerfed, or 1.0 if neutral.
  #-----------------------------------------------------------------------------
  def pbGetFieldPowerMultiplier(battler, move, type)
    return 1.0 unless @battle.has_field?
    field = @battle.current_field
    return 1.0 unless field.respond_to?(:field_data) && field.field_data
    data = field.field_data
    combined = 1.0
    # Check type multipliers
    data.type_multipliers.each do |mult|
      next unless mult[:type] == type
      next unless FIELD_DAMAGE_KEYS.include?(mult[:key])
      if mult[:condition]
        next unless Battle::FieldConditions.met?(@battle, battler, mult[:condition])
      end
      if [:defense, :defense_multiplier].include?(mult[:key])
        combined *= (1.0 / mult[:value])
      else
        combined *= mult[:value]
      end
    end
    # Check move multipliers
    data.move_multipliers.each do |mult|
      next unless mult[:move] == move.id
      next unless FIELD_DAMAGE_KEYS.include?(mult[:key])
      if mult[:condition]
        next unless Battle::FieldConditions.met?(@battle, battler, mult[:condition])
      end
      if [:defense, :defense_multiplier].include?(mult[:key])
        combined *= (1.0 / mult[:value])
      else
        combined *= mult[:value]
      end
    end
    combined
  end

  #-----------------------------------------------------------------------------
  # Returns array of field effect icon filenames for a move.
  # Each entry is a filename (without path) of a 24x24 icon to display.
  #-----------------------------------------------------------------------------
  def pbGetFieldEffectIndicators(battler, move, type)
    return [] unless @battle.has_field?
    field = @battle.current_field
    icons = []
    # Check data-driven field effects
    if field.respond_to?(:field_data) && field.field_data
      data = field.field_data
      data.effects.each do |effect|
        case effect[:name]
        when :no_charge
          moves = effect[:args].map { |m| m.to_sym }
          icons << "FieldNoCharge" if moves.include?(move.id)
        when :target_all
          moves = effect[:args].map { |m| m.to_sym }
          icons << "FieldTargetAll" if moves.include?(move.id)
        when :accuracy_set
          move_id = effect[:args][0]&.to_sym
          icons << "FieldAccuracy" if move_id == move.id
        when :always_hit
          moves = effect[:args].map { |m| m.to_sym }
          icons << "FieldAccuracy" if moves.include?(move.id)
        when :add_status, :add_burn, :add_paralysis, :add_poison, :add_freeze, :add_sleep
          move_id = effect[:args][0]&.to_sym
          icons << "FieldStatus" if move_id == move.id
        when :crit_boost
          moves = effect[:args].map { |m| m.to_sym }
          icons << "FieldCrit" if moves.include?(move.id)
        when :crit_type_boost
          boost_type = effect[:args][0]&.to_sym
          icons << "FieldCrit" if move.type == boost_type || type == boost_type
        when :always_crit
          moves = effect[:args].map { |m| m.to_sym }
          icons << "FieldCrit" if moves.include?(move.id)
        when :effect_chance_boost
          moves = effect[:args].map { |m| m.to_sym }
          icons << "FieldEffChance" if moves.include?(move.id)
        when :heal_boost
          moves = effect[:args].map { |m| m.to_sym }
          icons << "FieldHealBoost" if moves.include?(move.id)
        end
      end
    end
    # Check runtime effects on class-based fields
    if !field.respond_to?(:field_data) || !field.field_data
      effects = field.effects
      if effects[:no_charging].is_a?(Array)
        effects[:no_charging].each do |p|
          result = p.call(battler, move) rescue nil
          icons << "FieldNoCharge" if result
        end
      end
      if effects[:target_expand].is_a?(Array)
        effects[:target_expand].each do |p|
          result = p.call(battler, move, nil) rescue nil
          icons << "FieldTargetAll" if result
        end
      end
    end
    icons.uniq
  end

  #-----------------------------------------------------------------------------
  # Returns the added type symbol from type_add, or nil.
  #-----------------------------------------------------------------------------
  def pbGetFieldAddedType(move)
    return nil unless @battle.has_field?
    result = @battle.apply_field_effect(:base_type_add, move)
    return result if result && result.is_a?(Symbol)
    nil
  end
end
