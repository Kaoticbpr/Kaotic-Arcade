#!/bin/bash
# Add an installed Steam game to ES-DE with its artwork and trailer.
#   ./add-steam-game.sh <app id>          (the number in the game's Steam store URL)
# Close ES-DE first; steam-add.py stages the entry, then --refresh applies it and reloads the menu.
set -e
[ -z "$1" ] && { sed -n '2,4p' "$0"; exit 1; }
python3 "$HOME/Emulation/tools/scripts/steam-add.py" --add "$1"
python3 "$HOME/Emulation/tools/scripts/steam-add.py" --refresh
