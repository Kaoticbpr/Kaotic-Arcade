# Bazzite setup (mini PC / TV, Steam Game Mode)

> Commands below are run from `profiles/xarcade-pc/install/bazzite/` in this repo.

Tested on: Bazzite 44 (Fedora Kinoite, Game Mode), AMD Ryzen 7 8745H / Radeon 780M, 1080p output to a 4K 60 Hz TV,
Visual Pinball X 10.8.1-5436 (BGFX). Any Bazzite / SteamOS-style PC should work; weaker GPUs may need lower settings.

## 0. Before you start
- **EmuDeck** installed (it sets up ES-DE, the game menu, and the `~/Emulation` folders). Start ES-DE once.
- Switch to **Desktop Mode** for the setup (Steam menu > Power > Switch to Desktop), open a terminal (Konsole).

## 1. Install
```bash
git clone https://github.com/<you>/KaoticBPR-Arcade-Kit.git ~/KaoticBPR-Arcade-Kit
cd ~/KaoticBPR-Arcade-Kit/bazzite
./install.sh            # or: ./install.sh --all   (adds the haptic kit routing + loudness leveler)
```
What it does (safe to run again – it never deletes tables, ROMs or your own settings):

| Step | Result |
|---|---|
| Visual Pinball X | official Linux build from GitHub → `~/Applications/VPinballX` (previous one kept as `.old-…`) |
| Folders | `~/Emulation/roms/vpinball` (tables), `…/pinmame/roms` (ROMs), `altcolor`, `altsound`, `nvram`, `music`, `pupvideos` |
| Settings | SMAA anti-aliasing, screen-space reflections, no supersampling, FPS counter off, black DMD, PinMAME path |
| ES-DE | registers `~/.local/bin/vpx-launch.sh` as the Visual Pinball launcher |
| Tools | table installer + helpers in `~/Emulation/tools/scripts` |
| `--haptics` | "Pinball Playfield" audio output (TV + haptic kit) – see [HAPTICS.md](HAPTICS.md) |
| `--leveler` | loudness leveler for ES-DE games (+ one manual step: Steam launch options, the installer tells you) |

## 2. Add tables
For each table, download the table, backglass, ROM (and optional wheel, PuP pack, Serum colors) into one folder –
links are in [TABLES.md](../TABLES.md) – then:
```bash
./add-table.sh ~/Downloads/afm "Attack from Mars (Bally 1995)"
```
Name it **"Title (Maker Year)"**. The installer sorts the files, applies known Linux script fixes, sizes the backglass +
DMD next to the table **without changing its camera**, makes the ES-DE artwork and adds the table to ES-DE.
If a table misbehaves see [LINUX-FIXES.md](LINUX-FIXES.md).

## 3. Controls
- Keyboard defaults: flippers = Shift keys, plunger = Enter, start = 1, coin = 5, quit = Esc.
- **X-Arcade Arcade2TV-XR** (pinball/purple mode): with VPX closed run `vpx/vpx-xarcade.sh` once – flippers on the side
  buttons, plunger on the right stick, nudge on the left stick and the bump sensor, coin/start/exit on P2 X / Start.
- Other controllers: start a table, press **F12** → Input.

## 4. Steam games in ES-DE (optional)
```bash
esde/add-steam-game.sh 595960 "Pinball Wicked"     # app id from the Steam store URL
```
Adds the game to ES-DE's Steam list with Steam's own artwork; quitting the game hands the controller back to ES-DE.

## 5. Updating Visual Pinball
`./install.sh --latest` installs the newest release (the tested one is the default). Run `./install.sh` again after any
VPX update – an update resets the black DMD glass.

## Remote control from another PC (optional, advanced)
`remote/vpx-play.sh` / `vpx-try.sh` start a table on the TV over SSH (they borrow ES-DE's environment so Game Mode shows
it) – useful for screenshots and testing without touching the controller. ES-DE must be running.

## 6. Portrait mode (rotating TV)
Steam Game Mode always draws a 1920x1080 landscape screen, so a rotated TV cannot use it directly. The arcade therefore has
a second, Steam-less session for portrait: gamescope runs ES-DE and the games on a rotated output, and the Steam menu is not
part of it. Landscape is the normal Game Mode and is what everything boots into unless you switch.

| Command (`~/Emulation/tools/scripts/`) | What it does |
|---|---|
| `arcade-rotate.sh status` | shows the current mode |
| `arcade-rotate.sh portrait right` | swaps every table and vertical arcade game to its portrait settings, rotates the output and restarts the session (use `left` if the picture is upside down, and save it with `echo right > ~/Emulation/tools/portrait/direction`) |
| `arcade-rotate.sh landscape` | restores the original landscape settings (the round trip was tested byte for byte) |

- **From the controller:** hold **LB + RB for 5 seconds** while ES-DE is on screen. It never acts during a game or a Steam menu.
- **Backups:** `~/Emulation/tools/portrait/landscape-backup` holds the landscape copy of every file the switch touches.
- **Install or update tables in landscape mode only**, so the saved landscape files stay the originals.
- **Portrait layouts:** tables are scaled to fill the screen (stretch), with the backglass and DMD in a strip across the top and
  the playfield filling the rest. Each table has its own slide/scale numbers; they are the author's own tuning and are not part
  of this kit yet.
- **Limits:** Steam games do not run in portrait (Steam is not part of that session). 19 MAME-standalone games and 5 Steam
  vertical shooters have no portrait layout.

## 7. Lessons from daily use
- **Long attract-mode runs can blank the screen.** Steam's idle-sleep timer counts controller input, not what is on screen, so a
  table or game demoing by itself for about an hour puts the session to sleep, and it may not wake cleanly. In Steam
  Settings set the sleep / dim-after-idle timers to **Never**.
- **Sound at power-on can reach the haptic kit.** If the TV takes a few seconds to appear, the PC's headphone jack (which feeds the
  haptic amp) is briefly the only audio output, so the Steam start sound plays through the haptics. Harmless; it stops once
  the TV's HDMI output is up.
- **TeknoParrot did not work.** We tried Silver Strike Bowling Live through TeknoParrot's Linux support (GE-Proton, PostgreSQL 8.3,
  clean environment, trackball input mode) and the game always crashed in its own OpenGL start-up. Not recommended for now.
- **A table's saved side script (`.vbs`) overrides the script inside the table.** When you replace a table with a newer build,
  move the old `.vbs` away first, or the new table will run the old script.
