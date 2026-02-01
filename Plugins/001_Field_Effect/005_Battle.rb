def set_field(new_field = nil)
  $field = new_field
end

def default_field
  $field
end

#===============================================================================
# Counter Management Methods for Battle class
#===============================================================================
module Battle::FieldCounterMethods
  def initialize_field_counters
    @field_counters = {}
    @field_combo_history = []
  end

  def field_counters
    @field_counters ||= {}
    return @field_counters
  end

  def field_combo_history
    @field_combo_history ||= []
    return @field_combo_history
  end

  def field_combo_history=(value)
    @field_combo_history = value
  end

  def increment_field_counter(name, amount = 1)
    @field_counters ||= {}
    @field_counters[name] ||= 0
    @field_counters[name] += amount
  end

  def decrement_field_counter(name, amount = 1)
    @field_counters ||= {}
    return unless @field_counters[name]
    @field_counters[name] = [@field_counters[name] - amount, 0].max
  end

  def reset_field_counter(name)
    @field_counters ||= {}
    @field_counters[name] = 0
  end

  def reset_field_counters
    @field_counters = {}
  end

  def get_field_counter(name)
    @field_counters ||= {}
    return @field_counters[name] || 0
  end
end

class Battle
  attr_reader :stacked_fields
  attr_reader :current_field
  attr_accessor :field_counters
  attr_accessor :field_combo_history

  # Include counter management methods
  include Battle::FieldCounterMethods

  def create_base_field
    create_new_field(:BASE)
  end

  def set_default_field
    if default_field
      create_new_field(default_field, Battle::Field::INFINITE_FIELD_DURATION)
      set_field
    else
      all_fields_data.each do |field, data| # trainer field
        next if !trainerBattle?
        trainer_field = @opponent.map(&:name) & data[1]
        next if trainer_field.empty?
        create_new_field(field, Battle::Field::INFINITE_FIELD_DURATION)
        return
      end

      all_fields_data.each do |field, data| # map field
        next if !data[0].include?($game_map.map_id)
        create_new_field(field, Battle::Field::INFINITE_FIELD_DURATION)
        return
      end

      return if !Battle::Field::OPPOSING_ADVANTAGEOUS_TYPE_FIELD
      opposing_types = party2_able_pkmn_types.dup
      opposing_advantageous_types = trainerBattle? ? opposing_types.most_elements : opposing_types

      advantageous_fields = []
      all_fields_data.each do |field, data| # type field
        type_fields = opposing_advantageous_types & data[2]
        next if type_fields.empty?
        advantageous_fields << field
      end

      advantageous_fields = all_fields if advantageous_fields.empty?

      create_new_field(advantageous_fields.sample, Battle::Field::INFINITE_FIELD_DURATION)
    end

    set_test_field if debugControl
  end

  def set_test_field
    create_new_field(:PSYCHIC, 3)
  end

  def create_new_field(id, *args)
    duration = args[0]
    return if try_create_zero_duration_field?(duration)

    formatted_name = id.to_s.downcase.gsub(/_/, '')
    field_class_name = "Battle::Field_#{formatted_name}"
    return if try_create_base_field?(field_class_name) && !can_create_base_field?

    # Check if trying to create the same field that's already active
    # Use field ID comparison instead of class name for data-driven fields
    if has_field? && (try_create_current_field?(field_class_name) || @current_field.id == id.to_sym)
      return if is_infinite_field?
      if try_create_infinite_field?(args[0])
        remove_field(remove_all: true)
        set_field_duration(Battle::Field::INFINITE_FIELD_DURATION)
        add_field(@current_field)
        #pbDisplay(_INTL("The field will exist forever!"))
        #echoln("[Field set] #{field_name} was set! [#{stacked_fields_stat}]")
      else
        if duration && duration > Battle::Field::FIELD_DURATION_EXPANDED
          add_field_duration(Battle::Field::FIELD_DURATION_EXPANDED)
        else
          add_field_duration(duration || Battle::Field::FIELD_DURATION_EXPANDED)
        end
        pbDisplay(_INTL("The field has already existed!"))
        pbDisplay(_INTL("The field duration expanded to #{field_duration}!"))
      end
      return
    end

    # Use Field Factory to create fields (supports both Ruby classes and PBS data)
    new_field = Battle::FieldFactory.create(self, id, *args)
    return if new_field.nil?

    end_field if has_field?

    remove_field(remove_all: true) if try_create_infinite_field?(args[0])

    removed_field = remove_field(new_field, ignore_infinite: false)

    add_field(new_field)
    set_current_field(new_field)

    add_field_duration(removed_field.duration) if removed_field

    # Reset counters when field changes
    reset_field_counters if respond_to?(:reset_field_counters)

    set_fieldback if has_field?
    field_announcement(:start) if has_field?
    #echoln("[Field set] #{field_name} was set! [#{stacked_fields_stat}]") if has_field?

    apply_field_effect(:set_field_battle)
    eachBattler { |battler| apply_field_effect(:set_field_battler_universal, battler) }
    eachBattler { |battler| apply_field_effect(:set_field_battler, battler) }
  end

  def end_of_round_field_process
    return if !has_field?
    apply_field_effect(:EOR_field_battle)
    eachBattler do |battler|
      apply_field_effect(:EOR_field_battler, battler)
      return if battler.owner_party_all_fainted? # end of battle
    end

    field_duration_countdown
    remove_field

    end_field_process
  end

  def end_field_process
    if has_field?
      if is_top_field_activate?
        field_announcement(:continue)
      else
        end_field
        set_top_field
      end
    else
      end_field
      set_base_field
    end
  end

  def set_base_field
    set_current_field(base_field)
    set_fieldback

    apply_field_effect(:set_field_battle)
    eachBattler { |battler| apply_field_effect(:set_field_battler_universal, battler) }
    eachBattler { |battler| apply_field_effect(:set_field_battler, battler) }
  end

  def set_top_field
    set_current_field(top_field)
    set_fieldback
    field_announcement(:start)

    #echoln("[Field set] #{field_name} was set! [#{stacked_fields_stat}]") if has_field?

    apply_field_effect(:set_field_battle)
    eachBattler { |battler| apply_field_effect(:set_field_battler_universal, battler) }
    eachBattler { |battler| apply_field_effect(:set_field_battler, battler) }
  end

  def end_field
    field_announcement(:end)

    apply_field_effect(:end_field_battle)
    eachBattler { |battler| apply_field_effect(:end_field_battler, battler) }
  end

  def try_create_zero_duration_field?(duration)
    duration && duration == 0
  end

  def try_create_infinite_field?(duration)
    duration && duration == Battle::Field::INFINITE_FIELD_DURATION
  end

  def can_create_base_field?
    @stacked_fields.empty?
  end

  def try_create_base_field?(field_class_name)
    field_class_name == "Battle::Field_base"
  end

  def try_create_current_field?(field_class_name)
    field_class_name == @current_field.class.to_s
  end

  def add_field(new_field)
    @stacked_fields.push(new_field)
  end

  def add_field_duration(amount = 0)
    @current_field.add_duration(amount)
  end

  def reduce_field_duration(amount = 0)
    @current_field.reduce_duration(amount)
  end

  def set_field_duration(amount = 0)
    @current_field.set_duration(amount)
  end

  def field_duration_countdown
    @stacked_fields.each { |field| field.reduce_duration(1) if !field.infinite? }
  end

  def remove_field(remove_fields = nil, ignore_infinite: true, remove_all: false)
    return if !has_field?

    if remove_fields && ignore_infinite
      return @stacked_fields.delete_at(remove_fields) if remove_fields.is_a?(Integer)
      return @stacked_fields.delete(remove_fields)
    end

    removed_field = nil
    if remove_fields
      @stacked_fields.delete_if do |field|
        if !field.infinite? && field == remove_fields
          removed_field = field
          true
        end
      end
      return removed_field
    end

    if remove_all
      @stacked_fields.keep_if(&:is_base?)
      #echoln("[Field remove] All fields were removed!")
    else
      @stacked_fields.delete_if(&:end?)
      if stacked_fields_stat.empty?
        #echoln("[Field remove] All ended fields were removed!")
      else
        #echoln("[Field remove] All ended fields were removed! [#{stacked_fields_stat}]")
      end
    end
  end

  def set_current_field(new_field)
    @current_field = new_field
  end

  def end_current_field
    return if !has_field?
    remove_field(-1)
    end_field_process
  end

  def set_fieldback
    if has_field?
      @scene.set_fieldback
    else
      @scene.set_fieldback(true)
    end
  end

  def apply_field_effect(key, *args, apply_all: false)
    result = nil
    if apply_all
      @stacked_fields.each { |field| field.apply_field_effect(key, *args) if !Battle::Field::PARADOX_KEYS.include?(key) }
    else
      @stacked_fields.each do |field|
        next if Battle::Field::PARADOX_KEYS.include?(key)
        next if !field.always_online.include?(key)
        next if field.is_on_top?
        field.apply_field_effect(key, *args)
      end
      result = @current_field.apply_field_effect(key, *args)
    end
    return result
  end

  def field_announcement(announcement_type)
    case announcement_type
    when :start
      message = @current_field.field_announcement[0]
      pbDisplay(message) if message && !message.empty?
      if is_infinite_field?
        #pbDisplay(_INTL("The field will exist forever!"))
      else
        pbDisplay(_INTL("The field will last for {1} more turns!", field_duration))
      end
    when :continue
      message = @current_field.field_announcement[1] || @current_field.field_announcement[0]
      pbDisplay(message) if message && !message.empty?
      pbDisplay(_INTL("The field will last for {1} more turns!", field_duration)) if !is_infinite_field?
    when :end
      message = @current_field.field_announcement[2]
      pbDisplay(message) if message && !message.empty?
    end
  end

  def all_fields
    Battle::Field::DEFAULT_FIELD.keys
  end

  def all_fields_data
    Battle::Field::DEFAULT_FIELD
  end

  def field_id
    @current_field.id
  end

  def field_name
    @current_field.name
  end

  def field_duration
    @current_field.duration
  end

  def base_field
    @stacked_fields[0]
  end

  def has_base_field?
    base_field && base_field.is_base?
  end

  def top_field
    @stacked_fields[-1]
  end

  def is_top_field_activate?
    @current_field == top_field
  end

  def has_field?
    @stacked_fields.length >= 2
  end
  alias has_top_field? has_field?

  def stacked_fields_name
    @stacked_fields.map(&:name)[1..-1].join(", ")
  end

  def stacked_fields_stat
    @stacked_fields.map { |field| [field.name, field.duration] }[1..-1].join(", ")
  end

  def is_infinite_field?
    has_field? && @current_field.infinite?
  end

  #-----------------------------------------------------------------------------
  # Helper method to check and apply field-based status effects
  # Returns the status info hash if the move should apply a status, nil otherwise
  # Usage in move: status_info = @battle.field_status_for_move(self)
  #                if status_info && rand(100) < status_info[:chance]
  #                  target.pbInflictStatus(status_info[:status], user)
  #                end
  #-----------------------------------------------------------------------------
  def field_status_for_move(move)
    return nil unless has_field?
    result = apply_field_effect(:add_status, move)
    return result if result.is_a?(Hash) && result[:status]
    return nil
  end

  #-----------------------------------------------------------------------------
  # Applies field-based status effect to target if applicable
  # Returns true if status was applied, false otherwise
  # Usage in move's pbEffectAfterAllHits:
  #   @battle.apply_field_status(self, user, target)
  #-----------------------------------------------------------------------------
  def apply_field_status(move, user, target)
    status_info = field_status_for_move(move)
    return false unless status_info

    # Check chance
    return false unless rand(100) < status_info[:chance]

    # Apply the status
    case status_info[:status]
    when :BURN
      return false unless target.pbCanBurn?(user, false, move)
      target.pbBurn(user)
    when :PARALYSIS
      return false unless target.pbCanParalyze?(user, false, move)
      target.pbParalyze(user)
    when :POISON
      return false unless target.pbCanPoison?(user, false, move)
      target.pbPoison(user)
    when :FREEZE
      return false unless target.pbCanFreeze?(user, false, move)
      target.pbFreeze(user)
    when :SLEEP
      return false unless target.pbCanSleep?(user, false, move)
      target.pbSleep(user)
    when :TOXIC
      return false unless target.pbCanPoison?(user, false, move)
      target.pbPoison(user, nil, true)  # true for toxic
    else
      return false
    end

    return true
  end

  def is_field?(field)
    @current_field.is_field?(field)
  end

  def is_base_field?
    @current_field.is_base?
  end

  def is_electric_field?
    @current_field.is_electric?
  end

  def is_grassy_field?
    @current_field.is_grassy?
  end

  def is_misty_field?
    @current_field.is_misty?
  end

  def is_psychic_field?
    @current_field.is_psychic?
  end

  def is_beach_field?
    @current_field.is_beach?
  end

  def is_fairygrove_field?
    @current_field.is_fairygrove?
  end

  def is_crystalcave_field?
    @current_field.is_crystalcave?
  end
end

class Battle::Scene
  def set_fieldback(set_environment = false)
    if set_environment
      @sprites["battle_bg"].setBitmap(@environment_battleBG)
      @sprites["base_0"].setBitmap(@environment_playerBase)
      @sprites["base_1"].setBitmap(@environment_enemyBase)
    else
      field_name = @battle.current_field.fieldback
      return if !field_name || field_name.empty?
      root = "Graphics/Fieldbacks"
      battle_bg_path = "#{root}/#{field_name}_battlebg.png"
      return if !FileTest.exist?(battle_bg_path)
      @sprites["battle_bg"].setBitmap(battle_bg_path)
      @sprites["base_0"].setBitmap("#{root}/#{field_name + "_playerbase.png"}")
      @sprites["base_1"].setBitmap("#{root}/#{field_name + "_enemybase.png"}")
    end
  end
end

def debugControl
  $DEBUG && Input.press?(Input::CTRL)
end