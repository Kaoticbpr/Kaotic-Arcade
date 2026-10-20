#!/bin/bash
# X-Men '97 Arcade1Up - Cabinet Expansion v2 uninstaller (macOS)
cd "$(dirname "$0")" || exit 1
ADB="$(pwd)/platform-tools/adb"
chmod +x "$ADB" 2>/dev/null

echo
echo "=================================================================="
echo "   X-Men '97 Arcade1Up  -  UNINSTALL"
echo "=================================================================="
echo
echo "  Removes everything this mod added and puts the cabinet back to"
echo "  booting straight into X-Men '97."
echo "  Your original X-Men '97 was never modified and is not touched."
echo
read -r -p "Press RETURN to continue, or Ctrl-C to cancel. "
echo

"$ADB" start-server >/dev/null 2>&1
SERIAL=$("$ADB" devices | awk '$2=="device"{print $1; exit}')
if [ -z "$SERIAL" ]; then
  echo "  No cabinet detected. Check the cable and USB debugging."
  read -r -p "Press RETURN to close. "; exit 1
fi
echo "  Cabinet found: $SERIAL"
A=("$ADB" -s "$SERIAL")
echo

echo "  [1/5] Boot screen back to X-Men '97"
"${A[@]}" shell cmd package set-home-activity com.arcade/com.arcade.activity.NewHomeActivity >/dev/null 2>&1
echo "  [2/5] Turning off the LIVE button service"
"${A[@]}" shell settings put secure enabled_accessibility_services '""' >/dev/null 2>&1
"${A[@]}" shell settings put secure accessibility_enabled 0 >/dev/null 2>&1
echo "  [3/5] Removing the menu, Big Blue and Yoga Flame"
for P in com.arcade.frontend com.arcade.bigblue com.arcade.yoga; do
  "${A[@]}" uninstall "$P" >/dev/null 2>&1
done
echo
read -r -p "Also remove RetroArch and the extra games? (y/N): " RA
case "$RA" in
  y|Y) echo "  [4/5] Removing RetroArch and its files"
       "${A[@]}" uninstall com.retroarch.aarch64 >/dev/null 2>&1
       # Keep /sdcard/RetroArch/system - the user.s own BIOS files.
       for D in config saves states screenshots temp downloads playlists; do
         "${A[@]}" shell rm -rf "/sdcard/RetroArch/$D" >/dev/null 2>&1
       done
       "${A[@]}" shell rm -f /sdcard/RetroArch/cabinet.cfg >/dev/null 2>&1
       "${A[@]}" shell rm -rf /data/local/tmp/cores >/dev/null 2>&1 ;;
  *)   echo "  [4/5] Leaving RetroArch and your ROMs in place" ;;
esac
echo "  [5/5] Re-enabling the component the installer disabled"
"${A[@]}" shell pm enable com.android.keychain >/dev/null 2>&1

echo
echo "=================================================================="
echo "   DONE  -  reboot the cabinet and it is back to normal."
echo "=================================================================="
echo
read -r -p "Reboot the cabinet now? (y/N): " RB
case "$RB" in y|Y) "${A[@]}" reboot; echo "  Rebooting..." ;; esac
echo
read -r -p "Press RETURN to close. "
