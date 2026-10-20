# Control-panel screens for the added games

Twenty 1280x960 screens shown by `com.arcade.frontend/.ControlsActivity` before a game launches.
Installed as `res/drawable/ctrl_<id>.png`; the drawable name comes from `GameRegistry.ctrl`.

Two different pipelines, because the games split into two groups.

## 1. The seven 6-button games — logo swap on a genuine stock screen

`sfa sfa2 sfa3 redearth sfiii sfiii2 sfiii3`

Pixel-diffing the MVC2 app's own control screens showed that **they differ from each other in
nothing but the logo** — background watermark, panel photo, every leader line and every label
are byte-identical across `game_control_{46,100,101,105,106}`. And their labels are already
LIGHT / MEDIUM / HEAVY PUNCH and KICK, which is correct for all seven of these games.

So these are not redraws: they are the vendor's own screens with the logo replaced.

    javac tools/MakeScreen2.java
    java -cp tools MakeScreen2 <stock_base.png> plate_max.png <logo.png> out/ctrl_<id>.png

Base used: `_usbmod/work/mvc2/res/drawable-nodpi-v4/game_control_46.png`.

The old logo is erased with `plate_max.png` rather than a white box. The MARVEL VS CAPCOM
star's left point overlaps the background watermark, so a white box leaves a visible notch.
`plate_max.png` is the per-pixel **lightest** across the six stock screens — background is light
and logo ink is dark, so the max recovers true background wherever any one screen lacked a logo
there. Rebuild it with `tools/Plate.java` if needed.

## 2. The odd-layout games — drawn from scratch, themed per game

`ggx pstone svc cybots punisher mk mk2 mk3 umk3`

Their button counts and names don't match the stock screen, whose LIGHT/MEDIUM/HEAVY PUNCH and
KICK labels are baked into the image with no clean plate to erase them from — all eight stock
screens share identical labels. Attempts to reconstruct a clean plate left artefacts (the
max-blend mangles the 1P start button, which differs between screens). So these are original
designs.

The four Mortal Kombat screens are here for the label text, not the button count: MK uses all
six, but they are HIGH/LOW PUNCH, HIGH/LOW KICK, BLOCK and RUN, none of which the stock plate
says. MK1 and MK2 have no Run, so their bottom-right blocks instead (the core exposes it as
"Block 2") and the screen says BLOCK there.

    perl tools/mk.pl out/<id>.html <logo.png> <bg1> <bg2> <accent> <ink> TL TM TR BL BM BR

`-` for a label means that button is unused in this game; it renders dimmed and unlabelled.
Then render and downscale (2x for clean text):

    chrome --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
           --window-size=1280,960 --screenshot=out/<id>_2x.png file:///<abs>/out/<id>.html
    java -cp tools Scale out/<id>_2x.png out/ctrl_<id>.png 1280 960

Current invocations:

    perl tools/mk.pl out/ggx.html    logos/ggx_t.png    "#2b0a10" "#7a1220" "#e8b23a" "#1a0a02" \
         PUNCH KICK SLASH "HEAVY SLASH" DUST -
    perl tools/mk.pl out/pstone.html logos/pstone_t.png "#0d1f38" "#1d5c8a" "#f5a623" "#1a0d00" \
         ATTACK JUMP ITEM - - -
    perl tools/mk.pl out/svc.html    logos/svc_t.png    "#10111a" "#3a1020" "#d94a4a" "#160406" \
         "LIGHT PUNCH" "LIGHT KICK" "STRONG PUNCH" "STRONG KICK" - -

Design rules worth keeping if these are edited:
- Buttons use the cabinet's **real** colours (red/green/blue, both rows) so a player can match
  screen to panel without translating.
- Unused buttons are **dimmed, not removed** — hiding them would imply the panel has fewer.
- Both players are shown, because the panel has two sets and players look for their own side.

## Logos

`logos/*_t.png` are alpha-trimmed (`tools/TrimOut.java`) — several source logos carry large
transparent margins that otherwise make them render small inside a max-width/max-height box.
Two source files in `roms from pc/` are **WebP with a .png extension** (`PowerStoneLogo.png`,
`sf3 3rd strike.png`); Java ImageIO cannot read them. Convert via headless Chrome with
`--default-background-color=00000000` and trim.

## Note on the prompt text

Every screen, stock and custom, tells the player to press **1P START**. `ControlsActivity`
must therefore handle keycode **108** — it originally only launched on the action buttons
(96-103), so 1P Start did nothing. Fixed 2026-09-04; don't regress it.

## Grid tiles (`tile_<id>.png`)

**Transparent logos, no card / no plate** — they sit directly on the frontend's wallpaper and are
highlighted by `ExtraGamesActivity`'s focus stroke. Canvas is **460x460 with alpha**; the logo is
centred inside it.

The thing to watch is that source logos carry very different transparent margins, so dropping one
straight in can leave it far smaller than its neighbours on screen. Measure the actual artwork
(trim the alpha) rather than the canvas. Current footprints run roughly 300-440 px wide; Guilty
Gear X shipped at 216x172 and looked undersized until it was refitted to 321x258 with:

    java -cp tools FitTile logos/ggx_t.png out/tile_ggx.png 460 460 330 258
