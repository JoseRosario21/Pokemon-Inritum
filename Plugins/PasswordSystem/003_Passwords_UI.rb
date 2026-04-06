##─────────────────────────────────────────────────────────────────────────────
## Password System — UI
##─────────────────────────────────────────────────────────────────────────────

#-------------------------------------------------------------------------------
# Pokémon gift slide-in animation (mirrors Mystery Gift style).
# Called before nickname prompt so the player sees the Pokémon first.
#-------------------------------------------------------------------------------
def pbPasswordPokemonGiftAnimation(pkmn)
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99_999
  sprites = {}
  addBackgroundPlane(sprites, "bg", "mysterygift_bg", viewport)
  pbFadeInAndShow(sprites)

  sprite = PokemonSprite.new(viewport)
  sprite.setOffset(PictureOrigin::CENTER)
  sprite.setPokemonBitmap(pkmn)
  sprite.x = Graphics.width / 2
  sprite.y = -sprite.bitmap.height

  # Slide in from top
  timer_start = System.uptime
  start_y     = sprite.y
  loop do
    sprite.y = lerp(start_y, Graphics.height / 2, 1.5, timer_start, System.uptime)
    Graphics.update
    Input.update
    sprite.update
    break if sprite.y >= Graphics.height / 2
  end

  pbMEPlay("Battle capture success")
  pbWait(2.5) { sprite.update }

  msgwindow = pbCreateMessageWindow
  pbMessageDisplay(msgwindow,
    _INTL("{1} received {2}!", $player.name, pkmn.name) + "\\me[Pkmn get]\\wtnp[80]"
  ) { sprite.update }
  pbDisposeMessageWindow(msgwindow)

  # Fade out sprite
  timer_start = System.uptime
  loop do
    sprite.opacity = lerp(255, 0, 1.5, timer_start, System.uptime)
    Graphics.update
    Input.update
    sprite.update
    break if sprite.opacity <= 0
  end

  pbFadeOutAndHide(sprites)
  sprite.dispose
  pbDisposeSpriteHash(sprites)
  viewport.dispose
end

#-------------------------------------------------------------------------------
# Main password entry menu.
# Can be called from PokéGear, NPCs, or any map event.
#-------------------------------------------------------------------------------
def pbPasswordMenu
  pbMessage(_INTL("Enter a password to receive a gift or unlock a feature."))
  loop do
    raw = pbMessageFreeText(_INTL("Enter your password."), "", false, 30)
    break if raw.strip.empty?

    key = raw.strip.upcase
    effect = PasswordSystem::PASSWORDS[key]

    if effect.nil?
      pbMessage(_INTL("That password is not valid.\\nDouble-check and try again."))
    elsif $player.redeemed_passwords.include?(key)
      pbMessage(_INTL("That password has already been redeemed on this save."))
    else
      success = pbApplyPasswordEffect(effect)
      if success
        $player.redeemed_passwords.push(key)
        desc = effect[:description]
        pbMessage(desc) if desc && !desc.empty?
      end
    end

    break unless pbConfirmMessage(_INTL("Would you like to enter another password?"))
  end
end

#-------------------------------------------------------------------------------
# PokéGear app registration.
# Graphic needed: Graphics/UI/Pokegear/icon_passwords.png  (64×64, same style
# as the other gear icons).  A placeholder copy of icon_dexnav.png works fine
# until a proper icon is made.
#-------------------------------------------------------------------------------
MenuHandlers.add(:pokegear_menu, :passwords, {
  "name"      => _INTL("Passwords"),
  "icon_name" => "passwords",
  "order"     => 65,
  "effect"    => proc { |menu|
    pbPasswordMenu
    next false
  },
})
