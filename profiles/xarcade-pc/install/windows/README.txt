VPX CABINET KIT
===============
Visual Pinball X + the ES-DE game menu for a Windows 11 pinball cabinet, plus a drag-and-drop table installer
and a one-click switch between a sideways (landscape) and upright (portrait) TV.

WHAT YOU NEED
- Windows 11 (64-bit), internet for setup, about 1 GB free on C: plus room for tables (300 MB - 1 GB each).
- AMD Radeon: install the current Adrenalin driver from amd.com first.
- Set the TV to its native resolution in Settings > System > Display (usually 3840 x 2160) and 100% / 150% scaling.

1. SETUP (once)
   Unzip this folder anywhere, then double-click Setup.cmd.
   - If Windows says "Windows protected your PC": click More info > Run anyway.
   - Click YES if Windows asks to let Microsoft Visual C++ install.
   It installs everything into C:\Pinball and puts three shortcuts on the desktop:
     Start Pinball            - the game menu (ES-DE). Pick a table and press Enter/A to play.
     Pinball Table Installer  - add tables.
     Pinball Display Mode     - switch landscape / portrait.
   After setup you can delete this folder; a copy of the kit is kept in C:\Pinball\Kit.
   Running Setup.cmd again repairs/updates without losing tables.

2. ADDING A TABLE
   Download everything for ONE table (vpuniverse.com, vpforums.org - the Virtual Pinball Spreadsheet at
   virtualpinballspreadsheet.github.io lists the files for each table):
     - the table (.vpx, often in a zip)                       needed
     - the backglass (.directb2s)                             recommended
     - the ROM zip (e.g. afm_113b.zip) for real machines       needed if the table uses one
     - Serum colors (.cRZ), PuP pack, music, wheel image       optional
   Open "Pinball Table Installer", drag all of it (or the whole folder) into the window, check the name -
   best as "Title (Maker Year)", e.g. "Attack from Mars (Bally 1995)" - and press INSTALL TABLE.
   It sorts every file into place, fixes known script problems, places the backglass/DMD and adds the table
   with artwork to ES-DE. Read the NOTE lines at the end - e.g. it tells you when a ROM is missing.

3. LANDSCAPE / PORTRAIT
   Turn the TV, then open "Pinball Display Mode":
     LANDSCAPE - TV sideways. Desktop view, backglass top-left + DMD top-right.
     PORTRAIT  - TV upright. Windows rotates the screen, tables use their cabinet view, DMD at the top.
                 Tick "show the backglass" to also put the backglass above the DMD.
                 If the picture comes out upside down, press "flip it".
   Close any table first. ES-DE restarts by itself.

CONTROLS (keyboard defaults - most cabinet button boards send these keys)
   Flippers: Left / Right Shift      Plunger: Enter      Start: 1      Coin: 5      Nudge: Z / / / Space
   Quit a table: Esc, then "Quit" in the menu        Volume: - / =
   Change any of these inside a table: press F12 for VPX's in-game settings (also view/brightness tuning).

WHERE THINGS ARE
   C:\Pinball\ES-DE\ROMs\vpinball       tables (.vpx, .directb2s, per-table .ini / .vbs)
     \pinmame\roms                      ROM zips          \pinmame\altcolor   Serum / VNI colors
     \pupvideos  \music                 PuP packs, table music
   C:\Pinball\ES-DE\Emulators\VPinballX Visual Pinball X 10.8.1
   %APPDATA%\VPinballX\10.8\VPinballX.ini   VPX settings
   To remove a table: delete its files with that name in the tables folder.

TROUBLESHOOTING
   Table won't start / "ROM not found"  - add the ROM zip with the Table Installer (same table name).
   Black or white DMD box               - the table's ROM is missing, or it needs a different ROM version.
   Slow on a big table                  - press F12 > Video and lower the resolution / effects.
   Table looks wrong in portrait        - press F12 > Point of View to adjust it; VPX saves it for that table.
