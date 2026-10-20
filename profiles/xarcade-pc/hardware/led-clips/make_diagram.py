"""Draws the TV-edge cross-section diagram as a PNG (phone friendly)."""
import os
from PIL import Image, ImageDraw, ImageFont
S = 2
W, H = 680*S, 410*S
im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
f = lambda n, b=False: ImageFont.truetype(r"C:\Windows\Fonts\%s.ttf" % ("arialbd" if b else "arial"), n*S)
reg, bold = f(13), f(14, True)
INK, MUTE = (40, 40, 40), (95, 95, 95)

def rect(x, y, w, h, fill, line, dash=False):
    d.rectangle([x*S, y*S, (x+w)*S, (y+h)*S], fill=fill, outline=line, width=S)
def text(x, y, t, font=reg, fill=INK, anchor="la"):
    d.text((x*S, y*S), t, font=font, fill=fill, anchor=anchor)
def line(p, q, fill=MUTE, w=1):
    d.line([p[0]*S, p[1]*S, q[0]*S, q[1]*S], fill=fill, width=w*S)
def dim(x0, x1, y):
    line((x0, y), (x1, y), INK)
    for x in (x0, x1): line((x, y-5), (x, y+5), INK)

text(120, 22, "Looking down at the TV's top edge", reg, MUTE)
text(62, 208, "Screen", reg, MUTE, "ma"); text(62, 224, "(front)", reg, MUTE, "ma")
text(318, 208, "Back", reg, MUTE, "ma")
rect(120, 120, 40, 210, (225, 224, 220), (95, 94, 90))
rect(160, 152, 132, 178, (225, 224, 220), (95, 94, 90))
rect(120, 116, 40, 8, (159, 225, 203), (15, 110, 86))
rect(116, 100, 48, 14, (250, 199, 117), (133, 79, 11))
# dashed gauge tab
x0, y0, x1, y1 = 120, 74, 160, 84
rect(x0, y0, 40, 10, (238, 237, 254), (83, 74, 183))
dim(120, 160, 58); text(140, 40, "Flat band: ?", reg, INK, "ma")
dim(120, 292, 352); text(206, 366, "Overall thickness about 43 mm (already measured)", reg, INK, "ma")
for (a, b, t1, t2) in [((160, 79), (340, 79), "Gauge tab", "Lay each tab across the band"),
                       ((164, 107), (340, 124), "LED strip, about 12 mm wide", "Sticks on the flat band"),
                       ((160, 140), (340, 176), "Step where the back begins", "Where a clip can hook"),
                       ((292, 250), (340, 250), "Ribbed back shell", "Too uneven to stick to")]:
    line(a, b)
    text(348, b[1]-8, t1, bold); text(348, b[1]+10, t2, reg, MUTE)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tv_edge_cross_section.png")
im.save(out); print(out)
