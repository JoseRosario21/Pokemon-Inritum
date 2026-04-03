#===============================================================================
# Daily Rifts - Battle & Catch
#
# Execution order inside the battle:
#   1. Attack animation plays fully.
#   2. HP drops to 0 via normal pbReduceHP (bar empties).
#   3. pbFaint is called — we intercept here.
#   4. Custom "trembling" message + confusion animation replace the faint drop.
#   5. Player picks a Poké Ball (one attempt) or cancels.
#   6. Original pbFaint resumes: faint drop animation + battle cleanup.
#   7. Battle ends (outcome 1). Post-battle code checks rift_caught_pokemon.
#===============================================================================

#-------------------------------------------------------------------------------
# Module-level slot for passing the caught Pokémon back to the API post-battle.
#-------------------------------------------------------------------------------
module DailyRifts
  @rift_caught_pokemon = nil
  class << self
    attr_accessor :rift_caught_pokemon
  end
end

#-------------------------------------------------------------------------------
# Intercept pbFaint for the rift Pokémon.
# At this point: attack animation done, HP bar shows 0, faint is about to play.
# We substitute the faint message + faint animation with confusion + catch prompt,
# then call the original pbFaint with showMessage=false so only the sprite-drop
# and cleanup logic runs.
#-------------------------------------------------------------------------------
class Battle::Battler
  alias_method :daily_rifts_orig_pbFaint, :pbFaint

  def pbFaint(showMessage = true)
    pkmn = @pokemon

    if pkmn.instance_variable_defined?(:@rift_catch_rate) &&
       !pkmn.instance_variable_defined?(:@rift_catch_done)

      pkmn.instance_variable_set(:@rift_catch_done, true)

      # Replace the "X fainted!" message with a stunned message
      @battle.pbDisplayBrief(_INTL("{1} is trembling with exhaustion!", pbThis))

      # Confusion animation in place of the faint drop
      @battle.scene.pbCommonAnimation("Confusion", self) rescue nil

      # One-chance catch prompt
      caught = DailyRifts.in_battle_catch_prompt(@battle, self)
      DailyRifts.rift_caught_pokemon = pkmn if caught

      # Resume with showMessage=false — skip "X fainted!" but keep sprite-drop
      # and all battle cleanup (pbSetDefeated, effects reset, etc.)
      daily_rifts_orig_pbFaint(false)
      return
    end

    daily_rifts_orig_pbFaint(showMessage)
  end
end

#===============================================================================
module DailyRifts
  module_function

  # Builds the rift battle Pokémon: normal wild generation + 2 perfect IVs
  # + boosted catch rate stored on the instance.
  def build_rift_pokemon(species, level)
    pkmn = pbGenerateWildPokemon(species, level)

    iv_stats = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
    iv_stats.sample(GUARANTEED_PERFECT_IVS).each { |stat| pkmn.iv[stat] = Pokemon::IV_STAT_LIMIT }
    pkmn.calc_stats

    species_cr = GameData::Species.get(species).catch_rate
    pkmn.instance_variable_set(:@rift_catch_rate, (species_cr * CATCH_RATE_MULTIPLIER).clamp(1, 255))

    return pkmn
  end

  # Starts the rift battle. Balls are disabled so the only catch window is
  # the rift prompt that fires inside pbFaint.
  def start_rift_battle(entry)
    DailyRifts.rift_caught_pokemon = nil

    pkmn = build_rift_pokemon(entry[:species], entry[:level])

    setBattleRule("canLose")
    setBattleRule("noExp")
    setBattleRule("noMoney")
    setBattleRule("disablePokeBalls")

    return WildBattle.start_core(pkmn)
  end

  # Mid-battle catch prompt — called from the pbFaint alias while the sprite
  # is still visible and the battle message box is open.
  # Returns true if the Pokémon was caught, false otherwise.
  def in_battle_catch_prompt(battle, battler)
    pkmn         = battler.pokemon
    species_name = GameData::Species.get(pkmn.species).name

    # Collect Poké Balls in the bag
    available_balls = []
    GameData::Item.each do |item_data|
      next unless item_data.is_poke_ball? && $bag.has?(item_data.id)
      available_balls << item_data.id
    end

    if available_balls.empty?
      battle.pbDisplayPaused(
        _INTL("But you have no Poké Balls!\n{1} slips back into the rift...", species_name))
      return false
    end

    ball_names = available_balls.map { |id| GameData::Item.get(id).name }
    ball_names << _INTL("Don't throw")

    choice = pbMessage(
      _INTL("Your only chance!\nWhich ball will you throw at {1}?", species_name),
      ball_names,
      ball_names.length - 1)

    if choice == ball_names.length - 1
      battle.pbDisplayPaused(_INTL("{1} vanishes back into the rift...", species_name))
      return false
    end

    chosen_ball = available_balls[choice]
    $bag.remove(chosen_ball, 1)
    ball_name = GameData::Item.get(chosen_ball).name

    num_shakes = rift_catch_shakes(pkmn, chosen_ball)

    # Brief message then throw animation (mirrors normal pbThrowPokeBall flow)
    battle.pbDisplayBrief(_INTL("You threw a {1}!", ball_name))
    battle.scene.pbThrow(chosen_ball, num_shakes, false, battler.index, false)

    if num_shakes >= 4
      battle.pbDisplayPaused(_INTL("Gotcha! {1} was caught!", species_name))
      return true
    else
      msgs = [
        _INTL("Oh! So close..."),
        _INTL("Darn! Almost stayed in!"),
        _INTL("Aargh! Almost had it!"),
      ]
      battle.pbDisplayPaused(msgs[[num_shakes - 1, 0].max]) if num_shakes > 0
      battle.pbDisplayPaused(
        _INTL("{1} broke free and vanished back into the rift!", species_name))
      return false
    end
  end

  # Replicates Essentials' catch shake formula outside a full battle context.
  # HP is 0 at this point (pbFaint context) → maximises the HP factor.
  def rift_catch_shakes(pkmn, ball)
    return 4 if ball == :MASTERBALL

    ball_mod = case ball
               when :GREATBALL then 1.5
               when :ULTRABALL then 2.0
               else 1.0
               end

    catch_rate = pkmn.instance_variable_get(:@rift_catch_rate) || pkmn.species_data.catch_rate
    cr = (catch_rate * ball_mod).floor.clamp(1, 255)

    # b=0 (HP is 0 when pbFaint fires) → x = cr (maximum HP contribution)
    a = pkmn.totalhp
    b = [pkmn.hp, 0].max
    x = a > 0 ? (((3 * a - 2 * b) * cr.to_f) / (3 * a)).floor.clamp(1, 255) : cr
    return 4 if x >= 255

    y = (65_536 / ((255.0 / x)**0.1875)).floor

    num_shakes = 0
    4.times do |i|
      break if num_shakes < i
      num_shakes += 1 if rand(65_536) < y
    end
    return num_shakes
  end

end
