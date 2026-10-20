"""One plate of five short pressure-fit channels with different leg gaps (STL, mm), to find the rim width fast.
Order along x: 8.0, 8.4, 8.8, 9.2, 9.6 mm. A tall post marks the 8.0 mm end. Each piece is 15 mm long."""
import os, struct, math
LEN, STRIP, WALL, WALLH, FLOOR, LEG_T = 15.0, 10.0, 1.0, 3.0, 2.0, 1.5
FLAT, LEG, FRONT_LEG, SLOPE = 6.35, 12.0, 4.0, math.tan(math.radians(20))
GAPS, PITCH = (8.0, 8.4, 8.8, 9.2, 9.6), 24.0

def prism(pts, z0, z1, dx=0.0):
    pts = [(x+dx, y) for x, y in pts]; t, n = [], len(pts)
    for i in range(1, n-1):
        t.append(((*pts[0], z0), (*pts[i+1], z0), (*pts[i], z0)))
        t.append(((*pts[0], z1), (*pts[i], z1), (*pts[i+1], z1)))
    for i in range(n):
        a, b = pts[i], pts[(i+1) % n]
        t += [((*a, z0), (*b, z0), (*b, z1)), ((*a, z0), (*b, z1), (*a, z1))]
    return t
def rect(x0, y0, x1, y1): return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]

tris = []
for i, gap in enumerate(GAPS):
    mid = gap/2.0
    u0, u1 = mid - STRIP/2 - WALL, mid + STRIP/2 + WALL
    d = SLOPE*(LEG-FLAT)
    shapes = [rect(u0, 0, u1, FLOOR), rect(u0, FLOOR, u0+WALL, FLOOR+WALLH), rect(u1-WALL, FLOOR, u1, FLOOR+WALLH),
              rect(-LEG_T, -FRONT_LEG, 0, FLOOR), rect(gap, -FLAT, gap+LEG_T, FLOOR),
              [(gap,-FLAT),(gap+LEG_T,-FLAT),(gap+LEG_T+d,-LEG),(gap+d,-LEG)]]
    for s in shapes: tris += prism(s, 0, LEN, i*PITCH)
tris += prism(rect(-6, -12, -3, FLOOR+WALLH+6), 0, LEN)          # tall marker post at the 8.0 mm end
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rim_gap_plate_8.0-9.6.stl")
with open(path, "wb") as f:
    f.write(b"plate".ljust(80, b"\0")); f.write(struct.pack("<I", len(tris)))
    for a, b, c in tris: f.write(struct.pack("<12fH", 0,0,0, *a, *b, *c, 0))
print(path)
