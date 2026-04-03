#===============================================================================
# Boss Battles - Ally Call (SOS)
#
# When triggered by an on_break :ally_call entry, this converts the battle to
# doubles (if it isn't already) and sends in a new wild Pokémon at slot 3
# (second foe slot).  Only one ally can be active at a time; if slot 3 is
# already occupied by a living battler the call is silently skipped.
#
# ── Nil-hole problem ─────────────────────────────────────────────────────────
# @battlers is indexed as [player0, foe0, player1, foe1].  When @sideSizes[1]
# is set to 2, maxBattlerIndex becomes 3 and ALL battle loops iterate 0..3.
# Index 2 (player side slot 1) must therefore be a real Battle::Battler object
# so those loops don't crash on nil.  We create a blank (fainted, pokemon=nil)
# battler there and guard the two engine methods that would otherwise treat it
# as an active Pokémon needing a replacement or a refresh.
#
# ── Array-for-index problem ──────────────────────────────────────────────────
# After the battle converts to doubles (singleBattle?=false), certain doubles
# code paths pass the idxBattler argument as an Array rather than an Integer.
# @battlers[array] returns an array of battlers, which crashes when methods
# like .hasTera? or .hasMega? are called on it.
#
# We use `prepend` instead of alias_method so the guards sit at the front of
# the method resolution order and work correctly regardless of which DBK
# sub-plugins are installed or what order they loaded in.
#===============================================================================

# ---------------------------------------------------------------------------
# Array-for-index guards via prepend.
#
# These methods all do @battlers[idxBattler] internally; an Array argument
# turns that into @battlers.values_at(*array) → Array, then the next call
# (e.g. .hasTera?, .hasMega?) raises NoMethodError.
#
# Returning false (cannot switch / cannot mega / cannot tera / etc.) for
# non-Integer input is the safe default.  `defined?(super)` prevents a
# NoMethodError if the plugin that defines the method isn't installed.
# ---------------------------------------------------------------------------
module BossBattle
  module ArrayIndexGuard
    def pbCanSwitchOut?(idxBattler, *args)
      return false unless idxBattler.is_a?(Integer)
      super
    end

    def pbCanMegaEvolve?(idxBattler)
      return false unless idxBattler.is_a?(Integer)
      super
    end

    def pbCanTerastallize?(idxBattler)
      return false unless idxBattler.is_a?(Integer)
      defined?(super) ? super : false
    end

    def pbCanDynamax?(idxBattler)
      return false unless idxBattler.is_a?(Integer)
      defined?(super) ? super : false
    end

    def pbCanZMove?(idxBattler)
      return false unless idxBattler.is_a?(Integer)
      defined?(super) ? super : false
    end

    def pbCanUltraBurst?(idxBattler)
      return false unless idxBattler.is_a?(Integer)
      defined?(super) ? super : false
    end

    def pbCanUseAnyBattleMechanic?(idxBattler)
      return false unless idxBattler.is_a?(Integer)
      defined?(super) ? super : false
    end
  end
end

class Battle
  prepend BossBattle::ArrayIndexGuard
end

# ---------------------------------------------------------------------------
# Guard: Battle::Scene#pbChangePokemon skips when pkmn is nil.
# pbRefreshEverything calls pbChangePokemon(i, sprite.pkmn), and the blank
# sprite at index 2 has pkmn=nil — without this guard it would crash inside
# GameData::Species.sprite_bitmap_from_pokemon.
# ---------------------------------------------------------------------------
class Battle::Scene
  alias_method :boss_orig_pbChangePokemon, :pbChangePokemon

  def pbChangePokemon(idxBattler, pkmn)
    return if !pkmn   # blank slot — nothing to display
    boss_orig_pbChangePokemon(idxBattler, pkmn)
  end
end

# ---------------------------------------------------------------------------
# Guard: Battle#pbCanChooseNonActive? returns false for blank battler slots.
# pbEORSwitch iterates all battlers; the blank fainted battler at index 2
# would normally trigger "Use next Pokémon?" because pbCanChooseNonActive?
# returns true whenever the player has live party members.  Returning false
# here prevents that replacement prompt entirely for empty slots.
# ---------------------------------------------------------------------------
class Battle
  alias_method :boss_orig_pbCanChooseNonActive?, :pbCanChooseNonActive?

  def pbCanChooseNonActive?(idxBattler)
    return false if @battlers[idxBattler] && @battlers[idxBattler].pokemon.nil?
    boss_orig_pbCanChooseNonActive?(idxBattler)
  end
end

# ---------------------------------------------------------------------------
# Main ally-call method
# ---------------------------------------------------------------------------
class Battle
  # Adds an ally to the battle on the foe side. Called from BossShieldEffects.
  # boss_battler — the boss Battle::Battler that issued the call
  # species      — Symbol for the ally's species
  # level        — Integer level
  def pbBossCallAlly(boss_battler, species, level)
    ally_idx  = 3   # second foe slot
    blank_idx = 2   # player side slot 1 — must exist to avoid nil hole

    # If slot 3 already has a living Pokémon, don't add another.
    if @battlers[ally_idx] && !@battlers[ally_idx].fainted? &&
       @battlers[ally_idx].pokemon
      pbDisplay(_INTL("{1} called for help, but nobody answered!", boss_battler.pbThis))
      return
    end

    # Generate the ally Pokémon.
    ally_pkmn = pbGenerateWildPokemon(species, level)
    ally_pkmn.instance_variable_set(:@boss_sos_mon, true)

    # Expand party2 and tracking arrays.
    @party2.push(ally_pkmn)
    party_idx = @party2.length - 1

    @initialItems[1].push(ally_pkmn.item_id)
    @recycleItems[1].push(nil)
    @belch[1].push(false)
    @battleBond[1].push(false)
    @corrosiveGas[1].push(false)
    @usedInBattle[1].push(false)

    # Expand to doubles on the foe side.
    if @sideSizes[1] < 2
      @sideSizes[1] = 2
      # Recreate the target window so it has buttons for the new foe slot.
      # TargetMenu bakes @sideSizes into a fixed-size @buttons array at creation
      # time; without a rebuild slot 3 has no button and its name never appears.
      if @scene.respond_to?(:sprites) && @scene.sprites["targetWindow"]
        @scene.sprites["targetWindow"].dispose rescue nil
        @scene.sprites["targetWindow"] = Battle::Scene::TargetMenu.new(
          @scene.viewport, 200, @sideSizes
        ) rescue nil
      end
    end

    # -------------------------------------------------------------------------
    # Slot 2 — blank battler/sprite/databox to prevent nil hole in @battlers.
    #
    # maxBattlerIndex is now 3.  Every battle loop iterates 0..3, so index 2
    # must be a real (though fainted/empty) Battle::Battler.
    # pbInitBlank (called by Battler.new) sets @hp=0, @totalhp=0, @pokemon=nil.
    # The pbCanChooseNonActive? override above prevents the engine from treating
    # this as a real empty slot that needs a replacement Pokémon.
    # -------------------------------------------------------------------------
    if @battlers[blank_idx].nil?
      @battlers[blank_idx]      = Battle::Battler.new(self, blank_idx)
      @positions[blank_idx]     = Battle::ActivePosition.new
      @successStates[blank_idx] = Battle::SuccessState.new
      pbClearChoice(blank_idx)
    end

    # Blank sprite — pbRefreshEverything calls sprite.pkmn on every slot; the
    # slot needs a real sprite so the call doesn't crash on nil.
    if @scene.respond_to?(:pbCreatePokemonSprite) &&
       @scene.sprites["pokemon_#{blank_idx}"].nil?
      @scene.pbCreatePokemonSprite(blank_idx) rescue nil
    end

    # Blank databox — PokemonDataBox.new calls initializeDataBoxGraphic and
    # refresh internally; both are safe for a nil-pokemon battler (refresh
    # returns immediately when battler.pokemon is nil).
    if @scene.respond_to?(:sprites) && @scene.sprites["dataBox_#{blank_idx}"].nil?
      @scene.sprites["dataBox_#{blank_idx}"] =
        Battle::Scene::PokemonDataBox.new(
          @battlers[blank_idx], pbSideSize(blank_idx), @scene.viewport
        ) rescue nil
    end

    # -------------------------------------------------------------------------
    # Reposition the boss sprite (slot 1) from singles to doubles layout.
    #
    # The boss sprite was created with sideSize=1 at battle start.  Now that
    # the foe side has two slots we update sideSize so pbSetPosition places it
    # at the correct doubles offset.
    # -------------------------------------------------------------------------
    boss_sprite = @scene.sprites["pokemon_#{boss_battler.index}"] rescue nil
    if boss_sprite
      boss_sprite.instance_variable_set(:@sideSize, 2)
      boss_sprite.pbSetPosition rescue nil
    end
    boss_shadow = @scene.sprites["shadow_#{boss_battler.index}"] rescue nil
    if boss_shadow
      boss_shadow.instance_variable_set(:@sideSize, 2)
      boss_shadow.pbSetPosition rescue nil
    end

    # -------------------------------------------------------------------------
    # Set up the ally battler slot (index 3).
    # -------------------------------------------------------------------------
    if @battlers[ally_idx].nil?
      @battlers[ally_idx]      = Battle::Battler.new(self, ally_idx)
      @positions[ally_idx]     = Battle::ActivePosition.new
      @successStates[ally_idx] = Battle::SuccessState.new
      pbClearChoice(ally_idx)
    end

    # Initialize the battler from the new party slot.
    @battlers[ally_idx].pbInitialize(ally_pkmn, party_idx)

    # Show the ally entering the battle.
    pbDisplay(_INTL("{1} called for help!", boss_battler.pbThis))

    # Create the Pokémon sprite for slot 3.
    if @scene.respond_to?(:pbCreatePokemonSprite) &&
       @scene.sprites["pokemon_#{ally_idx}"].nil?
      @scene.pbCreatePokemonSprite(ally_idx) rescue nil
    end

    # Set the sprite bitmap DIRECTLY rather than via pbChangePokemon.
    # pbChangePokemon re-initialises every databox in a loop; some of those
    # databoxes may not be ready yet and would crash.
    # BattlerSprite.new sets visible=false; setPokemonBitmap does NOT set it
    # to true, so we must do it explicitly.
    ally_sprite = @scene.sprites["pokemon_#{ally_idx}"] rescue nil
    if ally_sprite
      ally_sprite.setPokemonBitmap(ally_pkmn, false) rescue nil
      ally_sprite.visible = true
    end
    ally_shadow = @scene.sprites["shadow_#{ally_idx}"] rescue nil
    if ally_shadow
      ally_shadow.setPokemonBitmap(ally_pkmn) rescue nil
      ally_shadow.visible = ally_pkmn.species_data.shows_shadow? rescue nil
    end

    # Create and initialise the databox for the ally.
    # PokemonDataBox.new sets visible=false in initializeOtherGraphics, so we
    # must explicitly show it after creation.
    if @scene.respond_to?(:sprites) && @scene.sprites["dataBox_#{ally_idx}"].nil?
      @scene.sprites["dataBox_#{ally_idx}"] =
        Battle::Scene::PokemonDataBox.new(
          @battlers[ally_idx], pbSideSize(ally_idx), @scene.viewport
        ) rescue nil
      @scene.sprites["dataBox_#{ally_idx}"].visible = true rescue nil
    end

    # -------------------------------------------------------------------------
    # Reposition the boss's databox for the doubles layout.
    #
    # The boss databox was created with sideSize=1 and sits at the singles
    # position.  Now that the foe side has two slots, re-initialise its
    # graphic with sideSize=2 so it moves to the correct doubles offset and
    # no longer overlaps the ally's databox.
    # -------------------------------------------------------------------------
    boss_databox = @scene.sprites["dataBox_#{boss_battler.index}"] rescue nil
    if boss_databox && !boss_databox.disposed?
      boss_databox.initializeDataBoxGraphic(pbSideSize(boss_battler.index))
      boss_databox.x = boss_databox.spriteX
      boss_databox.y = boss_databox.spriteY
      boss_databox.refresh
    end

    # -------------------------------------------------------------------------
    # Register the new slots with the battle AI.
    #
    # The AI creates AIBattler wrapper objects at battle start for each slot.
    # Slots 2 and 3 did not exist then, so the AI has no wrapper for them.
    # Without a wrapper, set_up(ally_idx) sets @user = nil, and the AI cannot
    # choose moves — the ally stands idle every turn.
    # -------------------------------------------------------------------------
    if @battleAI.respond_to?(:battlers) && @battleAI.battlers
      ai_battlers = @battleAI.battlers
      if @battlers[blank_idx] && !ai_battlers[blank_idx]
        ai_battlers[blank_idx] = Battle::AI::AIBattler.new(@battleAI, blank_idx)
      end
      ai_battlers[ally_idx] = Battle::AI::AIBattler.new(@battleAI, ally_idx)
    end

    @scene.pbRefreshOne(ally_idx) rescue nil
    pbOnBattlerEnteringBattle(ally_idx)
    # NOTE: pbAbilitiesOnSwitchIn does not exist in Essentials 21.1.
    #       pbOnBattlerEnteringBattle already handles all entry ability triggers.

    boss_battler.boss_sos_count += 1
  end
end
