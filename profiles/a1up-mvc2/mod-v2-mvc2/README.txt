==================================================================
  MARVEL VS CAPCOM 2  Arcade1Up  -  CABINET EXPANSION  (v2)
==================================================================

WHAT THIS DOES
--------------
Turns the MvC2 cabinet into a multi-game machine with a custom
front-end menu, background music, and TWO-PLAYER support for the
added games.

  *  Your original Marvel vs Capcom 2 is NOT modified.
  *  Adds Big Blue      (Street Fighter II Champion Edition)
  *  Adds Yoga Flame    (Street Fighter II Hyper Fighting)
  *  Adds an EXTRA GAMES menu that can run 20 more arcade games
     through RetroArch, with a control-panel diagram for each.
  *  Both players work on the extra games.
  *  Hold the LIVE button for 3 seconds to quit any game and
     return to the menu.


WHAT'S NEW IN THIS BUILD
------------------------
  *  TWENTY extra games, up from fifteen.  Added MORTAL KOMBAT 1,
     II, 3 and ULTIMATE 3, and THE PUNISHER.
  *  The EXTRA GAMES screen was redrawn.  The logos now sit
     straight on the artwork with no tiles or boxes around them,
     four rows of five, and the game you have highlighted is named
     underneath.  Nothing overlaps the banner along the top.
  *  Mortal Kombat's buttons are laid out to match the rest of the
     cabinet - punches along the top, kicks along the bottom, with
     BLOCK and RUN on the right - rather than the original MK
     cabinet's split rows.
  *  MORTAL KOMBAT IS NOW SET TO FREE PLAY.  Press Start and you
     are in - no credits to count, and continues cost nothing.
     All four boards hold that in their own memory, which ships in
     nvram/ along with the CMOS pre-clear.
  *  Start works properly again everywhere.  Letting go of the
     button used to cancel the coin-then-Start sequence before
     Start had been sent, which is why Mortal Kombat needed a pile
     of credits and repeated presses before a match would begin.
  *  Their "CMOS INVALID" first-run screen is pre-cleared, the same
     way the NAOMI games' BACKUPRAM prompt already was.
  *  Menu music starts as soon as the menu does.  It used to arrive
     several seconds late, because the track was being decoded on
     the same thread that was trying to show the screen.
  *  Holding LIVE no longer flashes the Recents list on the way
     back to the menu.


WHAT'S NEW IN v2
----------------
  *  TWO-PLAYER on the RetroArch games.  Player 2 was previously
     impossible: only player 1 reaches Android's input system.  A
     small service now reads the control panel directly and feeds
     player 2 to RetroArch.  No root required.
  *  SOUND on the RetroArch games.  The old config named an audio
     driver that does not exist in this build, so every game ran
     silent.
  *  The emulator CORES ARE INCLUDED and installed for you.  You no
     longer have to fetch them through RetroArch's Online Updater,
     and the cabinet does not need to be online at all.
  *  Per-game CONTROL PANEL SCREENS for all 20 extra games, with the
     button names read from the emulator itself so they are correct.
  *  BACKGROUND MUSIC on the menus (stops when a game starts).
  *  The LIVE button now SURVIVES A REBOOT.  It used to stop
     working after every power cycle.
  *  The cabinet now BOOTS TO THE MENU instead of straight into
     MvC2.
  *  The volume rocker no longer launches a game by accident, and
     your volume setting is remembered.


WHAT YOU NEED
-------------
  1.  An Arcade1Up MARVEL VS CAPCOM 2 cabinet.
  2.  A USB KEYBOARD.  Needed once, to turn on USB debugging.
      Plug it into the USB port on the back of the cabinet.
      (WINDOWS+N opens the notification shade - that is the only
       way into Android Settings; the cabinet has no app drawer.)
  3.  A MICRO-USB DATA CABLE from your PC to the cabinet's micro-USB
      port.  Charge-only cables will NOT work.  If Windows says
      "Unknown USB Device", it is the cable.
      No internet connection is needed - the emulator cores are
      included in this package.
  4.  Your own ROM files - see roms/PUT-YOUR-ROMS-HERE.txt.
      No ROMs are included in this package.
      Run VERIFY-ROMS.bat to check them before installing - it
      tells you exactly which files are missing or wrong.

HOW TO INSTALL
--------------
  Windows :  read INSTALL-GUIDE.txt, then run INSTALL.bat
  macOS   :  read INSTALL-GUIDE.txt, then open the mac folder

  To undo everything, run UNINSTALL.bat (or mac/UNINSTALL.command).


WHAT'S IN THIS FOLDER
---------------------
  INSTALL.bat / UNINSTALL.bat  Windows installer / uninstaller
  mac/                         Same, for macOS
  platform-tools/              Google's adb tool (Windows)
  apk/                         The apps that get installed
  cores/                       the two emulator cores, installed
                               for you by the installer
  config/cabinet.cfg           RetroArch settings for this cabinet
  nvram/                       Save data so the NAOMI games skip
                               their "BACKUPRAM Err" prompt, and so
                               the Mortal Kombat boards skip "CMOS
                               INVALID" and come up on FREE PLAY
  roms/                        Put your own ROM files here
  docs/                        Notes on how it works


IS THIS SAFE?
-------------
It does not touch the bootloader, the kernel, /system, or the
recovery partition.  Nothing is flashed.  Everything is a normal
Android app install plus some settings, and UNINSTALL.bat puts it
all back.  The cabinet is not rooted and does not need to be.


CREDITS / LICENCES
------------------
RetroArch is free software (GPLv3) from the libretro team - source
at https://github.com/libretro/RetroArch .  It is included here
unmodified for convenience.  adb is Google's, from the Android SDK
platform-tools.  Everything else in this package is just glue.
