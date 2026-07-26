require 'discord'

# Graphics.update runs every frame regardless of which scene is active (map,
# battle, menus, title screen), unlike EventHandlers' :on_frame_update which
# only fires during map scenes - needed here so the SDK's callback pump never
# stalls no matter what the player is doing.
module Graphics
  class << self
    alias_method :__discord_update, :update unless method_defined?(:__discord_update)
  end

  def self.update
    DiscordRPC.pump
    __discord_update
  end
end

module DiscordRPC
  # Create your own application at https://discord.com/developers/applications
  # and put its Application ID here. Rich presence images (large_image/
  # small_image below) are uploaded under that application's Rich Presence
  # art assets and referenced here by the asset key you gave them there.
  APP_ID = 1531033418249277601

  @info = {
    details: "",
    state: "",
    start_timestamp: Time.now.to_i,
    large_image: "game-icon",
    large_image_text: "Pokémon Inritum",
  }
  @connected = false

  def self.start
    return if @connected
    Discord.connect(APP_ID)
    @connected = true
    @info[:start_timestamp] = Time.now.to_i
    exploration
  rescue Exception
    @connected = false
  end

  # Called every frame via the Graphics.update hook above - just pumps the
  # SDK's own callback queue, doesn't touch presence content.
  def self.pump
    Discord.update if @connected
  rescue Exception
    @connected = false
  end

  def self.update_activity
    return unless @connected
    Discord.update_activity(@info)
  rescue Exception
    @connected = false
  end

  def self.exploration
    @info[:details] = ""
    @info[:state] = $game_map ? "Exploring #{$game_map.name}" : "At the title screen"
    update_activity
  end

  def self.battling
    @info[:details] = "In battle"
    @info[:state] = $game_map ? "Exploring #{$game_map.name}" : ""
    update_activity
  end
end

EventHandlers.add(:on_enter_map, :discord_rich_presence, proc {
  DiscordRPC.exploration
})

EventHandlers.add(:on_start_battle, :discord_rich_presence, proc {
  DiscordRPC.battling
})

EventHandlers.add(:on_end_battle, :discord_rich_presence, proc {
  DiscordRPC.exploration
})

DiscordRPC.start
