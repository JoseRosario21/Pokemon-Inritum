# These are one time abilities.
LIMITED_ABILITY = {
	:one_battle	=> [],
	:one_switch	=> [:DELTASTREAM, :DESOLATELAND, :DRIZZLE, :DROUGHT,
					:ELECTRICSURGE, :EMBODYASPECT, :EMBODYASPECT_1, :EMBODYASPECT_2, :EMBODYASPECT_3,
					:HADRONENGINE,
					:GRASSYSURGE,
					:INTIMIDATE,
					:MISTYSURGE,
					:ORICHALCUMPULSE,
					:PRIMORDIALSEA, :PSYCHICSURGE,
					:SANDSTREAM, :SCARE, :SNOWWARNING]
}

# These are move categories.
MOVES = {
	:move_category	 => ["damaging", "physical", "special", "status", "priority", "contact", "noncontact", "protect"],
	:move_subtype	 => ["air", "ball", "beam", "biting", "bomb", "bone", "charging", "dance", "drain", "drill", "explosion", "field",
						 "flinching", "head", "healing", "horn", "kicking", "multihit", "powder", "pulse", "punching", "rampage",
						 "recharging", "recoil", "slicing", "sound", "trapping", "weather", "wind", "wing"],
	:air_move		 => [],
	:ball_move 		 => [],
	:beam_move 		 => [],
	:biting_move 	 => [],
	:bomb_move 		 => [],
	:bone_move 		 => [],
	:charging_move 	 => [],
	:dance_move 	 => [],
	:drain_move 	 => [],
	:drill_move		 => [],
	:explosion_move  => [],
	:field_move		 => [],
	:flinching_move  => [],
	:head_move		 => [],
	:healing_move 	 => [],
	:horn_move		 => [],
	:kicking_move	 => [],
	:multihit_move	 => [],
	:powder_move 	 => [],
	:pulse_move 	 => [],
	:punching_move 	 => [],
	:rampage_move	 => [],
	:recharging_move => [],
	:recoil_move 	 => [],
	:slicing_move	 => [],
	:sound_move 	 => [],
	:trapping_move	 => [],
	:weather_move	 => [],
	:wind_move 		 => [],
	:wing_move 		 => []
}

EFFECTS = {
    :battler_effect => {}
}

# These are in-battle field effects.
FIELD_EFFECTS = {
	:Template => {
		:field_name_bg						=> ["Template", "TemplateField"],
		:field_DBK_EBUI_display				=> ["Template Field", "Something happens on this field."],
		:message_start_continue_end			=> ["xxx", "xxx", "xxx"],
		:weather_terrain_effect				=> { "weather" => [nil, nil], "terrain" => [nil, nil] },
		:other_weather_terrain_effect		=> { "no weather" => false, "perm weather" => false, "no terrain" => false, "perm terrain" => false }, # true for perm or number for turns
		:global_field_effect				=> { "Fairy Lock" => 0, "Gravity" => 0, "Inverse Room" => 0, "Magic Room" => 0, "Trick Room" => 0, "Wonder Room" => 0 },
		:block_status						=> { "sleep" => false, "toxic" => false, "burn" => false, "paralysis" => false, "frozen" => false, "drowsy" => false, "frostbite" => false, "yawn" => false, "confusion" => false },
		:block_move							=> { "priority" => false, "status" => false, "healing" => false, "protect" => true },
		:hidden_power_type					=> nil,
		:other_effect						=> { "inverse battle" => false, "no raise" => false, "no lower" => false, "no switch" => false, "no heal" => false, "no item" => false, "abil un-ltd" => false },
		:battler_type_change     			=> { [] => [nil, nil, nil] }, # true for all or an array
		:battler_ability_change     		=> { [] => nil },
		:battler_ability_add	     		=> { [] => [] }, # multi-ability need other plugin (Innate Abilities/Infinite Ability/All Abilities Mutation, have not tested)
		:battler_speed_change     			=> { [] => 1.0 },
		:battler_start_switch_status		=> [nil, { "chance" => nil }, { "badly poisoned" => false }],
		:battler_start_switch_hp			=> { false => { "hp lost" => nil, "hp gain" => nil } }, # e.g. "hp gain" => 1 / 4.0, true for all or an array
		:battler_start_switch_buff			=> { [] => { :ATTACK => 1 } },
		:battler_start_switch_cure			=> { "sleep" => false, "toxic" => false, "burn" => false, "paralysis" => false, "frozen" => false, "drowsy" => false, "frostbite" => false },
		:battler_start_switch_effect		=> { },   ### to-do
		:EOR_effect_status					=> [nil, { "chance" => nil }, { "badly poisoned" => false }],
		:EOR_effect_hp						=> { nil => { "hp lost" => nil, "hp gain" => nil } }, # e.g. "hp gain" => 1 / 4.0, true for all or an array
		:EOR_effect_buff					=> { [] => { :ATTACK => 1 } },
		:user_target_boost					=> { [nil, nil] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_target_range					=> [], # moves hit all targets	
		:move_priority			 			=> { [] => 1 },
		:move_priority_type			 		=> { [] => 1 },
		:move_priority_subtype			 	=> { [] => 1 },
		:move_accuracy						=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_accuracy_type					=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_accuracy_subtype				=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_type_change					=> { [] => nil },
		:move_type_change_type				=> { [] => nil },
		:move_type_change_subtype			=> { [] => nil },
		:move_type_add						=> { [] => nil },
		:move_type_add_type					=> { [] => nil },
		:move_type_add_subtype				=> { [] => nil },
		:move_boost							=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_type					=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_subtype					=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_message					=> { "The field strengthened the attack!" => [], "The field weakened the attack!" => [] },
		:move_effect_add					=> { },   ### to-do
		:move_change_field					=> { [] => [nil, nil] },   ### to-do
		:field_change_message				=> { "xxx" => [] }   ### to-do
	},
	:Beach => {
		:field_name_bg						=> ["Beach", "BeachField"],
		:field_DBK_EBUI_display				=> ["Beach Field", "A soothing breeze flows through the beach."],
		:message_start_continue_end			=> [nil, nil, nil],
		:weather_terrain_effect				=> { "weather" => [nil, nil], "terrain" => [nil, nil] },
		:other_weather_terrain_effect		=> { "no weather" => false, "perm weather" => false, "no terrain" => false, "perm terrain" => false }, # true for perm or number for turns
		:global_field_effect				=> { "Fairy Lock" => 0, "Gravity" => 0, "Inverse Room" => 0, "Magic Room" => 0, "Trick Room" => 0, "Wonder Room" => 0 },
		:block_status						=> { "sleep" => false, "toxic" => false, "burn" => false, "paralysis" => false, "frozen" => false, "drowsy" => false, "frostbite" => false, "yawn" => false, "confusion" => false },
		:block_move							=> { "priority" => false, "status" => false, "healing" => false, "protect" => true },
		:hidden_power_type					=> nil,
		:other_effect						=> { "inverse battle" => false, "no raise" => false, "no lower" => false, "no switch" => false, "no heal" => false, "no item" => false, "abil un-ltd" => false },
		:battler_type_change     			=> { [] => [nil, nil, nil] }, # true for all or an array
		:battler_ability_change     		=> { [] => nil },
		:battler_ability_add	     		=> { [] => [] }, # multi-ability need other plugin (Innate Abilities/Infinite Ability/All Abilities Mutation, have not tested)
		:battler_speed_change     			=> { [] => 0.9 },
		:battler_start_switch_status		=> [nil, { "chance" => nil }, { "badly poisoned" => false }],
		:battler_start_switch_hp			=> { false => { "hp lost" => nil, "hp gain" => nil } }, # e.g. "hp gain" => 1 / 4.0, true for all or an array
		:battler_start_switch_buff			=> { [] => { :ATTACK => 1 } },
		:battler_start_switch_cure			=> { "sleep" => false, "toxic" => false, "burn" => false, "paralysis" => false, "frozen" => false, "drowsy" => false, "frostbite" => false },
		:battler_start_switch_effect		=> { },   ### to-do
		:EOR_effect_status					=> [nil, { "chance" => nil }, { "badly poisoned" => false }],
		:EOR_effect_hp						=> { nil => { "hp lost" => nil, "hp gain" => nil } }, # e.g. "hp gain" => 1 / 4.0, true for all or an array
		:EOR_effect_buff					=> { [] => { :ATTACK => 1 } },
		:user_target_boost					=> { [nil, nil] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_target_range					=> [], # moves hit all targets	
		:move_priority			 			=> { [] => 1 },
		:move_priority_type			 		=> { [] => 1 },
		:move_priority_subtype			 	=> { [] => 1 },
		:move_accuracy						=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_accuracy_type					=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_accuracy_subtype				=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_type_change					=> { [] => nil },
		:move_type_change_type				=> { [] => nil },
		:move_type_change_subtype			=> { [] => nil },
		:move_type_add						=> { [] => nil },
		:move_type_add_type					=> { [] => nil },
		:move_type_add_subtype				=> { [] => nil },
		:move_boost							=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_type					=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_subtype					=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_message					=> { "The field strengthened the attack!" => [], "The field weakened the attack!" => [] },
		:move_effect_add					=> { },   ### to-do
		:move_change_field					=> { [] => [nil, nil] },   ### to-do
		:field_change_message				=> { "xxx" => [] }   ### to-do
	},
#===============================================================================
# Do NOT touch this
#===============================================================================
	:None => {
		:field_name_bg						=> [nil, nil],
		:field_DBK_EBU_display				=> [nil, nil],
		:message_start_continue_end			=> [nil, nil, nil],
		:weather_terrain_effect				=> { "weather" => [nil, nil], "terrain" => [nil, nil] },
		:other_weather_terrain_effect		=> { "no weather" => false, "perm weather" => false, "no terrain" => false, "perm terrain" => false }, # true for perm or number for turns
		:global_field_effect				=> { "Fairy Lock" => 0, "Gravity" => 0, "Inverse Room" => 0, "Magic Room" => 0, "Trick Room" => 0, "Wonder Room" => 0 },
		:block_status						=> { "sleep" => false, "toxic" => false, "burn" => false, "paralysis" => false, "frozen" => false, "drowsy" => false, "frostbite" => false, "yawn" => false, "confusion" => false },
		:block_move							=> { "priority" => false, "status" => false, "healing" => false, "protect" => false },
		:hidden_power_type					=> nil,
		:other_effect						=> { "inverse battle" => false, "no raise" => false, "no lower" => false, "no switch" => false, "no heal" => false, "no item" => false, "abil un-ltd" => false },
		:battler_type_change     			=> { [] => [nil, nil, nil] }, # true for all or an array
		:battler_ability_change     		=> { [] => nil },
		:battler_ability_add	     		=> { [] => [] }, # multi-ability need other plugin (Innate Abilities/Infinite Ability/All Abilities Mutation, have not tested)
		:battler_speed_change     			=> { [] => 1.0 },
		:battler_start_switch_status		=> [nil, { "chance" => nil }, { "badly poisoned" => false }],
		:battler_start_switch_hp			=> { false => { "hp lost" => nil, "hp gain" => nil } }, # e.g. "hp gain" => 1 / 4.0, true for all or an array
		:battler_start_switch_buff			=> { [] => { :ATTACK => 1 } },
		:battler_start_switch_cure			=> { "sleep" => false, "toxic" => false, "burn" => false, "paralysis" => false, "frozen" => false, "drowsy" => false, "frostbite" => false },
		:battler_start_switch_effect		=> { },   ### to-do
		:EOR_effect_status					=> [nil, { "chance" => nil }, { "badly poisoned" => false }],
		:EOR_effect_hp						=> { nil => { "hp lost" => nil, "hp gain" => nil } }, # e.g. "hp gain" => 1 / 4.0, true for all or an array
		:EOR_effect_buff					=> { [] => { :ATTACK => 1 } },
		:user_target_boost					=> { [nil, nil] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_target_range					=> [], # moves hit all targets	
		:move_priority			 			=> { [] => 1 },
		:move_priority_type			 		=> { [] => 1 },
		:move_priority_subtype			 	=> { [] => 1 },
		:move_accuracy						=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_accuracy_type					=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_accuracy_subtype				=> { [] => { "base" => nil, "modifier" => 1.0 } },
		:move_type_change					=> { [] => nil },
		:move_type_change_type				=> { [] => nil },
		:move_type_change_subtype			=> { [] => nil },
		:move_type_add						=> { [] => nil },
		:move_type_add_type					=> { [] => nil },
		:move_type_add_subtype				=> { [] => nil },
		:move_boost							=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_type					=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_subtype					=> { [] => { "power" => 1.0, "atk" => 1.0, "sp_atk" => 1.0, "dmg" => 1.0 } },
		:move_boost_message					=> { "The field strengthened the attack!" => [], "The field weakened the attack!" => [] },
		:move_effect_add					=> { },   ### to-do
		:move_change_field					=> { [] => [nil, nil] },   ### to-do
		:field_change_message				=> { "xxx" => [] }   ### to-do
	}
}