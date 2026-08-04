#===============================================================================
# Unidata - persistent cross-save metadata
#
# A small key/value store that lives OUTSIDE any save file, next to Game.rxdata.
# It survives new games, deleted saves and save-slot switching, which is what
# makes it useful for:
#
#   * "you have beaten this game before" unlocks / New Game+
#   * global achievement or completion tracking
#   * remembering settings that should not reset with a new playthrough
#
# Modelled on Rejuvenation's $Unidata. Access is via the $Unidata global:
#
#   $Unidata[:beaten_game]           # read, nil if never set
#   $Unidata[:beaten_game] = true    # write (persists immediately)
#   $Unidata.fetch(:runs, 0)         # read with a default
#   $Unidata.bump(:runs)             # increment a counter
#   $Unidata.key?(:beaten_game)
#   $Unidata.delete(:beaten_game)
#
# Values must be Marshal-safe: symbols, strings, numbers, booleans, arrays and
# hashes of those. Do not store Pokemon, sprites or anything holding a Bitmap.
#===============================================================================
class UnidataStore
  # Sits beside the save file rather than in it, which is the entire point.
  FILE_PATH = if File.directory?(System.data_directory)
                System.data_directory + "/unidata.dat"
              else
                "./unidata.dat"
              end

  # Bumped only if the on-disk shape ever changes.
  FORMAT = 1

  def initialize
    @data = {}
    load
  end

  #-----------------------------------------------------------------------------
  # Reading
  #-----------------------------------------------------------------------------
  def [](key)
    return @data[key.to_sym]
  end

  def fetch(key, default = nil)
    key = key.to_sym
    return @data.key?(key) ? @data[key] : default
  end

  def key?(key)
    return @data.key?(key.to_sym)
  end

  def keys
    return @data.keys
  end

  def to_h
    return @data.dup
  end

  #-----------------------------------------------------------------------------
  # Writing. Each write persists immediately -- this store exists to survive
  # events the game does not control (a crash, a deleted save), so deferring the
  # flush to some later checkpoint would defeat it.
  #-----------------------------------------------------------------------------
  def []=(key, value)
    @data[key.to_sym] = value
    save
    return value
  end

  def bump(key, amount = 1)
    key = key.to_sym
    @data[key] = (@data[key] || 0) + amount
    save
    return @data[key]
  end

  # Only writes if the key is unset -- for "first time we ever saw this" flags.
  def set_once(key, value)
    key = key.to_sym
    return @data[key] if @data.key?(key)
    self[key] = value
    return value
  end

  # Raises the stored value to `value` if it is higher. For personal bests.
  def raise_to(key, value)
    key = key.to_sym
    current = @data[key]
    return current if current.is_a?(Numeric) && current >= value
    self[key] = value
    return value
  end

  def delete(key)
    key = key.to_sym
    return nil if !@data.key?(key)
    value = @data.delete(key)
    save
    return value
  end

  def clear!
    @data = {}
    save
  end

  #-----------------------------------------------------------------------------
  # Disk
  #
  # Both directions are guarded. A corrupt or unreadable unidata file must never
  # stop the game booting -- it holds bonus content flags, nothing essential, so
  # the correct failure is "start empty", not "crash".
  #-----------------------------------------------------------------------------
  def load
    @data = {}
    return if !File.file?(FILE_PATH)
    begin
      raw = File.open(FILE_PATH, "rb") { |f| Marshal.load(f) }
      if raw.is_a?(Hash) && raw[:format].is_a?(Integer) && raw[:data].is_a?(Hash)
        @data = raw[:data]
      elsif raw.is_a?(Hash)
        @data = raw   # tolerate a bare hash, in case an older build wrote one
      end
    rescue StandardError => e
      echoln("[Unidata] could not read #{FILE_PATH}: #{e.message}")
      @data = {}
    end
  end

  def save
    begin
      # Written to a temporary file and moved into place, so a crash mid-write
      # cannot leave a half-written file where the real one was.
      tmp = FILE_PATH + ".tmp"
      File.open(tmp, "wb") { |f| Marshal.dump({ :format => FORMAT, :data => @data }, f) }
      File.delete(FILE_PATH) if File.file?(FILE_PATH)
      File.rename(tmp, FILE_PATH)
    rescue StandardError => e
      echoln("[Unidata] could not write #{FILE_PATH}: #{e.message}")
    end
  end
end

# Created on demand so the store is available from the moment scripts run.
$Unidata = UnidataStore.new if !$Unidata
