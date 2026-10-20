#!/usr/bin/env bash
# Rebuild the frontend's Java additions (ExtraGamesActivity/ControlsActivity/GameRegistry)
# and reinstall. Reruns from scratch every time.
set -euo pipefail

ROOT="/c/path/to/mvc2-cabinet"
FE="$ROOT/_frontend_extra"
TOOLS="$ROOT/_tools"
R8="$ROOT/_sdk/latest/lib/r8.jar"
ANDROID_JAR="$ROOT/_sdk/root/platforms/android-25/android.jar"
PROJ="$ROOT/_rebuild/fe_live"
KEYSTORE="$ROOT/_rebuild/mvc2mod.keystore"
KSPASS="mvc2mod"
KSALIAS="mvc2mod"

say() { printf '\n=== %s ===\n' "$*"; }

say "1. compile java -> classes"
rm -rf "$FE/javaout" "$FE/dexout" "$FE/shim.apk" "$FE/shimout"
mkdir -p "$FE/javaout" "$FE/dexout"
# Compile every source in the package rather than a hand-kept list -- the list drifted from
# reality once already, and step 5 derives its delete list from the same glob.
javac -source 8 -target 8 -XDstringConcat=inline -nowarn \
  -cp "$ANDROID_JAR" \
  -d "$FE/javaout" \
  "$FE/javasrc/com/arcade/frontend/"*.java 2>&1 | grep -v 'bootstrap class path' || true

say "2. check for invokedynamic (API25 has none)"
for cls in "$FE/javaout/com/arcade/frontend/"*.class; do
  if javap -c -p "$cls" 2>/dev/null | grep -q invokedynamic; then
    echo "FATAL: invokedynamic in $cls" >&2; exit 1
  fi
done
echo "  clean"

say "3. dex all compiled classes (including anonymous inner classes)"
mapfile -t CLASSFILES < <(find "$FE/javaout" -name "*.class")
java -cp "$R8" com.android.tools.r8.D8 \
     --output "$FE/dexout" --min-api 21 --no-desugaring \
     "${CLASSFILES[@]}"

say "4. round-trip through shim APK to get smali"
cp "$ROOT/_boot/probe/SettingsProvider.apk" "$FE/shim.apk"
jar uf "$FE/shim.apk" -C "$FE/dexout" classes.dex
java -jar "$TOOLS/apktool.jar" d -r -f -o "$FE/shimout" "$FE/shim.apk" >/dev/null 2>&1

say "5. install smali into frontend project"
# Delete OUR old smali first. Copying over the top leaves classes from previous builds behind
# for good -- an anonymous inner class that has since been renumbered (MenuMusic$2$1 becoming
# MenuMusic$3$1, say) stays in the APK referencing fields its outer class no longer has.
# MainActivity.smali is vendor code we patched by hand and must survive, so the delete list is
# derived from the sources we actually compile rather than being "everything here".
for SRC in "$FE/javasrc/com/arcade/frontend/"*.java; do
  BASE="$(basename "$SRC" .java)"
  rm -f "$PROJ/smali/com/arcade/frontend/$BASE.smali" \
        "$PROJ/smali/com/arcade/frontend/$BASE\$"*.smali
done
cp "$FE/shimout/smali/com/arcade/frontend/"*.smali "$PROJ/smali/com/arcade/frontend/"
ls "$PROJ/smali/com/arcade/frontend/"

say "6. rebuild + sign APK"
OUT="$ROOT/_rebuild/frontend_extra.apk"
rm -f "$OUT"
java -jar "$TOOLS/apktool.jar" b -o "$OUT" "$PROJ" 2>&1 | tail -6
java -jar "$TOOLS/apksigner.jar" sign --ks "$KEYSTORE" --ks-pass "pass:$KSPASS" \
     --ks-key-alias "$KSALIAS" --key-pass "pass:$KSPASS" "$OUT"

say "7. install"
export PATH="$PATH:$ROOT/platform-tools"
export MSYS_NO_PATHCONV=1
OUT_WIN="C:/path/to/mvc2-cabinet/_rebuild/frontend_extra.apk"
adb -s 524B4D00008987 install -r "$OUT_WIN" 2>&1 | tail -3

say "8. restore accessibility service + HOME preference (reinstall clears both)"
# Clearing first forces a REBIND. Just re-setting the same value leaves the old,
# now-stale service code bound after an APK reinstall.
adb -s 524B4D00008987 shell 'settings put secure enabled_accessibility_services ""'
sleep 2
adb -s 524B4D00008987 shell 'settings put secure enabled_accessibility_services com.arcade.frontend/com.arcade.frontend.SwitchService'
adb -s 524B4D00008987 shell 'settings put secure accessibility_enabled 1'
adb -s 524B4D00008987 shell 'cmd package set-home-activity com.arcade.frontend/com.arcade.frontend.MainActivity'

say "DONE"
ls -la "$OUT"
