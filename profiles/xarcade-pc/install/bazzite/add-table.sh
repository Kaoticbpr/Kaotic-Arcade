#!/bin/bash
# Add one Visual Pinball table.
#   ./add-table.sh "<folder with everything you downloaded for ONE table>" "Title (Maker Year)"
# e.g.  ./add-table.sh ~/Downloads/afm "Attack from Mars (Bally 1995)"
#
# Put the table (.vpx or its zip), backglass (.directb2s), ROM zip and any extras (wheel image, PuP pack, music,
# Serum colors) in the folder - loose or zipped. vpx-add.py sorts them into place, reads the ROM name, applies the
# known Linux script fixes, sizes the backglass + DMD next to the table WITHOUT changing its camera, makes ES-DE
# artwork and adds the table to ES-DE's pinball list.
set -e
[ $# -lt 2 ] && { sed -n '2,10p' "$0"; exit 1; }
[ -d "$1" ] || { echo "not a folder: $1"; exit 1; }
pgrep -x VPinballX_BGFX >/dev/null && { echo "Close Visual Pinball first."; exit 1; }
exec python3 "$HOME/Emulation/tools/scripts/vpx-add.py" "$1" "$(printf '%s' "$2" | base64 -w0)" --refresh
