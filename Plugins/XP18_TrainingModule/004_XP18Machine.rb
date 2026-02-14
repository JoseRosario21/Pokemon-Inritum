module XP18
  module_function

  # Stat display names for EV mode menu
  EV_STATS = [
    [:HP,              "HP"],
    [:ATTACK,          "Attack"],
    [:DEFENSE,         "Defense"],
    [:SPECIAL_ATTACK,  "Sp. Atk"],
    [:SPECIAL_DEFENSE, "Sp. Def"],
    [:SPEED,           "Speed"]
  ]

  #=============================================================================
  # Main entry point — call from map event: XP18.pbXP18Machine
  #=============================================================================
  def pbXP18Machine
    loop do
      choice = pbMessage(
        _INTL("Select which mode you want to use:"),
        [_INTL("XP Mode"), _INTL("EV Mode"), _INTL("Cancel")], 3
      )
      case choice
      when 0 then xp_mode
      when 1 then ev_mode
      else break
      end
    end
  end

  #=============================================================================
  # XP Mode — spend ticket, fight 6v6, earn EXP candies
  #=============================================================================
  def xp_mode
    # Check ticket
    unless $bag.has?(XP_TICKET)
      pbMessage(_INTL("You don't have an XP Ticket."))
      return
    end
    # Show rewards preview
    rewards = xp_rewards
    reward_text = rewards.map { |item, qty|
      "#{qty}x #{GameData::Item.get(item).real_name}"
    }.join(", ")
    return unless pbConfirmMessage(
      _INTL("XP Mode: Battle 6 simulated Pok\u00E9mon.\nReward: {1}\nUse 1 XP Ticket?", reward_text)
    )
    # Consume ticket
    $bag.remove(XP_TICKET, 1)
    # Heal party before battle if configured
    $player.party.each { |p| p.heal } if HEAL_BEFORE_BATTLE
    # Generate enemy team
    level_range = xp_level_range
    bst = bst_range
    team = generate_team(XP_PARTY_SIZE, level_range, bst)
    # Build trainer
    trainer = NPCTrainer.new(_INTL("Simulation"), TRAINER_TYPE)
    trainer.id = $player.make_foreign_ID
    trainer.lose_text = _INTL("Simulation complete. Good effort!")
    trainer.party = team
    # Battle rules
    setBattleRule("canlose")
    setBattleRule("noexp")
    setBattleRule("nomoney")
    won = TrainerBattle.start(trainer)
    # Outcome
    if won
      pbMessage(_INTL("Simulation complete! Distributing rewards..."))
      rewards.each do |item, qty|
        $bag.add(item, qty)
        item_name = GameData::Item.get(item).real_name
        pbMessage(_INTL("You received {1}x {2}!", qty, item_name))
      end
    else
      pbMessage(_INTL("Simulation failed. Your XP Ticket has been consumed."))
    end
    # Heal party after simulation
    $player.party.each { |pkmn| pkmn.heal }
  end

  #=============================================================================
  # EV Mode — spend ticket, pick Pokemon + stat, battle, apply EVs on win
  #=============================================================================
  def ev_mode
    # Check ticket
    unless $bag.has?(EV_TICKET)
      pbMessage(_INTL("You don't have an EV Ticket."))
      return
    end
    # Choose Pokemon from party
    pbMessage(_INTL("Select a Pok\u00E9mon for EV training."))
    pbChooseNonEggPokemon(1, 2)
    chosen_idx = pbGet(1)
    return if chosen_idx < 0
    pkmn = $player.party[chosen_idx]
    # Choose stat
    stat_commands = EV_STATS.map { |stat_id, name|
      current = pkmn.ev[stat_id] || 0
      _INTL("{1} (Current: {2})", name, current)
    }
    stat_commands.push(_INTL("Cancel"))
    stat_choice = pbMessage(
      _INTL("Which stat should be maximized for {1}?", pkmn.name),
      stat_commands, stat_commands.length
    )
    return if stat_choice >= EV_STATS.length
    ev_stat_id, ev_stat_name = EV_STATS[stat_choice]
    # Check if already maxed
    if (pkmn.ev[ev_stat_id] || 0) >= Pokemon::EV_STAT_LIMIT
      pbMessage(_INTL("{1}'s {2} EVs are already maximized!", pkmn.name, ev_stat_name))
      return
    end
    # Find currently maxed stats (252)
    maxed_stats = []
    EV_STATS.each do |sid, sname|
      next if sid == ev_stat_id
      maxed_stats.push([sid, sname]) if (pkmn.ev[sid] || 0) >= Pokemon::EV_STAT_LIMIT
    end
    # If already 2 maxed stats, player must choose which one to replace
    stat_to_replace = nil
    if maxed_stats.length >= 2
      replace_cmds = maxed_stats.map { |_, sname| _INTL("{1} (252)", sname) }
      replace_cmds.push(_INTL("Cancel"))
      pbMessage(_INTL("{1} already has {2} maximized stats.", pkmn.name, maxed_stats.length))
      replace_choice = pbMessage(
        _INTL("Which stat should be replaced?"),
        replace_cmds, replace_cmds.length
      )
      return if replace_choice >= maxed_stats.length
      stat_to_replace = maxed_stats[replace_choice][0]
      replace_name = maxed_stats[replace_choice][1]
      return unless pbConfirmMessage(
        _INTL("Replace {1} with {2} for {3}?\nThis will use 1 EV Ticket.", replace_name, ev_stat_name, pkmn.name)
      )
    else
      return unless pbConfirmMessage(
        _INTL("Maximize {1} EVs for {2}?\nThis will use 1 EV Ticket.", ev_stat_name, pkmn.name)
      )
    end
    # Consume ticket
    $bag.remove(EV_TICKET, 1)
    # Heal chosen Pokemon before training if configured
    pkmn.heal if HEAL_BEFORE_BATTLE
    # Battle loop (retry on loss, no extra ticket cost)
    won = false
    loop do
      # Generate enemy team
      team = generate_ev_team(pkmn, ev_stat_id)
      # Build trainer
      trainer = NPCTrainer.new(_INTL("EV Drill"), TRAINER_TYPE)
      trainer.id = $player.make_foreign_ID
      trainer.lose_text = _INTL("EV training session complete!")
      trainer.party = team
      # Temporarily isolate the chosen Pokemon
      original_party = $player.party.clone
      $player.party = [pkmn]
      # Battle rules
      setBattleRule("canlose")
      setBattleRule("noexp")
      setBattleRule("nomoney")
      battle_won = TrainerBattle.start(trainer)
      # Restore party
      $player.party = original_party
      if battle_won
        won = true
        break
      else
        # Heal for retry
        pkmn.heal
        retry_choice = pbMessage(
          _INTL("Training failed. Try again?"),
          [_INTL("Retry"), _INTL("Give Up")], 2
        )
        break if retry_choice == 1  # Give Up
      end
    end
    if won
      apply_evs(pkmn, ev_stat_id, stat_to_replace)
      pbMessage(_INTL("{1}'s {2} EVs were maximized to 252!", pkmn.name, ev_stat_name))
      pbMessage(_INTL("Total EVs: {1}/510.", total_evs(pkmn)))
    else
      pbMessage(_INTL("EV training cancelled. Your EV Ticket has been consumed."))
    end
    # Heal party after EV training
    $player.party.each { |p| p.heal }
  end

  #=============================================================================
  # Apply EV changes: maximize chosen stat, preserve existing maxed stats.
  # - Sets chosen stat to 252
  # - If a stat_to_replace is given, zeros that stat
  # - Zeros all non-maxed stats to stay under 510
  # Result: at most 2 stats at 252, everything else at 0
  #=============================================================================
  def apply_evs(pkmn, stat, stat_to_replace = nil)
    # Reset the replaced stat if swapping
    pkmn.ev[stat_to_replace] = 0 if stat_to_replace
    # Set the chosen stat to 252
    pkmn.ev[stat] = Pokemon::EV_STAT_LIMIT
    # Zero out all non-maxed stats to keep total under 510
    GameData::Stat.each_main do |s|
      next if (pkmn.ev[s.id] || 0) >= Pokemon::EV_STAT_LIMIT
      pkmn.ev[s.id] = 0
    end
    pkmn.calc_stats
  end

  #=============================================================================
  # Helper: total EVs for a Pokemon.
  #=============================================================================
  def total_evs(pkmn)
    total = 0
    GameData::Stat.each_main { |s| total += (pkmn.ev[s.id] || 0) }
    total
  end
end
