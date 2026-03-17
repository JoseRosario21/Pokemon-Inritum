class Battle::Field
  attr_reader :battle
  attr_reader :duration, :effects, :field_announcement, :fieldback, :id, :name   
  attr_reader :multipliers, :strengthened_message, :weakened_message
  attr_reader :nature_power_change, :secret_power_effect, :tailwind_duration
  attr_reader :always_online

  DEFAULT_FIELD_DURATION  = 5
  FIELD_DURATION_EXPANDED = 3
  INFINITE_FIELD_DURATION = -1

  OPPOSING_ADVANTAGEOUS_TYPE_FIELD = false

  BASE_KEYS = %i[set_field_battler_universal]

  PARADOX_KEYS = %i[begin_battle set_field_battle set_field_battler set_field_battler_universal
                   nature_power_change secret_power_effect tailwind_duration
                   end_field_battle end_field_battler]

  DEFAULT_FIELD = {
    :ELECTRIC => [[],           # map ids
                %w[],           # trainer names
                %i[]],  # advantageous types (DEACTIVATED)
    :GRASSY     => [[],
                %w[],
                %i[]],
    :MISTY      => [[],
                %w[],
                %i[]],
    :PSYCHIC    => [[],
                %w[],
                %i[]],
    :BEACH      => [[5],
                %w[],
                %i[]],
    :URBAN      => [[4],
                %w[],
                %i[]],
    :FOREST     => [[12,3,7],
                %w[],
                %i[]],
    :CAVE       => [[40,24],
                %w[],
                %i[]],
    :NORMALIZED => [[13],
                %w[],
                %i[]],
    :DARKFOREST => [[15,20,21,22,25],
                %w[],
                %i[]],
    :ZAPPFEFALLS => [[23],
                %w[Howard],
                %i[]],
    :FAIRYGROVE => [[27],
                %w[],
                %i[]],
    :CRYSTALCAVE => [[26],
                %w[],
                %i[]],
  }

  def initialize(battle)
    @battle                    = battle
    @effects                   = {}
    @field_announcement        = []
    @multipliers               = {}
    @base_strengthened_message = _INTL("The field strengthened the attack")
    @base_weakened_message     = _INTL("The field weakened the attack")
    @always_online             = []

    @effects[:calc_damage] = proc { |user, target, numTargets, move, type, power, mults, aiCheck|
      # Mark that calc_damage was called (for standalone hook detection)
      @battle.field_calc_damage_called = true if @battle.respond_to?(:field_calc_damage_called=)

      @multipliers.each do |mult, calc_proc|

        # Handle both old format [key, value, message] and new format [:type/:move, id, key, value, message]
        if mult[0] == :type || mult[0] == :move
          # New format: [:type/:move, type/move_id, mult_key, value, message]
          mult_key = mult[2]
          mult_value = mult[3]
          mult_message = mult[4]
        else
          # Old format: [mult_key, value, message]
          mult_key = mult[0]
          mult_value = mult[1]
          mult_message = mult[2]
        end

        next if mult_value == 1.0
        ret = calc_proc&.call(user, target, numTargets, move, type, power, mults, aiCheck)
        next if !ret

        mults[mult_key] *= mult_value

        next if aiCheck
        multiplier = (mult_key == :defense_multiplier) ? (1.0 / mult_value) : mult_value
        if mult_message && !mult_message.empty?
          @battle.pbDisplay(mult_message)
        elsif multiplier > 1.0
          if !@strengthened_message_displayed
            if @strengthened_message && !@strengthened_message.empty?
              @battle.pbDisplay(@strengthened_message)
            else
              @battle.pbDisplay(_INTL("{1} on {2}!", @base_strengthened_message, target.pbThis(true)))
            end
            @strengthened_message_displayed = true
          end
        elsif !@weakened_message_displayed
          if @weakened_message && !@weakened_message.empty?
            @battle.pbDisplay(@weakened_message)
          else
            @battle.pbDisplay(_INTL("{1} on {2}!", @base_weakened_message, target.pbThis(true)))
          end
          @weakened_message_displayed = true
        end
      end
      @strengthened_message_displayed = false
      @weakened_message_displayed = false
     }

    @effects[:nature_power_change] = proc { |move| next @nature_power_change }

    @effects[:secret_power_effect] = proc { |user, targets, move| next @secret_power_effect }

    @effects[:set_field_battler_universal] = proc { |battler| battler.pbItemHPHealCheck }

    @effects[:tailwind_duration] = proc { |battler| next @tailwind_duration }

  end

  def self.method_missing(method_name, *args, &block)
    echoln("Undefined class method #{method_name} is called with args: #{args.inspect}")
  end

  def method_missing(method_name, *args, &block)
    echoln("Undefined instance method #{method_name} is called with args: #{args.inspect}")
  end

  def apply_field_effect(key, *args)
    return if is_base? && !Battle::Field::BASE_KEYS.include?(key)
    #echoln("[Field effect apply] #{@name}'s key #{key.upcase} applied!")
    effect = @effects[key]
    return nil if effect.nil?

    # Handle both single procs and arrays of procs
    if effect.is_a?(Array)
      # For arrays, call each proc and return first truthy result
      effect.each do |proc|
        result = proc.call(*args)
        return result if result
      end
      return nil
    else
      # Single proc
      return effect.call(*args)
    end
  end

  def add_duration(amount = 0)
    return if infinite?
    @duration += amount
    #echoln("[Field duration change] #{@name}'s duration is now #{@duration}!")
  end

  def reduce_duration(amount = 0)
    return if infinite?
    @duration -= amount
    #echoln("[Field duration change] #{@name}'s duration is now #{@duration}!")
  end

  def set_duration(amount = 0)
    @duration = amount
    #echoln("[Field duration change] #{@name}'s duration is now #{@duration}!")
  end

  def ==(another_field)
    @id == another_field.id
  end

  def is_on_top?
    self == @battle.top_field
  end

  def default_duration?
    @duration == 5
  end

  def infinite?
    @duration == -1
  end

  def end?
    @duration == 0
  end

  def is_field?(field)
    @id == field
  end

  def is_base?
    @id == :BASE
  end

  def is_electric?
    @id == :ELECTRIC
  end

  def is_grassy?
    @id == :GRASSY
  end

  def is_misty?
    @id == :MISTY
  end

  def is_psychic?
    @id == :PSYCHIC
  end

  def is_beach?
    @id == :BEACH
  end

  def is_urban?
    @id == :URBAN
  end

  def is_forest?
    @id == :FOREST
  end

  def is_cave?
    @id == :CAVE
  end

  def is_normalized?
    @id == :NORMALIZED
  end

  def is_darkforest?
    @id == :DARKFOREST
  end

  def is_fairygrove?
    @id == :FAIRYGROVE
  end

  def is_crystalcave?
    @id == :CRYSTALCAVE
  end

  def is_zappfefalls?
    @id == :ZAPPFEFALLS
  end
end