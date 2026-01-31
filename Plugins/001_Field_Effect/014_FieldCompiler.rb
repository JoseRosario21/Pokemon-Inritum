#===============================================================================
# Field Effects PBS Compiler
# Compiles PBS/field_effects.txt into Data/field_effects.dat
#===============================================================================
module Compiler
  module_function

  #-----------------------------------------------------------------------------
  # Compile field effects from PBS file
  #-----------------------------------------------------------------------------
  def compile_field_effects(*paths)
    return if paths.none? { |p| FileTest.exist?(p) }
    compile_PBS_file_generic(GameData::FieldEffect, *paths) do |final_validate, hash|
      if final_validate
        validate_all_compiled_field_effects
      else
        validate_compiled_field_effect(hash)
      end
    end
  end

  def validate_compiled_field_effect(hash)
    # Validate nature power move exists
    if hash[:nature_power] && !GameData::Move.exists?(hash[:nature_power])
      raise _INTL("Unknown move '{1}' for NaturePower.", hash[:nature_power]) + "\n" + FileLineData.linereport
    end

    # Validate type multipliers reference valid types
    if hash[:type_multipliers]
      hash[:type_multipliers].each do |entry|
        next unless entry.is_a?(Array) && entry.length >= 3
        type_sym = entry[0].to_s.upcase.to_sym
        if !GameData::Type.exists?(type_sym)
          raise _INTL("Unknown type '{1}' in TypeMultiplier.", entry[0]) + "\n" + FileLineData.linereport
        end
      end
    end

    # Validate move multipliers reference valid moves
    if hash[:move_multipliers]
      hash[:move_multipliers].each do |entry|
        next unless entry.is_a?(Array) && entry.length >= 3
        move_sym = entry[0].to_s.upcase.to_sym
        if !GameData::Move.exists?(move_sym)
          raise _INTL("Unknown move '{1}' in MoveMultiplier.", entry[0]) + "\n" + FileLineData.linereport
        end
      end
    end

    # Validate transformation trigger moves exist
    if hash[:transformations]
      hash[:transformations].each do |entry|
        next unless entry.is_a?(Array) && entry.length >= 2
        move_sym = entry[0].to_s.upcase.to_sym
        if !GameData::Move.exists?(move_sym)
          raise _INTL("Unknown move '{1}' in TransformOn.", entry[0]) + "\n" + FileLineData.linereport
        end
      end
    end

    # Validate destroy trigger moves exist
    if hash[:destroy_triggers]
      hash[:destroy_triggers].each do |entry|
        next unless entry.is_a?(Array) && !entry.empty?
        move_sym = entry[0].to_s.upcase.to_sym
        if !GameData::Move.exists?(move_sym)
          raise _INTL("Unknown move '{1}' in DestroyOn.", entry[0]) + "\n" + FileLineData.linereport
        end
      end
    end

    # Validate combo moves exist
    if hash[:combos]
      hash[:combos].each do |entry|
        next unless entry.is_a?(Array) && entry.length >= 2
        moves_str = entry[0].to_s
        moves_str.split("+").each do |move|
          move_sym = move.strip.upcase.to_sym
          if !GameData::Move.exists?(move_sym)
            raise _INTL("Unknown move '{1}' in ComboTrigger.", move) + "\n" + FileLineData.linereport
          end
        end
      end
    end

    # Validate effects reference valid effect names
    if hash[:effects]
      hash[:effects].each do |entry|
        next unless entry.is_a?(Array) && !entry.empty?
        effect_name = entry[0].to_s.downcase.to_sym
        if !Battle::FieldEffectsLibrary.exists?(effect_name)
          raise _INTL("Unknown effect '{1}' in Effect.", entry[0]) + "\n" + FileLineData.linereport
        end
      end
    end
  end

  def validate_all_compiled_field_effects
    # Cross-validate that transformation target fields are defined
    # (They may be defined as Ruby classes, so we can't fully validate here)
  end
end

#===============================================================================
# Hook into the main compilation process
#===============================================================================
module Compiler
  class << self
    alias_method :compile_pbs_files_without_fields, :compile_pbs_files

    def compile_pbs_files
      compile_pbs_files_without_fields
      # Compile field effects after other PBS files (depends on Move, Type)
      field_paths = []
      if FileTest.exist?("PBS/field_effects.txt")
        field_paths << "PBS/field_effects.txt"
      end
      Dir.chdir("PBS/") do
        Dir.glob("field_effects_*.txt") do |f|
          field_paths.push("PBS/" + f)
        end
      end
      compile_field_effects(*field_paths) unless field_paths.empty?
    end
  end
end

#===============================================================================
# PBS Writer for field effects (for debug/export)
#===============================================================================
module Compiler
  module_function

  def write_field_effects
    return unless GameData::FieldEffect::DATA.length > 0
    write_pbs_file_message_start("PBS/field_effects.txt")
    File.open("PBS/field_effects.txt", "wb") do |f|
      f.write("\# " + _INTL("See the documentation on the wiki to learn how to edit this file.") + "\r\n")
      f.write("\#-------------------------------\r\n")
      GameData::FieldEffect.each do |field|
        f.write("\#-------------------------------\r\n")
        f.write("[#{field.id}]\r\n")
        f.write("Name = #{field.real_name}\r\n")
        f.write("Category = #{field.category}\r\n") if field.category && !field.category.empty?
        f.write("Tags = #{field.tags.join(",")}\r\n") if field.tags && !field.tags.empty?
        f.write("Fieldback = #{field.fieldback}\r\n") if field.fieldback && !field.fieldback.empty?
        f.write("NaturePower = #{field.nature_power}\r\n") if field.nature_power
        f.write("SecretPower = #{field.secret_power_effect}\r\n") if field.secret_power_effect > 0
        f.write("Duration = #{field.default_duration}\r\n") if field.default_duration != Battle::Field::DEFAULT_FIELD_DURATION
        if field.announcements && field.announcements.any? { |a| a && !a.empty? }
          f.write("Announcement = #{field.announcements.join("|")}\r\n")
        end
        field.type_multipliers.each do |mult|
          line = "TypeMultiplier = #{mult[:type]},#{mult[:key]},#{mult[:value]}"
          line += ",#{mult[:condition]}" if mult[:condition]
          line += ",#{mult[:message]}" if mult[:message]
          f.write(line + "\r\n")
        end
        field.move_multipliers.each do |mult|
          line = "MoveMultiplier = #{mult[:move]},#{mult[:key]},#{mult[:value]}"
          line += ",#{mult[:condition]}" if mult[:condition]
          line += ",#{mult[:message]}" if mult[:message]
          f.write(line + "\r\n")
        end
        field.status_immunities.each do |imm|
          line = "StatusImmunity = #{imm[:status]}"
          line += ",#{imm[:condition]}" if imm[:condition]
          f.write(line + "\r\n")
        end
        field.transformations.each do |trans|
          line = "TransformOn = #{trans[:trigger_move]},#{trans[:new_field] || "NONE"}"
          line += ",#{trans[:message]}" if trans[:message]
          line += ",#{trans[:condition]}" if trans[:condition]
          f.write(line + "\r\n")
        end
        if field.destroy_triggers && !field.destroy_triggers.empty?
          field.destroy_triggers.each do |destroy|
            line = "DestroyOn = #{destroy[:trigger_move]}"
            line += ",#{destroy[:message]}" if destroy[:message]
            line += ",#{destroy[:condition]}" if destroy[:condition]
            f.write(line + "\r\n")
          end
        end
        field.counters.each do |counter|
          line = "Counter = #{counter[:name]},#{counter[:threshold]},#{counter[:trigger]},#{counter[:result_field] || "NONE"}"
          line += ",#{counter[:message]}" if counter[:message]
          f.write(line + "\r\n")
        end
        field.combos.each do |combo|
          line = "ComboTrigger = #{combo[:moves].join("+")},#{combo[:result_field] || "NONE"}"
          line += ",#{combo[:message]}" if combo[:message]
          f.write(line + "\r\n")
        end
        if field.effects && !field.effects.empty?
          field.effects.each do |effect|
            line = "Effect = #{effect[:name]}"
            line += ",#{effect[:args].join(",")}" if effect[:args] && !effect[:args].empty?
            f.write(line + "\r\n")
          end
        end
        f.write("Flags = #{field.flags.join(",")}\r\n") if field.flags && !field.flags.empty?
      end
    end
    process_pbs_file_message_end
  end
end

#===============================================================================
# Load field effects data on game start
#===============================================================================
module GameData
  class FieldEffect
    def self.load
      filename = "Data/#{self::DATA_FILENAME}"
      if FileTest.exist?(filename)
        const_set(:DATA, load_data(filename))
      else
        const_set(:DATA, {}) unless const_defined?(:DATA)
      end
    end
  end
end
