#===============================================================================
# Soft Continue (Overworld-Only) Version 1.1
# Essentials v21.1 + Hotfix 1.0.9 Compatible
# Author: ArtZoyd - 6/9/2025
#===============================================================================

# Patch NilClass to avoid crashes from accidental method calls on nil objects.
# Returns nil instead of throwing NoMethodError (use cautiously!)
class NilClass
  def method_missing(*)
    nil
  end
end

# Global flags to coordinate and safely control soft continues
$force_soft_continue = false      # Forces exit from battle loops if needed
$soft_continue_pending = false   # Prevents reentry into the routine mid-execution

#===============================================================================
# Main Method: pbSoftContinue
# Safely reloads the last save without returning to the title screen.
# Only works in Scene_Map (overworld).
#===============================================================================
def pbSoftContinue
  # Exit immediately if we're not in the overworld (Scene_Map).
  return unless $scene.is_a?(Scene_Map)

  # Exit if there's no saved data to load.
  return unless SaveData.exists?

  # Set a global flag to prevent multiple calls during execution.
  $soft_continue_pending = true

  # Reset the camera if using a plugin like ZoomMap or Fancy Camera.
  #pbCameraReset rescue nil

  # Dispose of background zoom object safely if it's present.
  #if $game_temp&.background_zoom
  #  $game_temp.background_zoom.dispose rescue nil
  #  $game_temp.background_zoom = nil
  #end

  # Signal to exit from any running battle or interaction loops.
  $force_soft_continue = true

  # Dispose the current scene safely and clear it out.
  $scene&.dispose rescue nil
  $scene = nil

  # Fully clear the map event interpreter to prevent it from running scripts post-reset.
  if defined?(Interpreter) && $game_system&.map_interpreter
    $game_system.map_interpreter.clear rescue nil
  end

  # Freeze graphics to prevent screen tearing or partial visuals during the transition.
  Graphics.freeze

  # Small update to allow the freeze effect to take hold.
  Graphics.update
  Input.update

  # Additional frames to let all disposal operations settle.
  4.times { Graphics.update }

  # Mark all saved values as unloaded so a fresh read from disk is clean.
  SaveData.mark_values_as_unloaded

  # Load the saved data from disk.
  data = SaveData.read_from_file(SaveData::FILE_PATH)
  Game.load(data)  # Restores all game state: player, map, switches, etc.

  # Perform screen transition before re-entering gameplay.
  Graphics.transition(10)

  # Create a fresh map scene object. This becomes active in the next update loop.
  # We do NOT call $scene.main here because that would halt interpreter flow if
  # called mid-event. Let the game naturally flow into the new scene.
  $scene = Scene_Map.new

  # Clear soft continue flags so another soft continue can occur later.
  $soft_continue_pending = false
  $force_soft_continue = false
end

#===============================================================================
# F7 Trigger for Soft Continue (Overworld Only)
# Adds keybind check to Scene_Map#update.
#===============================================================================
if defined?(Scene_Map)
  class Scene_Map
    # Prevent multiple aliases by checking if already patched
    alias update_with_soft_continue_check update unless method_defined?(:update_with_soft_continue_check)

    # Inject key press check into Scene_Map update loop
    def update
      pbSoftContinue if Input.trigger?(Input::F7)   # Soft continue when F7 is pressed
      update_with_soft_continue_check               # Run original update method
    end
  end
end