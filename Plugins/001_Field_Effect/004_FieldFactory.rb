#===============================================================================
# Field Factory
# Creates field instances from either Ruby classes or PBS data
# Maintains backward compatibility with existing class-based fields
#===============================================================================
module Battle::FieldFactory
  module_function

  #-----------------------------------------------------------------------------
  # Create a field instance
  # @param battle [Battle] The battle object
  # @param field_id [Symbol] The field identifier
  # @param args [Array] Additional arguments (duration, etc.)
  # @return [Battle::Field, nil] The created field instance or nil
  #-----------------------------------------------------------------------------
  def create(battle, field_id, *args)
    return nil if field_id.nil?

    # Normalize field ID
    field_id = field_id.to_sym if field_id.is_a?(String)

    # Try specific Ruby class first (backward compatible)
    field_class = get_field_class(field_id)
    if field_class
      return field_class.new(battle, *args)
    end

    # Fall back to data-driven field from PBS
    if GameData::FieldEffect.exists?(field_id)
      return Battle::Field_DataDriven.new(battle, field_id, *args)
    end

    # Field not found
    echoln("[FieldFactory] Unknown field: #{field_id}")
    return nil
  end

  #-----------------------------------------------------------------------------
  # Get the Ruby class for a field ID
  # @param field_id [Symbol] The field identifier
  # @return [Class, nil] The field class or nil if not found
  #-----------------------------------------------------------------------------
  def get_field_class(field_id)
    # Format: Field_electric, Field_grassy, etc.
    formatted_name = field_id.to_s.downcase.gsub(/_/, "")
    class_suffix = "Field_#{formatted_name}"

    # Check if Battle module has this constant defined before attempting to get it
    # This avoids raising NameError which shows in Ruby's exception trace
    return nil unless defined?(Battle) && Battle.is_a?(Module)
    return nil unless Battle.const_defined?(class_suffix, false)

    klass = Battle.const_get(class_suffix, false)
    return klass if klass.is_a?(Class) && klass < Battle::Field

    return nil
  end

  #-----------------------------------------------------------------------------
  # Check if a field exists (either as class or PBS data)
  # @param field_id [Symbol] The field identifier
  # @return [Boolean]
  #-----------------------------------------------------------------------------
  def exists?(field_id)
    return false if field_id.nil?
    return true if get_field_class(field_id)
    return GameData::FieldEffect.exists?(field_id)
  end

  #-----------------------------------------------------------------------------
  # Get all available field IDs
  # @return [Array<Symbol>]
  #-----------------------------------------------------------------------------
  def all_field_ids
    ids = []

    # Add PBS-defined fields
    if GameData::FieldEffect.const_defined?(:DATA)
      GameData::FieldEffect.each { |f| ids << f.id }
    end

    # Add class-defined fields from Battle::Field::DEFAULT_FIELD
    Battle::Field::DEFAULT_FIELD.keys.each { |id| ids << id unless ids.include?(id) }

    return ids.uniq
  end
end

#===============================================================================
# Data-Driven Field Class
# Creates a field instance from PBS data (GameData::FieldEffect)
#===============================================================================
class Battle::Field_DataDriven < Battle::Field
  def initialize(battle, field_id, duration = nil, *args)
    super(battle)

    # Load data from PBS
    @data = GameData::FieldEffect.try_get(field_id)
    if @data.nil?
      raise "Unknown field ID: #{field_id}"
    end

    # Set basic properties from PBS data
    @id                  = @data.id
    @name                = @data.name
    @duration            = duration || @data.default_duration
    @fieldback           = @data.fieldback
    @nature_power_change = @data.nature_power
    @secret_power_effect = @data.secret_power_effect
    @field_announcement  = [
      @data.get_announcement(:start),
      @data.get_announcement(:continue),
      @data.get_announcement(:end)
    ]

    # Build multipliers from PBS data
    build_multipliers_from_data

    # Build status immunity proc from PBS data
    build_status_immunity_from_data

    # Build effects from PBS data
    build_effects_from_data
  end

  #-----------------------------------------------------------------------------
  # Build the @multipliers hash from PBS type/move multipliers
  #-----------------------------------------------------------------------------
  def build_multipliers_from_data
    return if @data.nil?

    # Type multipliers - use unique key including type
    @data.type_multipliers.each do |mult|
      mult_key = get_multiplier_key(mult[:key])
      next unless mult_key

      # Create unique entry key including the type
      entry_key = [:type, mult[:type], mult_key, mult[:value], mult[:message]]

      @multipliers[entry_key] = proc do |user, target, numTargets, move, type, power, mults, aiCheck|
        # Check if move type matches
        next false if type != mult[:type]

        # Check condition if specified
        if mult[:condition]
          condition_met = Battle::FieldConditions.met?(@battle, user, mult[:condition])
          next false unless condition_met
        end

        next true
      end
    end

    # Move multipliers - use unique key including move
    @data.move_multipliers.each do |mult|
      mult_key = get_multiplier_key(mult[:key])
      next unless mult_key

      # Create unique entry key including the move
      entry_key = [:move, mult[:move], mult_key, mult[:value], mult[:message]]

      @multipliers[entry_key] = proc do |user, target, numTargets, move, type, power, mults, aiCheck|
        # Check if move ID matches
        next false if move.id != mult[:move]

        # Check condition if specified
        if mult[:condition]
          condition_met = Battle::FieldConditions.met?(@battle, user, mult[:condition])
          next false unless condition_met
        end

        next true
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Convert PBS multiplier key name to internal symbol
  #-----------------------------------------------------------------------------
  def get_multiplier_key(key_name)
    case key_name.to_s.downcase
    when "power", "power_multiplier"
      return :power_multiplier
    when "attack", "attack_multiplier"
      return :attack_multiplier
    when "defense", "defense_multiplier"
      return :defense_multiplier
    when "final", "final_damage", "final_damage_multiplier"
      return :final_damage_multiplier
    when "accuracy", "accuracy_multiplier"
      return :accuracy_multiplier
    else
      return key_name.to_sym
    end
  end

  #-----------------------------------------------------------------------------
  # Build status immunity proc from PBS data
  #-----------------------------------------------------------------------------
  def build_status_immunity_from_data
    return if @data.nil?
    return if @data.status_immunities.empty?

    @effects[:status_immunity] = proc do |battler, newStatus, yawn, user, showMessages, selfInflicted, move, ignoreStatus|
      immunity_triggered = false

      @data.status_immunities.each do |imm|
        # Check if status matches
        status_matches = false
        case imm[:status]
        when :SLEEP
          status_matches = (newStatus == :SLEEP || yawn)
        when :POISON, :BURN, :PARALYSIS, :FREEZE, :FROSTBITE, :DROWSY
          status_matches = (newStatus == imm[:status])
        when :ALL, :ANY
          status_matches = true
        else
          status_matches = (newStatus == imm[:status])
        end

        next unless status_matches

        # Check condition if specified
        if imm[:condition]
          condition_met = Battle::FieldConditions.met?(@battle, battler, imm[:condition])
          next unless condition_met
        end

        # Status immunity triggered
        if showMessages
          @battle.pbDisplay(_INTL("{1} is protected by the {2}!", battler.pbThis, @name))
        end
        immunity_triggered = true
        break
      end

      next immunity_triggered
    end
  end

  #-----------------------------------------------------------------------------
  # Build effects from PBS Effect entries
  #-----------------------------------------------------------------------------
  def build_effects_from_data
    return if @data.nil?
    return if @data.effects.nil? || @data.effects.empty?

    @data.effects.each do |effect_entry|
      effect_name = effect_entry[:name]
      args = effect_entry[:args]

      # Get the effect from the library
      effect_data = Battle::FieldEffectsLibrary.get(effect_name)
      next unless effect_data

      # Build the effect proc
      effect_proc = Battle::FieldEffectsLibrary.build_effect(@battle, effect_name, args)
      next unless effect_proc

      # Map effect categories to internal effect keys
      case effect_data[:category]
      when :type
        # Type modification effects
        case effect_name
        when :type_add
          @effects[:base_type_add] ||= []
          @effects[:base_type_add] << effect_proc
        when :type_change
          @effects[:base_type_change] ||= []
          @effects[:base_type_change] << effect_proc
        when :type_convert
          @effects[:type_convert] ||= []
          @effects[:type_convert] << effect_proc
        end

      when :charging
        case effect_name
        when :no_charge
          @effects[:no_charging] ||= []
          @effects[:no_charging] << effect_proc
        when :force_charge
          @effects[:force_charging] ||= []
          @effects[:force_charging] << effect_proc
        end

      when :targeting
        @effects[:target_expand] ||= []
        @effects[:target_expand] << effect_proc

      when :duration
        case effect_name
        when :binding_boost
          @effects[:binding_boost] ||= []
          @effects[:binding_boost] << effect_proc
        when :effect_duration
          @effects[:increase_duration] ||= []
          @effects[:increase_duration] << effect_proc
        end

      when :effect
        @effects[:effect_boost] ||= []
        @effects[:effect_boost] << effect_proc

      when :healing
        case effect_name
        when :heal_boost
          @effects[:heal_boost] ||= []
          @effects[:heal_boost] << effect_proc
        when :heal_reduce
          @effects[:heal_reduce] ||= []
          @effects[:heal_reduce] << effect_proc
        when :ingrain_boost
          @effects[:ingrain_boost] = effect_proc
        when :aqua_ring_boost
          @effects[:aqua_ring_boost] = effect_proc
        when :leech_seed_boost
          @effects[:leech_seed_boost] = effect_proc
        end

      when :accuracy
        case effect_name
        when :accuracy_set, :accuracy_type_boost
          @effects[:accuracy_modify] ||= []
          @effects[:accuracy_modify] << effect_proc
        when :always_hit
          @effects[:always_hit] ||= []
          @effects[:always_hit] << effect_proc
        end

      when :status
        case effect_name
        when :add_status, :add_burn, :add_paralysis, :add_poison, :add_freeze, :add_sleep
          @effects[:add_status] ||= []
          @effects[:add_status] << effect_proc
        when :flinch_boost
          @effects[:flinch_boost] ||= []
          @effects[:flinch_boost] << effect_proc
        when :confusion_boost
          @effects[:confusion_boost] ||= []
          @effects[:confusion_boost] << effect_proc
        end

      when :crit
        @effects[:crit_boost] ||= []
        @effects[:crit_boost] << effect_proc

      when :recoil
        case effect_name
        when :no_recoil
          @effects[:no_recoil] ||= []
          @effects[:no_recoil] << effect_proc
        when :recoil_reduce, :recoil_boost
          @effects[:recoil_modify] ||= []
          @effects[:recoil_modify] << effect_proc
        end

      when :priority
        case effect_name
        when :priority_boost
          @effects[:priority_boost] ||= []
          @effects[:priority_boost] << effect_proc
        when :block_priority
          @effects[:block_priority] = effect_proc
        end

      when :speed
        case effect_name
        when :speed_double
          @effects[:speed_double] ||= []
          @effects[:speed_double] << effect_proc
        when :speed_halve
          @effects[:speed_halve] ||= []
          @effects[:speed_halve] << effect_proc
        when :speed_boost_entry
          @effects[:speed_boost_entry] ||= []
          @effects[:speed_boost_entry] << effect_proc
        end

      when :move_enhance
        case effect_name
        when :speed_boost_move
          @effects[:speed_boost_move] ||= []
          @effects[:speed_boost_move] << effect_proc
        when :stat_boost_move
          @effects[:stat_boost_move] ||= []
          @effects[:stat_boost_move] << effect_proc
        end

      when :end_turn
        case effect_name
        when :end_turn_damage
          @effects[:end_turn_damage] ||= []
          @effects[:end_turn_damage] << effect_proc
        when :end_turn_heal
          @effects[:end_turn_heal] ||= []
          @effects[:end_turn_heal] << effect_proc
        when :end_turn_status
          @effects[:end_turn_status] ||= []
          @effects[:end_turn_status] << effect_proc
        end

      when :entry
        case effect_name
        when :entry_stat_boost
          @effects[:entry_stat_boost] ||= []
          @effects[:entry_stat_boost] << effect_proc
        when :entry_status
          @effects[:entry_status] ||= []
          @effects[:entry_status] << effect_proc
        end

      when :hazard
        case effect_name
        when :hazard_boost
          @effects[:hazard_boost] ||= []
          @effects[:hazard_boost] << effect_proc
        when :hazard_type_change
          @effects[:hazard_type_change] ||= []
          @effects[:hazard_type_change] << effect_proc
        when :hazard_immune
          @effects[:hazard_immune] ||= []
          @effects[:hazard_immune] << effect_proc
        end

      when :ability
        case effect_name
        when :grant_ability
          @effects[:grant_ability] ||= []
          @effects[:grant_ability] << effect_proc
        when :suppress_ability
          @effects[:suppress_ability] ||= []
          @effects[:suppress_ability] << effect_proc
        when :ability_boost
          @effects[:ability_boost] ||= []
          @effects[:ability_boost] << effect_proc
        end

      when :failure
        @effects[:move_block] ||= []
        @effects[:move_block] << effect_proc

      when :weather
        case effect_name
        when :weather_boost
          @effects[:weather_boost] ||= []
          @effects[:weather_boost] << effect_proc
        when :set_weather
          @effects[:set_weather] = effect_proc
        end

      when :seed
        @effects[:activate_seed] ||= []
        @effects[:activate_seed] << effect_proc

      when :protection
        case effect_name
        when :damage_reduce
          @effects[:damage_reduce] ||= []
          @effects[:damage_reduce] << effect_proc
        when :move_immune
          @effects[:move_immune] ||= []
          @effects[:move_immune] << effect_proc
        end

      when :item
        case effect_name
        when :item_boost
          @effects[:item_boost] ||= []
          @effects[:item_boost] << effect_proc
        when :item_block
          @effects[:item_block] ||= []
          @effects[:item_block] << effect_proc
        end

      when :power
        # Power effects are added to multipliers instead
        # These are handled via MoveBoost, FlagBoost, etc.
        add_power_effect_to_multipliers(effect_name, args, effect_proc)

      when :echo
        @effects[:echo_boost] = effect_proc

      when :weight
        @effects[:weight_modify] = effect_proc

      when :special
        case effect_name
        when :camouflage_type
          @effects[:camouflage_type] = effect_proc
        end

      when :begin_battle
        @effects[:begin_battle] ||= []
        @effects[:begin_battle] << effect_proc
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Add power-related effects to multipliers
  #-----------------------------------------------------------------------------
  def add_power_effect_to_multipliers(effect_name, args, effect_proc)
    message = args.last if args.length > 2
    multiplier = args[1]&.to_f || 1.3

    case effect_name
    when :move_boost
      move_id = args[0]&.to_sym
      entry_key = [:power_multiplier, multiplier, message]
      @multipliers[entry_key] = proc do |user, target, numTargets, move, type, power, mults, aiCheck|
        next move.id == move_id
      end
    when :flag_boost
      flag = args[0]
      entry_key = [:power_multiplier, multiplier, message]
      @multipliers[entry_key] = proc do |user, target, numTargets, move, type, power, mults, aiCheck|
        next move.flags.any? { |f| f.to_s.downcase == flag.downcase }
      end
    when :stab_field_boost
      boost_type = args[0]&.to_sym
      entry_key = [:power_multiplier, multiplier, message]
      @multipliers[entry_key] = proc do |user, target, numTargets, move, type, power, mults, aiCheck|
        next user.pbHasType?(boost_type) && type == boost_type
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Access to the underlying PBS data
  #-----------------------------------------------------------------------------
  def field_data
    return @data
  end

  #-----------------------------------------------------------------------------
  # Check if this field has any transformations defined
  #-----------------------------------------------------------------------------
  def has_transformations?
    return false if @data.nil?
    return !@data.transformations.empty? || !@data.counters.empty? || !@data.combos.empty?
  end

  #-----------------------------------------------------------------------------
  # Check if this field has a specific effect
  #-----------------------------------------------------------------------------
  def has_effect?(effect_name)
    return false if @data.nil?
    return @data.has_effect?(effect_name)
  end

  #-----------------------------------------------------------------------------
  # Get effect arguments from PBS data
  #-----------------------------------------------------------------------------
  def get_effect_args(effect_name)
    return nil if @data.nil?
    effect = @data.get_effect(effect_name)
    return effect ? effect[:args] : nil
  end
end
