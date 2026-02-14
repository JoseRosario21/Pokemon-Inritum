================================================================================
  XP-18 TRAINING MODULE v1.0.0
  A combat simulator plugin for Pokemon Essentials v21.1
================================================================================

OVERVIEW
--------
The XP-18 Training Module is a ticket-based combat simulator with two modes:

  XP Mode  - Battle 6 dynamically generated Pokemon. Win to earn EXP Candies.
  EV Mode  - Pick one of your Pokemon and a stat. Win a 1v3 battle to maximize
             that stat's EVs to 252.

Everything scales automatically based on your game's level cap variable.


INSTALLATION
------------
1. Copy the "XP18_TrainingModule" folder into your project's Plugins/ directory.

2. Define the required items in PBS/items.txt (if not already present):

   [XPTICKET]
   Name = XP Ticket
   NamePlural = XP Tickets
   Pocket = 1
   Price = 0
   Description = A ticket that grants access to the XP-18 combat simulator.

   [EVTICKET]
   Name = EV Ticket
   NamePlural = EV Tickets
   Pocket = 1
   Price = 0
   Description = A ticket that grants access to EV training in the XP-18 simulator.

   Note: Set BPPrice or SellPrice as desired. The plugin only checks that the
   player has the item and consumes 1 per use.

3. Define the required EXP Candy items in PBS/items.txt (if not already present):
   EXPCANDYXS, EXPCANDYS, EXPCANDYM, EXPCANDYL, EXPCANDYXL
   These are standard Gen 8+ items and are likely already in your project.

4. Define the trainer type in PBS/trainer_types.txt (if not already present):

   [XP18Simulation]
   Name = XP-18 Simulation
   Gender = Male
   BaseMoney = 0
   SkillLevel = 50

5. Set the level cap game variable (default: variable 100) to your current
   level cap value. If you use the "Level Caps EX" plugin, this is already
   handled automatically. Otherwise, set it via events:

   Control Variables: [0100] = <your level cap>

6. Launch the game in debug mode to compile the plugin.


CALLING FROM A MAP EVENT
------------------------
Create an event with a Script command containing:

   XP18.pbXP18Machine

That's it. The plugin handles the full menu flow, ticket consumption, team
generation, battle, and rewards internally.


HOW IT WORKS
------------

  XP Mode:
    1. Player selects XP Mode
    2. Confirms ticket usage (shows reward preview)
    3. 1 XP Ticket is consumed
    4. Party is healed (if HEAL_BEFORE_BATTLE is true)
    5. 6 enemy Pokemon are generated based on current level cap
    6. Player battles the simulated trainer (6v6)
    7. Win  -> Receive EXP Candies (tier scales with level cap)
       Lose -> No rewards, ticket is still consumed
    8. Party is healed after battle

  EV Mode:
    1. Player selects EV Mode
    2. Chooses a Pokemon from party (no eggs)
    3. Chooses which stat to maximize (HP/Atk/Def/SpA/SpD/Spe)
    4. If the stat is already at 252, the player is informed and returned
    5. If the Pokemon already has 2 maxed stats, the player is prompted to
       choose which one to replace
    6. Confirms ticket usage
    7. 1 EV Ticket is consumed
    8. Selected Pokemon is healed (if HEAL_BEFORE_BATTLE is true)
    9. 3 enemy Pokemon are generated (biased toward the trained stat)
    10. Player battles with ONLY the selected Pokemon (1v3)
    11. Win  -> Chosen stat is set to 252 EVs, non-maxed stats are zeroed
        Lose -> Player can Retry (no extra ticket) or Give Up
    12. Party is healed after battle

  EV Stacking:
    - A Pokemon can have up to 2 stats maximized at 252 (total 504/510)
    - First EV training: sets 1 stat to 252, zeros everything else
    - Second EV training: sets another stat to 252, keeps the first
    - Third EV training: prompts which of the 2 maxed stats to replace


CONFIGURATION (001_Settings.rb)
-------------------------------
All settings are constants in the XP18 module. Edit them to customize:

  XP_ENEMY_COUNT         Number of enemy Pokemon in XP mode (default: 6)
  EV_ENEMY_COUNT         Number of enemy Pokemon in EV mode (default: 3)
  TRAINER_TYPE           Trainer type symbol (default: :XP18Simulation)
  EV_LEVEL_OFFSET        Enemy level offset in EV mode (default: -3)
  HEAL_BEFORE_BATTLE     Heal player's party before battle (default: true)
  LEVEL_CAP_VARIABLE     Game variable ID for level cap (default: 100)
  LEVEL_CAP_BYPASS_SWITCH  Game switch ID for level cap bypass (default: 100)
                           Set to nil if not using any level cap plugin
  XP_TICKET              Item symbol for XP mode (default: :XPTICKET)
  EV_TICKET              Item symbol for EV mode (default: :EVTICKET)
  BLACKLIST              Array of species symbols excluded from generation
  HELD_ITEMS_EARLY       Item pool for levels 0-24
  HELD_ITEMS_MID         Item pool for levels 25-49
  HELD_ITEMS_LATE        Item pool for levels 50+


SCALING
-------
Everything scales from the level cap variable:

  Level Cap    Enemy Levels    BST Range     Candy Rewards       Items Tier
  ----------   ------------    ---------     ----------------    ----------
  18 (0 bdg)   12 - 14         200 - 360     5x Candy S          Early
  25 (1 bdg)   17 - 20         252 - 408     2x S + 2x M         Early
  35 (2 bdg)   24 - 28         278 - 433     4x Candy M           Mid
  50           35 - 40         318 - 473     4x M + 1x L          Mid
  75           52 - 60         384 - 537     6x L + 1x XL         Late
  100          70 - 80         450 - 600     6x Candy XL           Late

  EV mode scales to the selected Pokemon's level instead of the level cap.


DEPENDENCIES
------------
  Required:  Pokemon Essentials v21.1
  Optional:  Level Caps EX (auto-compatible, manages variable 100)

  No hard plugin dependencies. The plugin reads from game variables directly.


COMPATIBILITY
-------------
  - Does not modify any existing scripts or classes
  - Does not alias or override any methods
  - Self-contained within the XP18 module
  - Compatible with Deluxe Battle Kit, Field Effects, and other battle plugins
