#!/bin/bash
# ES-DE Visual Pinball launcher. Most tables run on the current VPX build (~/Applications/VPinballX).
# Tables listed (by file name, without .vpx) in ~/Emulation/tools/vpx-legacy-tables.txt run on the older
# 10.8.1-3788 build (~/Applications/VPinballX-3788, settings in ~/.vpinball) - e.g. Firepower, whose 1980
# Williams sound board plays wrong on the new build. That build's joystick buttons don't work with the X-Arcade
# on Linux, so vpx-legacy-input.py turns the buttons into its default keys (and handles the P2 X + P2 Start exit).
table="${@: -1}"
name=$(basename "$table" .vpx)
# TV loudness boost while the table runs (VPX skips the arcade leveler), see vpx-volume.sh
setsid "$HOME/Emulation/tools/scripts/vpx-volume.sh" "$name" $$ >/dev/null 2>&1 < /dev/null &
if grep -qxF "$name" "$HOME/Emulation/tools/vpx-legacy-tables.txt" 2>/dev/null; then
  python3 "$HOME/Emulation/tools/scripts/vpx-legacy-input.py" $$ >/dev/null 2>&1 &
  exec "$HOME/Applications/VPinballX-3788/VPinballX_BGFX" "$@"
fi
exec "$HOME/Applications/VPinballX/VPinballX_BGFX" "$@"
