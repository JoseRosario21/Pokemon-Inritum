module XP18
  # --- Party sizes ---
  XP_ENEMY_COUNT = 6
  EV_ENEMY_COUNT = 3

  # --- Trainer type (must exist in PBS/trainer_types.txt) ---
  TRAINER_TYPE = :XP18Simulation

  # --- EV mode level offset (relative to player's Pokemon) ---
  EV_LEVEL_OFFSET = -3

  # --- Heal player's party before battle ---
  HEAL_BEFORE_BATTLE = true

  # --- Level cap variable (game variable that holds the current level cap) ---
  # If using Level Caps EX, this is automatically managed (default: variable 100)
  # Otherwise, set this variable manually via events to control scaling
  LEVEL_CAP_VARIABLE = 100

  # --- Level cap bypass switch (when ON, enemy Pokemon ignore level cap clamping) ---
  # If using Level Caps EX, this matches its bypass switch (default: switch 100)
  # If not using Level Caps EX, this can be set to nil to skip bypass logic
  LEVEL_CAP_BYPASS_SWITCH = 100

  # --- Ticket items ---
  XP_TICKET = :XPTICKET
  EV_TICKET = :EVTICKET

  # --- Species blacklist (legendaries, mythicals, ultra beasts) ---
  BLACKLIST = [
    :MEWTWO, :MEW, :LUGIA, :HOOH, :CELEBI, :KYOGRE, :GROUDON,
    :RAYQUAZA, :JIRACHI, :DEOXYS, :DIALGA, :PALKIA, :GIRATINA,
    :ARCEUS, :RESHIRAM, :ZEKROM, :KYUREM, :XERNEAS, :YVELTAL,
    :ZYGARDE, :SOLGALEO, :LUNALA, :NECROZMA, :ZACIAN, :ZAMAZENTA,
    :ETERNATUS, :CALYREX, :KORAIDON, :MIRAIDON,
    :MANAPHY, :PHIONE, :DARKRAI, :SHAYMIN, :VICTINI,
    :KELDEO, :MELOETTA, :GENESECT, :DIANCIE, :HOOPA, :VOLCANION,
    :MAGEARNA, :MARSHADOW, :ZERAORA, :MELTAN, :MELMETAL,
    :ZARUDE, :REGIELEKI, :REGIDRAGO, :GLASTRIER, :SPECTRIER,
    :ENAMORUS, :TINGLU, :CHIENPAO, :WOCHIEN, :CHIYU,
    :OGERPON, :TERAPAGOS, :PECHARUNT,
    # Ultra Beasts
    :NIHILEGO, :BUZZWOLE, :PHEROMOSA, :XURKITREE,
    :CELESTEELA, :KARTANA, :GUZZLORD, :POIPOLE, :NAGANADEL,
    :STAKATAKA, :BLACEPHALON,
    # Wonder Guard makes it potentially unbeatable with limited movesets
    :SHEDINJA
  ]

  # --- Held items pool, tiered by progression ---
  # Early game: basic berries and simple boost items
  HELD_ITEMS_EARLY = [
    :ORANBERRY, :SITRUSBERRY, :LUMBERRY, :PERSIMBERRY, :RAWSTBERRY,
    :CHESTOBERRY, :PECHABERRY, :SHELLBELL, :EVIOLITE
  ]
  # Mid game: type-boosting items and moderate competitive items
  HELD_ITEMS_MID = [
    :SITRUSBERRY, :LUMBERRY, :SHELLBELL, :EVIOLITE,
    :MUSCLEBAND, :WISEGLASSES, :EXPERTBELT, :SCOPELENS,
    :FOCUSSASH, :ROCKYHELMET
  ]
  # Late game: full competitive items
  HELD_ITEMS_LATE = [
    :LEFTOVERS, :LIFEORB, :CHOICEBAND, :CHOICESCARF, :CHOICESPECS,
    :FOCUSSASH, :ASSAULTVEST, :EXPERTBELT, :MUSCLEBAND, :WISEGLASSES,
    :ROCKYHELMET, :SCOPELENS, :WEAKNESSPOLICY
  ]

  module_function

  # --- Level cap reader ---
  # Reads from the configured game variable, falls back to max level if unset
  def level_cap
    val = $game_variables[LEVEL_CAP_VARIABLE]
    (val.is_a?(Integer) && val > 0) ? val : Settings::MAXIMUM_LEVEL
  end

  # --- Level-cap-based scaling functions ---

  # XP mode enemy level range: 70-80% of current level cap
  # This keeps enemies beatable since the player's team won't be fully trained
  def xp_level_range
    cap = level_cap
    min_lv = [(cap * 0.7).floor, 5].max
    max_lv = [(cap * 0.8).floor, 5].max
    [min_lv, max_lv]
  end

  # BST range for XP mode: scales from [200,360] at cap 18 to [450,600] at cap 100
  def bst_range
    cap = level_cap
    bst_range_for_level(cap)
  end

  # BST range based on an arbitrary level reference
  # Used by both XP mode (level cap) and EV mode (pokemon level)
  def bst_range_for_level(level)
    progress = [(level - 5).to_f / 95, 0].max.clamp(0.0, 1.0)
    min_bst = (200 + 250 * progress).floor
    max_bst = (360 + 240 * progress).floor
    [min_bst, max_bst]
  end

  # Held items pool based on a Pokemon's level
  # XP mode uses level cap as reference, EV mode uses the Pokemon's actual level
  def held_items_for_level(level)
    case level
    when 0..24  then HELD_ITEMS_EARLY
    when 25..49 then HELD_ITEMS_MID
    else             HELD_ITEMS_LATE
    end
  end

  # Candy rewards: tier up as level cap increases
  def xp_rewards
    cap = level_cap
    case cap
    when 0..24  then [[:EXPCANDYS, 5]] # 4000XP Total
    when 25..34 then [[:EXPCANDYS, 2], [:EXPCANDYM, 2]] # 7600XP Total
    when 35..44 then [[:EXPCANDYM, 4]] # 12000XP Total
    when 45..54 then [[:EXPCANDYM, 4], [:EXPCANDYL, 1]] # 22000XP Total
    when 55..64 then [[:EXPCANDYL, 4]] # 40000XP Total
    when 65..74 then [[:EXPCANDYL, 6]] # 60000XP Total
    when 75..84 then [[:EXPCANDYL, 6], [:EXPCANDYXL, 1]] # 90000XP Total
    when 85..94 then [[:EXPCANDYXL, 4]] # 120000XP Total
    else             [[:EXPCANDYXL, 6]] # 180000XP Total
    end
  end
end