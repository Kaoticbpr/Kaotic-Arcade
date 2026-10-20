#!/bin/bash
# MVC2 Arcade1Up - 3-in-1 Game Menu Installer (macOS)

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
ADB="$HERE/platform-tools/adb"

B=$'\033[1;36m'; Y=$'\033[1;33m'; G=$'\033[1;32m'; R=$'\033[1;31m'; N=$'\033[0m'

# macOS quarantines anything downloaded; clear it and make adb runnable.
xattr -dr com.apple.quarantine "$PKG" >/dev/null 2>&1
chmod +x "$ADB" >/dev/null 2>&1

if ! "$ADB" version >/dev/null 2>&1; then
    if command -v adb >/dev/null 2>&1; then
        ADB="$(command -v adb)"
        echo "${Y}  Using the adb already installed on this Mac.${N}"
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
${B}   MARVEL VS CAPCOM 2  Arcade1Up   -   3-in-1 Game Menu${N}
${B} ==================================================================${N}

  Adds two more games to your Marvel vs Capcom 2 cabinet:
      *  Big Blue    -  Street Fighter II  Champion Edition
      *  Yoga Flame  -  Street Fighter II  Hyper Fighting
  ...plus a "SELECT YOUR FIGHTER" menu to pick between all three.

  Your original Marvel vs Capcom 2 is NOT modified.

 ------------------------------------------------------------------
  BEFORE YOU START

  1) Turn the cabinet on and let it boot to the game.

  2) Enable USB debugging on the cabinet:
       Settings  ->  Developer options  ->  USB debugging
     If you don't see "Developer options", first open
       Settings -> About  and tap "Build number" 7 times.

  3) Connect a micro-USB DATA cable from this Mac to the cabinet's
     USB port.  (Charge-only cables will NOT work.)

     macOS needs no driver for this - just the cable.
 ------------------------------------------------------------------

BANNER
read -r -p "  Press Return to continue. "
echo

"$ADB" start-server >/dev/null 2>&1

# -------------------- wait for an authorized device --------------------
SERIAL=""
TRIES=0
while [ $TRIES -lt 45 ]; do
    SERIAL="$("$ADB" devices | awk '$2=="device"{print $1; exit}')"
    UNAUTH="$("$ADB" devices | awk '$2=="unauthorized"{print $1; exit}')"
    [ -n "$SERIAL" ] && break

    if [ -n "$UNAUTH" ]; then
        echo "${Y}  The cabinet is connected but NOT authorized yet.${N}"
        echo "  Look at the CABINET SCREEN for a popup:"
        echo "      \"Allow USB debugging?\"   -   choose  ALLOW"
        echo "      (tick \"Always allow from this computer\")"
        echo "  Tip: plug a USB mouse into the cabinet if you can't click it."
        echo
        echo "  Waiting - this continues automatically once you allow it..."
        sleep 4
    else
        echo "  No cabinet detected yet..."
        echo "    - Is it a DATA cable?  Try a different cable and USB port."
        echo "    - Is USB debugging turned ON in Developer options?"
        echo "    - Plug straight into the Mac, not through a hub."
        echo
        sleep 3
        if [ $TRIES -ge 12 ]; then
            echo "${R}  Could not find the cabinet.${N}"
            break
        fi
    fi
    TRIES=$((TRIES+1))
done

fail() {
    echo
    echo " ------------------------------------------------------------------"
    echo "${R}  Installation did NOT complete.${N}"
    echo "  If you never saw \"SUCCESS\", nothing lasting was changed."
    echo "  See README.txt for troubleshooting, then try again."
    echo " ------------------------------------------------------------------"
    echo
    read -r -p "  Press Return to close. "
    exit 1
}

[ -z "$SERIAL" ] && fail

echo "${G}  Cabinet found:  $SERIAL${N}"
echo

# -------------------- sanity check --------------------
if ! "$ADB" -s "$SERIAL" shell pm list packages com.arcade 2>/dev/null | grep -q "package:com.arcade"; then
    echo "${Y}  WARNING: this does not look like an Arcade1Up MvC2 cabinet${N}"
    echo "  (the \"com.arcade\" app was not found)."
    echo "  You can still continue, but it may not work correctly."
    echo
    read -r -p "  Continue anyway? (y/N): " GO
    case "$GO" in y|Y) ;; *) fail ;; esac
    echo
fi

echo "${B} ==================================================================${N}"
echo "  Installing - this takes a minute or two, do not unplug..."
echo "${B} ==================================================================${N}"
echo
echo " [1/3] Big Blue  (Street Fighter II Champion Edition)"
"$ADB" -s "$SERIAL" install -r "$PKG/apk/BigBlue.apk"   || fail
echo
echo " [2/3] Yoga Flame  (Street Fighter II Hyper Fighting)"
"$ADB" -s "$SERIAL" install -r "$PKG/apk/YogaFlame.apk" || fail
echo
echo " [3/3] SELECT YOUR FIGHTER menu"
"$ADB" -s "$SERIAL" install -r "$PKG/apk/Frontend.apk"  || fail
echo

echo " Granting permissions..."
for P in RECORD_AUDIO READ_EXTERNAL_STORAGE WRITE_EXTERNAL_STORAGE ACCESS_COARSE_LOCATION; do
    "$ADB" -s "$SERIAL" shell pm grant com.arcade.bigblue "android.permission.$P" >/dev/null 2>&1
    "$ADB" -s "$SERIAL" shell pm grant com.arcade.yoga    "android.permission.$P" >/dev/null 2>&1
done

echo " Setting the SELECT YOUR FIGHTER menu as the boot screen..."
"$ADB" -s "$SERIAL" shell cmd package set-home-activity com.arcade.frontend/com.arcade.frontend.MainActivity >/dev/null 2>&1

echo " Enabling the \"hold both Start buttons\" return-to-menu combo..."
"$ADB" -s "$SERIAL" shell settings put secure enabled_accessibility_services com.arcade.frontend/com.arcade.frontend.SwitchService
"$ADB" -s "$SERIAL" shell settings put secure accessibility_enabled 1

echo " Disabling the broken component that causes \"Key Chain has stopped\"..."
"$ADB" -s "$SERIAL" shell pm disable-user --user 0 com.android.keychain >/dev/null 2>&1

echo
echo "${G} ==================================================================${N}"
echo "${G}   SUCCESS${N}"
echo "${G} ==================================================================${N}"
echo
echo "  Installed:"
"$ADB" -s "$SERIAL" shell pm list packages 2>/dev/null | grep -i arcade
echo
echo "  HOW TO USE"
echo "    * Reboot the cabinet.  It boots to the SELECT YOUR FIGHTER menu."
echo "    * Joystick LEFT / RIGHT to choose, any button to play."
echo "    * From inside ANY game, hold"
echo "          PLAYER 1 START  +  PLAYER 2 START   together for 2 seconds"
echo "      to jump back to the menu."
echo
echo "  To undo everything, run  UNINSTALL.command"
echo
read -r -p "  Reboot the cabinet now? (y/N): " RB
case "$RB" in
    y|Y) "$ADB" -s "$SERIAL" reboot; echo "  Rebooting..." ;;
esac
echo
read -r -p "  Press Return to close. "
exit 0
