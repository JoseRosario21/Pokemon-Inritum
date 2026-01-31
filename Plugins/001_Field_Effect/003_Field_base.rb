class Battle::Field_base < Battle::Field
  def initialize(battle, duration = Battle::Field::INFINITE_FIELD_DURATION, *args)
    super(battle)
    @id       = :BASE
    @name     = _INTL("Base")
    @duration = duration
  end
end

#===============================================================================
# PBS FIELD EFFECTS REFERENCE
# Copy and modify this template to create new fields in PBS/field_effects.txt
#===============================================================================
=begin

#-------------------------------
# EXAMPLE FIELD (Complete Reference)
# This shows all available PBS properties and effects
#-------------------------------
[EXAMPLEFIELD]
Name = Example Field
Category = Custom
Tags = Outdoor,Natural,Magical
Fieldback = Example
NaturePower = THUNDERBOLT
SecretPower = 4
Duration = -1
Announcement = The field activates!|The field persists!|The field faded!

#===============================================================================
# TYPE MULTIPLIERS
# Format: TypeMultiplier = TYPE,multiplier_key,value,condition,message
# multiplier_key: power, attack, defense, final_damage, accuracy
# condition: grounded (optional)
#===============================================================================
TypeMultiplier = ELECTRIC,power,1.3,grounded,Electric moves surge!
TypeMultiplier = WATER,power,1.2,,,Water moves are boosted!
TypeMultiplier = FIRE,final_damage,0.5,,,Fire moves are weakened!

#===============================================================================
# MOVE MULTIPLIERS
# Format: MoveMultiplier = MOVENAME,multiplier_key,value,condition,message
#===============================================================================
MoveMultiplier = SURF,power,1.5,,,The waves crash harder!
MoveMultiplier = THUNDERBOLT,power,1.3,grounded,Lightning strikes!
MoveMultiplier = EARTHQUAKE,final_damage,0.5,,,The ground absorbs the shock!

#===============================================================================
# STATUS IMMUNITY
# Format: StatusImmunity = STATUS,condition
# STATUS: SLEEP, POISON, BURN, PARALYSIS, FREEZE, FROSTBITE, DROWSY, ALL
#===============================================================================
StatusImmunity = SLEEP,grounded
StatusImmunity = ALL,grounded

#===============================================================================
# TRANSFORMATIONS
# Format: TransformOn = TRIGGERMOVE,NEWFIELD,message,condition
# Use NONE as NEWFIELD to clear the field (or use DestroyOn instead)
#===============================================================================
TransformOn = SURF,FLOODED,The field flooded!
TransformOn = FLAMETHROWER,BURNING,The field caught fire!,sunny

#===============================================================================
# DESTROY TRIGGERS
# Format: DestroyOn = TRIGGERMOVE,message,condition
# Removes the field entirely without transforming
#===============================================================================
DestroyOn = DEFOG,The field was cleared!
DestroyOn = EARTHQUAKE,The field crumbled!,grounded

#===============================================================================
# COUNTERS
# Format: Counter = name,threshold,trigger,result_field,message
# trigger: type:WATER, move:SURF, category:special, flag:contact
#===============================================================================
Counter = water_buildup,3,type:WATER,FLOODED,Water flooded the field!
Counter = fire_buildup,2,type:FIRE,BURNING,The field ignited!

#===============================================================================
# COMBOS
# Format: ComboTrigger = MOVE1+MOVE2,RESULTFIELD,message
#===============================================================================
ComboTrigger = FIREPLEDGE+WATERPLEDGE,RAINBOW,A rainbow appeared!

#===============================================================================
# EFFECTS - TYPE MODIFICATION
#===============================================================================
Effect = type_add,MUDDYWATER,GROUND
Effect = type_change,CUT,GRASS
Effect = type_convert,NORMAL,GHOST

#===============================================================================
# EFFECTS - CHARGING/TURN
#===============================================================================
Effect = no_charge,DIG,DIVE,FLY
Effect = force_charge,SOLARBEAM

#===============================================================================
# EFFECTS - TARGETING
#===============================================================================
Effect = target_all,SANDATTACK,MUDSLAP

#===============================================================================
# EFFECTS - DURATION/BOOST
#===============================================================================
Effect = binding_boost,SANDTOMB,FIRESPIN,WHIRLPOOL
Effect = effect_chance_boost,LOWSWEEP,FLAMECHARGE
Effect = effect_duration,TAUNT,6

#===============================================================================
# EFFECTS - HEALING
#===============================================================================
Effect = heal_boost,SYNTHESIS,SHOREUP,MOONLIGHT
Effect = heal_reduce,RECOVER,0.5
Effect = ingrain_boost
Effect = aqua_ring_boost
Effect = leech_seed_boost

#===============================================================================
# EFFECTS - ACCURACY
#===============================================================================
Effect = accuracy_set,SLEEPPOWDER,100
Effect = accuracy_set,THUNDER,100
Effect = always_hit,SWIFT,AERIALACE
Effect = accuracy_penalty,0.8

#===============================================================================
# EFFECTS - STATUS APPLICATION
#===============================================================================
Effect = add_burn,FLAMECHARGE,30
Effect = add_paralysis,TACKLE,20
Effect = add_poison,MUDSLAP,10
Effect = add_freeze,ICEBEAM,15
Effect = add_sleep,SECRETPOWER,30
Effect = flinch_boost,BITE,HEADBUTT,60
Effect = confusion_boost,PSYBEAM,50

#===============================================================================
# EFFECTS - CRITICAL HITS
#===============================================================================
Effect = crit_boost,SLASH,NIGHTSLASH,CROSSPOISON
Effect = crit_type_boost,DARK,1
Effect = always_crit,FROSTBREATH,STORMTHROW

#===============================================================================
# EFFECTS - RECOIL
#===============================================================================
Effect = no_recoil,BRAVEBIRD,FLAREBLITZ
Effect = recoil_reduce,0.5
Effect = recoil_boost,1.5

#===============================================================================
# EFFECTS - PRIORITY
#===============================================================================
Effect = priority_boost,QUICKATTACK,1
Effect = block_priority,grounded

#===============================================================================
# EFFECTS - SPEED
#===============================================================================
Effect = speed_double,ELECTRIC
Effect = speed_halve,STEEL
Effect = speed_boost_entry,ELECTRIC,1

#===============================================================================
# EFFECTS - END OF TURN
#===============================================================================
Effect = end_turn_damage,16,grounded,The field zaps everyone!
Effect = end_turn_heal,16,grounded,The field heals everyone!
Effect = end_turn_status,POISON,10,grounded,Toxic fumes seep up!

#===============================================================================
# EFFECTS - ENTRY (Switch-in)
#===============================================================================
Effect = entry_stat_boost,FIRE,ATTACK,1
Effect = entry_status,PARALYSIS,ELECTRIC,Electricity paralyzes!

#===============================================================================
# EFFECTS - HAZARDS
#===============================================================================
Effect = hazard_boost,STEALTHROCK,2.0
Effect = hazard_type_change,STEALTHROCK,FIRE
Effect = hazard_immune,SPIKES,TOXICSPIKES

#===============================================================================
# EFFECTS - ABILITIES
#===============================================================================
Effect = grant_ability,WATERVEIL,grounded
Effect = suppress_ability,LEVITATE,HUGEPOWER
Effect = ability_boost,SWIFTSWIM,2.0
Effect = mimicry_type,ELECTRIC

#===============================================================================
# EFFECTS - MOVE FAILURE
#===============================================================================
Effect = move_block,DIG,DIVE,Can't burrow here!
Effect = type_block,GROUND,Ground moves fail here!

#===============================================================================
# EFFECTS - WEATHER INTERACTION
#===============================================================================
Effect = weather_boost,Sun,FIRE,1.3
Effect = set_weather,Sun,5

#===============================================================================
# EFFECTS - TERRAIN SEEDS
#===============================================================================
Effect = terrain_seed,ELECTRICSEED,DEFENSE,1

#===============================================================================
# EFFECTS - PROTECTION
#===============================================================================
Effect = damage_reduce,FIRE,0.5
Effect = move_immune,EARTHQUAKE,BULLDOZE

#===============================================================================
# EFFECTS - ITEMS
#===============================================================================
Effect = item_boost,LIFEORB,1.5
Effect = item_block,AIRBALLOON,EVIOLITE

#===============================================================================
# EFFECTS - CONTACT
#===============================================================================
Effect = contact_damage,8,The field hurts!
Effect = contact_status,BURN,30,Hot to touch!
Effect = contact_boost,1.3,Contact is enhanced!

#===============================================================================
# EFFECTS - SOUND
#===============================================================================
Effect = sound_boost,1.5,Sound echoes!
Effect = sound_block,Sound can't travel here!

#===============================================================================
# EFFECTS - PULSE/AURA
#===============================================================================
Effect = pulse_boost,1.5
Effect = aura_boost,1.5

#===============================================================================
# EFFECTS - STATS
#===============================================================================
Effect = stat_protect,ATTACK,DEFENSE
Effect = stat_block,EVASION,ACCURACY
Effect = type_stat_boost,FIRE,SPATK,1

#===============================================================================
# EFFECTS - EVASION
#===============================================================================
Effect = type_evasion,GHOST,1.2

#===============================================================================
# EFFECTS - FORM CHANGES
#===============================================================================
Effect = form_change,BURMY,1
Effect = form_change,WORMADAM,2

#===============================================================================
# EFFECTS - MOVE MORPHING
#===============================================================================
Effect = weather_ball_type,FIRE
Effect = terrain_pulse_type,ELECTRIC
Effect = nature_power_move,THUNDERBOLT

#===============================================================================
# EFFECTS - EXPLOSION
#===============================================================================
Effect = explosion_boost,1.5
Effect = explosion_protect

#===============================================================================
# EFFECTS - GRAVITY-LIKE
#===============================================================================
Effect = ground_flying
Effect = no_jump,FLY,BOUNCE,SKYDROP

#===============================================================================
# EFFECTS - CONSECUTIVE/ECHO
#===============================================================================
Effect = echo_boost,1.2,2.0

#===============================================================================
# EFFECTS - WEIGHT
#===============================================================================
Effect = weight_modify,0.5

#===============================================================================
# EFFECTS - TERRAIN
#===============================================================================
Effect = terrain_extend,3

#===============================================================================
# FLAGS (Custom markers for special handling)
#===============================================================================
Flags = Dangerous,Indoor,Magical


-- Example Fields


#-------------------------------
# STEAM FIELD (Transformation Target)
# Created when Water meets Fire/Electric fields
#-------------------------------
[STEAM]
Name = Steam Field
Category = Mixed
Tags = Artificial,Hot
Fieldback = Steam
NaturePower = SCALD
SecretPower = 10
Duration = -1
Announcement = Steam billows across the field!|Hot steam obscures the battlefield!|The steam dissipated!
TypeMultiplier = WATER,power,1.2
TypeMultiplier = FIRE,power,1.2
MoveMultiplier = SCALD,power,1.5
# Counter: Cold moves can condense the steam
Counter = ice_buildup,2,type:ICE,FLOODED,The steam condensed into water!
# Combo: Fire + Water pledge creates rainbow
ComboTrigger = FIREPLEDGE+WATERPLEDGE,RAINBOW,The pledges created a rainbow!

#-------------------------------
# FLOODED FIELD (Transformation Target)
# Water-covered terrain
#-------------------------------
[FLOODED]
Name = Flooded Field
Category = Water
Tags = Outdoor,Natural,Wet
Fieldback = Flooded
NaturePower = SURF
SecretPower = 11
Duration = -1
Announcement = Water covers the entire field!|The battlefield is submerged!|The floodwaters receded!
TypeMultiplier = WATER,power,1.5
TypeMultiplier = ELECTRIC,power,1.3
TypeMultiplier = FIRE,power,0.5
StatusImmunity = BURN
# Transformation: Electric moves electrify the water
TransformOn = THUNDER,ELECTRIFIED,The water became electrified!
TransformOn = THUNDERBOLT,ELECTRIFIED,Electricity courses through the water!
# Ice moves freeze the surface
TransformOn = BLIZZARD,FROZEN,The water froze solid!
Counter = ice_buildup,2,type:ICE,FROZEN,The water froze over!

#-------------------------------
# CHARRED FIELD (Transformation Target)
# Burned terrain
#-------------------------------
[CHARRED]
Name = Charred Field
Category = Destroyed
Tags = Outdoor,Artificial,Hot
Fieldback = Charred
NaturePower = INCINERATE
SecretPower = 12
Duration = -1
Announcement = The field is covered in ash and embers!|Smoke rises from the scorched earth!|The flames died down!
TypeMultiplier = FIRE,power,1.3
TypeMultiplier = GRASS,power,0.5
StatusImmunity = FREEZE
# Transformation: Rain extinguishes the fire
TransformOn = RAINDANCE,NONE,The rain extinguished the embers!

#-------------------------------
# CORRUPTED FIELD (Transformation Target)
# Dark/Poison terrain
#-------------------------------
[CORRUPTED]
Name = Corrupted Field
Category = Corrupted
Tags = Magical,Dark,Corrupted
Fieldback = Corrupted
NaturePower = DARKPULSE
SecretPower = 13
Duration = -1
Announcement = Dark energy corrupts the battlefield!|Malevolent power pulses through the area!|The corruption faded!
TypeMultiplier = DARK,power,1.4
TypeMultiplier = POISON,power,1.3
TypeMultiplier = PSYCHIC,power,0.5
TypeMultiplier = FAIRY,power,0.5
# Transformation: Fairy moves purify
Counter = fairy_buildup,3,type:FAIRY,NONE,The fairy magic purified the corruption!

#-------------------------------
# FROZEN FIELD (Transformation Target)
# Ice-covered terrain
#-------------------------------
[FROZEN]
Name = Frozen Field
Category = Ice
Tags = Outdoor,Cold
Fieldback = Frozen
NaturePower = ICEBEAM
SecretPower = 14
Duration = -1
Announcement = Ice covers the entire field!|The battlefield is frozen solid!|The ice melted away!
TypeMultiplier = ICE,power,1.4
TypeMultiplier = FIRE,power,0.7
StatusImmunity = BURN
# Transformation: Fire melts the ice
TransformOn = FLAMETHROWER,FLOODED,The fire melted the ice!
TransformOn = FIREBLAST,FLOODED,The ice melted from the intense heat!
Counter = fire_buildup,2,type:FIRE,FLOODED,The ice melted from the heat!

#-------------------------------
# BURNING FIELD (Transformation Target)
# Active fire terrain
#-------------------------------
[BURNING]
Name = Burning Field
Category = Fire
Tags = Outdoor,Hot,Dangerous
Fieldback = Burning
NaturePower = FIREBLAST
SecretPower = 15
Duration = -1
Announcement = Flames engulf the battlefield!|Fire rages across the field!|The flames died out!
TypeMultiplier = FIRE,power,1.5
TypeMultiplier = GRASS,power,0.3
TypeMultiplier = ICE,power,0.3
StatusImmunity = FREEZE
# Transformation: Water/Rain extinguishes
TransformOn = SURF,CHARRED,The water doused the flames!
TransformOn = RAINDANCE,CHARRED,The rain extinguished the fire!
Counter = water_buildup,2,type:WATER,CHARRED,The water put out the fire!

#-------------------------------
# RUINED FIELD (Transformation Target)
# Destroyed structures
#-------------------------------
[RUINED]
Name = Ruined Field
Category = Destroyed
Tags = Artificial,Rubble
Fieldback = Ruined
NaturePower = ROCKSLIDE
SecretPower = 16
Duration = -1
Announcement = Rubble and debris litter the field!|Destroyed structures surround you!|The ruins crumbled away!
TypeMultiplier = ROCK,power,1.3
TypeMultiplier = GROUND,power,1.3
TypeMultiplier = FIGHTING,power,1.2

#-------------------------------
# ELECTRIFIED FIELD (Transformation Target)
# Electrified water/terrain
#-------------------------------
[ELECTRIFIED]
Name = Electrified Field
Category = Dangerous
Tags = Artificial,Dangerous,Wet
Fieldback = Electrified
NaturePower = THUNDER
SecretPower = 17
Duration = -1
Announcement = Electricity crackles through the water!|The field is dangerously electrified!|The electrical charge dissipated!
TypeMultiplier = ELECTRIC,power,1.5
TypeMultiplier = WATER,power,1.3
StatusImmunity = SLEEP,grounded
# Very dangerous - damages grounded Pokemon each turn

#-------------------------------
# RAINBOW FIELD (Combo Target)
# Created by Fire + Water Pledge combo
#-------------------------------
[RAINBOW]
Name = Rainbow Field
Category = Magical
Tags = Magical,Beneficial
Fieldback = Rainbow
NaturePower = DAZZLINGGLEAM
SecretPower = 18
Duration = -1
Announcement = A beautiful rainbow arcs across the sky!|Prismatic light bathes the battlefield!|The rainbow faded!
TypeMultiplier = FIRE,power,1.3
TypeMultiplier = WATER,power,1.3
TypeMultiplier = GRASS,power,1.3
TypeMultiplier = FAIRY,power,1.2
# All secondary effects have increased chance (would need special handling)

=end