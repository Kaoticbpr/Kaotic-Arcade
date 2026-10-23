#!/usr/bin/env python3
"""Make the backglass and launcher images from the show art in "yo retro vpx table assets/".

    python3 tools/make_art.py   # writes art/backglass.png (1920x1080), art/launcher.png (640x960)
                                # and art/playfield.png (1353x3072)

The assets folder is gitignored (the intro video is too big for GitHub), so the images this writes are
committed instead. The hosts come from the full-size pixel art, cut out with the mask of the
background-removed copy. The backglass and launcher put them on a synthwave backdrop with the logo
above them; the playfield is comic pop art, drawn around the parts in tools/layout.py so moving a
shot there moves its artwork too.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

TABLE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout  # noqa: E402
ASSETS = TABLE / "yo retro vpx table assets"
ART = TABLE / "art"

HOSTS = ASSETS / "yo retro background.png"
HOSTS_MASK = ASSETS / "yo_retro_background-removebg-preview.png"  # same picture, background removed, small
LOGO = ASSETS / "logo.png"

# Retro palette from art/README.md: neon magenta, cyan and yellow on dark purple.
SKY_TOP = (14, 4, 32)
SKY_HORIZON = (92, 14, 96)
FLOOR = (10, 2, 24)
MAGENTA = (255, 40, 200)
CYAN = (0, 230, 255)
YELLOW = (255, 214, 0)


def hosts_cutout():
    """Both hosts at full resolution on a transparent background, trimmed to their outline."""
    hosts = Image.open(HOSTS).convert("RGBA")
    mask = Image.open(HOSTS_MASK).getchannel("A").resize(hosts.size, Image.LANCZOS)
    # The small mask scales up soft: harden it, then feather by a pixel so the outline stays smooth.
    mask = mask.point(lambda v: 0 if v < 100 else 255 if v > 160 else (v - 100) * 255 // 60)
    hosts.putalpha(mask.filter(ImageFilter.GaussianBlur(1.2)))
    return hosts.crop(hosts.getbbox())


def logo():
    image = Image.open(LOGO).convert("RGBA")
    return image.crop(image.getbbox())


def backdrop(width, height, horizon):
    """Synthwave sky over a neon grid floor; horizon is the floor line as a fraction of the height."""
    y0 = int(height * horizon)
    rows = np.linspace(0, 1, y0)[:, None, None]
    sky = (np.array(SKY_TOP) * (1 - rows) + np.array(SKY_HORIZON) * rows) * np.ones((1, width, 1))
    floor = np.ones((height - y0, width, 1)) * np.array(FLOOR)
    image = np.concatenate([sky, floor]).astype(np.float32)

    # Sun: a yellow-to-magenta disc sitting on the horizon, cut by the usual stripes near its base.
    r = width * 0.22 if width > height else width * 0.42
    yy, xx = np.mgrid[0:height, 0:width]
    cx, cy = width / 2, y0 - r * 0.15
    inside = ((xx - cx) ** 2 + (yy - cy) ** 2 < r * r) & (yy < y0)
    t = np.clip((yy - (cy - r)) / (2 * r), 0, 1)[..., None]
    sun = np.array(YELLOW) * (1 - t) + np.array(MAGENTA) * t
    band = (yy - (cy - r * 0.1)) / (r * 0.9)
    stripes = (band > 0) & (np.sin(band * band * 18) > 0.55)
    image[inside & ~stripes] = sun[inside & ~stripes]
    glow = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) ** 0.5 - r).clip(0) / (r * 0.35))[..., None]
    image += np.array(MAGENTA) * glow * 0.35 * (yy < y0)[..., None]

    # Grid: lines running to a vanishing point on the horizon, and crossbars spaced by perspective.
    floor_y = yy - y0
    depth = floor_y / (height - y0)
    on_floor = floor_y > 0
    for k in range(-14, 15):
        x_far = cx + k * width * 0.02
        x_near = cx + k * width * 0.16
        x_line = x_far + (x_near - x_far) * depth
        image[on_floor & (np.abs(xx - x_line) < 0.6 + 1.6 * depth)] = CYAN
    for i in range(1, 14):
        bar = y0 + (height - y0) * (i / 13) ** 2.2
        image[on_floor & (np.abs(yy - bar) < 0.6 + 1.6 * (i / 13) ** 2.2)] = CYAN
    image[y0 - 1:y0 + 2] = MAGENTA
    image = Image.fromarray(image.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")
    return image.filter(ImageFilter.GaussianBlur(0.6))


def place(canvas, image, width=None, height=None, center_x=None, top=None, bottom=None):
    scale = width / image.width if width else height / image.height
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    x = round((center_x if center_x is not None else canvas.width / 2) - image.width / 2)
    y = top if top is not None else bottom - image.height
    canvas.alpha_composite(image, (x, y))


def backglass(hosts, logo_image):
    canvas = backdrop(1920, 1080, horizon=0.62)
    place(canvas, hosts, height=770, bottom=1080)
    place(canvas, logo_image, height=400, top=24)
    return canvas


def launcher(hosts, logo_image):
    canvas = backdrop(640, 960, horizon=0.55)
    place(canvas, hosts, width=640, bottom=960)
    place(canvas, logo_image, width=520, top=40)
    return canvas


# ---------------------------------------------------------------- playfield (comic pop art)

PF_W, PF_H = 1353, 3072                # 4KP texture limit is 3072 px (art/README.md)
PF_SCALE = PF_H / 2162                 # table units -> pixels
POP_YELLOW = (255, 214, 0)
POP_ORANGE = (255, 106, 0)             # the logo's flipper orange
POP_RED = (230, 30, 40)
INK = (16, 12, 20)
PAPER = (255, 250, 235)


def pop_font(size):
    for name in ("impact.ttf", "Impact.ttf", "ariblk.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def pf(x, y):
    return x * PF_SCALE, y * PF_SCALE


def layout_parts():
    return {item["name"]: (kind, item) for kind, item in layout.parts()}


def part_xy(part):
    kind, item = part
    c = item.get("center") or item.get("position")
    return c["x"], c["y"]


def caption(draw, x, y, text, size, fill=PAPER, angle=0, canvas=None, outline=6):
    """Comic lettering: light letters with a thick black outline, centred on (x, y) in table units."""
    font = pop_font(round(size * PF_SCALE))
    px, py = pf(x, y)
    if angle == 0:
        draw.text((px, py), text, font=font, fill=fill, anchor="mm", stroke_width=outline, stroke_fill=INK)
        return
    box = draw.textbbox((0, 0), text, font=font, anchor="lt", stroke_width=outline)
    layer = Image.new("RGBA", (box[2] + 2 * outline, box[3] + 2 * outline), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((outline, outline), text, font=font, fill=fill, stroke_width=outline,
                               stroke_fill=INK)
    layer = layer.rotate(angle, expand=True, resample=Image.BICUBIC)
    canvas.alpha_composite(layer, (round(px - layer.width / 2), round(py - layer.height / 2)))


def burst(draw, x, y, r_out, r_in, points, fill, angle=0.0):
    """A comic starburst centred on (x, y) in table units."""
    cx, cy = pf(x, y)
    pts = []
    for i in range(points * 2):
        r = (r_out if i % 2 == 0 else r_in) * PF_SCALE
        a = angle + math.pi * i / points
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    draw.polygon(pts, fill=fill, outline=INK, width=6)


def pop_background():
    """Yellow centre fading to orange, orange halftone dots that grow toward the edges, speed lines."""
    yy, xx = np.mgrid[0:PF_H, 0:PF_W]
    cx, cy = pf(476, 1290)
    dist = np.hypot((xx - cx) / PF_W, (yy - cy) / PF_H * 0.55)
    t = np.clip(dist / 0.75, 0, 1)[..., None]
    image = np.array(POP_YELLOW) * (1 - t) + np.array(POP_ORANGE) * t
    # Speed lines: thin pale wedges radiating from the logo.
    rays = (np.sin(np.arctan2(yy - cy, xx - cx) * 48) > 0.93)
    image[rays] = image[rays] * 0.75 + np.array(PAPER) * 0.25
    # Halftone: a dot grid, dot size following the gradient.
    step = 22
    gx, gy = (xx % step) - step / 2, (yy % step) - step / 2
    dot_r = (2 + 7 * t[..., 0]) * (0.4 + 0.6 * (((xx // step) + (yy // step)) % 2 == 0))
    dots = np.hypot(gx, gy) < dot_r
    image[dots] = image[dots] * 0.78 + np.array(POP_RED) * 0.22
    return Image.fromarray(image.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")


def host_busts(hosts):
    """Head-and-shoulders of each host from the two-host cutout: (left host, right host)."""
    split = round(hosts.width * 0.465)
    top = round(hosts.height * 0.56)
    left = hosts.crop((0, 0, split, top))
    right = hosts.crop((split, 0, hosts.width, top))
    return left.crop(left.getbbox()), right.crop(right.getbbox())


def insert_disc(draw, light, label=None, label_size=13):
    """Paint an insert: a pale tint of its colour with a black rim, so the light glows through it."""
    kind, item = light
    x, y = part_xy(light)
    r = (max(p["x"] for p in item["drag_points"]) - x) + 4
    colour = tuple(int(item["color"][i:i + 2], 16) for i in (1, 3, 5))
    pale = tuple(round(c * 0.45 + 255 * 0.55) for c in colour)
    cx, cy = pf(x, y)
    rr = r * PF_SCALE
    draw.ellipse([cx - rr - 5, cy - rr - 5, cx + rr + 5, cy + rr + 5], fill=INK)
    draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=pale)
    draw.ellipse([cx - rr * 0.45, cy - rr * 0.55, cx + rr * 0.1, cy - rr * 0.1], fill=(255, 255, 255))
    if label:
        draw.text((cx, cy + 2), label, font=pop_font(round(label_size * PF_SCALE)), fill=INK, anchor="mm")


def arrow(draw, x, y, tip_x, tip_y, width, fill):
    """A fat comic arrow from (x, y) pointing at (tip_x, tip_y), table units."""
    ang = math.atan2(tip_y - y, tip_x - x)
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    length = math.hypot(tip_x - x, tip_y - y)
    head = width * 1.3
    w = width / 2
    pts = [(x + nx * w, y + ny * w), (x + ux * (length - head) + nx * w, y + uy * (length - head) + ny * w),
           (x + ux * (length - head) + nx * w * 2.2, y + uy * (length - head) + ny * w * 2.2), (tip_x, tip_y),
           (x + ux * (length - head) - nx * w * 2.2, y + uy * (length - head) - ny * w * 2.2),
           (x + ux * (length - head) - nx * w, y + uy * (length - head) - ny * w), (x - nx * w, y - ny * w)]
    draw.polygon([pf(*p) for p in pts], fill=fill, outline=INK, width=6)


def playfield(hosts, logo_image):
    parts = layout_parts()
    xy = lambda name: part_xy(parts[name])  # noqa: E731
    canvas = pop_background()
    draw = ImageDraw.Draw(canvas)

    # Centre: logo between the two hosts, in the open area above the slingshots.
    left_host, right_host = host_busts(hosts)
    for bust, cx in ((left_host, 232), (right_host, 720)):
        scale = 250 * PF_SCALE / bust.height
        bust = bust.resize((round(bust.width * scale), round(bust.height * scale)), Image.LANCZOS)
        px, py = pf(cx, 1440)
        canvas.alpha_composite(bust, (round(px - bust.width / 2), round(py - bust.height)))
    burst(draw, 476, 1280, 190, 140, 14, PAPER, angle=0.1)
    # The busts end in a straight cut: a black bar across both finishes them off.
    draw.polygon([pf(40, 1428), pf(912, 1428), pf(902, 1452), pf(50, 1452)], fill=INK)
    place(canvas, logo_image, height=round(290 * PF_SCALE), center_x=pf(476, 0)[0], top=round(pf(0, 1140)[1]))

    # Pop bumpers: a comic sound effect burst under each one.
    for name, word, colour, rot in (("Bumper1", "POW!", POP_RED, 0.2), ("Bumper2", "BAM!", (0, 170, 255), 0.5),
                                    ("Bumper3", "ZAP!", (140, 60, 255), 0.0)):
        x, y = xy(name)
        burst(draw, x, y, 82, 60, 12, colour, angle=rot)
        caption(draw, x, y + 66, word, 26)

    # Top lanes spell YO!
    for i, letter in enumerate("YO!", start=1):
        x, y = xy(f"TopLaneLight{i}")
        insert_disc(draw, parts[f"TopLaneLight{i}"], letter, label_size=17)
    # Segments: numbered inserts and the night's running order under them.
    for i in range(1, 6):
        insert_disc(draw, parts[f"ModeLight{i}"], str(i), label_size=17)
    caption(draw, 470, 980, "1 UNBOXING  2 FIRST FLIPS  3 CHAT ATTACK", 15, outline=4)
    caption(draw, 470, 1004, "4 BUG HUNT  5 THE VERDICT", 15, outline=4)

    # Shots: arrows into each lane, named after the segment that uses them.
    x, y = xy("RampArrow")
    arrow(draw, x, y + 40, x, y - 75, 34, POP_RED)
    insert_disc(draw, parts["RampArrow"])
    caption(draw, x, y + 62, "UNBOX", 20)
    x, y = xy("RightRampArrow")
    arrow(draw, x, y + 40, x, y - 75, 34, POP_RED)
    insert_disc(draw, parts["RightRampArrow"])
    caption(draw, x, y + 62, "UNBOX", 20)
    for name, tip_dy in (("LeftOrbitArrow", -110), ("RightOrbitArrow", -120)):
        x, y = xy(name)
        arrow(draw, x, y + 30, x, y + tip_dy, 30, (0, 170, 255))
        insert_disc(draw, parts[name])
        caption(draw, x, y + 52, "ORBIT", 16, outline=4)
    x, y = xy("Spinner")
    caption(draw, x + 30, y - 140, "THE VERDICT", 22, angle=90, canvas=canvas)
    x, y = xy("Standup2")
    caption(draw, x + 10, y + 48, "+10 SEC", 16, outline=4)
    x, y = xy("LockLight")
    insert_disc(draw, parts["LockLight"], "LOCK", label_size=8)
    caption(draw, x, y + 44, "BUG HUNT", 17, outline=4)
    x, y = xy("Scoop")
    burst(draw, x, y, 62, 44, 10, PAPER, angle=0.3)
    insert_disc(draw, parts["ScoopLight"])
    caption(draw, x, y + 108, "GO LIVE!", 20)
    x, y = xy("ExtraBallLight")
    insert_disc(draw, parts["ExtraBallLight"])
    caption(draw, x, y + 34, "EXTRA BALL", 15, outline=4)
    for n in range(2, 6):
        insert_disc(draw, parts[f"BonusXLight{n}"], f"{n}X", label_size=10)
    caption(draw, 437, 1120, "BONUS", 13, outline=4)
    x, y = xy("ShootAgainLight")
    insert_disc(draw, parts["ShootAgainLight"])
    caption(draw, x, y + 42, "SHOOT AGAIN", 17)
    caption(draw, x, 1560, "YO!", 46)
    return canvas


def main():
    hosts, logo_image = hosts_cutout(), logo()
    images = (("backglass.png", backglass(hosts, logo_image)), ("launcher.png", launcher(hosts, logo_image)),
              ("playfield.png", playfield(hosts, logo_image)))
    for name, image in images:
        image.convert("RGB").save(ART / name, optimize=True)
        print(f"wrote art/{name} ({image.width}x{image.height})")


if __name__ == "__main__":
    main()
