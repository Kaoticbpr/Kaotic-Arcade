"""Fit gauges for the Dig2Go strip on the Hisense 43E6QF edge. Writes two binary STLs (mm)."""
import struct, os

def box(x0, y0, z0, x1, y1, z1):
    v = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    q = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    t = []
    for a,b,c,d in q:
        t += [(v[a],v[b],v[c]),(v[a],v[c],v[d])]
    return t

def write(path, tris):
    with open(path, "wb") as f:
        f.write(b"gauge".ljust(80, b"\0")); f.write(struct.pack("<I", len(tris)))
        for a,b,c in tris:
            f.write(struct.pack("<12fH", 0,0,0, *a, *b, *c, 0))

here = os.path.dirname(os.path.abspath(__file__))

# 1) strip-width slot gauge: slots 10..14 mm, run open-ended along Y, 8 mm walls
slots = [10, 11, 12, 13, 14]
wall, base, length, height = 3.0, 2.0, 25.0, 8.0
x = 0.0
tris = []
tris += box(0, 0, 0, wall + sum(slots) + wall*len(slots), length, base)
tris += box(x, 0, base, x + wall, length, height); x += wall
for s in slots:
    x += s
    tris += box(x, 0, base, x + wall, length, height); x += wall
tris += box(x - wall, 0, base, x, length, height + 6)   # tall end wall marks the 14 mm side
write(os.path.join(here, "gauge_strip_width_slots_10-14.stl"), tris)

# 2) edge-face width step gauge: tabs 8..14 mm wide, 2 mm thick, joined by a spine
widths = [8, 9, 10, 11, 12, 13, 14]
tabl, gap, th = 20.0, 3.0, 2.0
tris = []; y = 0.0
for w in widths:
    tris += box(0, y, 0, w, y + tabl, th); y += tabl + gap
tris += box(-4, 0, 0, 0, y - gap, th)                    # spine on the narrow side
tris += box(-4, y - gap, 0, 14, y - gap + 3, th + 2)       # end bar marks the 14 mm tab
write(os.path.join(here, "gauge_edge_face_width_steps_8-14.stl"), tris)
print("ok")
