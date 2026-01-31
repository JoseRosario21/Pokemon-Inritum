#===============================================================================
# GameData::FieldEffect - PBS-based field definitions
# Provides data-driven field properties compiled from PBS/field_effects.txt
#===============================================================================
module GameData
  class FieldEffect
    attr_reader :id
    attr_reader :real_name
    attr_reader :category
    attr_reader :tags
    attr_reader :fieldback
    attr_reader :nature_power
    attr_reader :secret_power_effect
    attr_reader :default_duration
    attr_reader :announcements
    attr_reader :type_multipliers
    attr_reader :move_multipliers
    attr_reader :status_immunities
    attr_reader :transformations
    attr_reader :destroy_triggers
    attr_reader :counters
    attr_reader :combos
    attr_reader :effects
    attr_reader :flags
    attr_reader :pbs_file_suffix

    DATA = {}
    DATA_FILENAME = "field_effects.dat"
    PBS_BASE_FILENAME = "field_effects"
    OPTIONAL = true

    extend ClassMethodsSymbols
    include InstanceMethods

    # PBS Schema for field_effects.txt
    # Format types:
    #   s = string, m = symbol, u = unsigned int, i = signed int, b = boolean
    #   e = enum, *X = array of X, ^X = multiple lines of X
    SCHEMA = {
      "SectionName"     => [:id,                   "m"],
      "Name"            => [:real_name,            "s"],
      "Category"        => [:category,             "s"],
      "Tags"            => [:tags,                 "*s"],
      "Fieldback"       => [:fieldback,            "s"],
      "NaturePower"     => [:nature_power,         "e", :Move],
      "SecretPower"     => [:secret_power_effect,  "u"],
      "Duration"        => [:default_duration,     "i"],
      "Announcement"    => [:announcements,        "*s"],
      "TypeMultiplier"  => [:type_multipliers,     "^*s"],
      "MoveMultiplier"  => [:move_multipliers,     "^*s"],
      "StatusImmunity"  => [:status_immunities,    "^*s"],
      "TransformOn"     => [:transformations,      "^*s"],
      "DestroyOn"       => [:destroy_triggers,     "^*s"],
      "Counter"         => [:counters,             "^*s"],
      "ComboTrigger"    => [:combos,               "^*"],
      "Effect"          => [:effects,              "^*s"],
      "Flags"           => [:flags,                "*s"]
    }

    def initialize(hash)
      @id                   = hash[:id]
      @real_name            = hash[:real_name]            || "Unnamed Field"
      @category             = hash[:category]             || "Custom"
      @tags                 = hash[:tags]                 || []
      @fieldback            = hash[:fieldback]            || ""
      @nature_power         = hash[:nature_power]
      @secret_power_effect  = hash[:secret_power_effect]  || 0
      @default_duration     = hash[:default_duration]     || Battle::Field::DEFAULT_FIELD_DURATION
      @announcements        = parse_announcements(hash[:announcements])
      @type_multipliers     = parse_type_multipliers(hash[:type_multipliers])
      @move_multipliers     = parse_move_multipliers(hash[:move_multipliers])
      @status_immunities    = parse_status_immunities(hash[:status_immunities])
      @transformations      = parse_transformations(hash[:transformations])
      @destroy_triggers     = parse_destroy_triggers(hash[:destroy_triggers])
      @counters             = parse_counters(hash[:counters])
      @combos               = parse_combos(hash[:combos])
      @effects              = parse_effects(hash[:effects])
      @flags                = hash[:flags]                || []
      @pbs_file_suffix      = hash[:pbs_file_suffix]      || ""
    end

    # @return [String] the translated name of this field effect
    def name
      return _INTL(@real_name)
    end

    def has_flag?(flag)
      return @flags.any? { |f| f.downcase == flag.downcase }
    end

    def has_tag?(tag)
      return @tags.any? { |t| t.downcase == tag.downcase }
    end

    # Get announcement by type: :start, :continue, :end
    def get_announcement(type)
      case type
      when :start, 0
        return @announcements[0]
      when :continue, 1
        return @announcements[1] || @announcements[0]
      when :end, 2
        return @announcements[2]
      end
      return nil
    end

    #---------------------------------------------------------------------------
    # Parsing methods for complex PBS properties
    #---------------------------------------------------------------------------
    private

    # Announcements format: "Start message|Continue message|End message"
    # Can also be provided as array: ["Start", "Continue", "End"]
    def parse_announcements(data)
      return ["", "", ""] if data.nil? || data.empty?
      if data.is_a?(Array)
        if data.length == 1 && data[0].include?("|")
          parts = data[0].split("|").map(&:strip)
          return [parts[0] || "", parts[1] || "", parts[2] || ""]
        end
        return [data[0] || "", data[1] || "", data[2] || ""]
      end
      parts = data.split("|").map(&:strip)
      return [parts[0] || "", parts[1] || "", parts[2] || ""]
    end

    # TypeMultiplier formats:
    # "TYPE,value|message" - assumes 'power' key
    # "TYPE,key,value" - explicit key, no message
    # "TYPE,key,value,condition" - with condition (grounded, etc)
    # "TYPE,key,value|message" - with message after pipe
    # "TYPE,key,value,condition|message" - full format
    # Note: Use | for message because PBS compiler limits comma-separated values
    def parse_type_multipliers(data)
      return [] if data.nil? || data.empty?
      result = []
      known_keys = %w[power final_damage attack defense]
      known_conditions = %w[grounded airborne sunny rainy sandstorm hail snow]

      data.each do |entry|
        next if entry.nil? || entry.empty?

        # Join array back to string if needed, then split by | for message
        full_str = entry.is_a?(Array) ? entry.join(",") : entry.to_s
        main_part, message = full_str.split("|", 2).map { |s| s&.strip }

        parts = main_part.split(",").map(&:strip)
        next if parts.length < 2

        type_sym = parts[0].to_sym

        if known_keys.include?(parts[1]&.downcase)
          # Has explicit key: TYPE,key,value[,condition]
          key_sym = parts[1].to_sym
          value = parts[2].to_f
          condition = parts[3] && known_conditions.include?(parts[3].downcase) ? parts[3] : nil
        else
          # No key (assume power): TYPE,value
          key_sym = :power
          value = parts[1].to_f
          condition = nil
        end

        result << { type: type_sym, key: key_sym, value: value, condition: condition, message: message }
      end
      return result
    end

    # MoveMultiplier formats:
    # "MOVE,value|message" - assumes 'power' key, message after pipe
    # "MOVE,key,value" - explicit key, no message
    # "MOVE,key,value|message" - full format with message after pipe
    # Note: Use | for message because PBS compiler limits comma-separated values
    def parse_move_multipliers(data)
      return [] if data.nil? || data.empty?
      result = []
      known_keys = %w[power final_damage attack defense]

      data.each do |entry|
        next if entry.nil? || entry.empty?

        # Join array back to string if needed, then split by | for message
        full_str = entry.is_a?(Array) ? entry.join(",") : entry.to_s
        main_part, message = full_str.split("|", 2).map { |s| s&.strip }

        parts = main_part.split(",").map(&:strip)
        next if parts.length < 2

        move_sym = parts[0].to_sym

        if known_keys.include?(parts[1]&.downcase)
          # Has explicit key: MOVE,key,value
          key_sym = parts[1].to_sym
          value = parts[2].to_f
        else
          # No key (assume power): MOVE,value
          key_sym = :power
          value = parts[1].to_f
        end

        result << { move: move_sym, key: key_sym, value: value, condition: nil, message: message }
      end
      return result
    end

    # StatusImmunity format: "STATUS,condition"
    # Example: "SLEEP,grounded"
    def parse_status_immunities(data)
      return [] if data.nil? || data.empty?
      result = []
      data.each do |entry|
        next if entry.nil? || entry.empty?
        parts = entry.is_a?(Array) ? entry : entry.split(",").map(&:strip)
        next if parts.empty?
        result << {
          status:    parts[0].to_sym,
          condition: parts[1] || nil
        }
      end
      return result
    end

    # TransformOn format: "TRIGGERMOVE,NEWFIELD,message,condition"
    # Example: "SURF,STEAM,The water evaporated into steam!"
    def parse_transformations(data)
      return [] if data.nil? || data.empty?
      result = []
      data.each do |entry|
        next if entry.nil? || entry.empty?
        parts = entry.is_a?(Array) ? entry : entry.split(",").map(&:strip)
        next if parts.length < 2
        result << {
          trigger_move: parts[0].to_sym,
          new_field:    parts[1] == "NONE" ? nil : parts[1].to_sym,
          message:      parts[2] || nil,
          condition:    parts[3] || nil
        }
      end
      return result
    end

    # DestroyOn format: "TRIGGERMOVE,message,condition"
    # Example: "DEFOG,The mist was blown away!"
    # Example: "EARTHQUAKE,The field crumbled!,grounded"
    def parse_destroy_triggers(data)
      return [] if data.nil? || data.empty?
      result = []
      data.each do |entry|
        next if entry.nil? || entry.empty?
        parts = entry.is_a?(Array) ? entry : entry.split(",").map(&:strip)
        next if parts.empty?
        result << {
          trigger_move: parts[0].to_sym,
          message:      parts[1] || nil,
          condition:    parts[2] || nil
        }
      end
      return result
    end

    # Counter format: "counter_name,threshold,trigger_condition,result_field,message"
    # Example: "water_buildup,3,type:WATER,FLOODED,The field became flooded!"
    def parse_counters(data)
      return [] if data.nil? || data.empty?
      result = []
      data.each do |entry|
        next if entry.nil? || entry.empty?
        parts = entry.is_a?(Array) ? entry : entry.split(",").map(&:strip)
        next if parts.length < 4
        result << {
          name:         parts[0].to_sym,
          threshold:    parts[1].to_i,
          trigger:      parts[2],
          result_field: parts[3] == "NONE" ? nil : parts[3].to_sym,
          message:      parts[4] || nil
        }
      end
      return result
    end

    # ComboTrigger format: "MOVE1+MOVE2+...,RESULTFIELD,message"
    # Example: "FIREPLEDGE+WATERPLEDGE,RAINBOW,The pledges created a rainbow!"
    def parse_combos(data)
      return [] if data.nil? || data.empty?
      result = []
      data.each do |entry|
        next if entry.nil? || entry.empty?
        parts = entry.is_a?(Array) ? entry : entry.split(",").map(&:strip)
        next if parts.length < 2
        moves = parts[0].split("+").map { |m| m.strip.to_sym }
        result << {
          moves:        moves,
          result_field: parts[1] == "NONE" ? nil : parts[1].to_sym,
          message:      parts[2] || nil
        }
      end
      return result
    end

    # Effect format: "effect_name,arg1|arg2|arg3"
    # PBS compiler only captures 2 comma values, so use | for additional args
    # Example: "type_add,MUDDYWATER|GROUND"
    # Example: "no_charge,DIG|DIVE|FLY"
    # Example: "effect_duration,TAUNT|6"
    # Example: "add_status,THIEF|PARALYSIS|100"
    def parse_effects(data)
      return [] if data.nil? || data.empty?
      result = []
      data.each do |entry|
        next if entry.nil? || entry.empty?
        # Entry comes as array like ["effect_name", "arg1|arg2|arg3"]
        parts = entry.is_a?(Array) ? entry : entry.split(",").map(&:strip)
        next if parts.empty?
        effect_name = parts[0].downcase.to_sym
        # Split remaining args by | separator
        if parts[1]
          args = parts[1].split("|").map(&:strip)
        else
          args = []
        end
        result << {
          name: effect_name,
          args: args
        }
      end
      return result
    end

    # Get effects by category
    def effects_by_category(category)
      return [] if @effects.nil? || @effects.empty?
      @effects.select do |effect|
        effect_data = Battle::FieldEffectsLibrary.get(effect[:name])
        effect_data && effect_data[:category] == category
      end
    end

    # Check if this field has a specific effect
    def has_effect?(effect_name)
      return false if @effects.nil? || @effects.empty?
      @effects.any? { |e| e[:name] == effect_name.to_sym }
    end

    # Get effect data by name
    def get_effect(effect_name)
      return nil if @effects.nil? || @effects.empty?
      @effects.find { |e| e[:name] == effect_name.to_sym }
    end
  end
end
