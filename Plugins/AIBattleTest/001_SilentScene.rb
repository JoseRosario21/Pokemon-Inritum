#===============================================================================
# AI Battle Test - Silent battle scene
#
# Stands in for Battle::Scene so a battle can run with no graphics, no sound and
# no input. Every method the battle engine calls on its scene is defined here as
# a no-op; the handful that return a value return the choice that keeps a battle
# moving without a player.
#
# Every method takes `*args` deliberately. Matching 80-odd real signatures by
# hand invites an ArgumentError the first time the engine passes an extra
# argument -- and a stub has no use for the arguments anyway. Where a return
# value matters it is read positionally out of args.
#
# Two deliberate omissions: `sprites` and `viewport`. The Boss Battles plugin
# guards its sprite work with `@scene.respond_to?(:sprites)`, so leaving them
# undefined makes it skip that work cleanly rather than us faking a sprite hash.
#
# The method list was taken from every `@scene.<method>` call in
# Data/Scripts/011_Battle and the battle plugins, so it matches what the engine
# actually uses rather than what Battle::Scene happens to expose.
#===============================================================================
module AIBattleTest
  class SilentScene
    # Rolling record of what the battle said, so a crash report can show the
    # last few lines before it went wrong.
    MESSAGE_HISTORY = 12

    attr_reader :messages
    attr_reader :rounds

    def initialize
      @messages = []
      @tick = 0
      @rounds = 0
    end

    # Keeps the window alive during a long run without slowing it to a crawl.
    def yield_to_graphics
      @tick += 1
      return if @tick % AIBattleTest::FRAMES_PER_YIELD != 0
      Graphics.update
      Input.update
    end

    def record(msg)
      return if msg.nil?
      @messages.push(msg.to_s.gsub("\n", " "))
      @messages.shift while @messages.length > MESSAGE_HISTORY
    end

    #---------------------------------------------------------------------------
    # Messages
    #---------------------------------------------------------------------------
    def pbDisplayMessage(*args);        record(args[0]); yield_to_graphics; nil; end
    def pbDisplay(*args);               record(args[0]); yield_to_graphics; nil; end
    def pbDisplayPausedMessage(*args);  record(args[0]); yield_to_graphics; nil; end

    # Declining optional prompts is the safe default -- it never commits the
    # battle to an action a real player did not ask for.
    def pbDisplayConfirmMessage(*args); record(args[0]); false; end

    # (msg, commands, defaultValue = 0)
    def pbShowCommands(*args);          record(args[0]); args[2] || 0; end

    #---------------------------------------------------------------------------
    # Menus. Unused while controlPlayer is on, but they must still answer safely
    # if something reaches them. -1 reads as "cancelled" throughout the engine.
    #---------------------------------------------------------------------------
    def pbCommandMenu(*args);        0;  end
    def pbCommandMenuEx(*args);      0;  end
    def pbSafariCommandMenu(*args);  0;  end
    def pbFightMenu(*args);          -1; end
    def pbItemMenu(*args);           -1; end
    def pbPartyScreen(*args);        -1; end
    def pbChooseTarget(*args);       -1; end
    def pbForgetMove(*args);         -1; end
    def pbNameEntry(*args);          args[1].respond_to?(:name) ? args[1].name : ""; end
    def pbResetCommandsIndex(*args); nil; end

    #---------------------------------------------------------------------------
    # Phase and battle lifecycle
    #---------------------------------------------------------------------------
    def pbStartBattle(*args);       nil; end
    def pbEndBattle(*args);         nil; end
    def pbBeginAttackPhase(*args);      yield_to_graphics; nil; end
    def pbBeginEndOfRoundPhase(*args);  yield_to_graphics; nil; end
    def pbUpdate(*args);                yield_to_graphics; nil; end
    def pbRefresh(*args);           nil; end
    def pbRefreshOne(*args);        nil; end
    def pbRefreshEverything(*args); nil; end
    def pbForceEndSpeech(*args);    nil; end

    # The round counter lives here because it is the one hook called once per
    # round that the harness controls. Two stall-y teams would otherwise loop
    # forever, and there is no player to press B.
    def pbBeginCommandPhase(*args)
      @rounds += 1
      if @rounds > AIBattleTest::MAX_TURNS
        raise AIBattleTest::StalledBattle, "no result after #{@rounds} rounds"
      end
      yield_to_graphics
      nil
    end

    #---------------------------------------------------------------------------
    # Sending out / recalling
    #---------------------------------------------------------------------------
    def pbSendOutBattlers(*args);     nil; end
    def pbRecall(*args);              nil; end
    def pbChangePokemon(*args);       nil; end
    def pbSwapBattlerSprites(*args);  nil; end
    def pbShowPartyLineup(*args);     nil; end
    def pbShowOpponent(*args);        nil; end
    def pbAnimateTrainerIntros(*args); nil; end
    def pbCreatePokemonSprite(*args); nil; end

    #---------------------------------------------------------------------------
    # Animations
    #---------------------------------------------------------------------------
    def pbAnimation(*args);              yield_to_graphics; nil; end
    def pbCommonAnimation(*args);        nil; end
    def pbCommonAnimationExists?(*args); false; end
    def pbDamageAnimation(*args);        nil; end
    def pbAnimateSubstitute(*args);      nil; end
    def pbItemUseAnimation(*args);       nil; end
    def pbBattlerFlee(*args);            nil; end
    def pbShowAbilitySplash(*args);      nil; end
    def pbHideAbilitySplash(*args);      nil; end
    def pbReplaceAbilitySplash(*args);   nil; end
    def pbShowHelp(*args);               nil; end
    def pbHideHelp(*args);               nil; end
    def pbShowMegaEvolution(*args);      nil; end
    def pbShowPrimalReversion(*args);    nil; end
    def pbRevertBattlerStart(*args);     nil; end
    def pbRevertBattlerEnd(*args);       nil; end

    #---------------------------------------------------------------------------
    # Capture
    #---------------------------------------------------------------------------
    def pbThrow(*args);            nil; end
    def pbThrowAndDeflect(*args);  nil; end
    def pbThrowSuccess(*args);     nil; end
    def pbHideCaptureBall(*args);  nil; end
    def pbShowPokedex(*args);      nil; end

    #---------------------------------------------------------------------------
    # Exp / levelling
    #---------------------------------------------------------------------------
    def pbEXPBar(*args);  nil; end
    def pbLevelUp(*args); nil; end

    #---------------------------------------------------------------------------
    # Battle-type specific
    #---------------------------------------------------------------------------
    def pbSafariStart(*args);          nil; end
    def pbThrowBait(*args);            nil; end
    def pbThrowRock(*args);            nil; end
    def pbBattleArenaBattlers(*args);  nil; end
    def pbBattleArenaJudgment(*args);  nil; end
    def pbWildBattleSuccess(*args);    nil; end
    def pbTrainerBattleSuccess(*args); nil; end

    #---------------------------------------------------------------------------
    # Field Effect plugin
    #---------------------------------------------------------------------------
    def set_fieldback(*args); nil; end

    #---------------------------------------------------------------------------
    # Deluxe Battle Kit. These are display-only, but the engine reaches them on
    # any battle where a Dynamax / Terastal / Ultra Burst happens, which random
    # teams do hit -- without them every such run would report a missing method.
    #---------------------------------------------------------------------------
    def pbShowDynamax(*args);      nil; end
    def pbDynamaxSendOut(*args);   nil; end
    def pbHPChanged(*args);        nil; end
    def pbShowTerastallize(*args); nil; end
    def pbRevertTera(*args);       nil; end
    def pbShowUltraBurst(*args);   nil; end

    #---------------------------------------------------------------------------
    # Safety net. If the engine or a plugin grows a new scene call, the harness
    # notes it and keeps going rather than failing the whole run -- but
    # respond_to? stays honest, so anything guarded by a capability check is
    # correctly treated as unsupported.
    #---------------------------------------------------------------------------
    def method_missing(name, *args)
      AIBattleTest.note_missing_scene_method(name)
      nil
    end

    def respond_to_missing?(_name, _include_private = false)
      false
    end
  end

  module_function

  def note_missing_scene_method(name)
    @missing_scene_methods ||= []
    @missing_scene_methods.push(name.to_s) if !@missing_scene_methods.include?(name.to_s)
  end

  def missing_scene_methods
    @missing_scene_methods ||= []
    return @missing_scene_methods
  end

  def clear_missing_scene_methods
    @missing_scene_methods = []
  end
end
