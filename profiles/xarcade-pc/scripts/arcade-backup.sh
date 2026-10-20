#!/bin/bash
# Arcade config backup: small, no games/ROMs/media. Result: ~/backups/arcade-config-<date>.tar.gz (+ RESTORE.txt inside).
# Run:  ~/Emulation/tools/scripts/arcade-backup.sh        (safe to run any time; only reads, then writes one archive)
set -u
H="$HOME"; D=$(date +%Y%m%d-%H%M%S); OUT="$H/backups"; mkdir -p "$OUT"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/extra"

# live WLED settings (strip config, LED count, current limit, Alexa name)
[ -n "${WLED_IP:-}" ] && curl -s -m 5 http://$WLED_IP/json/cfg -o "$WORK/extra/wled-cfg.json" 2>/dev/null
[ -n "${WLED_IP:-}" ] && curl -s -m 5 http://$WLED_IP/json/info -o "$WORK/extra/wled-info.json" 2>/dev/null
# installed Steam shortcuts (non-Steam games) and the system service list
cp "$H/.local/share/Steam/userdata/"*/config/shortcuts.vdf "$WORK/extra/" 2>/dev/null
systemctl --user list-unit-files --no-pager > "$WORK/extra/user-units.txt" 2>/dev/null
flatpak list --app > "$WORK/extra/flatpaks.txt" 2>/dev/null
pip list --user 2>/dev/null > "$WORK/extra/pip-user.txt"

cat > "$WORK/extra/RESTORE.txt" <<'E'
Arcade config backup. Extract into the home folder:  tar -xzf arcade-config-<date>.tar.gz -C ~
Paths are relative to ~ . What is inside:
  govee/                  lights engine (govee_vpx.py, wled.py, b2s_palette.py, tv.py), colour tables, adb key
  .config/systemd/user/   lights service + rotate button + menu-focus services (then: systemctl --user daemon-reload)
  Emulation/tools/scripts, Emulation/tools/portrait (+ loudness, fixes json)  rotation + portrait layouts
  pinball-portrait/       portrait layout generator + overrides.json (without the big render folder)
  ES-DE/                  gamelists, collections, settings, custom systems (not themes/media)
  .local/share/VPinballX/10.8/VPinballX.ini + Emulation/roms/vpinball/*.ini|*.vbs   Visual Pinball settings per table
  Steam Controller Configs (Steam Input per-game files)
  .config/unity3d/YARC/YARG/release/{profiles,settings.json}   YARG profiles and settings
  Applications/launch-yarg.sh, Games/GHWT/*.sh|*.py, Emulation/roms/steam/*.sh   launchers
  extra/                  WLED cfg/info, shortcuts.vdf, unit/flatpak/pip lists
After restoring: re-run the Steam Input games once, restart ES-DE, and `systemctl --user daemon-reload`.
E

LIST="$WORK/list.txt"; : > "$LIST"
add() { for p in "$@"; do [ -e "$H/$p" ] && echo "$p" >> "$LIST"; done; }
add govee .config/systemd/user Emulation/tools/scripts Emulation/tools/portrait Emulation/tools/vpx-loudness.json \
    Emulation/tools/vpx-table-fixes.json Emulation/tools/trackball-profiles.json Emulation/tools/launchers \
    ES-DE/gamelists ES-DE/collections ES-DE/settings ES-DE/custom_systems \
    .local/share/VPinballX/10.8/VPinballX.ini ".local/share/Steam/steamapps/common/Steam Controller Configs" \
    .config/unity3d/YARC/YARG/release/profiles .config/unity3d/YARC/YARG/release/settings.json \
    Applications/launch-yarg.sh Games/GHWT/launch-ghwt.sh Games/GHWT/launch-ghwtde.sh Games/GHWT/enforce-input.py \
    Games/GHWT/guitar-replug.sh .mame/cfg ".var/app/org.libretro.RetroArch/config/retroarch/config" \
    .config/environment.d .local/bin pinball-portrait/gen_ini.py pinball-portrait/overrides.json pinball-portrait/apply_layout.py \
    pinball-portrait/layout_test.py pinball-portrait/base.ini pinball-portrait/runh.sh pinball-portrait/p2
ls "$H"/Emulation/roms/steam/*.sh "$H"/Emulation/roms/vpinball/*.ini "$H"/Emulation/roms/vpinball/*.vbs 2>/dev/null | sed "s|^$H/||" >> "$LIST"

ARCH="$OUT/arcade-config-$D.tar.gz"
tar --ignore-failed-read --exclude='*.bak*' --exclude='*/rot' --exclude='govee/state' --exclude='__pycache__' \
    -czf "$ARCH" -C "$H" -T "$LIST" -C "$WORK" extra 2>/dev/null
echo "backup written: $ARCH ($(du -h "$ARCH" | cut -f1), $(tar -tzf "$ARCH" | wc -l) files)"
# keep the 10 newest
ls -1t "$OUT"/arcade-config-*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
