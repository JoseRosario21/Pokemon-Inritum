#==============================================================================#
#                               Magnet Train Scene                             #
#                                    by SNR                                    #
#                  based on PurpleZaffre's RSE Cable Car Scene                 #
#==============================================================================#
#                                Instructions                                  #
#                                                                              #
# To call the scene, just put                                                  #
# MagnetTrainScene.new(going_left, map_id, map_x, map_y, direction)            #
# in an event.                                                                 #
#                                                                              #
# The arguments are:                                                           #
# going_up - If true, the train will go left. If false, the car will go right. #
# map_id - The ID of the map where the player will appear after the scene.     #
# map_x - The X coordinate on the map where the player will appear.            #
# map_y - The Y coordinate on the map where the player will appear.            #
# direction - The direction you want the player to be facing when the scene    #
# finishes. If this field is left empty, it will always assume 2 (down). The   #
# input received should be one of the following:                               #
# 2 - down                                                                     #
# 4 - left                                                                     #
# 6 - right                                                                    #
# 8 - up                                                                       #
#                                                                              #
# An example: MagnetTrainScene.new(false, 294, 22, 38, 8)                      #
# In this example, the train is going right, and the player will then appear   #
# in the map with ID 294, in the coordinates 22(X) 38(Y) and facing up.        #
#==============================================================================#
#                               Configurations                                 #
#                                                                              #
#                                                                              #
# Change this to what you want the background music to be when playing the     #
# scene. Must be located in the folder Audio/BGM.                              #
MAGNET_TRAIN_BGM = "Train"                                               #      
#                                                                              #
# Tones applied to Pictures (except Train) in function of daytime              #
MORNING_TONE =  Tone.new(-40, -50, -35, 50)   # Morning                        #
DAY_TONE =  Tone.new(  0,   0,   0,  0)       # Day                            #
AFTERNOON_TONE =  Tone.new(  0,   0,   0,  0) # Afternoon                      #
EVENING_TONE =  Tone.new(-15, -60, -10, 20)   # Evening                        #
NIGHT_TONE =  Tone.new(-70, -90,  15, 55)     # Night                          #
#==============================================================================#
#                    Please give credit when using this.                       #
#==============================================================================#


class MagnetTrainScene
  def initialize(going_left, map_id, map_x, map_y, direction=2)
    pbBGMFade(0.1)
    @sprites = {}
    @sprites["Black"] = Sprite.new
    @sprites["Black"].bitmap = Bitmap.new("Graphics/Plugins/Vehicles/Train/black")
    @sprites["Black"].z = 99999
    @sprites["Black"].opacity = 0
    for i in 0..14
      @sprites["Black"].opacity += 17
      pbWait(0.01)
    end
    pbBGMPlay(MAGNET_TRAIN_BGM)
    @sprites["BG"] = Sprite.new
    @sprites["BG"].bitmap = Bitmap.new("Graphics/Plugins/Vehicles/Train/bg" + ((PBDayNight.isNight?) ? "_night" : (PBDayNight.isEvening? || PBDayNight.isAfternoon? ? "_afternoon" : "")))
    @sprites["BG"].tone = get_current_tone
    @sprites["BG"].y = -98
    @sprites["BG"].z = 90000
    @sprites["Rails"] = Sprite.new
    @sprites["Rails"].bitmap = Bitmap.new("Graphics/Plugins/Vehicles/Train/rails")
    @sprites["Rails"].tone = get_current_tone
    @sprites["Train"] = Sprite.new
    @sprites["Train"].bitmap = Bitmap.new("Graphics/Plugins/Vehicles/Train/train_male")
    @sprites["Trees"] = Sprite.new
    @sprites["Trees"].bitmap = Bitmap.new("Graphics/Plugins/Vehicles/Train/trees")
    @sprites["Trees"].tone = get_current_tone

    if going_left
      go_left
    else
      go_right
    end
    @sprites["BG"].dispose
    @sprites["Rails"].dispose
    @sprites["Train"].dispose
    @sprites["Trees"].dispose
    pbBGMFade(0.3)
    pbWait(0.6)
    $game_player.transparent = false
    $game_temp.player_transferring = true
    $game_temp.player_new_map_id = map_id
    $game_temp.player_new_x = map_x
    $game_temp.player_new_y = map_y
    $game_temp.player_new_direction = direction
    pbBGMStop(0)
    pbWait(0.05)
    for i in 0..14
      @sprites["Black"].opacity -= 17
      pbWait(0.01)
    end
    pbDisposeSpriteHash(@sprites)
    $game_map.autoplay
  end

  def go_left

    @sprites["Rails"].x = -1536
    @sprites["Rails"].y = 120
    @sprites["Rails"].z = 92000
    @sprites["Train"].x = 420
    @sprites["Train"].y = 230
    @sprites["Train"].z = 96000
    @sprites["Trees"].x = -1536
    @sprites["Trees"].y = 360
    @sprites["Trees"].z = 96200
    for i in 0..30
      if i < 4
        @sprites["Black"].opacity -= 50
      elsif i == 4
        @sprites["Black"].opacity -= 55
      elsif i >= 26 && i < 30
        @sprites["Black"].opacity += 50
      elsif i == 30
        @sprites["Black"].opacity += 55
      end
      @sprites["Train"].x -= 10
      pbWait(0.02)
      @sprites["Rails"].x += 6
      @sprites["Trees"].x += 6
      pbWait(0.02)
      pbWait(0.02)
      @sprites["Rails"].x += 6
      @sprites["Trees"].x += 6
      @sprites["Train"].x -= 10
      pbWait(0.02)
    end
  end

  def go_right
    @sprites["Rails"].x = 0
    @sprites["Rails"].y = 120
    @sprites["Rails"].z = 92000
    @sprites["Train"].x = -256
    @sprites["Train"].y = 230
    @sprites["Train"].z = 96000
    @sprites["Trees"].x = 0
    @sprites["Trees"].y = 360
    @sprites["Trees"].z = 96200
    for i in 0..30
      if i < 4
        @sprites["Black"].opacity -= 50
      elsif i == 4
        @sprites["Black"].opacity -= 55
      elsif i >= 26 && i < 30
        @sprites["Black"].opacity += 50
      elsif i == 30
        @sprites["Black"].opacity += 55
      end
      @sprites["Train"].x += 10
      pbWait(0.02)
      @sprites["Rails"].x -= 6
      @sprites["Trees"].x -= 6
      pbWait(0.02)
      pbWait(0.02)
      @sprites["Rails"].x -= 6
      @sprites["Trees"].x -= 6
      @sprites["Train"].x += 10
      pbWait(0.02)
    end
  end

  def get_current_tone
    if PBDayNight.isNight?
      return NIGHT_TONE
    elsif PBDayNight.isMorning?
      return MORNING_TONE
    elsif PBDayNight.isEvening?
      return MORNING_TONE
    elsif PBDayNight.isAfternoon?
      return AFTERNOON_TONE
    else
      return DAY_TONE
    end
  end
end