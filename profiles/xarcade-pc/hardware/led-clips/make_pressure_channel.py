"""Pressure-fit channel for the TV's 1/4" rim (STL, mm).
Rim: about 10 mm front-to-back, flat for 6.35 mm down, then the back slopes out (~20 deg, guess).
Strip (10 mm, silicone) lies in the open channel on top; legs grip the rim; double-sided tape is backup.
Profile is extruded along z (60 mm), so it prints standing on end, no supports."""
import os, struct, math
LEN, STRIP, WALL, WALLH, FLOOR, LEG_T = 60.0, 10.0, 1.0, 3.0, 2.0, 1.5
FLAT, LEG, FRONT_LEG, SLOPE = 6.35, 12.0, 4.0, math.tan(math.radians(20))

def prism(pts, z0, z1):
    t, n = [], len(pts)
    for i in range(1, n-1):
        t.append(((*pts[0], z0), (*pts[i+1], z0), (*pts[i], z0)))
        t.append(((*pts[0], z1), (*pts[i], z1), (*pts[i+1], z1)))
    for i in range(n):
        a, b = pts[i], pts[(i+1) % n]
        t += [((*a, z0), (*b, z0), (*b, z1)), ((*a, z0), (*b, z1), (*a, z1))]
    return t
def rect(x0, y0, x1, y1): return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
def write(path, tris):
    with open(path, "wb") as f:
        f.write(b"channel".ljust(80, b"\0")); f.write(struct.pack("<I", len(tris)))
        for a, b, c in tris: f.write(struct.pack("<12fH", 0,0,0, *a, *b, *c, 0))

here = os.path.dirname(os.path.abspath(__file__))
for gap in (9.8, 10.0, 10.2):             # space between the legs; rim is about 10 mm wide, so 9.8 is a slight press
    mid = gap/2.0
    u0, u1 = mid - STRIP/2 - WALL, mid + STRIP/2 + WALL          # channel outer edges, strip centred on the rim
    shapes = [rect(u0, 0, u1, FLOOR),                              # floor
              rect(u0, FLOOR, u0+WALL, FLOOR+WALLH),               # strip wall, front
              rect(u1-WALL, FLOOR, u1, FLOOR+WALLH),               # strip wall, back
              rect(-LEG_T, -FRONT_LEG, 0, FLOOR),                  # short front leg: small locator on the screen-side face
              rect(gap, -FLAT, gap+LEG_T, FLOOR)]                  # back leg, flat part
    d = SLOPE*(LEG-FLAT)
    shapes.append([(gap,-FLAT),(gap+LEG_T,-FLAT),(gap+LEG_T+d,-LEG),(gap+d,-LEG)])   # back leg, on the slope
    tris = []
    for s in shapes: tris += prism(s, 0, LEN)
    write(os.path.join(here, f"test_channel_pressure_fit_shortfront_{gap:.2f}mm.stl"), tris)
print("ok")
