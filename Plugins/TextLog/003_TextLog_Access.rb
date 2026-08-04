#===============================================================================
# Text Log - Access
#
# Map key only. Reviewing a line you just missed should cost one press, not a
# trip through the pause menu -- and a menu entry for it would be dead weight
# next to a shortcut nobody would stop using.
#
# `pbViewTextLog` is still available from an event Script command if a scene
# ever wants to open it directly.
#===============================================================================

#===============================================================================
# Map shortcut.
#
# Guarded on the same conditions the built-in map keys use: no interpreter
# running, no forced movement, no message on screen, player not mid-step. Those
# guards are why this is a narrow alias rather than a frame handler -- opening a
# full scene from inside a running event would strand the interpreter.
#===============================================================================
if TextLog::ENABLE_MAP_KEY
  class Scene_Map
    alias text_log_update update unless method_defined?(:text_log_update)

    def update
      if Input.trigger?(TextLog::MAP_KEY) &&
         !$game_temp.message_window_showing &&
         !pbMapInterpreterRunning? &&
         !$game_player.moving? &&
         $PokemonGlobal && !$PokemonGlobal.forced_movement? &&
         TextLog.any?
        pbPlayDecisionSE
        pbFadeOutIn { pbViewTextLog }
        return
      end
      text_log_update
    end
  end
end
