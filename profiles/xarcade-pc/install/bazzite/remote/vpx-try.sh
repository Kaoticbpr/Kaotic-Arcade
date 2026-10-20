#!/bin/bash
# Launch one table on the TV (with ES-DE's environment, so it shows in Game Mode), wait, screenshot, close.
# usage: vpx-try.sh "<table name without .vpx>" [seconds=35] [out.jpg=/tmp/try.jpg]
T="$HOME/Emulation/roms/vpinball/$1.vpx"; W=${2:-35}; OUT=${3:-/tmp/try.jpg}
E=$(pgrep -x es-de | head -1); [ -z "$E" ] && { echo "ES-DE not running"; exit 1; }
pgrep -x VPinballX_BGFX >/dev/null && { echo "a table is already running"; exit 1; }
( while IFS= read -r -d "" kv; do export "$kv"; done < /proc/$E/environ
  setsid "$HOME/.local/bin/vpx-launch.sh" -play "$T" >/tmp/vpx-try.log 2>&1 < /dev/null & )
for t in $(seq 1 30); do pgrep -x VPinballX_BGFX >/dev/null && break; sleep 1; done
sleep "$W"; gamescopectl screenshot /tmp/try.png; sleep 2
python3 -c "from PIL import Image; import sys; Image.open(\"/tmp/try.png\").convert(\"RGB\").resize((1920,1080)).save(sys.argv[1], quality=88)" "$OUT"
pkill -x VPinballX_BGFX; for t in $(seq 1 20); do pgrep -x VPinballX_BGFX >/dev/null || break; sleep 1; done; echo ok
