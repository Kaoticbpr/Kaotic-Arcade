#!/bin/bash
# MVC2 Arcade1Up - Uninstaller / revert to stock (macOS)

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
ADB="$HERE/platform-tools/adb"

B=$'\033[1;33m'; G=$'\033[1;32m'; R=$'\033[1;31m'; N=$'\033[0m'

xattr -dr com.apple.quarantine "$PKG" >/dev/null 2>&1
chmod +x "$ADB" >/dev/null 2>&1

if ! "$ADB" version >/dev/null 2>&1; then
    if command -v adb >/dev/null 2>&1; then
        ADB="$(command -v adb)"
    else
        echo "${R}  Could not run adb.${N}"
        echo "  Try:  brew install android-platform-tools"
        echo
        read -r -p "  Press Return to close. "
        exit 1
    fi
fi

clear
cat <<BANNER
${B} ==================================================================${N}
${B}   MARVEL VS CAPCOM 2  Arcade1Up   -   UNINSTALL / REVERT TO STOCK${N}
${B} ==================================================================${N}

  This removes Big Blue, Yoga Flame and the SELECT YOUR FIGHTER menu,
  puts the boot screen back to the original Marvel vs Capcom 2,
  and re-enables the component that was disabled.

  Your original Marvel vs Capcom 2 was never touched and stays.

 ------------------------------------------------------------------
  Connect the micro-USB DATA cable from this Mac to the cabinet,
  with USB debugging turned on (same as when you installed).
 ------------------------------------------------------------------

BANNER
read -r -p "  Press Return to continue. "
echo

"$ADB" start-server >/dev/null 2>&1

SERIAL=""
TRIES=0
while [ $TRIES -lt 45 ]; do
    SERIAL="$("$ADB" devices | awk '$2=="device"{print $1; exit}')"
    UNAUTH="$("$ADB" devices | awk '$2=="unauthorized"{print $1; exit}')"
    [ -n "$SERIAL" ] && break
    if [ -n "$UNAUTH" ]; then
        echo "  Not authorized yet - choose ALLOW on the cabinet screen."
        sleep 4
    else
        echo "  No cabinet detected yet..."
        sleep 3
        [ $TRIES -ge 12 ] && break
    fi
    TRIES=$((TRIES+1))
done

if [ -z "$SERIAL" ]; then
    echo
    echo "${R}  Could not reach the cabinet. Check the connection and try again.${N}"
    echo
    read -r -p "  Press Return to close. "
    exit 1
fi

echo "${G}  Cabinet found:  $SERIAL${N}"
echo

echo " Restoring the original Marvel vs Capcom 2 boot screen..."
"$ADB" -s "$SERIAL" shell cmd package set-home-activity com.arcade/com.arcade.activity.legal.LegalActivity >/dev/null 2>&1

echo " Turning off the return-to-menu combo..."
"$ADB" -s "$SERIAL" shell settings delete secure enabled_accessibility_services >/dev/null 2>&1
"$ADB" -s "$SERIAL" shell settings put secure enabled_accessibility_services null >/dev/null 2>&1
"$ADB" -s "$SERIAL" shell settings put secure accessibility_enabled 0 >/dev/null 2>&1

echo " Re-enabling com.android.keychain..."
"$ADB" -s "$SERIAL" shell pm enable com.android.keychain >/dev/null 2>&1
"$ADB" -s "$SERIAL" shell pm enable-user --user 0 com.android.keychain >/dev/null 2>&1

echo " Removing the added games and menu..."
"$ADB" -s "$SERIAL" uninstall com.arcade.frontend
"$ADB" -s "$SERIAL" uninstall com.arcade.bigblue
"$ADB" -s "$SERIAL" uninstall com.arcade.yoga

echo
echo "${G} ==================================================================${N}"
echo "${G}   DONE - cabinet reverted to stock.${N}"
echo "${G} ==================================================================${N}"
echo
"$ADB" -s "$SERIAL" shell pm list packages 2>/dev/null | grep -i arcade
echo
read -r -p "  Reboot the cabinet now? (y/N): " RB
case "$RB" in y|Y) "$ADB" -s "$SERIAL" reboot ;; esac
echo
read -r -p "  Press Return to close. "
exit 0
