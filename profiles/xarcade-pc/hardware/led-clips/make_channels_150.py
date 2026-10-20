"""U-channels for the Dig2Go strip (STL, mm). Floor takes double-sided tape, walls keep the strip straight.
Length along x, width along y, height along z. Prints flat, no supports."""
import os, struct
LEN, FLOOR, WALL, WALLH = 150.0, 1.6, 1.0, 3.0

def box(x0, y0, z0, x1, y1, z1):
    v = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    q = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    t = []
    for a, b, c, d in q: t += [(v[a], v[b], v[c]), (v[a], v[c], v[d])]
    return t
def write(path, tris):
    with open(path, "wb") as f:
        f.write(b"channel".ljust(80, b"\0")); f.write(struct.pack("<I", len(tris)))
        for a, b, c in tris: f.write(struct.pack("<12fH", 0,0,0, *a, *b, *c, 0))

here = os.path.dirname(os.path.abspath(__file__))
for inner in (10.0, 10.2, 10.4):
    w = inner + 2*WALL
    tris = box(0, 0, 0, LEN, w, FLOOR) + box(0, 0, 0, LEN, WALL, FLOOR+WALLH) + box(0, w-WALL, 0, LEN, w, FLOOR+WALLH)
    write(os.path.join(here, f"channel_150mm_for_strip_{inner:.1f}mm.stl"), tris)
print("ok")
