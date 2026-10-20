==================================================================
  MARVEL VS CAPCOM 2  Arcade1Up   -   3-in-1 Game Menu
                  Windows  and  macOS
==================================================================

WHAT THIS DOES
--------------
Adds two more games to your Marvel vs Capcom 2 Arcade1Up cabinet:

    Big Blue    =  Street Fighter II  Champion Edition
    Yoga Flame  =  Street Fighter II  Hyper Fighting

...and a custom-themed "SELECT YOUR FIGHTER" menu (Marvel vs Capcom
key art, comic title, each cabinet with its game logo) so you can
pick between all three (Marvel vs Capcom 2, Big Blue, Yoga Flame).

Menu splash design by KaoticBPR.

Your original Marvel vs Capcom 2 game is NOT modified in any way.
Everything here is reversible - run the uninstaller to go back
to stock.


WHAT'S IN THIS FOLDER
---------------------
    README.txt         <- this file

  Windows:
    INSTALL.bat        <- double-click this to install
    UNINSTALL.bat      <- double-click this to revert to stock
    platform-tools\    <- Google's "adb" tool for Windows

  Mac:
    mac\HOW-TO-RUN.txt <- READ THIS FIRST if you're on a Mac
    mac\INSTALL.command
    mac\UNINSTALL.command
    mac\platform-tools\  <- Google's "adb" tool for macOS

  Both:
    apk\               <- the three app files that get installed

  Nothing is installed onto your computer - adb just runs from
  this folder.


REQUIREMENTS
------------
  - A Windows PC  OR  a Mac (Intel or Apple Silicon - both work).
  - The Arcade1Up "Marvel vs Capcom 2" cabinet (the WiFi one, Android based).
  - A micro-USB DATA cable from the computer to the cabinet's USB port.
    Many cheap cables are charge-only and will NOT work - if Windows
    pops up "Unknown USB Device (Device Descriptor Request Failed)",
    that's a bad cable, try another one.

  (The cabinet is Android 7 - it has no wireless-debugging pairing,
   so a USB cable is required. A cable is a one-time thing; after
   install you never need the computer again.)

  Windows may need a moment to sort out its USB driver the first time.
  macOS needs no driver at all.


STEP 1 - TURN ON USB DEBUGGING (on the cabinet)
----------------------------------------------
  1. On the cabinet go to  Settings.
  2. If there is no "Developer options":
        open  Settings -> About  and tap  "Build number"  seven times.
  3. Open  Settings -> Developer options  and turn ON  "USB debugging".


STEP 2 - CONNECT THE CABINET
----------------------------
  Plug the micro-USB data cable from your computer into the cabinet's
  USB port (usually on the back of the control deck / underside).


STEP 3 - RUN THE INSTALLER
--------------------------

  ON WINDOWS
      Double-click  INSTALL.bat  and follow the prompts.

  ON A MAC
      Open  mac/HOW-TO-RUN.txt  for the full version. Short version:
      open Terminal and paste this one line:

        cd ~/Downloads/MVC2-Cabinet-3in1 && bash mac/INSTALL.command

      (Running it with "bash" avoids macOS's downloaded-file block,
       so you don't have to change any security settings.)

  BOTH
      If the installer says the cabinet is "unauthorized", look at the
      CABINET SCREEN for an "Allow USB debugging?" popup and choose ALLOW
      (tick "Always allow from this computer"). The installer waits for you.
      If you can't click it with the joystick, plug a USB mouse into the
      cabinet.

      When it finishes it will offer to reboot the cabinet.  Say YES.

  NOTE - the FIRST boot right after installing may briefly show
  Marvel vs Capcom 2 before the SELECT YOUR FIGHTER menu appears. That's
  normal; it settles within a few seconds. Every boot after that
  goes straight to the menu.

  NOTE - Big Blue and Yoga Flame run a one-time setup the first time
  they launch, which can reset the cabinet's VOLUME. If it's loud or
  silent afterwards, just set the volume back in Settings.

  NOTE - after any reboot you may need to re-select "File transfer"
  / "MTP" on the cabinet's USB notification if you plan to run the
  installer again. Not needed for normal play.


HOW TO USE IT
-------------
  - The cabinet now boots straight to the SELECT YOUR FIGHTER menu.
  - Move the joystick LEFT / RIGHT to choose a game.
  - Press any action button to start it.

  - TO GET BACK TO THE MENU from inside any game:
        hold  PLAYER 1 START  +  PLAYER 2 START   together for 2 seconds.
    (This works in all three games, including Marvel vs Capcom 2.)


TO UNDO EVERYTHING
------------------
  Windows:  double-click  UNINSTALL.bat
  Mac:      cd ~/Downloads/MVC2-Cabinet-3in1 && bash mac/UNINSTALL.command

  It removes the two added games and the menu, restores the original
  Marvel vs Capcom 2 boot screen, and re-enables what was disabled.


TROUBLESHOOTING
---------------
  "No cabinet detected"
     - Use a different USB cable (must carry data, not just power).
       "Unknown USB Device" in Windows = bad/charge-only cable.
     - Try a USB port directly on the computer, not a hub.
     - Confirm USB debugging is ON in Developer options.
     - Unplug and replug the cable after the cabinet is fully booted.

  "unauthorized"
     - Accept the "Allow USB debugging" popup on the cabinet screen.

  MAC: "cannot be opened because the developer cannot be verified"
     - You double-clicked instead of using the Terminal line. Use:
          cd ~/Downloads/MVC2-Cabinet-3in1 && bash mac/INSTALL.command
       See mac/HOW-TO-RUN.txt.

  MAC: "permission denied"
     - Same fix - run it with "bash" as shown above, which does not
       need the executable flag.

  MAC: "Could not run adb"
     - Rare. Install a system copy and re-run; the script will find it:
          brew install android-platform-tools

  A game shows "not installed" in the menu
     - Re-run the installer; one of the apps didn't install. Watch for
       an error line during install.

  "Key Chain has stopped" keeps popping up
     - Re-run the installer (it disables the broken component that causes
       this). It's a pre-existing bug in the cabinet's firmware, not
       caused by this mod.

  The menu doesn't stick as the boot screen
     - Re-run the installer.

  The "hold both Start buttons" combo stopped working
     - Re-run the installer (this re-enables it). Note: it can get turned
       off if the SELECT YOUR FIGHTER app is ever "force stopped" in Settings.


NOTES / CREDITS
---------------
  - Big Blue and Yoga Flame are the Arcade1Up Street Fighter cabinet
    game apps, repackaged so they can run alongside Marvel vs Capcom 2.
  - No ROMs are included or distributed by this - the game data is
    inside the original app files.
  - Marvel vs Capcom 2 (com.arcade) is never modified, re-signed, or
    removed.
  - adb is Google's Android Platform Tools, included unmodified under
    its own license (see platform-tools/NOTICE.txt).
==================================================================
