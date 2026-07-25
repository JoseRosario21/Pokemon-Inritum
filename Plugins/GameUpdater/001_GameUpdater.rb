require 'fileutils'
require 'rubygems'
require 'zip'

module GameUpdater
  #=============================================================================
  # Configuration - fill these in once hosting is set up.
  #=============================================================================

  # Raw URL to a gist containing a line like:
  #   GAME_VERSION=2.5.1
  # This is checked at boot to see if a newer version is available. Reuses the
  # same gist the old poke_updater system used (that system is fully removed
  # now, so its old DOWNLOAD_URL/FORCE_UPDATE lines are just ignored here).
  MANIFEST_URL = "https://gist.githubusercontent.com/JoseRosario21/9dd86019f894c1f7599890d41b907480/raw/gistfile1.txt"

  # The GitHub repo patches are published to, as a fixed "latest" release tag.
  # Expects two assets on that release: patch.zip, and optionally deletions.txt.
  RELEASE_OWNER = "JoseRosario21"
  RELEASE_REPO  = "Pokemon-Inritum"

  def self.patch_url
    "https://github.com/#{RELEASE_OWNER}/#{RELEASE_REPO}/releases/download/latest/patch.zip"
  end

  def self.deletions_url
    "https://github.com/#{RELEASE_OWNER}/#{RELEASE_REPO}/releases/download/latest/deletions.txt"
  end

  #=============================================================================
  # Version check
  #=============================================================================

  def self.current_version
    Gem::Version.new(Settings::GAME_VERSION)
  end

  # Returns the remote version as a Gem::Version, or nil if the manifest
  # couldn't be reached/parsed.
  def self.remote_version
    body = EngineNetworking.https_get(MANIFEST_URL)
    match = body.match(/^\s*GAME_VERSION\s*=\s*(\S+)\s*$/)
    return nil unless match
    return Gem::Version.new(match[1])
  rescue Exception
    return nil
  end

  #=============================================================================
  # Patch download/apply
  #=============================================================================

  def self.download_patch
    body = EngineNetworking.https_get(self.patch_url)
    path = File.join(Dir.pwd, 'patch.zip')
    File.open(path, 'wb') { |f| f.write(body) }
    return path
  end

  # Deletions are optional - a release with nothing removed won't have this
  # asset, so a failed download here just means "nothing to delete".
  def self.download_deletions
    body = EngineNetworking.https_get(self.deletions_url)
    path = File.join(Dir.pwd, 'deletions.txt')
    File.open(path, 'wb') { |f| f.write(body) }
    return path
  rescue Exception
    return nil
  end

  def self.apply_patch(zip_path)
    Zip::File.open(zip_path) do |zip_file|
      zip_file.each do |entry|
        destination = File.join(Dir.pwd, entry.name)
        FileUtils.mkdir_p(File.dirname(destination))
        File.delete(destination) if File.exist?(destination)
        # extract()'s 2nd arg is joined with destination_directory: internally -
        # passing an already-absolute path here doubles it.
        zip_file.extract(entry, entry.name, destination_directory: Dir.pwd) { true }
      end
    end
    File.delete(zip_path)
  end

  def self.apply_deletions(deletions_path)
    return unless deletions_path && File.exist?(deletions_path)
    File.foreach(deletions_path) do |line|
      path = line.strip
      next if path.empty?
      full_path = File.join(Dir.pwd, path)
      File.delete(full_path) if File.exist?(full_path)
    end
    File.delete(deletions_path)
  end

  #=============================================================================
  # Entry point
  #=============================================================================

  # Called once at boot (see Data/Scripts/016_UI/013_UI_Load.rb). Silent if
  # there's no update and prompt_if_none is false.
  def self.check_for_updates(prompt_if_none: false)
    remote = self.remote_version
    if remote.nil?
      Kernel.pbMessage(_INTL("Unable to check for updates. Check your internet connection.")) if prompt_if_none
      return
    end
    if remote <= self.current_version
      Kernel.pbMessage(_INTL("You are on the latest version.")) if prompt_if_none
      return
    end
    return unless Kernel.pbConfirmMessage(_INTL("A new update ({1}) is available. Update now?", remote.to_s))
    self.perform_update
  end

  def self.perform_update
    # \wtnp[0] makes these status lines display-and-continue instead of
    # waiting for a button press, since the download/apply calls right after
    # them are blocking and would otherwise never even start until dismissed.
    Kernel.pbMessage(_INTL("Downloading update...") + "\\wtnp[0]")
    zip_path = self.download_patch
    deletions_path = self.download_deletions

    Kernel.pbMessage(_INTL("Applying update...") + "\\wtnp[0]")
    self.apply_patch(zip_path)
    self.apply_deletions(deletions_path)

    Kernel.pbMessage(_INTL("Update complete! The game will now close - please restart it."))
    Kernel.exit!
  rescue Exception => e
    Kernel.pbMessage(_INTL("The update failed: {1}", e.message))
  end
end
