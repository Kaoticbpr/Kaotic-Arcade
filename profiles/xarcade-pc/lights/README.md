# Lights (WLED strip around the TV)

`govee_vpx.py` runs as a systemd user service (`govee-vpx.service.example`) and drives a WLED controller over DDP:

| Mode | What the strip does |
|---|---|
| Pinball (VPX) | table colours from `table_colors.json`, flashers/strobes/beacons from the table's DOF output, music hits |
| ES-DE browsing | the selected game's colours with an attract animation (meteor, plasma, fire, rain ...) |
| Arcade / Steam | game colours plus music and button hits; Steam games without hand-picked colours follow the screen edges |
| Rhythm games | fret colours on their own part of the strip, strum sparkles, YARG's stage-kit light show (sACN) |
| Idle | ambient fire |

`wled.py` is the WLED driver, `b2s_palette.py` picks colours from backglass art, `tv.py` switches a Fire TV on/off
over ADB with Wake-on-LAN (`TV_IP`, `TV_MAC`). Linux only (PipeWire, evdev, gamescope); tested on Bazzite.
