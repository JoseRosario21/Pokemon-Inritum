#==============================================================================
# UnrealTime extensions — Pokémon Inritum additions
#==============================================================================
module UnrealTime
  module_function

  # Asks the player if they want to nap, then advances time to the next
  # period: night (20:00) if it's currently day, or morning (06:00) if night.
  # Handles the fade, messages, and time jump — call this from a bed event.
  def sleep_to_next_period
    return unless pbConfirmMessage(_INTL("Do you want to take a nap?"))
    if PBDayNight.isNight?
      pbMessage(_INTL("You curl up and fall asleep..."))
      pbFadeOutIn { UnrealTime.advance_to(6, 0) }
      pbMessage(_INTL("Good morning! You woke up feeling refreshed."))
    else
      pbMessage(_INTL("You curl up and fall asleep..."))
      pbFadeOutIn { UnrealTime.advance_to(20, 0) }
      pbMessage(_INTL("Good evening! You woke up feeling refreshed."))
    end
  end
end

def pbSleepUntilNextPeriod
  UnrealTime.sleep_to_next_period
end
