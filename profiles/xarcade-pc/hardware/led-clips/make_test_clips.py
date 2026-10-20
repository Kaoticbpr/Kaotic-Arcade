"""Test clips for the Dig2Go strip on the TV's thin outer rim (STL, mm).
Profile (x: front face=0 -> back, y: rim top=0, up = outward) is extruded 12 mm along z.
Front leg grips the screen-side face, back leg follows the sloped back (~20 deg), bridge rails pin the strip edges,
the gap between them leaves a window for the LEDs. Print z-up, no supports."""
import os, struct, math
LEN, WALL, LEG, STRIP, SLOPE = 12.0, 2.0, 12.0, 3.4, math.tan(math.radians(20))
WINDOW = 7.0

def prism(pts, z0, z1):
    tris, n = [], len(pts)
    for i in range(1, n-1):
        tris.append(((*pts[0], z0), (*pts[i+1], z0), (*pts[i], z0)))
        tris.append(((*pts[0], z1), (*pts[i], z1), (*pts[i+1], z1)))
    for i in range(n):
        a, b = pts[i], pts[(i+1) % n]
        tris.append(((*a, z0), (*b, z0), (*b, z1)))
        tris.append(((*a, z0), (*b, z1), (*a, z1)))
    return tris
def rect(x0, y0, x1, y1): return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]

def clip(W):
    top = STRIP + 2.0
    shapes = [rect(-WALL, -LEG, 0, top)]                                   # front leg
    shapes.append(rect(W, 0, W+WALL, top))                                 # back leg, upper
    d = SLOPE*LEG
    shapes.append([(W,0),(W+WALL,0),(W+WALL+d,-LEG),(W+d,-LEG)])           # back leg, sloped
    c = (W/2) - 0.0
    shapes.append(rect(-WALL, STRIP, c-WINDOW/2, top))                     # front rail
    shapes.append(rect(c+WINDOW/2, STRIP, W+WALL, top))                    # back rail
    tris = []
    for s in shapes: tris += prism(s, 0, LEN)
    return tris

def write(path, tris):
    with open(path, "wb") as f:
        f.write(b"clip".ljust(80, b"\0")); f.write(struct.pack("<I", len(tris)))
        for a, b, c in tris: f.write(struct.pack("<12fH", 0,0,0, *a, *b, *c, 0))

here = os.path.dirname(os.path.abspath(__file__))
for w in (9.0, 10.0, 11.0):
    write(os.path.join(here, f"test_clip_rim_{int(w)}mm.stl"), clip(w + 0.2))   # +0.2 mm fit clearance
print("ok")
