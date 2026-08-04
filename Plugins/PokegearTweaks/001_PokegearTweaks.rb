#===============================================================================
# Pokegear Tweaks
#
#   * Removes the Phone app.
#   * Draws app buttons as text only, with no icon.
#
# Both are done from here rather than by editing Data/Scripts, so an Essentials
# update does not quietly undo them.
#===============================================================================

#-------------------------------------------------------------------------------
# Phone
#
# MenuHandlers.remove is the supported way to drop an entry another script
# registered. Deleting the registration in 008_UI_Pokegear.rb would work too,
# but would be reverted by any engine update.
#-------------------------------------------------------------------------------
MenuHandlers.remove(:pokegear_menu, :phone)

#-------------------------------------------------------------------------------
# Text-only buttons
#
# Deleting the icon PNGs on their own would CRASH the Pokegear, not fall back to
# text. PokegearButton#refresh calls pbDrawImagePositions unconditionally, which
# does AnimatedBitmap.new(pbBitmapName(path)); pbBitmapName returns the path
# unchanged when the file is missing, and AnimatedBitmap then fails to open it.
#
# So the draw has to be removed, which is what this override does. Icon files
# can then be deleted or kept -- nothing reads them either way.
#-------------------------------------------------------------------------------
class PokegearButton
  def refresh
    self.bitmap.clear
    rect = Rect.new(0, 0, @button.width, @button.height / 2)
    rect.y = @button.height / 2 if @selected
    self.bitmap.blt(0, 0, @button.bitmap, rect)
    # Centred in the button rather than offset to clear an icon that is no
    # longer drawn.
    pbDrawTextPositions(self.bitmap, [
      [@name, rect.width / 2, (rect.height / 2) - 10, :center,
       PokegearButton::TEXT_BASE_COLOR, PokegearButton::TEXT_SHADOW_COLOR]
    ])
  end
end
