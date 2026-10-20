#!/bin/bash
# Start one pinball table on the TV from a remote session (uses ES-DE's environment so it shows in Game Mode and
# goes through the normal launcher). usage: vpx-play.sh "<table name without .vpx>"
E=$(pgrep -x es-de | head -1); [ -z "$E" ] && { echo "ES-DE not running"; exit 1; }
while IFS= read -r -d "" kv; do case "$kv" in BASH_FUNC*) ;; *) export "$kv";; esac; done < /proc/$E/environ
exec "$HOME/.local/bin/vpx-launch.sh" -play "$HOME/Emulation/roms/vpinball/$1.vpx"
