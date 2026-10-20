# Linux fixes (Visual Pinball X standalone on Bazzite)

VPX on Linux runs table scripts with its own VBScript engine and PinMAME as a plugin. Almost every table works, but a few
Windows habits break. These are the problems we hit building the KaoticBPR Arcade and how they were fixed.
`bazzite/add-table.sh` applies the first one automatically; the rest are per table.

> **Script fixes go in a side file.** To change a table's script, extract it once
> (`~/Applications/VPinballX/VPinballX_BGFX -extractvbs "<table>.vpx"`). That writes `<table>.vbs` next to the table,
> and VPX then uses the `.vbs` instead of the script inside the `.vpx`. The table file itself is never edited.
> Delete the `.vbs` to go back to the original. A table update needs the fix applied again.

## 1. ROM lamps never light (`controller.lamp(n)=true`)
On Linux PinMAME reports lamps/switches as `1`, not `True`, so scripts comparing to `True` never match.
**Fixed automatically** by `vpx-add.py` when a table is added.

## 2. Script stops with "Runtime error on line N" – `Something(...).Property = x` in one statement
The Linux engine doesn't accept setting a property on the result of a call in the same statement.
Example – **Theatre of Magic, line 176**:
```vb
CapKicker1.CreateSizedBallWithMass (Ballsize/2,BallMass).ID=5
```
Fix: create the object first. Here the `.ID` was never used anywhere else and can't be set on Linux, so it is dropped:
```vb
Dim capBall5 : Set capBall5 = CapKicker1.CreateSizedBallWithMass(Ballsize/2,BallMass)
```
How to find it: `~/.local/share/VPinballX/10.8/vpinball.log` → `Runtime error on line N, col C`.

## 3. Colour DMD (Serum) not loading – ROM name upper case
Linux file names are case-sensitive. **Scared Stiff** asks for ROM `SS_15`; the colour file sits in `altcolor/ss_15/ss_15.cRZ`.
Fix: symlinks with the script's spelling:
```bash
cd ~/Emulation/roms/vpinball/pinmame/altcolor && ln -s ss_15 SS_15 && ln -s ss_15.cRZ ss_15/SS_15.cRZ
```

## 4. A table has no music / voices (only mechanical sounds)
PinMAME saves each ROM's sound-mixer state in `pinmame/cfg/<rom>.cfg`. If that was saved while an AltSound pack was
active, the ROM's own sound stays muted after the pack is removed (or volume jumps up and then fades to nothing).
Fix: with VPX closed, move `pinmame/cfg/<rom>.cfg` aside – PinMAME rebuilds it. High scores are **not** in that file.

## 5. "Incorrect U22 for this game" on the DMD (Theatre of Magic, coin-play ROM)
Turn on PinMAME's *skip startup tests* for that table only – add to `<table>.ini`:
```ini
[Plugin.PinMAME]
Cheat = 1
```
Or switch the table to the home ROM: in the script set `Romset = 1` (uses `tom_14h`).

## 6. A table is very quiet after "Factory settings restored"
A ROM reset puts the machine's **own** volume back to its default (Theatre of Magic came back at 13 of 31).
Raise it like a real machine: in attract mode press the coin-door key (**End**), then **9** (+) / **8** (−), then **End** again.
It is saved in the ROM's NVRAM when you quit the table normally.
For everyday balancing between tables use VPX's per-table gain instead (survives ROM resets) – in `<table>.ini`:
```ini
[Player]
AudioSource.PinMAME.Gain = 3.0     ; global default in this kit is 2.0
```

## 7. Two DMDs on screen (tables with a DMD built into their room/background)
Some modern tables (The Walking Dead 4K, Metallica Remastered) draw their own DMD into the scene.
- **Keep the table's DMD:** turn the kit's windows off in `<table>.ini` → `[Backglass] BackglassOutput = 0` and `[ScoreView] ScoreViewOutput = 0`.
- **Keep the kit's DMD (sharper dots):** put the score view over the built-in one and hide the table's – e.g. The Walking Dead
  (`TextBox` is its desktop DMD), at the end of `Sub LoadVRRoom` in the extracted `.vbs`: `TextBox.x = -500`.

## 8. Everything renders but the backglass/DMD cover the table
Never fix this by changing the table's camera (`ViewDT*` keys) – that is how a whole collection's views get ruined.
Size the windows instead: `[Backglass] BackglassWidth/Height` and `[ScoreView] ScoreViewWndX/Y/Width/Height` in `<table>.ini`.
`vpx-add.py` sizes them automatically from the table's default view.

## 9. Supersampling looks blurry
`Player.AAFactor` 1.25 / 1.5 on a 1080p TV gives a soft, shimmering picture (non-integer downscale) and on a Radeon 780M
1.5 halves the frame rate. Keep 1.0 and use **SMAA** (`FXAA = 6`) – the kit's default.
