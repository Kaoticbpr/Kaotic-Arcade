#!/usr/bin/env bash
# Build the shipping frontend APKs -- one per cabinet -- without touching a device.
#
# rebuild.sh is the development loop: it builds the MvC2 frontend and pushes it straight to the
# cabinet over adb. This script is the release counterpart. It compiles the Java once and drops
# the resulting smali into EVERY frontend project, then builds and signs each one, so the two
# cabinets can never drift apart in code -- they differ only in res/ and in the one class name
# the MvC2 tile is pointed at.
#
#   fe_live -> Frontend.apk       Marvel vs Capcom 2 cabinet
#   fe_xmen -> Frontend-XMen.apk  X-Men '97 deluxe cabinet
#
set -euo pipefail

ROOT="/c/path/to/mvc2-cabinet"
FE="$ROOT/_frontend_extra"
TOOLS="$ROOT/_tools"
R8="$ROOT/_sdk/latest/lib/r8.jar"
ANDROID_JAR="$ROOT/_sdk/root/platforms/android-25/android.jar"
KEYSTORE="$ROOT/_rebuild/mvc2mod.keystore"
KSPASS="mvc2mod"
KSALIAS="mvc2mod"

# project dir : output apk
PROJECTS=(
  "$ROOT/_rebuild/fe_live:$ROOT/_rebuild/frontend_extra.apk"
  "$ROOT/_rebuild/fe_xmen:$ROOT/_rebuild/frontend_xmen.apk"
)

say() { printf '\n=== %s ===\n' "$*"; }

say "1. compile java -> classes"
rm -rf "$FE/javaout" "$FE/dexout" "$FE/shim.apk" "$FE/shimout"
mkdir -p "$FE/javaout" "$FE/dexout"
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

for ENTRY in "${PROJECTS[@]}"; do
  PROJ="${ENTRY%%:*}"
  OUT="${ENTRY##*:}"

  say "5. install smali into $(basename "$PROJ")"
  # Delete OUR old smali first, for the reason rebuild.sh spells out: copying over the top
  # leaves renumbered inner classes behind for good. MainActivity.smali is vendor code we
  # patched by hand -- and in fe_xmen it carries the XmenLegalActivity name -- so the delete
  # list is derived from the sources we compile rather than being "everything here".
  for SRC in "$FE/javasrc/com/arcade/frontend/"*.java; do
    BASE="$(basename "$SRC" .java)"
    rm -f "$PROJ/smali/com/arcade/frontend/$BASE.smali" \
          "$PROJ/smali/com/arcade/frontend/$BASE\$"*.smali
  done
  cp "$FE/shimout/smali/com/arcade/frontend/"*.smali "$PROJ/smali/com/arcade/frontend/"

  say "6. build + sign $(basename "$OUT")"
  rm -f "$OUT" "$OUT.idsig"
  java -jar "$TOOLS/apktool.jar" b -o "$OUT" "$PROJ" 2>&1 | tail -4
  java -jar "$TOOLS/apksigner.jar" sign --ks "$KEYSTORE" --ks-pass "pass:$KSPASS" \
       --ks-key-alias "$KSALIAS" --key-pass "pass:$KSPASS" "$OUT"
  java -jar "$TOOLS/apksigner.jar" verify --print-certs "$OUT" | head -3
  ls -la "$OUT"
done

say "DONE"
