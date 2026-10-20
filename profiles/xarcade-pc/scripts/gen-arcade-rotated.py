#!/usr/bin/env python3
"""Rotated-frame layouts for vertical arcade games, for a TV that is physically turned 90 degrees while the output stays 1920x1080.
The game is drawn rotated inside the landscape frame (RetroArch video_rotation) and the marquee overlay is pre-rotated, so after the TV is turned
the picture is upright: marquee band on top, game below.
  gen-arcade-rotated.py cw|ccw     cw  = TV turned clockwise (frame's left edge becomes the top)   [default]
                                   ccw = TV turned counter-clockwise (frame's right edge becomes the top)
Writes ~/Emulation/tools/portrait/ra/<core>/<rom>.cfg and overlays/<rom>.{cfg,png} (the files portrait-switch.py swaps in). Run it in LANDSCAPE mode only.
Sources: ~/Emulation/tools/portrait-src/overlays/<rom>.png = the original upright 1080x1920 overlays (copied once, never overwritten)."""
import json, os, shutil, sys
from PIL import Image
H = os.path.expanduser("~"); T = H + "/Emulation/tools"; OUT = T + "/portrait"; SRC = T + "/portrait-src/overlays"
direction = sys.argv[1] if len(sys.argv) > 1 else "cw"
assert direction in ("cw", "ccw"), "usage: gen-arcade-rotated.py cw|ccw"
if not os.path.isdir(SRC):
    shutil.copytree(OUT + "/overlays", SRC)
G = json.load(open(T + "/maintenance/tv-arrival/marquee-audit/installed-games.json"))
BAND, FW, FH = 480, 1920, 1080
ROT = "1" if direction == "cw" else "3"          # RetroArch video_rotation: 1 = 90 deg, 3 = 270 deg (verified by headless test)
VX = BAND if direction == "cw" else 0            # game area is the 1440x1080 part of the frame away from the marquee band
os.makedirs(OUT + "/overlays", exist_ok=True)
n = 0
for x in G:
    if not (x.get("vertical") and x["system"] == "arcade"): continue
    stem = x["stem"]; src = f"{SRC}/{stem}.png"
    if not os.path.exists(src): continue
    core = x["emulator"] if x["emulator"] not in ("default", "", None) else "FinalBurn Neo"
    im = Image.open(src).convert("RGBA")
    im = im.rotate(90 if direction == "cw" else -90, expand=True)
    assert im.size == (FW, FH), im.size
    im.save(f"{OUT}/overlays/{stem}.png", optimize=True)
    open(f"{OUT}/overlays/{stem}.cfg", "w").write(f"overlays = 1\noverlay0_overlay = {stem}.png\noverlay0_full_screen = true\noverlay0_descs = 0\n")
    cfg = f'''input_overlay = "{OUT}/overlays/{stem}.cfg"
input_overlay_enable = "true"
input_overlay_opacity = "1.000000"
input_overlay_scale_landscape = "1.000000"
input_overlay_auto_scale = "false"
input_overlay_auto_rotate = "false"
input_overlay_hide_in_menu = "true"
input_overlay_aspect_adjust_landscape = "0.000000"
input_overlay_x_offset_landscape = "0.000000"
input_overlay_y_offset_landscape = "0.000000"
input_overlay_hide_when_gamepad_connected = "false"
input_overlay_enable_autopreferred = "false"
video_rotation = "{ROT}"
video_shader_enable = "false"
video_scale_integer = "false"
video_crop_overscan = "false"
video_viewport_bias_x = "0.000000"
video_viewport_bias_y = "0.000000"
aspect_ratio_index = "23"
custom_viewport_x = "{VX}"
custom_viewport_y = "0"
custom_viewport_width = "{FW - BAND}"
custom_viewport_height = "{FH}"
config_save_on_exit = "false"
'''
    os.makedirs(f"{OUT}/ra/{core}", exist_ok=True)
    open(f"{OUT}/ra/{core}/{stem}.cfg", "w").write(cfg); n += 1
open(OUT + "/rotation", "w").write(direction + "\n")
print("built", n, "games,", direction)
