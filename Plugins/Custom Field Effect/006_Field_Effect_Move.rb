class Battle::Move
  def pbDamagingMove?
    return damagingMove?
  end

  def pbPhysicalMove?
	return true if physicalMove?
	return true if function_code == "UseUserAttackInsteadOfUserSpAtk"
	return function_code == "UseTargetDefenseInsteadOfTargetSpDef"
  end

  def pbSpecialMove?
    return true if specialMove?
	return true if function_code == "UseUserSpAtkInsteadOfUserAttack"
	return function_code == "UseTargetSpDefInsteadOfTargetDefense"
  end

  def pbStatusMove?
    return statusMove?
  end

#===============================================================================
#
#===============================================================================
  alias field_effect_pbPriority pbPriority
  def pbPriority(user)
    ret = field_effect_pbPriority(user)
	ret = pbPriority_field_effect(user, ret)
    return ret
  end

  alias field_effect_pbTarget pbTarget
  def pbTarget(_user)
    ret = field_effect_pbTarget(_user)
	fe = FIELD_EFFECTS[@battle.field.field_effect]
	moves = fe[:move_target_range]
	ret = GameData::Target.get(:AllNearFoes) if moves.any? && moves.include?(@id)
    return ret
  end

  def priorityMove?(user = nil)
    return true if user && @battle.choices[user.index][4] > 0
	return true if pbPriority(user) > 0
	return @priority > 0
  end

  def contactMove?
    return true if @flags.any? { |f| f[/^Contact$/i] }
  end
  
  if PluginManager.installed?("Demanding Yellow Custom Scripts")
    def pbContactMove?(user, target)
      return true  if user.hasActiveAbility?(:CLOSETOUCH) || target.hasActiveAbility?(:CLOSETOUCH)
      return false if user.hasActiveItem?(:PUNCHINGGLOVE) && punchingMove?
      return false if user.hasActiveAbility?(:LONGREACH) || target.hasActiveAbility?(:LONGREACH)
      return contactMove?
    end
  end

  def protectMove?
    return true if @flags.any? { |f| f[/^Protect$/i] }
	return [:DETECT, :ENDURE, :PROTECT, :KINGSSHIELD, :SPIKYSHIELD, :BANEFULBUNKER, :OBSTRUCT, :SILKTRAP, :BURNINGBULWARK, :MATBLOCK, :WIDEGUARD, :QUICKGUARD].include?(@id)
  end
  
#===============================================================================
#
#===============================================================================
  def airMove?
    return true if @flags.any? { |f| f[/^Air$/i] }
	return MOVES[:air_move].include?(@id)
  end

  def ballMove?
    return true if @flags.any? { |f| f[/^Ball$/i] }
	return MOVES[:ball_move].include?(@id)
  end

  def beamMove?
    return true if @flags.any? { |f| f[/^Beam$/i] }
	return MOVES[:beam_move].include?(@id)
  end

  def bitingMove?
    return true if @flags.any? { |f| f[/^Biting$/i] }
	return MOVES[:biting_move].include?(@id)
  end

  def bombMove?
    return true if @flags.any? { |f| f[/^Bomb$/i] }
	return MOVES[:bomb_move].include?(@id)
  end

  def boneMove?
    return true if @flags.any? { |f| f[/^Bone$/i] }
	return MOVES[:bone_move].include?(@id)
  end

  def chargingMove?
    return true if @flags.any? { |f| f[/^Charging$/i] }
	return MOVES[:charging_move].include?(@id)
  end

  def chargeMove?
    return chargingMove?
  end

  def danceMove?
    return true if @flags.any? { |f| f[/^Dance$/i] }
	return MOVES[:dance_move].include?(@id)
  end

  def drainMove?
    return true if @flags.any? { |f| f[/^Drain$/i] }
	return MOVES[:drain_move].include?(@id)
  end

  def drillMove?
    return true if @flags.any? { |f| f[/^Drill$/i] }
	return MOVES[:drill_move].include?(@id)
  end

  def explosionMove?
    return true if @flags.any? { |f| f[/^Explosion$/i] }
	return MOVES[:explosion_move].include?(@id)
  end

  def fieldMove?
    return true if @flags.any? { |f| f[/^Field$/i] }
	return MOVES[:field_move].include?(@id)
  end

  def flinchingMove?
    return true if @flags.any? { |f| f[/^Flinching$/i] }
	return MOVES[:flinching_move].include?(@id)
  end

  def headMove?
    return true if @flags.any? { |f| f[/^Head$/i] }
	return MOVES[:head_move].include?(@id)
  end

  def healingMove?
    return true if @flags.any? { |f| f[/^Healing$/i] }
	return MOVES[:healing_move].include?(@id)
  end

  def hornMove?
    return true if @flags.any? { |f| f[/^Horn$/i] }
	return MOVES[:horn_move].include?(@id)
  end

  def kickingMove?
    return true if @flags.any? { |f| f[/^Kicking$/i] }
	return MOVES[:kicking_move].include?(@id)
  end

  def multiHitMove?
    return true if @flags.any? { |f| f[/^MultiHit$/i] }
	return MOVES[:multihit_move].include?(@id)
  end

  def powderMove?
    return true if @flags.any? { |f| f[/^Powder$/i] }
	return MOVES[:powder_move].include?(@id)
  end

  def pulseMove?
    return true if @flags.any? { |f| f[/^Pulse$/i] }
	return MOVES[:pulse_move].include?(@id)
  end

  def punchingMove?
    return true if @flags.any? { |f| f[/^Punching$/i] }
	return MOVES[:punching_move].include?(@id)
  end

  def rampageMove?
    return true if @flags.any? { |f| f[/^Rampage$/i] }
	return MOVES[:rampage_move].include?(@id)
  end

  def rechargingMove?
    return true if @flags.any? { |f| f[/^Recharging$/i] }
	return MOVES[:recharging_move].include?(@id)
  end

  def recoilMove?
    return true if @flags.any? { |f| f[/^Recoil$/i] }
	return MOVES[:recoil_move].include?(@id)
  end

  def slicingMove?
    return true if @flags.any? { |f| f[/^Slicing$/i] }
	return MOVES[:slicing_move].include?(@id)
  end

  def soundMove?
    return true if @flags.any? { |f| f[/^Sound$/i] }
	return MOVES[:sound_move].include?(@id)
  end

  def trappingMove?
    return true if @flags.any? { |f| f[/^Trapping$/i] }
	return MOVES[:trapping_move].include?(@id)
  end

  def weatherMove?
    return true if @flags.any? { |f| f[/^Weather$/i] }
	return MOVES[:weather_move].include?(@id)
  end

  def windMove?
    return true if @flags.any? { |f| f[/^Wind$/i] }
	return MOVES[:wind_move].include?(@id)
  end

  def wingMove?
    return true if @flags.any? { |f| f[/^Wing$/i] }
	return MOVES[:wing_move].include?(@id)
  end

#===============================================================================
#
#===============================================================================
  alias field_effect_pbCalcType pbCalcType
  def pbCalcType(user)
    ret = field_effect_pbCalcType(user)
	ret = pbCalcType_field_effect(user, ret)
    return ret
  end

  alias field_effect_pbCalcTypeModSingle pbCalcTypeModSingle
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = field_effect_pbCalcTypeModSingle(moveType, defType, user, target)
	ret = pbCalcTypeModSingle_field_effect(moveType, defType, user, target, ret)
	return ret
  end

  alias field_effect_pbCalcAccuracyModifiers pbCalcAccuracyModifiers
  def pbCalcAccuracyModifiers(user, target, modifiers)
    pbCalcAccuracyModifiers_field_effect(user, target, modifiers)
    field_effect_pbCalcAccuracyModifiers(user, target, modifiers)
  end

  alias field_effect_pbCalcDamageMultipliers pbCalcDamageMultipliers
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    pbCalcDamageMults_field_effect(user, target, numTargets, type, baseDmg, multipliers)
	field_effect_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
  end

  if PluginManager.installed?("Deluxe Battle Kit")
    def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
      args = [user, target, numTargets, type, baseDmg]
	  pbCalcDamageMults_field_effect(*args, multipliers)
      pbCalcDamageMults_Global(*args, multipliers)
      pbCalcDamageMults_Abilities(*args, multipliers)
      pbCalcDamageMults_Items(*args, multipliers)
      # Parental Bond's second attack
	  if user.effects[PBEffects::ParentalBond] == 2
	    multipliers[:power_multiplier] *= 0.25 if user.hasActiveAbility?(:MULTIHEADED)
	  elsif user.effects[PBEffects::ParentalBond] == 1
	    multipliers[:power_multiplier] *= 0.5 if user.hasActiveAbility?([:RAGINGBOXER, :PRIMALMAW])
        multipliers[:power_multiplier] *= 0.25 if user.hasActiveAbility?([:PARENTALBOND, :HYPERAGGRESSIVE])
	    multipliers[:power_multiplier] *= 0.125 if user.hasActiveAbility?(:MULTIHEADED)
	  end
      pbCalcDamageMults_Other(*args, multipliers)
      pbCalcDamageMults_Field(*args, multipliers)
      pbCalcDamageMults_Badges(*args, multipliers)
      multipliers[:final_damage_multiplier] *= 0.75 if numTargets > 1
      pbCalcDamageMults_Weather(*args, multipliers)
      pbCalcDamageMults_Random(*args, multipliers)
      pbCalcDamageMults_Type(*args, multipliers)
      pbCalcDamageMults_Status(*args, multipliers)
      pbCalcDamageMults_Screens(*args, multipliers)
      multipliers[:final_damage_multiplier] *= 2 if target.effects[PBEffects::Minimize] && tramplesMinimize?
      if defined?(PBEffects::GlaiveRush) && target.effects[PBEffects::GlaiveRush] > 0
        multipliers[:final_damage_multiplier] *= 2 
      end
      multipliers[:power_multiplier] = pbBaseDamageMultiplier(multipliers[:power_multiplier], user, target)
      multipliers[:final_damage_multiplier] = pbModifyDamage(multipliers[:final_damage_multiplier], user, target)
    end
  end
end