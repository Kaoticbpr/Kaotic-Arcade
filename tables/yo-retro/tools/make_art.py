#!/usr/bin/env python3
"""Make the backglass and launcher images from the show art in "yo retro vpx table assets/".

    python3 tools/make_art.py   # writes art/backglass.png (1920x1080) and art/launcher.png (640x960)

The assets folder is gitignored (the intro video is too big for GitHub), so the images this writes are
committed instead. The hosts come from the full-size pixel art, cut out with the mask of the
background-removed copy, and go on a synthwave backdrop with the logo above them.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

TABLE = Path(__file__).resolve().parent.parent
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


def main():
    hosts, logo_image = hosts_cutout(), logo()
    for name, image in (("backglass.png", backglass(hosts, logo_image)), ("launcher.png", launcher(hosts, logo_image))):
        image.convert("RGB").save(ART / name, optimize=True)
        print(f"wrote art/{name} ({image.width}x{image.height})")


if __name__ == "__main__":
    main()
