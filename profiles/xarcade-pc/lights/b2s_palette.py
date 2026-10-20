#!/usr/bin/env python3
"""Pull a table's signature colors out of its .directb2s backglass art,
and an arcade game's colors out of its ES-DE marquee.

  python3 b2s_palette.py            build/refresh the cache for every table + arcade game
  python3 b2s_palette.py "Attack from Mars (Bally 1995)"   show one table
  python3 b2s_palette.py arcade sf2                        show one arcade game

Cache: ~/govee/palettes.json   Manual overrides: ~/govee/table_colors.json
  e.g. {"Attack from Mars (Bally 1995)": ["#ff2000", "#20ff40", "#2060ff"]}
"""
import base64
import colorsys
import io
import json
import os
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

HOME = os.path.expanduser("~")
TABLE_DIR = os.path.join(HOME, "Emulation/roms/vpinball")
CACHE = os.path.join(HOME, "govee/palettes.json")
OVERRIDES = os.path.join(HOME, "govee/table_colors.json")
MEDIA_DIR = os.path.join(HOME, "Emulation/tools/downloaded_media")
STEAM_CACHE = os.path.join(HOME, ".local/share/Steam/appcache/librarycache")
ARCADE_SYSTEMS = ["arcade", "mame", "fbneo", "neogeo", "naomi", "atomiswave", "model2", "cps1", "cps2", "cps3"]
DEFAULT = [(255, 40, 0), (255, 140, 0), (0, 200, 255), (40, 80, 255), (170, 0, 255), (255, 0, 140)]


def _load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def backglass_image(b2s_path):
    for _, el in ET.iterparse(b2s_path, events=("start",)):
        if el.tag in ("BackglassImage", "ThumbnailImage") and el.get("Value"):
            return Image.open(io.BytesIO(base64.b64decode(el.get("Value")))).convert("RGB")
    return None


def extract(img, k=7, keep=4):
    img = img.copy()
    img.thumbnail((96, 96))
    px = np.asarray(img, dtype=np.float32).reshape(-1, 3) / 255
    mx, mn = px.max(1), px.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    good = px[(sat > 0.35) & (mx > 0.3)]
    if len(good) < 50:
        return None
    rng = np.random.default_rng(1)
    cent = good[rng.choice(len(good), k, replace=False)]
    for _ in range(12):
        lab = np.argmin(((good[:, None] - cent[None]) ** 2).sum(-1), 1)
        cent = np.array([good[lab == i].mean(0) if (lab == i).any() else cent[i] for i in range(k)])
    counts = np.bincount(lab, minlength=k)
    scored = []
    for c, n in zip(cent, counts):
        h, s, v = colorsys.rgb_to_hsv(*c)
        scored.append((n * (s * v) ** 1.5, h, s))
    scored.sort(reverse=True)
    out = []
    for _, h, s in scored:
        if all(min(abs(h - oh), 1 - abs(h - oh)) > 0.05 for oh, _ in out):
            out.append((h, s))
        if len(out) == keep:
            break
    # vivid versions of the art's colors (LEDs look washed out otherwise)
    return [tuple(int(x * 255) for x in colorsys.hsv_to_rgb(h, max(0.75, s), 1.0)) for h, s in out]


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def palette_for(table_name, b2s_path=None):
    """Override > cache > extract from backglass > default."""
    return _cached(table_name, table_name, lambda: _from_b2s(b2s_path or os.path.join(TABLE_DIR, table_name + ".directb2s")))


def game_palette(system, rom):
    """Arcade/console game colors from ES-DE's marquee art (fallback: title screen, screenshot).

    Keyed "system/rom" in the cache and in table_colors.json, e.g. "arcade/sf2"."""
    def build():
        for kind in ("marquees", "titlescreens", "screenshots"):
            for ext in (".png", ".jpg"):
                p = os.path.join(MEDIA_DIR, system, kind, rom + ext)
                if os.path.exists(p):
                    pal = extract(Image.open(p).convert("RGB"))
                    if pal:
                        return pal
        return None
    return _cached(f"{system}/{rom}", rom, build)


def steam_palette(appid, name=""):
    """Steam game colors from Steam's cached library art. Override key "steam/<appid>" or the game name."""
    ov = _load(OVERRIDES)
    if name in ov:
        return [hex2rgb(c) for c in ov[name]]

    def build():
        d = os.path.join(STEAM_CACHE, str(appid))
        if not os.path.isdir(d):
            return None
        files = [os.path.join(d, f) for f in os.listdir(d) if f.lower().endswith((".jpg", ".png"))]
        files.sort(key=lambda p: (os.path.basename(p) != "header.jpg", -os.path.getsize(p)))
        for p in files:
            pal = extract(Image.open(p).convert("RGB"))
            if pal:
                return pal
        return None
    return _cached(f"steam/{appid}", name or str(appid), build)


def _from_b2s(path):
    if os.path.exists(path):
        img = backglass_image(path)
        return extract(img) if img else None
    return None


def _cached(key, label, build):
    """Override > cache > build() > default; result cached under key."""
    ov = _load(OVERRIDES)
    if key in ov:
        return [hex2rgb(c) for c in ov[key]]
    cache = _load(CACHE)
    if key in cache:
        return [tuple(c) for c in cache[key]]
    pal = None
    try:
        pal = build()
    except Exception as e:  # corrupt/odd art: fall back quietly
        print(f"palette: {label}: {e}", flush=True)
    pal = pal or DEFAULT
    cache[key] = pal
    try:
        with open(CACHE, "w") as f:
            json.dump(cache, f, indent=1)
    except OSError:
        pass
    return pal


def main():
    if len(sys.argv) > 2:
        print(sys.argv[1], sys.argv[2], game_palette(sys.argv[1], sys.argv[2]))
        return
    if len(sys.argv) > 1:
        print(sys.argv[1], palette_for(sys.argv[1]))
        return
    for fn in sorted(os.listdir(TABLE_DIR)):
        if fn.endswith(".directb2s"):
            name = fn[:-10]
            pal = palette_for(name)
            print(f"{name:55} " + " ".join("#%02x%02x%02x" % c for c in pal), flush=True)
    for system in ARCADE_SYSTEMS:
        d = os.path.join(HOME, "Emulation/roms", system)
        if not os.path.isdir(d):
            continue
        roms = sorted({os.path.splitext(f)[0] for f in os.listdir(d) if not f.startswith(".")})
        n = sum(1 for r in roms if game_palette(system, r) != DEFAULT)
        print(f"{system}: {n}/{len(roms)} games got colors from their art", flush=True)


if __name__ == "__main__":
    main()
