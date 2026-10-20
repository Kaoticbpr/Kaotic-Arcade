#!/bin/bash
# KaoticBPR Arcade Kit - Bazzite (SteamOS-style Game Mode) installer.
#
#   ./install.sh                 Visual Pinball X + folders + tuned settings + table tools   (always)
#   ./install.sh --haptics       ...plus the haptic-kit audio routing (shaker / bass transducer on the headphone jack)
#   ./install.sh --leveler       ...plus the loudness leveler (evens out volume between games while ES-DE is open)
#   ./install.sh --all           everything above
#   ./install.sh --latest        use the newest VPX release instead of the tested one
#
# Safe to run again: it repairs/updates and never deletes tables, ROMs or your own settings.
# It does NOT install ES-DE or EmuDeck (install EmuDeck first - see docs/BAZZITE.md) and never touches table cameras.
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPX_TAG="v10.8.1-5436-af26b2d93"          # the build this kit was tested on
VPX_DIR="$HOME/Applications/VPinballX"
TABLES="$HOME/Emulation/roms/vpinball"
TOOLS="$HOME/Emulation/tools"
MEDIA="$TOOLS/downloaded_media/vpinball"
INI="$HOME/.local/share/VPinballX/10.8/VPinballX.ini"
HAPTICS=0; LEVELER=0; LATEST=0
for a in "$@"; do case "$a" in
  --haptics) HAPTICS=1 ;; --leveler) LEVELER=1 ;; --all) HAPTICS=1; LEVELER=1 ;; --latest) LATEST=1 ;;
  -h|--help) sed -n '2,13p' "$0"; exit 0 ;; *) echo "unknown option: $a"; exit 1 ;; esac; done

say()  { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()   { printf '   \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '   \033[33m!\033[0m %s\n' "$*"; }

say "Checking this PC"
for c in curl tar unzip python3 pactl; do command -v $c >/dev/null || { echo "missing: $c"; exit 1; }; done
pgrep -x VPinballX_BGFX >/dev/null && { echo "Close Visual Pinball first (it rewrites its settings on exit)."; exit 1; }
ok "tools present, VPX not running"

# ---------------------------------------------------------------- Visual Pinball X
say "Visual Pinball X (Linux, BGFX build)"
if [ $LATEST = 1 ]; then API="https://api.github.com/repos/vpinball/vpinball/releases?per_page=1"
else API="https://api.github.com/repos/vpinball/vpinball/releases/tags/$VPX_TAG"; fi
URL=$(curl -fsSL "$API" | python3 -c '
import json,sys,re
d=json.load(sys.stdin); d=d[0] if isinstance(d,list) else d
for a in d["assets"]:
    if re.search(r"VPinballX_BGFX-.*-linux-x64-Release\.(tar\.gz|zip)$", a["name"]): print(a["browser_download_url"]); break')
[ -z "$URL" ] && { echo "Could not find the Linux download on GitHub."; exit 1; }
NAME=$(basename "$URL")
if [ -f "$VPX_DIR/.kit-release" ] && [ "$(cat "$VPX_DIR/.kit-release")" = "$NAME" ]; then
  ok "already installed: $NAME"
else
  TMP=$(mktemp -d); echo "   downloading $NAME ..."
  curl -fL --progress-bar -o "$TMP/$NAME" "$URL"
  mkdir -p "$TMP/x"; case "$NAME" in *.zip) unzip -q "$TMP/$NAME" -d "$TMP/x" ;; *) tar xzf "$TMP/$NAME" -C "$TMP/x" ;; esac
  # some releases wrap the files in another archive/folder - find the folder that holds the program
  inner=$(find "$TMP/x" -maxdepth 2 -name '*.tar*' -o -maxdepth 2 -name '*.zip' | head -1 || true)
  [ -n "$inner" ] && { case "$inner" in *.zip) unzip -q "$inner" -d "$TMP/x" ;; *) tar xf "$inner" -C "$TMP/x" ;; esac; }
  BIN=$(find "$TMP/x" -type f -name VPinballX_BGFX | head -1)
  [ -z "$BIN" ] && { echo "VPinballX_BGFX not found in the download."; exit 1; }
  [ -d "$VPX_DIR" ] && mv "$VPX_DIR" "$VPX_DIR.old-$(date +%Y%m%d%H%M%S)" && warn "previous VPX kept as $VPX_DIR.old-*"
  mkdir -p "$(dirname "$VPX_DIR")"; mv "$(dirname "$BIN")" "$VPX_DIR"; chmod +x "$VPX_DIR/VPinballX_BGFX"
  echo "$NAME" > "$VPX_DIR/.kit-release"; rm -rf "$TMP"
  ok "installed to $VPX_DIR"
fi

# ---------------------------------------------------------------- folders + tools
say "Folders and table tools"
mkdir -p "$TABLES"/{music,pupvideos} "$TABLES"/pinmame/{roms,nvram,cfg,altcolor,altsound} \
         "$MEDIA"/{covers,marquees,screenshots,videos} "$TOOLS/scripts"
cp "$KIT"/tools/*.py "$TOOLS/scripts/"; chmod +x "$TOOLS"/scripts/*.py
cp "$KIT"/remote/*.sh "$TOOLS/scripts/"; chmod +x "$TOOLS"/scripts/*.sh
ok "tables:  $TABLES   (ROMs in pinmame/roms)"
ok "tools:   $TOOLS/scripts   (vpx-add.py = table installer, see docs)"

# ---------------------------------------------------------------- VPX settings
say "Visual Pinball settings (graphics, DMD look, paths)"
mkdir -p "$(dirname "$INI")"; [ -f "$INI" ] || : > "$INI"
VPXSET_INI="$INI" python3 "$TOOLS/scripts/vpxset.py" \
  "Player.PlayfieldFullScreen=1" "Player.AAFactor=1.0" "Player.FXAA=6" "Player.SSRefl=1" "Player.ShowFPS=0" \
  "Player.Sharpen=1" "Backglass.BackglassOutput=2" "Plugin.B2SLegacy.B2SHideGrill=1" \
  "Plugin.PinMAME.PinMAMEPath=$TABLES/pinmame/" \
  "DMD.Profile1UnlitDotColor=0X00000000" "DMD.Profile2UnlitDotColor=0X00000000" "DMD.Profile3UnlitDotColor=0X00000000" \
  "DMD.Profile4UnlitDotColor=0X00000000" "DMD.Profile5UnlitDotColor=0X00000000" "DMD.Profile6UnlitDotColor=0X00000000" \
  "DMD.Profile7UnlitDotColor=0X00000000" >/dev/null
ok "SMAA anti-aliasing, screen-space reflections, 1080p native (no supersampling), FPS counter off"
ok "black DMD background (unlit dots off)"
# black DMD glass: the score-view layouts ship with a grey 'dirty glass' ambient light - set it to black
L="$VPX_DIR/plugins/scoreview/layouts"
if [ -d "$L" ]; then
  for f in "$L"/lay4x1-dmd*.scv; do [ -f "$f" ] && sed -i -E 's/^(\s*Ambient:\s*)\[0\.4,0\.4,0\.4\]/\1[0.0,0.0,0.0]/' "$f"; done
  ok "black DMD glass (re-run this installer after a VPX update)"
fi

# ---------------------------------------------------------------- ES-DE
say "ES-DE (Visual Pinball system)"
mkdir -p "$HOME/.local/bin"; cp "$KIT/esde/vpx-launch.sh" "$HOME/.local/bin/"; chmod +x "$HOME/.local/bin/vpx-launch.sh"
FR="$HOME/ES-DE/custom_systems/es_find_rules.xml"
if [ ! -d "$HOME/ES-DE" ]; then
  warn "ES-DE not found (~/ES-DE) - install EmuDeck/ES-DE first, then run this again"
elif [ -f "$FR" ] && grep -q 'emulator name="VISUAL-PINBALL"' "$FR"; then
  ok "ES-DE already has a Visual Pinball launcher rule (left as is: $FR)"
else
  mkdir -p "$(dirname "$FR")"
  [ -f "$FR" ] && cp "$FR" "$FR.bak-kit-$(date +%Y%m%d%H%M%S)"
  python3 - "$FR" "$HOME/.local/bin/vpx-launch.sh" <<'PY'
import os, sys
p, launcher = sys.argv[1], sys.argv[2]
NL = chr(10)
rule = NL.join(['    <emulator name="VISUAL-PINBALL">',
                '        <rule type="staticpath">',
                f'            <entry>{launcher}</entry>',
                '        </rule>',
                '    </emulator>', ''])
s = open(p, encoding="utf-8").read() if os.path.exists(p) else ""
if "</ruleList>" in s:
    i = s.rfind("</ruleList>"); s = s[:i] + rule + s[i:]
else:
    s = NL.join(['<?xml version="1.0"?>', '<ruleList>', '']) + rule + '</ruleList>' + NL
open(p, "w", encoding="utf-8").write(s)
PY
  ok "ES-DE's Visual Pinball system now starts tables with ~/.local/bin/vpx-launch.sh"
fi

# ---------------------------------------------------------------- haptics (optional)
if [ $HAPTICS = 1 ]; then
  say "Haptic kit audio routing"
  echo "   Audio outputs on this PC:"; pactl list short sinks | awk '{printf "     %s\n", $2}'
  TV=$(pactl list short sinks | awk '$2 ~ /hdmi/ {print $2; exit}')
  HP=$(pactl list short sinks | awk '$2 ~ /analog-stereo$/ {print $2; exit}')
  read -rp "   TV output   [$TV]: " a; TV=${a:-$TV}
  read -rp "   Haptic kit  [$HP] (headphone jack): " a; HP=${a:-$HP}
  [ -z "$TV" ] || [ -z "$HP" ] && { echo "Both outputs are needed."; exit 1; }
  for f in arcade-haptic.conf arcade-haptic-lp.conf; do
    sed -e "s|@TV_SINK@|$TV|g" -e "s|@HAPTIC_SINK@|$HP|g" "$KIT/haptics/$f.in" > "$TOOLS/$f"; done
  cp "$KIT/haptics/haptic-router.sh" "$TOOLS/scripts/"; chmod +x "$TOOLS/scripts/haptic-router.sh"
  mkdir -p "$HOME/.config/systemd/user"; cp "$KIT"/haptics/*.service "$HOME/.config/systemd/user/"
  systemctl --user daemon-reload; systemctl --user enable --now arcade-haptic.service arcade-haptic-lp.service >/dev/null 2>&1
  VPXSET_INI="$INI" VPXSET_NOBACKUP=1 python3 "$TOOLS/scripts/vpxset.py" "Player.SoundDevice=Pinball Playfield" >/dev/null
  ok "\"Pinball Playfield\" output = TV + haptic kit; VPX table sounds go there (music/voices stay on the TV)"
  ok "Pinball Wicked / Zaccaria: low-passed copy to the haptic kit (edit ~/.config/arcade-haptic-games to add games)"
fi

# ---------------------------------------------------------------- leveler (optional)
if [ $LEVELER = 1 ]; then
  say "Loudness leveler"
  cp "$KIT/leveler/arcade-leveler.conf" "$TOOLS/"; cp "$KIT/leveler/arcade-leveler.sh" "$TOOLS/scripts/"; chmod +x "$TOOLS/scripts/arcade-leveler.sh"
  mkdir -p "$HOME/.config/systemd/user"; cp "$KIT/leveler/arcade-leveler.service" "$HOME/.config/systemd/user/"
  systemctl --user daemon-reload
  if [ -f "$HOME/.local/bin/arcade-env.sh" ]; then warn "kept your existing ~/.local/bin/arcade-env.sh (compare with leveler/arcade-env.sh)"
  else mkdir -p "$HOME/.local/bin"; cp "$KIT/leveler/arcade-env.sh" "$HOME/.local/bin/"; chmod +x "$HOME/.local/bin/arcade-env.sh"; fi
  ok "installed; it runs while ES-DE is open"
  warn "one manual step: Steam > ES-DE > Properties > Launch Options:  ~/.local/bin/arcade-env.sh %command%"
fi

say "Done"
cat <<EOF
   Next:
   1. Add tables:   ./add-table.sh <folder with one table's downloads> "Title (Maker Year)"
                    download links for every table: TABLES.md
   2. Controls:     X-Arcade Arcade2TV-XR owners run  vpx/vpx-xarcade.sh  once (VPX closed);
                    other controllers: start a table and press F12 > Input
   3. Steam games:  esde/add-steam-game.sh <app id> "Name"   (optional)
   Full guide: docs/BAZZITE.md
EOF
