#===============================================================================
# Field Effects Library
# Defines all available field effects that can be referenced from PBS
# Each effect is a named proc that can be invoked by data-driven fields
#===============================================================================
module Battle::FieldEffectsLibrary
  module_function

  #=============================================================================
  # EFFECT REGISTRY
  # Maps effect names to their implementations
  #=============================================================================
  EFFECTS = {}

  def register(name, category, &block)
    EFFECTS[name.to_sym] = {
      category: category,
      proc: block
    }
  end

  def get(name)
    EFFECTS[name.to_sym]
  end

  def exists?(name)
    EFFECTS.key?(name.to_sym)
  end

  #=============================================================================
  # MOVE POWER EFFECTS
  # Modify move power based on various conditions
  #=============================================================================

  # Boost power of specific moves
  # PBS: MoveBoost = SURF,1.5,The waves surge with power!
  register(:move_boost, :power) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    multiplier = args[1]&.to_f || 1.5
    message = args[2]

    proc { |user, target, numTargets, move, type, power, mults, aiCheck|
      next false unless move.id == move_id
      mults[:power_multiplier] *= multiplier
      battle.pbDisplay(_INTL(message)) if message && !message.empty? && !aiCheck
      next true
    }
  end

  # Boost power of moves with specific flags (contact, sound, pulse, etc.)
  # PBS: FlagBoost = contact,1.3,The field empowers contact moves!
  register(:flag_boost, :power) do |battle, field_data, args|
    flag = args[0]&.downcase
    multiplier = args[1]&.to_f || 1.3
    message = args[2]

    proc { |user, target, numTargets, move, type, power, mults, aiCheck|
      has_flag = move.flags.any? { |f| f.to_s.downcase == flag }
      next false unless has_flag
      mults[:power_multiplier] *= multiplier
      battle.pbDisplay(_INTL(message)) if message && !message.empty? && !aiCheck
      next true
    }
  end

  # Boost power based on user's type
  # PBS: STABFieldBoost = FIRE,1.2
  register(:stab_field_boost, :power) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    multiplier = args[1]&.to_f || 1.2
    message = args[2]

    proc { |user, target, numTargets, move, type, power, mults, aiCheck|
      next false unless user.pbHasType?(boost_type)
      next false unless type == boost_type
      mults[:power_multiplier] *= multiplier
      battle.pbDisplay(_INTL(message)) if message && !message.empty? && !aiCheck
      next true
    }
  end

  #=============================================================================
  # TYPE MODIFICATION EFFECTS
  # Change move types
  #=============================================================================

  # Add secondary type to a move
  # PBS: TypeAdd = MUDDYWATER,GROUND
  register(:type_add, :type) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    added_type = args[1]&.to_sym

    proc { |move|
      next nil unless move.id == move_id
      next added_type
    }
  end

  # Change move's primary type
  # PBS: TypeChange = CUT,GRASS
  register(:type_change, :type) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    new_type = args[1]&.to_sym

    proc { |move|
      next nil unless move.id == move_id
      next new_type
    }
  end

  # Change all moves of a type to another type
  # PBS: TypeConvert = NORMAL,GHOST
  register(:type_convert, :type) do |battle, field_data, args|
    from_type = args[0]&.to_sym
    to_type = args[1]&.to_sym

    proc { |move|
      next nil unless move.type == from_type
      next to_type
    }
  end

  #=============================================================================
  # ACCURACY EFFECTS
  #=============================================================================

  # Set specific accuracy for moves
  # PBS: AccuracySet = SLEEPPOWDER,100
  register(:accuracy_set, :accuracy) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    accuracy = args[1]&.to_i || 100

    proc { |move|
      next nil unless move.id == move_id
      next accuracy
    }
  end

  # Boost accuracy for move type
  # PBS: AccuracyTypeBoost = FIRE,1.2
  register(:accuracy_type_boost, :accuracy) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    multiplier = args[1]&.to_f || 1.2

    proc { |move, user, target, accuracy|
      next nil unless move.type == boost_type
      next (accuracy * multiplier).to_i
    }
  end

  # Moves always hit (bypass accuracy check)
  # PBS: AlwaysHit = SWIFT,AERIALACE
  register(:always_hit, :accuracy) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move|
      next moves.include?(move.id)
    }
  end

  #=============================================================================
  # CHARGING/TURN EFFECTS
  #=============================================================================

  # Skip charging turn for moves
  # PBS: NoCharge = DIG,DIVE,FLY
  register(:no_charge, :charging) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |user, move|
      next moves.include?(move.id)
    }
  end

  # Force charging (normally instant moves take 2 turns)
  # PBS: ForceCharge = SOLARBEAM
  register(:force_charge, :charging) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |user, move|
      next moves.include?(move.id)
    }
  end

  #=============================================================================
  # TARGETING EFFECTS
  #=============================================================================

  # Expand move to hit all opponents
  # PBS: TargetAll = SANDATTACK,MUDSLAP
  register(:target_all, :targeting) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |user, move, preTargetData|
      next moves.include?(move.id)
    }
  end

  #=============================================================================
  # DURATION/EFFECT BOOST
  #=============================================================================

  # Boost binding move duration
  # PBS: BindingBoost = SANDTOMB,WHIRLPOOL,FIRESPIN
  register(:binding_boost, :duration) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move|
      next moves.include?(move.id)
    }
  end

  # Boost secondary effect chance (doubles it)
  # PBS: EffectChanceBoost = LOWSWEEP,FLAMECHARGE
  register(:effect_chance_boost, :effect) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move|
      next 2 if moves.include?(move.id)
      next nil
    }
  end

  # Set specific duration for effects
  # PBS: EffectDuration = TAUNT,6
  register(:effect_duration, :duration) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    duration = args[1]&.to_i || 5

    proc { |move|
      next nil unless move.id == move_id
      next duration
    }
  end

  #=============================================================================
  # HEALING EFFECTS
  #=============================================================================

  # Boost healing moves
  # PBS: HealBoost = SYNTHESIS,SHOREUP,MOONLIGHT
  register(:heal_boost, :healing) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move|
      next moves.include?(move.id)
    }
  end

  # Reduce healing effectiveness
  # PBS: HealBlock = SYNTHESIS,MOONLIGHT
  register(:heal_reduce, :healing) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }
    multiplier = args.last.to_f rescue 0.5

    proc { |move|
      next nil unless moves.include?(move.id)
      next multiplier
    }
  end

  # Boost Ingrain healing
  # PBS: IngrainBoost = true
  register(:ingrain_boost, :healing) do |battle, field_data, args|
    proc { next true }
  end

  # Boost Aqua Ring healing
  # PBS: AquaRingBoost = true
  register(:aqua_ring_boost, :healing) do |battle, field_data, args|
    proc { next true }
  end

  # Boost Leech Seed drain
  # PBS: LeechSeedBoost = true
  register(:leech_seed_boost, :healing) do |battle, field_data, args|
    proc { next true }
  end

  #=============================================================================
  # MOVE ENHANCEMENT EFFECTS
  # Effects that enhance specific moves in various ways
  #=============================================================================

  # Speed boost from specific moves (like Splash on Beach)
  # PBS: Effect = speed_boost_move,SPLASH,2,User gained momentum!
  # PBS: Effect = speed_boost_move,FLAMEWHEEL,1
  register(:speed_boost_move, :move_enhance) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    stages = args[1]&.to_i || 2
    message = args[2]

    proc { |user, move|
      next nil unless move.id == move_id
      next { stages: stages, message: message }
    }
  end

  # Stat boost from specific moves
  # PBS: Effect = stat_boost_move,SPLASH,SPEED,2,User gained momentum!
  register(:stat_boost_move, :move_enhance) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    stat = args[1]&.to_sym || :SPEED
    stages = args[2]&.to_i || 1
    message = args[3]

    proc { |user, move|
      next nil unless move.id == move_id
      next { stat: stat, stages: stages, message: message }
    }
  end

  #=============================================================================
  # STATUS EFFECTS
  #=============================================================================

  # Generic add status to moves
  # PBS: AddStatus = THIEF,PARALYSIS,100
  # PBS: AddStatus = TACKLE,BURN,30
  register(:add_status, :status) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    status = args[1]&.to_sym || :PARALYSIS
    chance = args[2]&.to_i || 100

    proc { |move|
      next nil unless move.id == move_id
      next { status: status, chance: chance }
    }
  end

  # Add status to moves that don't normally have it
  # PBS: AddBurn = FLAMECHARGE,30
  register(:add_burn, :status) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    chance = args[1]&.to_i || 30

    proc { |move|
      next nil unless move.id == move_id
      next { status: :BURN, chance: chance }
    }
  end

  register(:add_paralysis, :status) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    chance = args[1]&.to_i || 30

    proc { |move|
      next nil unless move.id == move_id
      next { status: :PARALYSIS, chance: chance }
    }
  end

  register(:add_poison, :status) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    chance = args[1]&.to_i || 30

    proc { |move|
      next nil unless move.id == move_id
      next { status: :POISON, chance: chance }
    }
  end

  register(:add_freeze, :status) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    chance = args[1]&.to_i || 30

    proc { |move|
      next nil unless move.id == move_id
      next { status: :FREEZE, chance: chance }
    }
  end

  register(:add_sleep, :status) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    chance = args[1]&.to_i || 30

    proc { |move|
      next nil unless move.id == move_id
      next { status: :SLEEP, chance: chance }
    }
  end

  # Boost flinch chance
  # PBS: FlinchBoost = BITE,HEADBUTT,60
  register(:flinch_boost, :status) do |battle, field_data, args|
    moves = args[0..-2].map { |m| m.to_sym }
    chance = args.last.to_i rescue 60

    proc { |move|
      next nil unless moves.include?(move.id)
      next chance
    }
  end

  # Boost confusion chance
  # PBS: ConfusionBoost = PSYBEAM,50
  register(:confusion_boost, :status) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    chance = args[1]&.to_i || 50

    proc { |move|
      next nil unless move.id == move_id
      next chance
    }
  end

  #=============================================================================
  # CRITICAL HIT EFFECTS
  #=============================================================================

  # Boost crit rate for specific moves
  # PBS: CritBoost = SLASH,NIGHTSLASH,CROSSPOISON
  register(:crit_boost, :crit) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move, user|
      next 1 if moves.include?(move.id)
      next nil
    }
  end

  # Boost crit rate for type
  # PBS: CritTypeBoost = DARK,1
  register(:crit_type_boost, :crit) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    stages = args[1]&.to_i || 1

    proc { |move, user|
      next stages if move.type == boost_type
      next nil
    }
  end

  # Guarantee crits for moves
  # PBS: AlwaysCrit = FROSTBREATH,STORMTHROW
  register(:always_crit, :crit) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move, user|
      next 99 if moves.include?(move.id)
      next nil
    }
  end

  #=============================================================================
  # RECOIL EFFECTS
  #=============================================================================

  # Reduce recoil damage
  # PBS: RecoilReduce = 0.5
  register(:recoil_reduce, :recoil) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 0.5

    proc { |move, user, recoil_damage|
      next (recoil_damage * multiplier).to_i
    }
  end

  # Remove recoil entirely
  # PBS: NoRecoil = BRAVEBIRD,FLAREBLITZ
  register(:no_recoil, :recoil) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move, user|
      next moves.include?(move.id)
    }
  end

  # Increase recoil
  # PBS: RecoilBoost = 1.5
  register(:recoil_boost, :recoil) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 1.5

    proc { |move, user, recoil_damage|
      next (recoil_damage * multiplier).to_i
    }
  end

  #=============================================================================
  # PRIORITY EFFECTS
  #=============================================================================

  # Boost priority for moves
  # PBS: PriorityBoost = QUICKATTACK,1
  register(:priority_boost, :priority) do |battle, field_data, args|
    move_id = args[0]&.to_sym
    boost = args[1]&.to_i || 1

    proc { |move, user|
      next nil unless move.id == move_id
      next boost
    }
  end

  # Block priority moves (like Psychic Terrain)
  # PBS: BlockPriority = true,grounded
  register(:block_priority, :priority) do |battle, field_data, args|
    condition = args[0]

    proc { |move, user, target|
      next false unless move.priority > 0
      if condition == "grounded"
        next target.affectedByTerrain?
      end
      next true
    }
  end

  #=============================================================================
  # SPEED EFFECTS
  #=============================================================================

  # Double speed for type
  # PBS: SpeedDouble = ELECTRIC
  register(:speed_double, :speed) do |battle, field_data, args|
    boost_type = args[0]&.to_sym

    proc { |battler|
      next battler.pbHasType?(boost_type)
    }
  end

  # Halve speed for type
  # PBS: SpeedHalve = STEEL
  register(:speed_halve, :speed) do |battle, field_data, args|
    debuff_type = args[0]&.to_sym

    proc { |battler|
      next battler.pbHasType?(debuff_type)
    }
  end

  # Speed boost on entry
  # PBS: SpeedBoostEntry = ELECTRIC,1
  register(:speed_boost_entry, :speed) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    stages = args[1]&.to_i || 1

    proc { |battler|
      next nil unless battler.pbHasType?(boost_type)
      next stages
    }
  end

  #=============================================================================
  # END OF TURN EFFECTS
  #=============================================================================

  # Damage grounded Pokemon each turn
  # PBS: EndTurnDamage = 16,grounded,The field zaps everyone!
  register(:end_turn_damage, :end_turn) do |battle, field_data, args|
    fraction = args[0]&.to_i || 16
    condition = args[1]
    message = args[2]

    proc { |battler|
      if condition == "grounded"
        next nil unless battler.affectedByTerrain?
      end
      next { fraction: fraction, message: message }
    }
  end

  # Heal grounded Pokemon each turn (like Grassy Terrain)
  # PBS: EndTurnHeal = 16,grounded,The grass heals everyone!
  register(:end_turn_heal, :end_turn) do |battle, field_data, args|
    fraction = args[0]&.to_i || 16
    condition = args[1]
    message = args[2]

    proc { |battler|
      if condition == "grounded"
        next nil unless battler.affectedByTerrain?
      end
      next { fraction: fraction, message: message }
    }
  end

  # Apply status at end of turn
  # PBS: EndTurnStatus = POISON,10,grounded,Toxic fumes seep from the ground!
  register(:end_turn_status, :end_turn) do |battle, field_data, args|
    status = args[0]&.to_sym
    chance = args[1]&.to_i || 10
    condition = args[2]
    message = args[3]

    proc { |battler|
      if condition == "grounded"
        next nil unless battler.affectedByTerrain?
      end
      next { status: status, chance: chance, message: message }
    }
  end

  #=============================================================================
  # ENTRY EFFECTS
  #=============================================================================

  # Stat boost on entry for type
  # PBS: EntryStatBoost = FIRE,ATTACK,1
  register(:entry_stat_boost, :entry) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    stat = args[1]&.to_sym
    stages = args[2]&.to_i || 1

    proc { |battler|
      next nil unless battler.pbHasType?(boost_type)
      next { stat: stat, stages: stages }
    }
  end

  # Apply status on entry
  # PBS: EntryStatus = PARALYSIS,ELECTRIC,The electricity paralyzes!
  register(:entry_status, :entry) do |battle, field_data, args|
    status = args[0]&.to_sym
    immune_type = args[1]&.to_sym
    message = args[2]

    proc { |battler|
      next nil if immune_type && battler.pbHasType?(immune_type)
      next { status: status, message: message }
    }
  end

  #=============================================================================
  # HAZARD EFFECTS
  #=============================================================================

  # Boost hazard damage
  # PBS: HazardBoost = STEALTHROCK,2.0
  register(:hazard_boost, :hazard) do |battle, field_data, args|
    hazard = args[0]&.to_sym
    multiplier = args[1]&.to_f || 2.0

    proc { |hazard_type|
      next nil unless hazard_type == hazard
      next multiplier
    }
  end

  # Change hazard type
  # PBS: HazardTypeChange = STEALTHROCK,FIRE
  register(:hazard_type_change, :hazard) do |battle, field_data, args|
    hazard = args[0]&.to_sym
    new_type = args[1]&.to_sym

    proc { |hazard_type|
      next nil unless hazard_type == hazard
      next new_type
    }
  end

  # Nullify hazards
  # PBS: HazardImmune = SPIKES,TOXICSPIKES
  register(:hazard_immune, :hazard) do |battle, field_data, args|
    hazards = args.map { |h| h.to_sym }

    proc { |hazard_type|
      next hazards.include?(hazard_type)
    }
  end

  #=============================================================================
  # ABILITY EFFECTS
  #=============================================================================

  # Grant ability effects to all Pokemon
  # PBS: GrantAbility = WATERVEIL
  register(:grant_ability, :ability) do |battle, field_data, args|
    ability = args[0]&.to_sym
    condition = args[1]

    proc { |battler|
      if condition == "grounded"
        next nil unless battler.affectedByTerrain?
      end
      next ability
    }
  end

  # Suppress abilities
  # PBS: SuppressAbility = LEVITATE,HUGEPOWER
  register(:suppress_ability, :ability) do |battle, field_data, args|
    abilities = args.map { |a| a.to_sym }

    proc { |battler|
      next abilities.include?(battler.ability_id)
    }
  end

  # Boost ability effects (ability-specific handling needed)
  # PBS: AbilityBoost = SWIFTSWIM,2.0
  register(:ability_boost, :ability) do |battle, field_data, args|
    ability = args[0]&.to_sym
    multiplier = args[1]&.to_f || 2.0

    proc { |battler|
      next nil unless battler.ability_id == ability
      next multiplier
    }
  end

  #=============================================================================
  # MOVE FAILURE EFFECTS
  #=============================================================================

  # Prevent certain moves from working
  # PBS: MoveBlock = DIG,DIVE,The field prevents burrowing!
  register(:move_block, :failure) do |battle, field_data, args|
    moves = args[0..-2].map { |m| m.to_sym }
    message = args.last

    proc { |move, user|
      next nil unless moves.include?(move.id)
      next message
    }
  end

  # Prevent moves of certain type
  # PBS: TypeBlock = GROUND,Electricity grounds the attack!
  register(:type_block, :failure) do |battle, field_data, args|
    blocked_type = args[0]&.to_sym
    message = args[1]

    proc { |move, user|
      next nil unless move.type == blocked_type
      next message
    }
  end

  #=============================================================================
  # WEATHER/TERRAIN INTERACTION EFFECTS
  #=============================================================================

  # Boost during weather
  # PBS: WeatherBoost = Sun,FIRE,1.3
  register(:weather_boost, :weather) do |battle, field_data, args|
    weather = args[0]&.to_sym
    boost_type = args[1]&.to_sym
    multiplier = args[2]&.to_f || 1.3

    proc { |move, current_weather|
      next nil unless current_weather == weather
      next nil unless move.type == boost_type
      next multiplier
    }
  end

  # Auto-set weather when field activates
  # PBS: SetWeather = Sun,5
  register(:set_weather, :weather) do |battle, field_data, args|
    weather = args[0]&.to_sym
    duration = args[1]&.to_i || 5

    proc { next { weather: weather, duration: duration } }
  end

  #=============================================================================
  # SEED EFFECTS (Field-specific consumables)
  #=============================================================================

  # Define which seed activates on this field
  # PBS: ActivateSeed = ELECTRICSEED,DEFENSE,1
  register(:activate_seed, :seed) do |battle, field_data, args|
    seed_item = args[0]&.to_sym
    stat = args[1]&.to_sym
    stages = args[2]&.to_i || 1

    proc { |item|
      next nil unless item == seed_item
      next { stat: stat, stages: stages }
    }
  end

  #=============================================================================
  # SPECIAL MOVE EFFECTS
  #=============================================================================

  # Nature Power becomes this move
  # (Already handled by NaturePower in PBS, but this allows conditions)
  register(:nature_power_change, :special) do |battle, field_data, args|
    move = args[0]&.to_sym
    condition = args[1]

    proc { |user|
      if condition == "grounded" && !user.affectedByTerrain?
        next nil
      end
      next move
    }
  end

  # Secret Power effect
  register(:secret_power_effect, :special) do |battle, field_data, args|
    effect = args[0]&.to_i || 1

    proc { next effect }
  end

  # Camouflage type
  # PBS: CamouflageType = ELECTRIC
  register(:camouflage_type, :special) do |battle, field_data, args|
    new_type = args[0]&.to_sym

    proc { next new_type }
  end

  #=============================================================================
  # PROTECTION EFFECTS
  #=============================================================================

  # Reduce damage from type
  # PBS: DamageReduce = FIRE,0.5
  register(:damage_reduce, :protection) do |battle, field_data, args|
    damage_type = args[0]&.to_sym
    multiplier = args[1]&.to_f || 0.5

    proc { |move, target|
      next nil unless move.type == damage_type
      next multiplier
    }
  end

  # Immunity to moves (not types)
  # PBS: MoveImmune = EARTHQUAKE,BULLDOZE
  register(:move_immune, :protection) do |battle, field_data, args|
    moves = args.map { |m| m.to_sym }

    proc { |move, target|
      next moves.include?(move.id)
    }
  end

  #=============================================================================
  # ITEM EFFECTS
  #=============================================================================

  # Boost held item effects
  # PBS: ItemBoost = LIFEORB,1.5
  register(:item_boost, :item) do |battle, field_data, args|
    item = args[0]&.to_sym
    multiplier = args[1]&.to_f || 1.5

    proc { |battler|
      next nil unless battler.item_id == item
      next multiplier
    }
  end

  # Nullify held items
  # PBS: ItemBlock = AIRBALLOON,EVIOLITE
  register(:item_block, :item) do |battle, field_data, args|
    items = args.map { |i| i.to_sym }

    proc { |battler|
      next items.include?(battler.item_id)
    }
  end

  #=============================================================================
  # ECHO/CONSECUTIVE EFFECTS
  #=============================================================================

  # Boost consecutive use of same move
  # PBS: EchoBoost = 1.2
  register(:echo_boost, :echo) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 1.2
    max_boost = args[1]&.to_f || 2.0

    proc { |move, user, consecutive_count|
      boost = [1.0 + ((multiplier - 1.0) * consecutive_count), max_boost].min
      next boost
    }
  end

  #=============================================================================
  # WEIGHT EFFECTS
  #=============================================================================

  # Modify weight for weight-based moves
  # PBS: WeightModify = 0.5
  register(:weight_modify, :weight) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 0.5

    proc { |battler|
      next multiplier
    }
  end

  #=============================================================================
  # TERRAIN SEED EFFECTS
  #=============================================================================

  # Activate terrain seed on this field
  # PBS: TerrainSeed = ELECTRICSEED,DEFENSE,1
  register(:terrain_seed, :seed) do |battle, field_data, args|
    seed_item = args[0]&.to_sym
    stat = args[1]&.to_sym || :DEFENSE
    stages = args[2]&.to_i || 1

    proc { |battler, item|
      next nil unless item == seed_item
      next { stat: stat, stages: stages }
    }
  end

  #=============================================================================
  # FORM CHANGE EFFECTS (Burmy, Wormadam, etc.)
  #=============================================================================

  # Change Pokemon form based on field
  # PBS: FormChange = BURMY,1
  # PBS: FormChange = WORMADAM,2
  register(:form_change, :form) do |battle, field_data, args|
    species = args[0]&.to_sym
    form = args[1]&.to_i || 0

    proc { |battler|
      next nil unless battler.species == species
      next form
    }
  end

  #=============================================================================
  # PLEDGE COMBO EFFECTS
  #=============================================================================

  # Fire + Grass Pledge = Sea of Fire (damages non-Fire types)
  # PBS: PledgeEffect = fire_sea,8,FIRE
  register(:pledge_effect, :pledge) do |battle, field_data, args|
    effect_type = args[0]&.to_sym  # :fire_sea, :swamp, :rainbow
    duration = args[1]&.to_i || 4
    immune_type = args[2]&.to_sym

    proc { |battler|
      next nil if immune_type && battler.pbHasType?(immune_type)
      next { type: effect_type, duration: duration }
    }
  end

  #=============================================================================
  # MOVE MORPHING EFFECTS
  #=============================================================================

  # Weather Ball type change
  # PBS: WeatherBallType = FIRE
  register(:weather_ball_type, :morph) do |battle, field_data, args|
    new_type = args[0]&.to_sym

    proc { |move|
      next nil unless move.id == :WEATHERBALL
      next new_type
    }
  end

  # Terrain Pulse type change
  # PBS: TerrainPulseType = ELECTRIC
  register(:terrain_pulse_type, :morph) do |battle, field_data, args|
    new_type = args[0]&.to_sym

    proc { |move|
      next nil unless move.id == :TERRAINPULSE
      next new_type
    }
  end

  # Nature Power move change (alternative to NaturePower PBS property)
  # PBS: NaturePowerMove = THUNDERBOLT
  register(:nature_power_move, :morph) do |battle, field_data, args|
    new_move = args[0]&.to_sym

    proc { next new_move }
  end

  #=============================================================================
  # STAT STAGE EFFECTS
  #=============================================================================

  # Prevent lowering of specific stats
  # PBS: StatProtect = ATTACK,DEFENSE
  register(:stat_protect, :stat) do |battle, field_data, args|
    protected_stats = args.map { |s| s.to_sym }

    proc { |battler, stat, amount|
      next protected_stats.include?(stat) && amount < 0
    }
  end

  # Prevent raising of specific stats
  # PBS: StatBlock = EVASION,ACCURACY
  register(:stat_block, :stat) do |battle, field_data, args|
    blocked_stats = args.map { |s| s.to_sym }

    proc { |battler, stat, amount|
      next blocked_stats.include?(stat) && amount > 0
    }
  end

  # Auto stat boost for type (at battle start or switch in)
  # PBS: TypeStatBoost = FIRE,SPATK,1
  register(:type_stat_boost, :stat) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    stat = args[1]&.to_sym || :ATTACK
    stages = args[2]&.to_i || 1

    proc { |battler|
      next nil unless battler.pbHasType?(boost_type)
      next { stat: stat, stages: stages }
    }
  end

  #=============================================================================
  # CONTACT EFFECTS
  #=============================================================================

  # Damage to Pokemon making contact
  # PBS: ContactDamage = 8,The field hurts on contact!
  register(:contact_damage, :contact) do |battle, field_data, args|
    fraction = args[0]&.to_i || 8
    message = args[1]

    proc { |user, target, move|
      next nil unless move.flags.include?("Contact")
      next { fraction: fraction, message: message }
    }
  end

  # Status on contact
  # PBS: ContactStatus = BURN,30,Hot to the touch!
  register(:contact_status, :contact) do |battle, field_data, args|
    status = args[0]&.to_sym
    chance = args[1]&.to_i || 30
    message = args[2]

    proc { |user, target, move|
      next nil unless move.flags.include?("Contact")
      next { status: status, chance: chance, message: message }
    }
  end

  # Boost contact moves
  # PBS: ContactBoost = 1.3,Physical contact is enhanced!
  register(:contact_boost, :contact) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 1.3
    message = args[1]

    proc { |move|
      next nil unless move.flags.include?("Contact")
      next { multiplier: multiplier, message: message }
    }
  end

  #=============================================================================
  # SOUND EFFECTS
  #=============================================================================

  # Boost sound-based moves
  # PBS: SoundBoost = 1.5,The sound echoes!
  register(:sound_boost, :sound) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 1.5
    message = args[1]

    proc { |move|
      next nil unless move.flags.include?("Sound")
      next { multiplier: multiplier, message: message }
    }
  end

  # Block sound-based moves
  # PBS: SoundBlock = Sound can't travel here!
  register(:sound_block, :sound) do |battle, field_data, args|
    message = args[0]

    proc { |move|
      next nil unless move.flags.include?("Sound")
      next message || "The sound doesn't reach!"
    }
  end

  #=============================================================================
  # PULSE/AURA EFFECTS
  #=============================================================================

  # Boost pulse moves (Heal Pulse, Water Pulse, etc.)
  # PBS: PulseBoost = 1.5
  register(:pulse_boost, :pulse) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 1.5

    proc { |move|
      next nil unless move.flags.include?("Pulse")
      next multiplier
    }
  end

  # Boost aura moves (Aura Sphere, etc.)
  # PBS: AuraBoost = 1.5
  register(:aura_boost, :aura) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 1.5

    proc { |move|
      # Aura Sphere and similar moves
      aura_moves = [:AURASPHERE, :DARKPULSE, :DRAGONPULSE, :ORIGINPULSE]
      next nil unless aura_moves.include?(move.id)
      next multiplier
    }
  end

  #=============================================================================
  # EVASION/ACCURACY FIELD EFFECTS
  #=============================================================================

  # Global accuracy reduction (like sand/hail)
  # PBS: AccuracyPenalty = 0.8
  register(:accuracy_penalty, :accuracy) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 0.8

    proc { |move, user, target|
      next multiplier
    }
  end

  # Evasion boost for type
  # PBS: TypeEvasion = GHOST,1.2
  register(:type_evasion, :evasion) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    multiplier = args[1]&.to_f || 1.2

    proc { |battler|
      next nil unless battler.pbHasType?(boost_type)
      next multiplier
    }
  end

  #=============================================================================
  # TERRAIN EXTENSION
  #=============================================================================

  # Extend terrain duration when set
  # PBS: TerrainExtend = 3
  register(:terrain_extend, :terrain) do |battle, field_data, args|
    extra_turns = args[0]&.to_i || 3

    proc { next extra_turns }
  end

  #=============================================================================
  # ABILITY MIMICRY
  #=============================================================================

  # Mimicry ability type change
  # PBS: MimicryType = ELECTRIC
  register(:mimicry_type, :ability) do |battle, field_data, args|
    new_type = args[0]&.to_sym

    proc { |battler|
      next nil unless battler.hasActiveAbility?(:MIMICRY)
      next new_type
    }
  end

  #=============================================================================
  # EXPLOSION/SELF-DESTRUCT EFFECTS
  #=============================================================================

  # Modify explosion damage
  # PBS: ExplosionBoost = 1.5
  register(:explosion_boost, :explosion) do |battle, field_data, args|
    multiplier = args[0]&.to_f || 1.5

    proc { |move|
      explosion_moves = [:EXPLOSION, :SELFDESTRUCT, :MINDBLOWN, :MISTYEXPLOSION]
      next nil unless explosion_moves.include?(move.id)
      next multiplier
    }
  end

  # Prevent self-KO from explosion moves
  # PBS: ExplosionProtect = true
  register(:explosion_protect, :explosion) do |battle, field_data, args|
    proc { |move, user|
      explosion_moves = [:EXPLOSION, :SELFDESTRUCT, :MINDBLOWN]
      next explosion_moves.include?(move.id)
    }
  end

  #=============================================================================
  # GRAVITY-LIKE EFFECTS
  #=============================================================================

  # Ground flying types
  # PBS: GroundFlying = true
  register(:ground_flying, :gravity) do |battle, field_data, args|
    proc { |battler|
      next battler.pbHasType?(:FLYING) || battler.hasActiveAbility?(:LEVITATE)
    }
  end

  # Prevent jumping moves
  # PBS: NoJump = FLY,BOUNCE,SKYDROP
  register(:no_jump, :gravity) do |battle, field_data, args|
    blocked_moves = args.map { |m| m.to_sym }

    proc { |move|
      next blocked_moves.include?(move.id)
    }
  end

  #=============================================================================
  # BEGIN BATTLE EFFECTS
  #=============================================================================

  # Random stat boost at battle start
  # PBS: Effect = begin_random_stat_boost,1,The equilibrium of the field enhances {1}!
  register(:begin_random_stat_boost, :begin_battle) do |battle, field_data, args|
    stages = args[0]&.to_i || 1
    message = args[1]

    proc { |battler|
      stats = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
      random_stat = stats.sample
      stat_name = GameData::Stat.get(random_stat).name
      if message && !message.empty?
        battle.pbDisplay(_INTL(message.gsub("{1}", stat_name)))
      else
        battle.pbDisplay(_INTL("The field enhances {1}!", stat_name))
      end
      battler.pbRaiseStatStage(random_stat, stages, battler)
      next true
    }
  end

  # Specific stat boost at battle start
  # PBS: Effect = begin_stat_boost,ATTACK,1,grounded
  register(:begin_stat_boost, :begin_battle) do |battle, field_data, args|
    stat = args[0]&.to_sym || :ATTACK
    stages = args[1]&.to_i || 1
    condition = args[2]

    proc { |battler|
      if condition == "grounded"
        next nil unless battler.affectedByTerrain?
      end
      battler.pbRaiseStatStage(stat, stages, battler)
      next true
    }
  end

  # Type-based stat boost at battle start
  # PBS: Effect = begin_type_stat_boost,FIRE,ATTACK,1
  register(:begin_type_stat_boost, :begin_battle) do |battle, field_data, args|
    boost_type = args[0]&.to_sym
    stat = args[1]&.to_sym || :ATTACK
    stages = args[2]&.to_i || 1

    proc { |battler|
      next nil unless battler.pbHasType?(boost_type)
      battler.pbRaiseStatStage(stat, stages, battler)
      next true
    }
  end

  #=============================================================================
  # HELPER METHOD TO BUILD EFFECTS FROM PBS DATA
  #=============================================================================
  def self.build_effect(battle, effect_name, args)
    effect_data = get(effect_name)
    return nil unless effect_data

    effect_data[:proc].call(battle, nil, args)
  end
end
