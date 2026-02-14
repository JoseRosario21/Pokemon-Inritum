#===============================================================================
# Field Effect Move Info UI - Fight Menu Button Type Hooks
# Aliases display_type so fight menu buttons show field-changed types.
# Aliases refreshButtonNames to draw boost/nerf arrows on move buttons.
#===============================================================================
class Battle::Move
  alias_method :display_type_without_field, :display_type

  def display_type(battler)
    ret = display_type_without_field(battler)
    return ret unless @battle&.has_field?
    # Check field type_change effects
    field_ret = @battle.apply_field_effect(:base_type_change, self)
    if field_ret && field_ret.is_a?(Symbol) && field_ret != ret
      ret = field_ret
    end
    ret
  end
end

#===============================================================================
# Fight Menu - Draw boost/nerf arrows on move buttons
#===============================================================================
class Battle::Scene::FightMenu < Battle::Scene::MenuBase
  alias_method :refreshButtonNames_without_field, :refreshButtonNames

  def refreshButtonNames
    # Call original (draws move name text on @overlay)
    refreshButtonNames_without_field
    return if !USE_GRAPHICS
    return if !@battler
    battle = @battler.battle
    return unless battle.has_field?
    field = battle.current_field
    return unless field.respond_to?(:field_data) && field.field_data
    data = field.field_data
    moves = @battler.moves
    arrow_path = Settings::BATTLE_UI_GRAPHICS_PATH
    boost_icon = arrow_path + "Move Flags/FieldBoost"
    nerf_icon = arrow_path + "Move Flags/FieldNerf"
    has_boost = pbResolveBitmap(boost_icon)
    has_nerf = pbResolveBitmap(nerf_icon)
    return unless has_boost || has_nerf
    damage_keys = [:power, :power_multiplier, :final_damage, :final_damage_multiplier,
                   :attack, :attack_multiplier, :defense, :defense_multiplier]
    imagePos = []
    @buttons.each_with_index do |button, i|
      next if !@visibility["button_#{i}"]
      next if !moves[i]
      move = moves[i]
      next unless move.damagingMove?
      type = move.pbCalcType(@battler)
      # Calculate field power multiplier for this move
      mult = 1.0
      data.type_multipliers.each do |m|
        next unless m[:type] == type
        next unless damage_keys.include?(m[:key])
        if m[:condition]
          next unless Battle::FieldConditions.met?(battle, @battler, m[:condition])
        end
        # Defense multiplier is inverted (lower defense = more damage)
        if [:defense, :defense_multiplier].include?(m[:key])
          mult *= (1.0 / m[:value])
        else
          mult *= m[:value]
        end
      end
      data.move_multipliers.each do |m|
        next unless m[:move] == move.id
        next unless damage_keys.include?(m[:key])
        if m[:condition]
          next unless Battle::FieldConditions.met?(battle, @battler, m[:condition])
        end
        if [:defense, :defense_multiplier].include?(m[:key])
          mult *= (1.0 / m[:value])
        else
          mult *= m[:value]
        end
      end
      # Draw arrow in bottom-right corner of the button
      if mult > 1.0 && has_boost
        bx = button.x - self.x + button.src_rect.width - 22
        by = button.y - self.y + button.src_rect.height - 26
        imagePos.push([boost_icon, bx, by])
      elsif mult < 1.0 && has_nerf
        bx = button.x - self.x + button.src_rect.width - 22
        by = button.y - self.y + button.src_rect.height - 26
        imagePos.push([nerf_icon, bx, by])
      end
    end
    pbDrawImagePositions(@overlay.bitmap, imagePos) if !imagePos.empty?
  end
end
