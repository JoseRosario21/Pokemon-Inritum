#===============================================================================
# Field Effect Move Info UI - UI Rendering Hooks
# Aliases pbGetFinalModifiers and pbUpdateMoveInfoWindow to integrate
# field effect data into the Enhanced Battle UI's move info panel.
#===============================================================================
class Battle::Scene
  #-----------------------------------------------------------------------------
  # Alias pbGetFinalModifiers to apply field multipliers and set bonus text.
  #-----------------------------------------------------------------------------
  alias_method :pbGetFinalModifiers_without_field, :pbGetFinalModifiers

  def pbGetFinalModifiers(battler, move, type, baseDmg, power, acc, pri, chance, showTera)
    # Store field info for use in pbUpdateMoveInfoWindow
    @field_move_info = nil
    # Call original
    bonus, power, acc, pri, chance = pbGetFinalModifiers_without_field(
      battler, move, type, baseDmg, power, acc, pri, chance, showTera)
    # Apply field effect modifiers
    return bonus, power, acc, pri, chance unless @battle.has_field?
    field = @battle.current_field
    field_name = field.name
    field_power_mult = pbGetFieldPowerMultiplier(battler, move, type)
    # Track what changed for icon drawing
    info = { power_mult: field_power_mult, type_changed: false, acc_changed: false }
    # Power multiplier from field
    if power > 0 && field_power_mult != 1.0
      power *= field_power_mult
      if bonus.nil?
        if field_power_mult > 1.0
          bonus = [_INTL("Power boosted by the {1}.", field_name), BASE_RAISED, SHADOW_RAISED]
        else
          bonus = [_INTL("Power weakened by the {1}.", field_name), BASE_LOWERED, SHADOW_LOWERED]
        end
      end
    end
    # Check for type change (if move type differs from base)
    if type != move.type
      type_changed_by_field = false
      if field.respond_to?(:field_data) && field.field_data
        field.field_data.effects.each do |effect|
          case effect[:name]
          when :type_change
            type_changed_by_field = true if effect[:args][0]&.to_sym == move.id
          when :type_convert
            type_changed_by_field = true if effect[:args][0]&.to_sym == move.type
          end
        end
      end
      if type_changed_by_field
        info[:type_changed] = true
        if bonus.nil?
          bonus = [_INTL("Type changed by the {1}.", field_name), BASE_RAISED, SHADOW_RAISED]
        end
      end
    end
    # Check for accuracy modifications
    if acc > 0 && field.respond_to?(:field_data) && field.field_data
      field.field_data.effects.each do |effect|
        case effect[:name]
        when :accuracy_set
          if effect[:args][0]&.to_sym == move.id
            new_acc = effect[:args][1]&.to_i || 100
            if new_acc != acc
              acc = new_acc
              info[:acc_changed] = true
              if bonus.nil?
                bonus = [_INTL("Accuracy modified by the {1}.", field_name), BASE_RAISED, SHADOW_RAISED]
              end
            end
          end
        when :always_hit
          moves = effect[:args].map { |m| m.to_sym }
          if moves.include?(move.id)
            acc = 0  # "---" means it always hits
            info[:acc_changed] = true
            if bonus.nil?
              bonus = [_INTL("Always hits on the {1}.", field_name), BASE_RAISED, SHADOW_RAISED]
            end
          end
        end
      end
    end
    # Check for effect chance boost
    if chance > 0 && chance < 100 && field.respond_to?(:field_data) && field.field_data
      field.field_data.effects.each do |effect|
        next unless effect[:name] == :effect_chance_boost
        moves = effect[:args].map { |m| m.to_sym }
        if moves.include?(move.id)
          chance = [chance * 2, 100].min
          if bonus.nil?
            bonus = [_INTL("Effect chance boosted by the {1}.", field_name), BASE_RAISED, SHADOW_RAISED]
          end
          break
        end
      end
    end
    @field_move_info = info
    return bonus, power, acc, pri, chance
  end

  #-----------------------------------------------------------------------------
  # Alias pbUpdateMoveInfoWindow to draw field effect icons and indicators.
  #-----------------------------------------------------------------------------
  alias_method :pbUpdateMoveInfoWindow_without_field, :pbUpdateMoveInfoWindow

  def pbUpdateMoveInfoWindow(battler, specialAction, cw)
    # Call original (which calls pbGetFinalModifiers internally)
    pbUpdateMoveInfoWindow_without_field(battler, specialAction, cw)
    return if @enhancedUIToggle != :move
    return unless @battle.has_field?
    xpos = 0
    ypos = 78
    move = battler.moves[cw.index].clone
    if specialAction == :zmove && cw.mode == 2
      move = move.convert_zmove(battler, @battle, cw.index, false)
    elsif battler.dynamax? || specialAction == :dynamax && cw.mode == 2
      move = move.convert_dynamax_move(battler, @battle, cw.index)
    end
    type = move.pbCalcType(battler)
    #---------------------------------------------------------------------------
    # Draw field effect indicator icons in the flag row
    indicators = pbGetFieldEffectIndicators(battler, move, type)
    if !indicators.empty?
      # Count existing flag icons to offset after them
      existing_flags = 0
      flags = move.flags.clone
      if GameData::Target.get(move.target).targets_foe
        flags.push("NoProtect")      if !flags.include?("CanProtect")
        flags.push("NoMirrorMove")   if !flags.include?("CanMirrorMove")
      end
      flags.uniq!
      flags.each do |flag|
        flag = "ZMove"               if flag.include?("ZMove_")
        flag = "DynamaxMove"         if flag.include?("DynamaxMove_") || flag == "GmaxMove"
        flag = "HighCriticalHitRate" if flag.include?("HighCriticalHitRate_")
        path = @path + "Move Flags/" + flag
        existing_flags += 1 if pbResolveBitmap(path)
      end
      imagePos = []
      indicators.each_with_index do |icon_name, idx|
        break if (existing_flags + idx) >= 8
        icon_path = @path + "Move Flags/" + icon_name
        next unless pbResolveBitmap(icon_path)
        ix = xpos + 6 + ((existing_flags + idx) * 26)
        iy = ypos + 35
        imagePos.push([icon_path, ix, iy])
      end
      pbDrawImagePositions(@enhancedUIOverlay, imagePos) if !imagePos.empty?
    end
    #---------------------------------------------------------------------------
    # Draw secondary type for type_add
    added_type = pbGetFieldAddedType(move)
    if added_type && move.damagingMove?
      # Clear original type/category area and redraw with dual type
      # Main type icon shifted left
      typenumber = GameData::Type.get(type).icon_position
      added_typenumber = GameData::Type.get(added_type).icon_position
      category = move.category
      # Handle special category cases
      case move.function_code
      when "CategoryDependsOnHigherDamageTera",
           "TerapagosCategoryDependsOnHigherDamage"
        terastal = battler.tera? || (specialAction == :tera && cw.teraType > 0)
        if terastal
          realAtk, realSpAtk = battler.getOffensiveStats
          category = (realAtk > realSpAtk) ? 0 : 1
        end
      when "CategoryDependsOnHigherDamagePoisonTarget",
           "CategoryDependsOnHigherDamageIgnoreTargetAbility"
        move.pbOnStartUse(battler, [battler.pbDirectOpposing])
        category = move.calcCategory
      end
      imagePos = [
        # Main type shifted left
        ["Graphics/UI/types",    xpos + 240, ypos + 8, 0, typenumber * 28, 64, 28],
        # Added type
        ["Graphics/UI/types",    xpos + 316, ypos + 8, 0, added_typenumber * 28, 64, 28],
        # Category shifted right
        ["Graphics/UI/category", xpos + 384, ypos + 8, 0, category * 28, 64, 28]
      ]
      pbDrawImagePositions(@enhancedUIOverlay, imagePos)
      # Draw "+" text between types
      textPos = [
        ["+", xpos + 308, ypos + 12, :center, BASE_LIGHT, SHADOW_LIGHT]
      ]
      pbDrawTextPositions(@enhancedUIOverlay, textPos)
    end
  end
end
