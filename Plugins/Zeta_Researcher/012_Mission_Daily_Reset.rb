#===============================================================================
# Daily Mission Reset - resets daily mission progress at the start of a new day
#===============================================================================
class ZetaResearcherData
  # Encodes the current day as an integer: yday + year * 1000
  # Avoids Date class for MKXP compatibility.
  def self.encode_day(time)
    return time.yday + time.year * 1000
  end

  # Checks if the day has changed and resets daily missions if so.
  # Called silently (no popup) before mission operations.
  def check_daily_reset
    ensure_migrated
    today = ZetaResearcherData.encode_day(pbGetTimeNow)
    if @daily_reset_day.nil? || @daily_reset_day != today
      reset_daily_missions
      @daily_reset_day = today
    end
  end
end
