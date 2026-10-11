#!/bin/sh
# Black Widow installer - runs ON the cabinet. Usage: remote-install.sh install|uninstall [reboot|noreboot]
# Only ADDS things. Never updates Batocera, never touches system files, backs up everything it edits.

MODE="${1:-install}"
REBOOT="${2:-noreboot}"
R="${BW_ROOT:-}"   # empty on a real cabinet; only set when testing against a fake tree

SRC="$(cd "$(dirname "$0")" && pwd)"
MAME="$R/userdata/roms/mame"
GL="$MAME/gamelist.xml"
COLL="$R/userdata/system/configs/emulationstation/collections/custom-shootemups.cfg"
CONF="$R/userdata/system/batocera.conf"
CFGDIR="$R/userdata/saves/mame/mame/cfg"
BKROOT="$R/userdata/system/backups"
ROMLINE="./roms/mame/bwidow.zip"

cleanup() { case "$SRC" in /tmp/bwi) rm -rf /tmp/bwi /tmp/bwidow-installer.tgz ;; esac; }
trap cleanup EXIT

say()  { echo "  $*"; }
ok()   { echo "  [ OK ] $*"; }
warn() { echo "  [WARN] $*"; }
die()  { echo "  [FAIL] $*"; echo "  Nothing further was changed."; exit 1; }

ensure_newline() { [ -s "$1" ] && [ -n "$(tail -c1 "$1")" ] && echo >> "$1"; return 0; }

echo
echo "=== Black Widow ${MODE} ==="

[ -d "$R/userdata/roms" ] || die "This doesn't look like a Batocera cabinet (no /userdata/roms)."
[ -d "$MAME" ] || die "No /userdata/roms/mame folder found."

# ---------------------------------------------------------------- INSTALL
if [ "$MODE" = "install" ]; then
    [ -f "$MAME/bwidow.zip" ] || [ -f "$SRC/rom/bwidow.zip" ] || die "bwidow.zip was not supplied."

    # One backup folder holds the ORIGINAL files from the first run; later runs never overwrite it.
    BK="$(ls -d "$BKROOT"/bwidow-installer-* 2>/dev/null | head -1)"
    [ -n "$BK" ] || BK="$BKROOT/bwidow-installer-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BK" || die "Cannot create backup folder $BK"
    say "Backups: $BK"
    ROM_ADDED=0; HAD_CFG=0; GL_ADDED=0
    [ -f "$BK/state" ] && . "$BK/state"
    backup() { [ -e "$1" ] && [ ! -e "$2" ] && cp -p "$1" "$2"; return 0; }

    # --- ROM (never overwrite a ROM that's already there)
    if [ -f "$MAME/bwidow.zip" ]; then
        ok "bwidow.zip already on the cabinet - left untouched"
    else
        cp "$SRC/rom/bwidow.zip" "$MAME/bwidow.zip" && chmod 644 "$MAME/bwidow.zip" || die "Could not copy ROM"
        ROM_ADDED=1
        ok "ROM installed"
    fi

    # --- artwork / video / manual (back up anything we replace)
    mkdir -p "$MAME/images" "$MAME/videos" "$MAME/manuals" "$BK/assets"
    for pair in "bwidow-image.png:images" "bwidow-marquee.png:images" "bwidow-thumb.jpg:images" \
                "bwidow-video.mp4:videos" "bwidow-manual.pdf:manuals"; do
        f="${pair%%:*}"; d="${pair##*:}"
        backup "$MAME/$d/$f" "$BK/assets/$f"
        cp "$SRC/assets/$f" "$MAME/$d/$f" && chmod 644 "$MAME/$d/$f" || die "Could not copy $f"
    done
    ok "artwork, transparent logo, video preview and manual installed"

    # --- controls (twin stick)
    mkdir -p "$CFGDIR"
    if [ -f "$CFGDIR/bwidow.cfg" ] && [ ! -e "$BK/state" ]; then cp -p "$CFGDIR/bwidow.cfg" "$BK/bwidow.cfg"; HAD_CFG=1; fi
    cp "$SRC/bwidow.cfg" "$CFGDIR/bwidow.cfg" && chmod 644 "$CFGDIR/bwidow.cfg" || die "Could not install controls"
    ok "twin-stick controls installed (left stick = move, right stick = fire)"

    # --- game list entry
    if [ -f "$GL" ]; then
        backup "$GL" "$BK/gamelist.xml"
        if grep -q '<path>\./bwidow\.zip</path>' "$GL"; then
            warn "gamelist.xml already has a Black Widow entry - left as is"
        else
            TMP="$GL.bwtmp"
            awk -v blk="$SRC/gamelist-entry.xml" '
                /<\/gameList>/ && !done { while ((getline line < blk) > 0) print line; done=1 }
                { print }
            ' "$GL" > "$TMP"
            OPEN=$(grep -c '<game[ >]' "$TMP"); CLOSE=$(grep -c '</game>' "$TMP")
            if [ "$OPEN" = "$CLOSE" ] && grep -q '<path>\./bwidow\.zip</path>' "$TMP" && [ "$(grep -c '</gameList>' "$TMP")" = "1" ]; then
                cat "$TMP" > "$GL" && GL_ADDED=1 && ok "added Black Widow to the MAME game list"
            else
                warn "could not safely edit gamelist.xml - skipped (your file is unchanged)"
            fi
            rm -f "$TMP"
        fi
    else
        { echo '<?xml version="1.0"?>'; echo '<gameList>'; cat "$SRC/gamelist-entry.xml"; echo '</gameList>'; } > "$GL"
        GL_ADDED=1
        ok "created a MAME game list containing Black Widow"
    fi

    # --- shoot 'em up collection
    if [ -f "$COLL" ]; then
        backup "$COLL" "$BK/custom-shootemups.cfg"
        if grep -qx "$ROMLINE" "$COLL"; then
            ok "already in the Shoot 'em ups collection"
        else
            ensure_newline "$COLL"; echo "$ROMLINE" >> "$COLL"; ok "added to the Shoot 'em ups collection"
        fi
    else
        warn "no Shoot 'em ups collection on this cabinet - skipped"
    fi

    # --- emulator selection (same as the other MAME games)
    if [ -f "$CONF" ]; then
        backup "$CONF" "$BK/batocera.conf"
        for line in 'mame["bwidow.zip"].core=mame' 'mame["bwidow.zip"].emulator=libretro'; do
            grep -qxF "$line" "$CONF" || { ensure_newline "$CONF"; echo "$line" >> "$CONF"; }
        done
        ok "emulator settings set"
    fi

    { echo "ROM_ADDED=$ROM_ADDED"; echo "HAD_CFG=$HAD_CFG"; echo "GL_ADDED=$GL_ADDED"; } > "$BK/state"

    echo
    echo "  DONE. To undo everything, run Uninstall-BlackWidow.bat."
    echo "  IMPORTANT: restart the cabinet BEFORE playing any game, so the game list reloads"
    echo "  (otherwise EmulationStation can overwrite the new entry)."

# -------------------------------------------------------------- UNINSTALL
elif [ "$MODE" = "uninstall" ]; then
    BK="$(ls -d "$BKROOT"/bwidow-installer-* 2>/dev/null | head -1)"
    [ -n "$BK" ] || die "No installer backup found - nothing to uninstall."
    say "Using backup: $BK"
    ROM_ADDED=0; HAD_CFG=0; GL_ADDED=0
    [ -f "$BK/state" ] && . "$BK/state"

    # game list: drop the Black Widow block, but only if the installer added it
    if [ "$GL_ADDED" = "1" ] && [ -f "$GL" ] && grep -q '<path>\./bwidow\.zip</path>' "$GL"; then
        TMP="$GL.bwtmp"
        awk '
            /^[ \t]*<game[ >]/ { buf=$0; inblk=1; keep=1; next }
            inblk { buf = buf "\n" $0
                    if ($0 ~ /<path>\.\/bwidow\.zip<\/path>/) keep=0
                    if ($0 ~ /<\/game>/) { if (keep) print buf; inblk=0 }
                    next }
            { print }
        ' "$GL" > "$TMP" && cat "$TMP" > "$GL" && ok "removed from game list"
        rm -f "$TMP"
    else
        say "game list entry left in place (it was there before the installer ran)"
    fi
    [ -f "$COLL" ] && sed -i "\#^$ROMLINE\$#d" "$COLL" && ok "removed from Shoot 'em ups collection"
    [ -f "$CONF" ] && sed -i '/^mame\["bwidow\.zip"\]\./d' "$CONF" && ok "removed emulator settings"

    for f in images/bwidow-image.png images/bwidow-marquee.png images/bwidow-thumb.jpg videos/bwidow-video.mp4 manuals/bwidow-manual.pdf; do
        rm -f "$MAME/$f"
        [ -f "$BK/assets/$(basename "$f")" ] && cp -p "$BK/assets/$(basename "$f")" "$MAME/$f"
    done
    ok "artwork removed (earlier files restored if there were any)"

    if [ "$HAD_CFG" = "1" ] && [ -f "$BK/bwidow.cfg" ]; then cp -p "$BK/bwidow.cfg" "$CFGDIR/bwidow.cfg"; else rm -f "$CFGDIR/bwidow.cfg"; fi
    ok "controls config reverted"

    if [ "$ROM_ADDED" = "1" ]; then rm -f "$MAME/bwidow.zip"; ok "ROM removed (it was added by the installer)"
    else say "ROM left in place (it was there before the installer ran)"; fi
    echo
    echo "  Uninstalled. Restart the cabinet before playing any game."
else
    die "Unknown mode: $MODE"
fi

if [ "$REBOOT" = "reboot" ]; then
    echo
    echo "  Rebooting the cabinet in 3 seconds..."
    ( sleep 3; reboot ) >/dev/null 2>&1 &
fi
exit 0
