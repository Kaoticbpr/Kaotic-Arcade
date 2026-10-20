#!/bin/bash
# X-Men '97 Arcade1Up - Cabinet Expansion v2 installer (macOS)
cd "$(dirname "$0")" || exit 1
ROOT="$(cd .. && pwd)"
ADB="$(pwd)/platform-tools/adb"
chmod +x "$ADB" 2>/dev/null

echo
echo "=================================================================="
echo "   X-MEN '97 DELUXE  Arcade1Up   -   CABINET EXPANSION  v2"
echo "=================================================================="
echo
echo "  Adds Big Blue, Yoga Flame, and an EXTRA GAMES menu that runs"
echo "  up to 20 more arcade games - with sound, TWO-PLAYER support,"
echo "  per-game control screens and menu music."
echo
echo "  Your original X-Men '97 is NOT modified."
echo
echo "------------------------------------------------------------------"
echo "  BEFORE YOU START   (see INSTALL-GUIDE.txt for detail)"
echo "   1) USB keyboard plugged into the back of the cabinet."
echo "   2) USB debugging ON:"
echo "        WINDOWS+N opens the notification shade, then the cog."
echo "        There is no app drawer on this cabinet."
echo "        About tablet > 'Build number' x7, then"
echo "        Developer options > USB debugging"
echo "   3) A micro-USB DATA cable from this Mac to the cabinet."
echo "   4) Your ROMs copied into the  roms  folder (optional)."
echo "------------------------------------------------------------------"
echo
read -r -p "Press RETURN to begin, or Ctrl-C to cancel. "
echo

"$ADB" start-server >/dev/null 2>&1

SERIAL=""
for i in $(seq 1 45); do
  SERIAL=$("$ADB" devices | awk '$2=="device"{print $1; exit}')
  UNAUTH=$("$ADB" devices | awk '$2=="unauthorized"{print $1; exit}')
  [ -n "$SERIAL" ] && break
  if [ -n "$UNAUTH" ]; then
    echo "  Cabinet connected but NOT authorized."
    echo "  On the CABINET SCREEN accept 'Allow USB debugging?' using the"
    echo "  USB keyboard (tick 'Always allow from this computer')."
  else
    echo "  Waiting for the cabinet...  (is it a DATA cable? is USB debugging on?)"
  fi
  sleep 4
done

if [ -z "$SERIAL" ]; then
  echo
  echo "  Could not find the cabinet. See INSTALL-GUIDE.txt."
  echo
  read -r -p "Press RETURN to close. "
  exit 1
fi
echo "  Cabinet found: $SERIAL"
A=("$ADB" -s "$SERIAL")
echo

if ! "${A[@]}" shell pm list packages com.arcade 2>/dev/null | grep -q "package:com.arcade"; then
  echo "  WARNING: this does not look like an Arcade1Up X-Men '97 cabinet."
  read -r -p "  Continue anyway? (y/N): " GO
  case "$GO" in y|Y) ;; *) exit 1 ;; esac
fi

echo "=================================================================="
echo "  Installing - several minutes. Do not unplug."
echo "=================================================================="
echo
echo "  [1/8] Big Blue";      "${A[@]}" install -r "$ROOT/apk/BigBlue.apk"           || exit 1
echo "  [2/8] Yoga Flame";    "${A[@]}" install -r "$ROOT/apk/YogaFlame.apk"         || exit 1
echo "  [3/8] RetroArch";     "${A[@]}" install -r "$ROOT/apk/RetroArch_aarch64.apk" || exit 1
echo "  [4/8] The menu";      "${A[@]}" install -r "$ROOT/apk/Frontend.apk"          || exit 1

echo "  [5/8] Permissions"
for P in READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE; do
  for PKG in com.arcade.bigblue com.arcade.yoga com.retroarch.aarch64; do
    "${A[@]}" shell pm grant "$PKG" "android.permission.$P" >/dev/null 2>&1
  done
done
# Lets the menu re-arm the LIVE button itself after every reboot.
"${A[@]}" shell pm grant com.arcade.frontend android.permission.WRITE_SECURE_SETTINGS >/dev/null 2>&1

echo "  [6/8] Emulator cores, settings and NAOMI save data"
"${A[@]}" shell mkdir -p /sdcard/RetroArch/system >/dev/null 2>&1
"${A[@]}" shell mkdir -p /sdcard/RetroArch/saves/Flycast/reicast >/dev/null 2>&1
"${A[@]}" shell mkdir -p /sdcard/roms >/dev/null 2>&1
"${A[@]}" shell mkdir -p /data/local/tmp/cores >/dev/null 2>&1
echo "        cores (about 95 MB, takes a moment)..."
"${A[@]}" push "$ROOT/cores/fbneo_libretro_android.so"   /data/local/tmp/cores/ >/dev/null 2>&1
"${A[@]}" push "$ROOT/cores/flycast_libretro_android.so" /data/local/tmp/cores/ >/dev/null 2>&1
# Cores must live on /data, which is mounted exec-capable; /sdcard is noexec so a core
# there could never be loaded. 755/644 lets RetroArch read them from its own uid.
"${A[@]}" shell chmod 755 /data/local/tmp/cores >/dev/null 2>&1
"${A[@]}" shell chmod 644 /data/local/tmp/cores/fbneo_libretro_android.so >/dev/null 2>&1
"${A[@]}" shell chmod 644 /data/local/tmp/cores/flycast_libretro_android.so >/dev/null 2>&1
"${A[@]}" push "$ROOT/config/cabinet.cfg" /sdcard/RetroArch/cabinet.cfg >/dev/null 2>&1
# Core override for Flycast only: NAOMI output is quieter than the CPS games, so lift its
# digital level rather than the amp (raising the amp instead just adds speaker hiss).
"${A[@]}" shell mkdir -p /sdcard/RetroArch/config/Flycast >/dev/null 2>&1
"${A[@]}" push "$ROOT/config/Flycast.cfg" /sdcard/RetroArch/config/Flycast/Flycast.cfg >/dev/null 2>&1

# Per-game button remaps for the 3- and 4-button games, so their buttons read left-to-right
# across the top row instead of starting on the bottom row. PLAYER 1 only; player 2 is
# remapped inside the menu app, because RetroArch does not apply remaps to network-gamepad input.
"${A[@]}" shell mkdir -p "/sdcard/RetroArch/config/remaps/FinalBurn Neo" >/dev/null 2>&1
"${A[@]}" shell mkdir -p /sdcard/RetroArch/config/remaps/Flycast >/dev/null 2>&1
"${A[@]}" push "$ROOT/config/remaps/FinalBurn Neo" /sdcard/RetroArch/config/remaps/ >/dev/null 2>&1
"${A[@]}" push "$ROOT/config/remaps/Flycast" /sdcard/RetroArch/config/remaps/ >/dev/null 2>&1
# Pre-seeded save data, so nobody has to sit through a first-boot error screen. The NAOMI
# games open on "BACKUPRAM ID Err ... Press any key" and the four Mortal Kombat boards on
# "CMOS INVALID - FACTORY SETTINGS RESTORED" until their NVRAM has been written once, and it
# is only written on a clean shutdown - which quitting with the LIVE button is not.
"${A[@]}" shell mkdir -p "/sdcard/RetroArch/saves/FinalBurn Neo/fbneo" >/dev/null 2>&1
for F in "$ROOT"/nvram/flycast/*; do
  [ -f "$F" ] && "${A[@]}" push "$F" /sdcard/RetroArch/saves/Flycast/reicast/ >/dev/null 2>&1
done
for F in "$ROOT"/nvram/fbneo/*; do
  [ -f "$F" ] && "${A[@]}" push "$F" "/sdcard/RetroArch/saves/FinalBurn Neo/fbneo/" >/dev/null 2>&1
done

echo "  [7/8] Checking and copying your ROMs"
echo
bash "$(pwd)/verify-roms.sh"; RC=$?
if [ "$RC" = "1" ]; then
  echo
  read -r -p "  Some sets did not match. Copy them anyway? (y/N): " GOR
  case "$GOR" in y|Y) ;; *) echo "  Stopped."; exit 1 ;; esac
fi
echo
N=0
for F in "$ROOT"/roms/*.zip; do
  [ -f "$F" ] || continue
  N=$((N+1)); B="$(basename "$F")"
  echo "        $B"
  case "$B" in
    # naomi.zip must go in BOTH places: Flycast resolves the NAOMI BIOS relative to the
    # CONTENT directory, so with it only in system/ every NAOMI game fails with
    # "cannot load BIOS naomi" even though the file is present and correct.
    naomi.zip) "${A[@]}" push "$F" /sdcard/RetroArch/system/ >/dev/null 2>&1
               "${A[@]}" push "$F" /sdcard/roms/ >/dev/null 2>&1 ;;
    neogeo.zip) "${A[@]}" push "$F" /sdcard/RetroArch/system/ >/dev/null 2>&1 ;;
    *)                    "${A[@]}" push "$F" /sdcard/roms/ >/dev/null 2>&1 ;;
  esac
done
[ "$N" -eq 0 ] && echo "        No ROMs found - see roms/PUT-YOUR-ROMS-HERE.txt"

echo "  [8/8] Boot screen and LIVE button"
"${A[@]}" shell cmd package set-home-activity com.arcade.frontend/com.arcade.frontend.MainActivity >/dev/null 2>&1
# Clearing first forces a REBIND; re-setting the same value leaves the stale
# service bound and the LIVE button stays dead.
"${A[@]}" shell settings put secure enabled_accessibility_services '""' >/dev/null 2>&1
sleep 2
"${A[@]}" shell settings put secure enabled_accessibility_services com.arcade.frontend/com.arcade.frontend.SwitchService >/dev/null 2>&1
"${A[@]}" shell settings put secure accessibility_enabled 1 >/dev/null 2>&1
"${A[@]}" shell am startservice -n com.arcade.frontend/.P2BridgeService >/dev/null 2>&1
"${A[@]}" shell pm disable-user --user 0 com.android.keychain >/dev/null 2>&1

cat <<'EOT'

==================================================================
  INSTALLED
==================================================================

  Everything is installed - including the two emulator cores, so
  there is nothing left to download.

------------------------------------------------------------------
  HOW TO USE
    * The cabinet boots to the menu.
    * Joystick LEFT / RIGHT to choose, any button to select.
    * EXTRA GAMES tile has the 10 added games.
    * Hold the LIVE button 3 seconds to quit a game.
    * Player 1 and Player 2 both work everywhere.

  To undo everything, run UNINSTALL.command
------------------------------------------------------------------

EOT

read -r -p "Reboot the cabinet now? (y/N): " RB
case "$RB" in y|Y) "${A[@]}" reboot; echo "  Rebooting..." ;; esac
echo
read -r -p "Press RETURN to close. "
