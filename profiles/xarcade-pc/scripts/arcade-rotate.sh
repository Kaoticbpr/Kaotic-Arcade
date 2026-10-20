#!/usr/bin/env bash
# One-command orientation switch for the rotating TV.
#   arcade-rotate.sh status
#   arcade-rotate.sh landscape            normal Steam Game Mode session (CoinOPS theme, all original settings)
#   arcade-rotate.sh portrait [left|right]  Steam-less PORTRAIT session: ES-DE runs directly on a true 1080x1920 screen
#                                         (Steam Game Mode cannot give a portrait screen: it forces 1920x1080). Default direction: saved in
#                                         ~/Emulation/tools/portrait/direction (right = the TV turned the way it is mounted now).
# Both directions swap every pinball table and vertical arcade game (portrait-switch.py), then restart the session (closes ES-DE).
# Refuses while a table/game is running. Add --no-restart to only swap files and stage the session.
# Recovery over ssh if a session ever fails to come up:   arcade-rotate.sh landscape
set -euo pipefail
S=~/Emulation/tools/scripts; SW=$S/portrait-switch.py; DIRF=~/Emulation/tools/portrait/direction
CONF=~/.config/environment.d/91-arcade-portrait.conf
mode=${1:-status}; shift || true
dir=right; [ -f "$DIRF" ] && dir=$(tr -d '[:space:]' < "$DIRF")
restart=1
for a in "$@"; do case $a in left|right) dir=$a;; --no-restart) restart=0;; --now) restart=1;; esac; done
state() { python3 "$SW" status | sed -n 's/^mode: \([a-z]*\).*/\1/p'; }
restart_session() {
  if [ $restart = 1 ]; then systemctl --user restart gamescope-session-plus@ogui-steam.service; echo "Session restarting..."
  else echo "Staged. Restart Game Mode (or rerun without --no-restart) to apply."; fi
}
case $mode in
  status) echo "session: $(grep -q '^STEAMCMD=.' $CONF 2>/dev/null && echo "portrait (Steam-less, $dir)" || echo "landscape (Steam)")"; python3 "$SW" status; exit 0;;
  landscape)
    python3 "$SW" landscape || [ "$(state)" = landscape ]
    cat > "$CONF" <<EOF2
# Landscape: clear the portrait-session overrides (they can be inherited from the boot environment). Written by arcade-rotate.sh.
GAMESCOPE_BIN=$HOME/Emulation/tools/scripts/arcade-gamescope.py
GAMESCOPECMD=
STEAMCMD=
EOF2
    python3 $S/arcade-display-preset.py landscape --activate >/dev/null
    echo "Landscape: original settings restored. Turn the TV back to landscape."
    restart_session;;
  portrait)
    python3 "$SW" portrait || [ "$(state)" = portrait ]
    echo "$dir" > "$DIRF"
    python3 $S/arcade-display-preset.py landscape --activate >/dev/null
    cat > "$CONF" <<EOF
# Arcade portrait session (written by arcade-rotate.sh, removed by 'arcade-rotate.sh landscape'). Sourced by gamescope-session-plus after the session file.
GAMESCOPE_BIN=/usr/bin/gamescope
GAMESCOPECMD="/usr/bin/gamescope -W 3840 -H 2160 -w 1080 -h 1920 --force-external-orientation $dir --prefer-output *,eDP-1 --xwayland-count 1 --hide-cursor-delay 3000 --fade-out-duration 200"
STEAMCMD="$HOME/.local/bin/arcade-env.sh $HOME/Applications/ES-DE.AppImage"
EOF
    echo "Portrait ($dir): ES-DE will start on a 1080x1920 screen without Steam. Turn the TV to portrait."
    restart_session;;
  *) echo "usage: $0 status|landscape|portrait [left|right] [--no-restart]"; exit 2;;
esac
