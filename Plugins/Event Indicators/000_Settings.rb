# =========== Instructions ===========
# 1. Define any custom event indicators in EVENT_INDICATORS below. (See Defining Indicators)
# 2. Open the event page that you want to show an indicator when active
# 3. In that event page, add a new Comment command.
# 4. Add text to the Comment in the format noted below. The first line must be
#    "Event Indicator" without quotes. The second line follows the format
#    <indicator id> <x adjustment> <y adjustment>
#    - Replace <indicator ID> with the ID of the indicator you want to use. For example, 
#      you could replace it with the word quest for the "quest" indicator.
#    - (Optional) Replace <x adjustment> with the value of x that you want to
#      adjust the placement of the indicator by. For example, you could replace it 
#      with 2 if you want it to be 2 pixels to the right.
#    - (Optional) Replace <y adjustment> with the value of y that you want to
#      adjust the placement of the indicator by. For example, you could replace it 
#      with -6 if you want it to be 6 pixels up.
#   
#    Format:
#      Event Indicator
#      <indicator id> <x adjustment> <y adjustment>
#
#    Example 1:
#      Event Indicator
#      quest
#
#    Example 2:
#      Event Indicator
#      question 2 -6
#
# 5. For text bubble indicators (ones that have :text => true), you set what text 
#    will appear in the bubble starting with the third line of the Comment. Any 
#    lines used after that will be a part of the text that appears (but it is 
#    not recommended to show a lot of text in these bubbles). Simple text is 
#    supported, with some text modification commands available:
#    - \PN pulls in the player's name.
#    - \PM pulls in the player's current money.
#    - \v[x] pulls in the value of variable x.
#    - \n will force a line break.
#    - \sc[yourcode] will execute what you have set in the [] as a script call, and replace 
#      this with the result of that script. For example, for text "Potions: \sc[$bag.quantity(:POTION)]", 
#      it would appear as "Potions: 99".
#   
#    Text Bubble Indicator Format:
#      Event Indicator
#      <indicator id> <x adjustment> <y adjustment>
#      <text>
#
#    Example 1:
#      Event Indicator
#      questsimpletext
#      Yum, Oran berries.
#
#    Example 2:
#      Event Indicator
#      questiontext 2 -6
#      Where is it..?
#
# 6. You're all set! Now when that event page is active, it should show your indicator.
#
# =========== Defining Indicators ===========
# Define each indicator for your game in EVENT_INDICATORS in the Settings module below.
# Each indicator definition is a hash, where the key is the ID of the indicator, as a string, 
# that you'll use when adding Comments to event pages. There are several parameters you 
# can define for your indicator:
#   - :graphic => String - The filepath of the graphic you want to use for the indicator
#   - :x_adjustment => (Optional) Integer - Adjust the indicator's x position by this value. 
#                      Can be positive or negative.
#   - :y_adjustment => (Optional) Integer - Adjust the indicator's y position by this value. 
#                      Can be positive or negative.
#   - :min_distance => (Optional) Integer - The indicator will only appear if the player is 
#                      this number of tiles away from the event or closer.
#   - :max_distance => (Optional) Integer - The indicator will only appear if the player is 
#                      this number of tiles away from the event or farther.
#   - :must_face => (Optional) Boolean - If true, the indicator will only be visible if 
#                        the player is facing in the direction of the event.
#   - :must_look_away => (Optional) Boolean - If true, the indicator will only be visible if 
#                        the player is not facing in the direction of the event.
#   - :always_visible => (Optional) Boolean - If true, the indicator will be visible even when 
#                        you run/interact with the event. If not set or set to false, the
#                        indicator will disappear when you run/interact with the event.
#   - :movement_speed => (Optional) Integer - Adjust the vertical movement speed for this
#                        indicator. The lower the number, the faster the movement.
#   - :no_movement => (Optional) Boolean - If true, the indicator will not have vertical movement.
#   - :animation_frames => (Optional) Integer - Set the number of frames contained within
#                        the graphic for this indicator, to be used for animating the graphic.
#   - :animation_speed => (Optional) Integer - Adjust the animation speed for this
#                        indicator's graphic. The lower the number, the faster the animation.
#   - :condition => (Optional) Proc - Set a condition for the indicator to be visible. 
#                       If not set, it will always appear if the event page is active.
#                       Example: proc { $game_switches[5] }
#   - :text => (Optional) Boolean - If true, the indicator will be a text bubble, showing
#                       text you define in the Comment. For these indicators, the graphic
#                       must be a 48px windowskin.
#   - :text_max_width => (Optional) Integer - Set max width of the text bubble indicator. 
#                       This value is approximately a pixel value, with the actual value 
#                       being a multiple of 16 + padding.
#                       This overrides the EVENT_INDICATOR_MAX_TEXT_WIDTH value.
#   - :hide_text_arrow => (Optional) Boolean - If true, a text bubble indicator will not have
#                       have an arrow pointing to the event. If not set or set to false, 
#                       the arrow will appear if there is a graphic named the same as the
#                       :graphic file with "_arrow" at the end of the file name.
#   - :text_show_pause_indicator => (Optional) Boolean - If true, a pause arrow will appear 
#                       at the end of the text bubble, similar to normal text boxes. If you
#                       don't set it for the indicator definition, you can always add
#                       "\1" to the end of your text to add it for specific messages.
#                       By default, the "pause" graphic will be used (or "pause_light"
#                       if the text is using light font colors). If there is a graphic
#                       named the same as the :graphic file with "_pause" at the end of 
#                       the file name, that will be used, instead.
#   - :text_bubble_flair => (Optional) String or Hash - Add a graphic to a text bubble
#                       indicator to provide more information (a "flair"). The graphic must
#                       be no larger than 28px tall or wide. 
#                       If you only want one flair to appear, and in the position set in
#                       EVENT_INDICATOR_DEFAULT_TEXT_FLAIR_POSITION, set this to the 
#                       filepath of the graphic you want to use.
#                       If you want multiple flairs to appear or use a different position
#                       than the default, set this to a hash with the following structure:
#
#                       :text_bubble_flair => {
#                           position_number => file_path,
#                           position_number => file_path
#                       }
#
#                       file_path is the filepath of the graphic you want to use.
#                       position_number is the integer representing the location for the
#                       flair, as noted here:
#                       1: Top Left   2: Top Center   3: Top Right
#                       4: Left Center             5: Right Center
#                       6: Bottom Left             7: Bottom Right
#                        
#  Examples:
#        "question" => {
#            :graphic => "Graphics/UI/Event Indicators/event_question",
#            :always_visible => true,
#            :x_adjustment => 2,
#            :y_adjustment => -6,
#            :ignore_time_shading => true,
#            :movement_speed => 20,
#            :animation_frames => 4,
#            :animation_speed => 10,
#            :min_distance => 5
#        },
#        "questsimpletext" => {
#            :graphic => "Graphics/UI/Event Indicators/message_1",
#            :text => true,
#            :text_bubble_flair => {
#               1 => "Graphics/UI/Event Indicators/flair_quest"
#            }
#        }
#
# =========== Use Cases ===========
# The use case that spawned this plugin is to show an indicator when the event
# can give you a quest. After defining a "quest" indicator in EVENT_INDICATORS,
# You would add the appropriate Comment to the event, in the appropriate page.
# After you run/interact with the event, which gives you the quest, you'll
# likely set a Self Switch or some other condition to make a new page become
# active for the event. Don't include an indicator Comment to that page,
# and it will no longer show an indicator. If wanted, the new page can show
# a new indicator by adding a Comment to that page as well.


module Settings

    #------------------------------------------------------------------------------------
    # Define your Event Indicators
    #------------------------------------------------------------------------------------
    EVENT_INDICATORS = {
        "quest" => {
            :graphic => "Graphics/UI/Event Indicators/quest_available",
            :movement_speed => 20
        },
        "questsimple" => {
            :graphic => "Graphics/UI/Event Indicators/quest_available_simple"
        },
        "questsimpletext" => {
            :graphic => "Graphics/UI/Event Indicators/message_1",
            :text => true,
            :text_bubble_flair => "Graphics/UI/Event Indicators/flair_quest",
        },
        "questsimpletextcritical" => {
            :graphic => "Graphics/UI/Event Indicators/message_4",
            :text => true,
            :text_bubble_flair => {
                1 => "Graphics/UI/Event Indicators/flair_stop",
                3 => "Graphics/UI/Event Indicators/flair_quest"
            },
        },
        "questsimpleanimated" => {
            :graphic => "Graphics/UI/Event Indicators/quest_available_simple_anim",
            :animation_frames => 4
        },
        "questsimpleanimatednomove" => {
            :graphic => "Graphics/UI/Event Indicators/quest_available_simple_anim",
            :animation_frames => 4,
            :no_movement => true
        },
        "questshortnpc" => {
            :graphic => "Graphics/UI/Event Indicators/quest_available",
            :y_adjustment => 4
        },
        "question" => {
            :graphic => "Graphics/UI/Event Indicators/event_question",
            :always_visible => true,
            :ignore_time_shading => true
        }
    }

    #------------------------------------------------------------------------------------
    # Set x and y adjustments that will apply to all event indicators. Can be positive
    # or negative.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_X_ADJ = 0
    EVENT_INDICATOR_Y_ADJ = 0

    #------------------------------------------------------------------------------------
    # Set x and y adjustments that will apply to text bubble indicators. Can be positive
    # or negative. These values are in addition to all other adjustment values.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_TEXT_X_ADJ = 0
    EVENT_INDICATOR_TEXT_Y_ADJ = 0

    #------------------------------------------------------------------------------------
    # Set to true to have all text bubble indicators have a consistent height above an
    # event, no matter if it has a flair, showing a text arrow, or not.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_TEXT_CONSISTENT_Y = true

    #------------------------------------------------------------------------------------
    # Set to true to allow the player to hide indicators in the Options menu.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_ALLOW_HIDE_OPTION = false

    #------------------------------------------------------------------------------------
    # Set to true to have indicators bob up and down, when visible.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_VERTICAL_MOVEMENT = false

    #------------------------------------------------------------------------------------
    # Set to an integer representing the number of runtime frames between each vertical 
    # movement frame. The lower the number, the faster the movement.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_DEFAULT_MOVEMENT_SPEED = 10

    #------------------------------------------------------------------------------------
    # Set to true to allow the player to disable indicator movement in the Options menu.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_ALLOW_MOVEMENT_OPTION = false

    #------------------------------------------------------------------------------------
    # Set to an integer representing the number of runtime frames between each graphic 
    # frame for indicators with multiple frames. The lower the number, the faster the 
    # movement.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_DEFAULT_ANIMATION_SPEED = 10

    #------------------------------------------------------------------------------------
    # Set max width of text bubble indicators. This value is approximately a pixel value,
    # with the actual value being a multiple of 16 + padding.
    # Also set the max number of lines text bubble indicators can have.
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_MAX_TEXT_WIDTH = 176
    EVENT_INDICATOR_MAX_TEXT_LINES = 2

    #------------------------------------------------------------------------------------
    # Set to an integer representing the default location for text bubble indicator
    # flair icons.
    # 1: Top Left   2: Top Center   3: Top Right
    # 4: Left Center             5: Right Center
    # 6: Bottom Left             7: Bottom Right
    #------------------------------------------------------------------------------------
    EVENT_INDICATOR_DEFAULT_TEXT_FLAIR_POSITION = 3

end