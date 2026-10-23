# Yo! Retro (original VPX table)

An original, modern-style pinball table for Visual Pinball X, based on **Yo! Retro**, the Thursday show
on [youtube.com/@kaoticbpr](https://www.youtube.com/@kaoticbpr) where KaoticBPR and Half-A-Dozen review
AtGames table releases.
It's built first for the **AtGames Legends 4KP running Legends Unchained** (VPX standalone), so it can be
shared with that community. It needs no ROM.

**Status: v0.2, loads on the 4KP; gameplay not yet tested.** It has the layout, full rules, DMD score display and
the Yo! Retro theme (segments, Half-A-Dozen Multiball, the finale). The theme song is in; the voice hooks are
ready, but the art and voice takes still need adding. Rules and layout are in [DESIGN.md](DESIGN.md),
lines to record are in [VOICE_SCRIPT.md](VOICE_SCRIPT.md), and the art brief is in [art/README.md](art/README.md).

![Layout](docs/layout.png)

## How it's made

The table is built from source, so every change is a readable diff:

| Path | What |
|---|---|
| `base/` | The VPX starter table (walls, flippers, slings, plunger, drain), extracted by vpxtool |
| `tools/layout.py` | Every part this table adds: bumpers, ramp, orbits, targets, scoop, inserts, timers |
| `script/*.vbs` | The game rules, joined in order into the table script |
| `art/`, `sounds/` | Artwork, sounds, voice takes and the theme song, picked up by the build when present |
| `legends/` | Legends Unchained files: starting `table.ini`, draft `table.yml` |
| `tools/build.py` | Puts it all together into `dist/YoRetro.vpx` |

## Build

Needs Python 3 with Pillow, and [vpxtool](https://github.com/francisdb/vpxtool)
(`cargo install vpxtool --locked`, or a release binary).

```sh
python3 tools/build.py          # -> dist/YoRetro.vpx
python3 tools/check_script.py   # lint the script: blocks, undeclared names, missing parts
python3 tools/render_layout.py  # -> docs/layout.png and the art templates
```

## Test on the Legends 4KP

1. Build, then copy `dist/YoRetro.vpx` and `dist/YoRetro.ini` (the build copies it from
   `legends/table.ini`) to the USB drive using the Table Manager's **Add Table > Manual** page.
2. Play, and note anything off: stuck balls, unmakeable shots, the auto-launch too weak or too strong
   (`AutoKickSpeed` in `script/00_setup.vbs`), the DMD layout.
3. Tune the view with **F12** in game and save; send back the new `View*` values for `legends/table.ini`.

Legends Unchained runs VPX standalone 10.8.0, which won't open a newer file, so the build saves the table
as a 10.8 file (`save_as_vpx_108` in `tools/build.py`). The first build loads on the 4KP; play-testing is next.
