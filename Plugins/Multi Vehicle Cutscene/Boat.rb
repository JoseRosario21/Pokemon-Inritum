#==============================================================================#
#                               SeaGallop Scene                                #
#                                by Mr. Gela                                   #
#==============================================================================#
#                                Instructions                                  #
#                                                                              #
# To call the scene, just put seaGallop(mirrored) in an event.                 #
#                                                                              #
# The arguments are:                                                           #
# mirrored - If true, the boat will go left. If false, the boat will go right. #
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
# An example: seaGallop(false, 294, 22, 38, 8)                                 #
# In this example, the boat is going right, and the player will then appear    #
# in the map with ID 294, in the coordinates 22(X) 38(Y) and facing up.        #
#==============================================================================#
#                               Configurations                                 #
#                                                                              #
#                                                                              #
# Change this to what you want the background music to be when playing the     #
# scene. Must be located in the folder Audio/BGM.                              #
BOAT_BGM = "Boat"                                                              #      
#                                                                              #
# Tones applied to Pictures (except Boat) in function of daytime               #
MORNING_TONE =  Tone.new(-40, -50, -35, 50)   # Morning                        #
DAY_TONE =  Tone.new(  0,   0,   0,  0)       # Day                            #
AFTERNOON_TONE =  Tone.new(  0,   0,   0,  0) # Afternoon                      #
EVENING_TONE =  Tone.new(-15, -60, -10, 20)   # Evening                        #
NIGHT_TONE =  Tone.new(-70, -90,  15, 55)     # Night                          #
#==============================================================================#
#                    Please give credit when using this.                       #
#==============================================================================#

# Calls the scene
def seaGallop(mirror=false)
  pbFadeOutIn(99999){
    scene=Seagallop_Scene.new
    screen=Seagallop_Screen.new(scene)
    screen.pbStartScreen(mirror)
  }
end

# Wait utility
def wait(frames)
  frames.times do
    Graphics.update
  end
end

# Actual scene
class Seagallop_Scene

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
    if @mirror==false # Not mirrored
      if @sprites["bg"]
        @sprites["bg"].ox-=2 # Move sea towards the right
      end
      if @sprites["wind"]
        @sprites["wind"].ox+=24 # Move wind towards the left
      end
    else # Mirrored
      if @sprites["bg"]
        @sprites["bg"].ox+=2 # Move sea towards the right
      end
      if @sprites["wind"]
        @sprites["wind"].ox-=24 # Move wind towards the left
      end
    end
  end

  def boatAnimation
    boat=@sprites["boat"]
    trail=@sprites["trail"]
    if @mirror==false # Not mirrored
      for i in 1..150
        pbUpdate
        boat.x+=8   # move boat every frame
        if (i%2)==0 # move trail but only every two frames
                    # cause that's kind of what FRLG does
          trail.x+=8*2 
        end
        wait(1)
      end
    else # Mirrored
      for i in 1..150
        pbUpdate
        boat.x-=8   # move boat every frame
        if (i%2)==0 # move trail but only every two frames
                    # cause that's kind of what FRLG does
          trail.x-=8*2 
        end
        wait(1)
      end
    end
    pbEndScene
  end
  
  def pbStartScene(mirror)
    @viewport = Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @mirror=mirror
      # bg
      addBackgroundPlane(@sprites,"bg","Seagallop/waterBg",@viewport)
      @sprites["bg"].zoom_x=2
      @sprites["bg"].zoom_y=2
      
      # bg "overlay"
      addBackgroundPlane(@sprites,"wind","Seagallop/waterWind0",@viewport)
      @sprites["wind"].zoom_x=2
      @sprites["wind"].zoom_y=2
      
    if @mirror==false # Not mirrored  
      # boat
      @sprites["boat"] = IconSprite.new(0,0,@viewport)
      @sprites["boat"].setBitmap("Graphics/Plugins/Vehicles/Boat/waterBoat")
      @sprites["boat"].zoom_x=2
      @sprites["boat"].zoom_y=2
      @sprites["boat"].x=0-@sprites["boat"].bitmap.width*2
      @sprites["boat"].y=(Graphics.height-@sprites["boat"].bitmap.height)/2 
      @sprites["boat"].z+=1
      
      # graphic under the boat
      @sprites["trail"] = IconSprite.new(0,0,@viewport)
      @sprites["trail"].setBitmap("Graphics/Plugins/Vehicles/Boat/waterTrail")
      @sprites["trail"].zoom_x=2
      @sprites["trail"].zoom_y=2
      @sprites["trail"].x=@sprites["boat"].x-@sprites["trail"].bitmap.width*2+42*2
      @sprites["trail"].y=@sprites["boat"].y+15*2
      
    else # Mirrored
      # boat
      @sprites["boat"] = IconSprite.new(0,0,@viewport)
      @sprites["boat"].setBitmap("Graphics/Plugins/Vehicles/Boat/waterBoat")
      @sprites["boat"].zoom_x=2
      @sprites["boat"].zoom_y=2
      @sprites["boat"].x=Graphics.width+@sprites["boat"].bitmap.width*2
      @sprites["boat"].y=(Graphics.height-@sprites["boat"].bitmap.height)/2 
      @sprites["boat"].z+=1
      @sprites["boat"].mirror=true
      
      # graphic under the boat
      @sprites["trail"] = IconSprite.new(0,0,@viewport)
      @sprites["trail"].setBitmap("Graphics/Plugins/Vehicles/Boat/waterTrail")
      @sprites["trail"].zoom_x=2
      @sprites["trail"].zoom_y=2
      @sprites["trail"].x=@sprites["boat"].x+@sprites["boat"].bitmap.width-10*2
      @sprites["trail"].y=@sprites["boat"].y+15*2
      @sprites["trail"].mirror=true

    end
    


    pbFadeInAndShow(@sprites) { pbUpdate }
    boatAnimation
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

class Seagallop_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(mirror)
    @scene.pbStartScene(mirror)
  end
end