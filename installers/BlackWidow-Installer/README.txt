BLACK WIDOW for the Buy Stuff WrestleFest cabinet
=================================================

WHAT IT DOES
  - Adds Black Widow to the cabinet's MAME games
  - Adds the cabinet art, gameplay screenshot, transparent logo, video preview and manual
  - Sets up TWIN-STICK controls: left stick = move, right stick = fire (the second stick)
      (the four face buttons also fire as a backup)
  - Coin works on Select or Start, and Free Play is on so Start alone begins a game
  - Puts the game in the "Shoot 'em ups" collection

WHAT IT DOES NOT DO
  - It does NOT update Batocera or touch any system, Buy Stuff or boot scripts.
  - It only adds files and appends a few lines; every file it edits is backed up first to
    /userdata/system/backups/bwidow-installer-<date>/ on the cabinet.

EXTRACT FIRST
  Do NOT run the installer from inside the zip. Right-click the zip > Extract All...,
  open the extracted folder, then double-click Install-BlackWidow.bat from there.
  If anything goes wrong the window stays open; send a photo of it plus the file
  install-log.txt (created in this folder) to whoever gave you the installer.

BEFORE YOU START
  1. Put your own copy of bwidow.zip (the Black Widow ROM) in this folder, next to
     Install-BlackWidow.bat. The ROM is not included.
  2. Your PC and the cabinet must be on the same WiFi.
  3. You need the cabinet's IP address (check your router for a device named "Buystuff")
     and its root password (default: linux).

RUN IT
  Double-click Install-BlackWidow.bat, press Enter to use 192.168.1.77 (or type a different IP),
  say y to restart, and type the password (linux) when asked (twice; nothing shows as you type).

  IMPORTANT: the cabinet must restart BEFORE you play any game, or its game list can
  overwrite the new entry. Saying "y" to the restart question handles this.

UNDO
  Double-click Uninstall-BlackWidow.bat. It removes only what this installer added
  (and restores any file it replaced).

TROUBLESHOOTING
  - "Can't reach ... port 22": wrong IP, cabinet off, or different network.
  - "Copy failed": wrong password.
  - Windows says ssh not found: Settings > Apps > Optional features > add "OpenSSH Client".
  - Controls feel wrong: tell whoever made this which stick/buttons are off.
