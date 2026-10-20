==================================================================
  CABINET CRT FILTER  -  scanlines on / off
  add-on for the Arcade1Up Cabinet Expansion mod
==================================================================

WHAT IT DOES
------------
Puts a CRT arcade-monitor look on the extra games: scanlines, a soft
aperture grille, a little phosphor glow, and crisp pixel edges instead
of the slightly soft stretch you get now.

Run it once  ->  filter ON.
Run it again ->  filter OFF.

That is the whole thing. It is not an install; nothing new is added to
the cabinet's menu and no app is installed or replaced.


WHAT IT AFFECTS
---------------
Only the games in the EXTRA GAMES menu - the ones that run through
RetroArch:

    Street Fighter Alpha 1 / 2 / 3      Guilty Gear X
    Street Fighter III 1 / 2 / 3        Power Stone
    Red Earth                           SVC Chaos
    Garou, KOF '98, Real Bout Special, Samurai Shodown V Special,
    Cyberbots, The Punisher, Mortal Kombat 1 / 2 / 3 / UMK3

Marvel vs Capcom 2, Big Blue and Yoga Flame are NOT affected - they
are separate apps and do not run through RetroArch. There is no way
to add the filter to those without replacing their emulator.


HOW TO USE IT
-------------
WINDOWS

  1) Unzip this whole folder somewhere - Desktop is fine.
  2) Connect the cabinet to the PC with a micro-USB DATA cable and
     turn USB debugging on, exactly as you did for the installer.
  3) Double-click   CRT-FILTER.bat
  4) Start any game from EXTRA GAMES.

  Double-click CRT-FILTER.bat again to turn it back off.

macOS

  Open the  mac  folder and double-click  CRT-FILTER.command
  (right-click > Open the first time, so Gatekeeper lets it run).

A game that is ALREADY running keeps the old look until you quit back
to the menu (hold P1 + P2 Start) and start it again.


HOW STRONG?
-----------
Double-click  CRT-STRENGTH.bat  (Windows) and pick:

  LIGHT    A hint of scanline, no grille. Brightest. Kindest to the
           busy CPS3 games - Street Fighter III and Red Earth.

  MEDIUM   Scanlines plus a soft aperture grille. Closest to a real
           cabinet monitor, and what you get by default.

  HEAVY    Deep gaps and a strong grille. Very authentic, but darker.
           Best in a dim room.

On macOS, run  CRT-FILTER.command  with an argument instead:
    ./CRT-FILTER.command light      (or medium / heavy / off / status)

The strength is remembered, so switching the filter off and back on
brings your choice back.


DOES IT SLOW THE GAMES DOWN?
----------------------------
No. Measured on the cabinet with the filter on, Power Stone - the
heaviest of the added games - held a locked 60.0 fps with no dropped
frames at all. The shader is a single pass and the RK3399's GPU has
plenty of headroom for it at this resolution.


THINGS WORTH KNOWING
--------------------
* If you re-run the Cabinet Expansion INSTALLER, it rewrites
  RetroArch\cabinet.cfg and the filter goes back to OFF. Just run
  CRT-FILTER.bat again afterwards.

* The filter is off by default and nothing about the cabinet changes
  until you run it.


WHAT IT ACTUALLY CHANGES ON THE CABINET
---------------------------------------
Four small text files plus one line of config. Nothing else is
touched, and nothing is deleted:

  /sdcard/RetroArch/shaders/cabinet-crt.glsl     the shader itself
  /sdcard/RetroArch/shaders/crt-light.glslp      the three strengths
  /sdcard/RetroArch/shaders/crt-medium.glslp
  /sdcard/RetroArch/shaders/crt-heavy.glslp

  /sdcard/RetroArch/config/global.glslp          one line, saying
        which strength to use. RetroArch reads this automatically for
        every game. When the filter is off this file is renamed to
        global.glslp.off rather than deleted, which is how the
        strength is remembered.

  /sdcard/RetroArch/cabinet.cfg                  gains or updates a
        single line, video_shader_enable = "true" / "false".
        RetroArch ignores the preset completely unless this is set,
        so it has to be flipped as well. The rest of the file is left
        exactly as the installer wrote it.

To undo everything by hand, delete the two files above and set
video_shader_enable back to "false".


ABOUT THE SHADER
----------------
cabinet-crt.glsl is written for this cabinet specifically - a 1280x960
4:3 panel. The scanline spacing is taken from the game's own line
count, not from the screen, so the gaps land correctly whether the
game is a 224-line CPS2 board scaled 4.28x or a 480-line NAOMI board
scaled exactly 2x. It is commented if you want to read or change it.
