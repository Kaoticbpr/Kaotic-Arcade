#!/usr/bin/env python3
"""Draw the playfield from build/expanded (run tools/build.py first).

    python3 tools/render_layout.py   # writes docs/layout.png and art/templates/*.png

docs/layout.png is the labelled overview. The templates in art/templates are sized
for the Legends 4KP (see art/README.md): draw the artwork on top of them, keeping
holes, lanes and inserts where the outlines are.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

TABLE = Path(__file__).resolve().parent.parent
EXPANDED = TABLE / "build" / "expanded"
W, H = 952.0, 2162.0

COLORS = {"Wall": (60, 60, 70), "Rubber": (200, 40, 40), "Ramp": (40, 110, 220), "Trigger": (30, 150, 60),
          "Bumper": (230, 120, 0), "Kicker": (0, 0, 0), "HitTarget": (200, 0, 160), "Spinner": (0, 150, 150),
          "Flipper": (0, 0, 0), "Gate": (120, 120, 120), "Plunger": (120, 120, 120)}


def load_items():
    items = []
    for f in sorted((EXPANDED / "gameitems").glob("*.json")):
        data = json.loads(f.read_text())
        kind = next(iter(data))
        items.append((kind, data[kind]))
    return items


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw(scale, labels, background=(255, 255, 255)):
    img = Image.new("RGB", (round(W * scale), round(H * scale)), background)
    d = ImageDraw.Draw(img)
    s = scale
    label_font = font(max(10, round(14 * s)))
    line = max(1, round(2 * s))

    def pt(x, y):
        return (x * s, y * s)

    def text(x, y, msg, fill=(90, 0, 140)):
        if labels:
            d.text(pt(x + 6, y - 6), msg, fill=fill, font=label_font)

    for kind, o in load_items():
        col = COLORS.get(kind, (150, 150, 150))
        dps = o.get("drag_points") or []
        c = o.get("center") or o.get("position")
        if kind == "Wall":
            if len(dps) > 2 and o.get("is_collidable", True):
                visible = o.get("is_top_bottom_visible") or o.get("is_side_visible")
                d.polygon([pt(p["x"], p["y"]) for p in dps], outline=col,
                          fill=(205, 205, 210) if visible else None, width=line)
        elif kind == "Rubber":
            if o.get("is_visible", True) and len(dps) > 1:
                d.line([pt(p["x"], p["y"]) for p in dps + dps[:1]], fill=col, width=line * 2)
        elif kind == "Ramp":
            pts = [(p["x"], p["y"]) for p in dps]
            if len(pts) > 1 and o.get("is_visible", True) and o.get("width_bottom", 0) > 5:
                d.line([pt(*p) for p in pts], fill=(170, 200, 250), width=round(o["width_bottom"] * s))
                d.line([pt(*p) for p in pts], fill=col, width=line)
                text(*pts[-1], f"{o['name']} (h {o['height_top']:.0f})", col)
        elif kind == "Light":
            if not o.get("is_bulb_light") and len(dps) > 2:
                d.polygon([pt(p["x"], p["y"]) for p in dps], fill=o["color"], outline=(0, 0, 0))
        elif kind == "Bumper":
            r = o["radius"]
            d.ellipse([pt(c["x"] - r, c["y"] - r), pt(c["x"] + r, c["y"] + r)], outline=col, width=line * 2)
            text(c["x"], c["y"], o["name"])
        elif kind == "Kicker":
            r = o["radius"]
            d.ellipse([pt(c["x"] - r, c["y"] - r), pt(c["x"] + r, c["y"] + r)], fill=(40, 40, 40))
            text(c["x"] + r, c["y"], o["name"])
        elif kind == "Trigger":
            if o.get("is_visible", True) and o.get("shape") != "none":
                r = o["radius"]
                d.ellipse([pt(c["x"] - r, c["y"] - r), pt(c["x"] + r, c["y"] + r)], outline=col, width=line)
            text(c["x"], c["y"], o["name"], col)
        elif kind == "HitTarget":
            a = math.radians(o["rot_z"])
            hw, hd = o["size"]["x"] / 2, 6
            ux, uy, nx, ny = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
            corners = [(c["x"] + ux * i * hw + nx * j * hd, c["y"] + uy * i * hw + ny * j * hd)
                       for i, j in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            d.polygon([pt(*p) for p in corners], fill=col)
            text(c["x"], c["y"], o["name"], col)
        elif kind in ("Spinner", "Gate"):
            a = math.radians(o["rotation"])
            hl = o["length"] / 2
            d.line([pt(c["x"] - math.cos(a) * hl, c["y"] - math.sin(a) * hl),
                    pt(c["x"] + math.cos(a) * hl, c["y"] + math.sin(a) * hl)], fill=col, width=line * 3)
            text(c["x"], c["y"], o["name"], col)
        elif kind == "Flipper":
            a = math.radians(o["start_angle"])
            tip = (c["x"] + math.sin(a) * o["flipper_radius_max"], c["y"] - math.cos(a) * o["flipper_radius_max"])
            d.line([pt(c["x"], c["y"]), pt(*tip)], fill=col, width=round(o["base_radius"] * 1.6 * s))
    return img


def guide(size, title, notes, margin):
    """A blank canvas of the right size with a safe-area box and notes."""
    img = Image.new("RGB", size, (235, 235, 240))
    d = ImageDraw.Draw(img)
    w, h = size
    d.rectangle([margin, margin, w - margin, h - margin], outline=(220, 0, 120), width=4)
    d.text((margin + 20, margin + 20), title, fill=(30, 30, 30), font=font(max(24, w // 30)))
    y = margin + 20 + max(24, w // 30) + 20
    for line in notes:
        d.text((margin + 20, y), line, fill=(80, 80, 80), font=font(max(16, w // 60)))
        y += max(16, w // 60) + 10
    return img


def main():
    docs = TABLE / "docs"
    templates = TABLE / "art" / "templates"
    docs.mkdir(exist_ok=True)
    templates.mkdir(parents=True, exist_ok=True)

    draw(0.5, labels=True).save(docs / "layout.png")
    # 4KP textures top out at 3072 px (MaxTexDimension), so the playfield art is 1353 x 3072.
    pf_scale = 3072 / H
    draw(pf_scale, labels=False).save(templates / "playfield_template_1353x3072.png")
    draw(pf_scale, labels=True).save(templates / "playfield_template_labelled_1353x3072.png")
    guide((1920, 1080), "BACKGLASS 1920 x 1080",
          ["Shown on the 4KP's backglass screen.", "Keep text and faces inside the pink box.",
           "Save as art/backglass.png"], 40).save(templates / "backglass_template_1920x1080.png")
    guide((640, 960), "LAUNCHER 640 x 960",
          ["Box art in the Legends launcher menu.", "Save as art/launcher.png"], 24).save(
        templates / "launcher_template_640x960.png")
    print(f"wrote {docs / 'layout.png'} and art templates in {templates}")


if __name__ == "__main__":
    main()
