#==============================================================================#
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#
#==============================================================================#
#                          Rock Climb with Animation                           #
#                                    v1.1                                      #
#                             By Ulithium_Dragon                               #
#                     Edited by DarrylBD99 for V19 support                     #
#==============================================================================#
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\#
#==============================================================================#
#          Implements Rock Climbing and plays a custom animation               #
#             when using the Rock Climb HM in the overworld.                   #
#------------------------------------------------------------------------------#
#    Place the Rock Climb graphics on the tileset you want to use them with    #
#      (You will need to do this manually using an image editing program)      #
#                                                                              #
#         Change the terrain tags of the tiles you added with numbers          #
#       used in line 172 and line 179 [make sure to change it if needed]       #
#                                                                              #
#==============================================================================#
#   If you want to have Rock Climb as an HM, you will need to add a new item   #
#   to your "items.txt" PSB file...                                            #
#                                                                              #
#-----------#                                                                  #
#| Example: |                                                                  #
#-----------#                                                                  #
#[HM09]
#Name = HM09
#NamePlural = HM09s
#Pocket = 4
#Price = 0
#FieldUse = HM
#Move = ROCKCLIMB
#Description = A charging attack that may also leave the foe confused.
#                                                                              #
#------------------------------------------------------------------------------#
#           in the provided pbs file "tm.txt" underneath [ROCKCLIMB]           #
#       add the Pokemon names (in all caps) you want to learn Rock Climb       #
#                                                                              #
#-----------#                                                                  #
#| Example: |                                                                  #
#-----------#                                                                  #
=begin
[ROCKCLIMB]
VENUSAUR,BLASTOISE,SANDSHREW,SANDSLASH,NIDOQUEEN,NIDOKING,GOLDUCK,MANKEY,PRIMEAPE,ARCANINE,POLIWRATH,MACHOP,MACHOKE,MACHAMP,GEODUDE,GRAVELER,GOLEM,ONIX,CUBONE,MAROWAK,HITMONLEE,HITMONCHAN,LICKITUNG,RHYHORN,RHYDON,CHANSEY,KANGASKHAN,ELECTABUZZ,MAGMAR,PINSIR,TAUROS,OMASTAR,KABUTOPS,SNORLAX,MEWTWO,MEW,MEGANIUM,TYPHLOSION,FERALIGATR,AMPHAROS,STEELIX,GRANBULL,URSARING,BLISSEY,RAIKOU,ENTEI,SUICUNE,TYRANITAR,SCEPTILE,BLAZIKEN,SWAMPERT,LUDICOLO,VIGOROTH,SLAKING,EXPLOUD,MAKUHITA,HARIYAMA,AGGRON,ZANGOOSE,REGIROCK,REGICE,REGISTEEL,GROUDON,TURTWIG,GROTLE,TORTERRA,CHIMCHAR,MONFERNO,INFERNAPE,EMPOLEON,BIBAREL,CRANIDOS,RAMPARDOS,GIBLE,GABITE,GARCHOMP,MUNCHLAX,LUCARIO,DRAPION,CROAGUNK,TOXICROAK,ABOMASNOW,LICKILICKY,RHYPERIOR,ELECTIVIRE,MAGMORTAR,MAMOSWINE,HEATRAN,REGIGIGAS,GIRATINA,DARKRAI,ARCEUS
=end
#------------------------------------------------------------------------------#
# make sure to hold CTRL for a fully recompile to add the tms into pokemon.txt #
#------------------------------------------------------------------------------#


#==============================================================================#
#                                   SETTINGS                                   #
#==============================================================================#
module RockClimbSettings
  # Animation IDs from visible encounters
  ## Rock Climb Rocks animation
  ROCK_CRUMBLE_ANIMATION_ID   = 19 #Default: 19

  ## Rock CLimb Dusts animation UP
  ROCK_DUST_ANIMATION_UP_ID   = 20 #Default: 20

  ## Rock CLimb Dusts animation DOWN
  ROCK_DUST_ANIMATION_DOWN_ID = 21 #Default: 21

  
  # Filename for the Rock Climb Base
  ROCKCLIMB_BASE = "base_rockclimb"  #Default: "base_rockclimb"

  # The badge needed to use Rock Climb in the field.
  BADGE_FOR_ROCKCLIMB = 8  #Default: 8

  # Allows players to descend when using rock climb
  ENABLE_DESCENDING = true  #Default: false

  # Time in seconds for one cycle of bobbing (playing 4 charset frames) while
  # rock climbing.
  ROCK_CLIMB_BOB_DURATION = 1.5 #Default: 1.5

  # Audio File for Rock Climp in SE folder
  ROCK_CLIMB_SFX = "Rock Climb EX" #Default: "Rock Climb EX"

  # Sets Movement Speed when Rock Climbing
  ROCK_CLIMB_SPEED = 4 #Default: 4
end
#==============================================================================#
