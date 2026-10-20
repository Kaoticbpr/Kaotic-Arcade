#!/bin/bash
# Arcade1Up Cabinet - CRT scanline filter on/off (macOS)
#
#   ./CRT-FILTER.command              toggle on / off
#   ./CRT-FILTER.command light        on, at that strength
#   ./CRT-FILTER.command medium
#   ./CRT-FILTER.command heavy
#   ./CRT-FILTER.command on | off | status
#
cd "$(dirname "$0")" || exit 1
ROOT="$(cd .. && pwd)"
ADB="$(pwd)/platform-tools/adb"
chmod +x "$ADB" 2>/dev/null

RADIR="/storage/emulated/0/RetroArch"
SHDIR="$RADIR/shaders"
CFGDIR="$RADIR/config"
PRESET="$CFGDIR/global.glslp"
PARKED="$CFGDIR/global.glslp.off"

WANT="toggle"
STYLE=""
case "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" in
  on)     WANT="on" ;;
  off)    WANT="off" ;;
  status) WANT="status" ;;
  light)  WANT="on"; STYLE="crt-light" ;;
  medium) WANT="on"; STYLE="crt-medium" ;;
  heavy)  WANT="on"; STYLE="crt-heavy" ;;
esac

echo
echo "=================================================================="
echo "   CABINET CRT FILTER   -   scanlines on / off"
echo "=================================================================="
echo
echo "  Affects the games in the EXTRA GAMES menu only.  Marvel vs"
echo "  Capcom 2, Big Blue and Yoga Flame are left alone - they do not"
echo "  run through RetroArch."
echo
echo "  The cabinet must be plugged into this Mac with a DATA micro-USB"
echo "  cable, with USB debugging on - the same as for the installer."
echo

fail() { echo; echo "------------------------------------------------------------------"; echo "  Nothing was changed."; echo "------------------------------------------------------------------"; echo; read -r -p "Press RETURN to close. "; exit 1; }

[ -x "$ADB" ] || { echo "  ERROR: platform-tools/adb is missing."; fail; }

"$ADB" start-server >/dev/null 2>&1

SERIAL=""
for _ in $(seq 1 12); do
  SERIAL=$("$ADB" devices | awk '$2=="device"{print $1; exit}')
  UNAUTH=$("$ADB" devices | awk '$2=="unauthorized"{print $1; exit}')
  [ -n "$SERIAL" ] && break
  if [ -n "$UNAUTH" ]; then
    echo "  Cabinet connected but NOT authorized.  On the CABINET SCREEN"
    echo "  accept 'Allow USB debugging?' with the USB keyboard."
  else
    echo "  Looking for the cabinet...  (is it a DATA cable?)"
  fi
  sleep 4
done
[ -n "$SERIAL" ] || { echo; echo "  Could not find the cabinet."; fail; }
A=("$ADB" -s "$SERIAL")
echo "  Cabinet found:  $SERIAL"
echo

"${A[@]}" shell "pm list packages com.retroarch.aarch64" | grep -q com.retroarch.aarch64 || {
  echo "  RetroArch is not installed on this cabinet, so there are no"
  echo "  extra games for the filter to apply to.  Run the Cabinet"
  echo "  Expansion installer first."
  fail
}

STATE=$("${A[@]}" shell "if [ -f $PRESET ]; then echo ON; elif [ -f $PARKED ]; then echo OFF; else echo NONE; fi" | tr -d '\r')
CURSTYLE=$("${A[@]}" shell "cat $PRESET $PARKED 2>/dev/null | grep -o 'crt-[a-z]*'" | tr -d '\r' | head -1)
[ -n "$CURSTYLE" ] || CURSTYLE="crt-medium"
[ -n "$STYLE" ]    || STYLE="$CURSTYLE"

if [ "$WANT" = "status" ]; then
  if [ "$STATE" = "ON" ]; then
    echo "  The CRT filter is currently  ON   (${CURSTYLE#crt-})"
  else
    echo "  The CRT filter is currently  OFF"
  fi
  echo; read -r -p "Press RETURN to close. "; exit 0
fi

if [ "$WANT" = "toggle" ]; then
  if [ "$STATE" = "ON" ]; then WANT="off"; else WANT="on"; fi
fi

# Flips video_shader_enable in cabinet.cfg.  RetroArch ignores the auto-preset
# completely unless this is "true", so the flag has to be set as well as the
# preset file.  The rewrite happens on the cabinet through a temp file that is
# only committed when it comes out non-empty, so a half-written config can
# never replace a good one.
set_flag() {
  "${A[@]}" shell "cd $RADIR && [ -f cabinet.cfg ] && grep -v '^video_shader_enable' cabinet.cfg > .crt.tmp && printf 'video_shader_enable = \"$1\"\n' >> .crt.tmp && [ -s .crt.tmp ] && mv .crt.tmp cabinet.cfg && echo FLAG_OK" | grep -q FLAG_OK
}

if [ "$WANT" = "on" ]; then
  echo "  Turning the CRT filter ON  (${STYLE#crt-})..."
  echo
  "${A[@]}" shell "mkdir -p $SHDIR $CFGDIR" >/dev/null 2>&1
  for f in "$ROOT"/shaders/*; do
    "${A[@]}" push "$f" "$SHDIR/" >/dev/null 2>&1 || { echo "  ERROR: could not copy the shader files onto the cabinet."; fail; }
  done
  # global.glslp is RetroArch's "apply to every game" auto-preset.  Holding it as
  # a one-line #reference means the strength can be changed by rewriting one
  # short file, and none of the installer's own settings files get touched.
  "${A[@]}" shell "printf '#reference \"$SHDIR/$STYLE.glslp\"\n' > $PRESET && rm -f $PARKED" >/dev/null 2>&1
  set_flag true || { echo "  ERROR: could not update RetroArch/cabinet.cfg on the cabinet."; fail; }
  "${A[@]}" shell "[ -f $PRESET ] && echo VERIFIED" | grep -q VERIFIED || { echo "  ERROR: the preset did not stick."; fail; }

  echo "  DONE - the CRT filter is now ON."
  echo
  echo "  Start any game from the EXTRA GAMES menu to see it.  A game"
  echo "  that is already running keeps the old look until you quit back"
  echo "  to the menu (hold P1 + P2 Start) and go in again."
  echo
  echo "  Too strong, or too dim?  Run this again with  light  or  heavy."
else
  echo "  Turning the CRT filter OFF..."
  echo
  # Parked, not deleted, so the next switch-on comes back at whatever
  # strength was last chosen.
  "${A[@]}" shell "[ -f $PRESET ] && mv $PRESET $PARKED" >/dev/null 2>&1
  set_flag false || { echo "  ERROR: could not update RetroArch/cabinet.cfg on the cabinet."; fail; }
  echo "  DONE - the CRT filter is now OFF."
  echo
  echo "  Start any game from the EXTRA GAMES menu to see the clean image."
fi

echo
echo "=================================================================="
echo
read -r -p "Press RETURN to close. "
