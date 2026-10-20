"""Draws the LED strip layout plan (back view + edge cross-section) as a phone-friendly PNG."""
import os
from PIL import Image, ImageDraw, ImageFont
S = 2
W, H = 600*S, 820*S
im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
fnt = lambda n, b=False: ImageFont.truetype(r"C:\Windows\Fonts\%s.ttf" % ("arialbd" if b else "arial"), n*S)
reg, bold, big = fnt(13), fnt(14, True), fnt(17, True)
INK, MUTE, AMB, AMBD, CLIP, CLIPD = (40,40,40), (100,100,100), (239,159,39), (133,79,11), (216,90,48), (153,60,29)
def T(x, y, t, f=reg, c=INK, a="la"): d.text((x*S, y*S), t, font=f, fill=c, anchor=a)
def L(p, q, c=MUTE, w=1): d.line([p[0]*S, p[1]*S, q[0]*S, q[1]*S], fill=c, width=int(w*S))
def R(x0, y0, x1, y1, fill=None, out=None, w=1): d.rectangle([x0*S, y0*S, x1*S, y1*S], fill=fill, outline=out, width=int(w*S))
def P(pts, fill, out, w=1): d.polygon([(x*S, y*S) for x, y in pts], fill=fill, outline=out, width=int(w*S))

T(300, 18, "Plan: LED strip on the TV edge", big, INK, "ma")
T(300, 40, "Back of the TV, landscape", reg, MUTE, "ma")
x0, y0, x1, y1 = 70, 90, 530, 354
R(x0, y0, x1, y1, (232, 231, 226), (95, 94, 90), 1.5)
R(205, 150, 395, 310, (200, 199, 194), (130, 129, 124))
T(300, 224, "Ports, power and", reg, MUTE, "ma"); T(300, 240, "bracket (not touched)", reg, MUTE, "ma")
sw = 7
def strip(p, q): L(p, q, AMB, sw)
strip((x0, y0), (x1, y0)); strip((x0, y0), (x0, y1)); strip((x1, y0), (x1, y1))
strip((x0, y1), (293, y1)); strip((307, y1), (x1, y1))
L((300, y1-10), (300, y1+10), (90, 90, 90), 1.5)
T(300, y1+14, "seam", reg, MUTE, "ma")
T(300, y0-32, "Top, left, right: skinny flat edge", bold, INK, "ma")
T(300, y0-16, "strip on the flat edge, back slopes away", reg, MUTE, "ma")
T(240, y1+34, "Bottom: first run", bold, INK, "ma"); T(240, y1+52, "smooth band, tape only", reg, MUTE, "ma")
T(430, y1+34, "Bottom: second run", bold, INK, "ma"); T(430, y1+52, "stops at the seam", reg, MUTE, "ma")
R(34, y1-6, 62, y1+22, (60, 110, 190), (30, 60, 120)); T(48, y1+26, "Controller", reg, INK, "ma")
T(48, y1+42, "(bottom-left)", reg, MUTE, "ma")

T(300, 478, "Edge cross-section (looking along the top edge)", bold, INK, "ma")
ox, oy = 90, 500
P([(ox, oy+40), (ox+40, oy+40), (ox+172, oy+210), (ox, oy+210)], (225,224,220), (95,94,90))
T(ox+8, oy+226, "front", reg, MUTE); T(ox+110, oy+226, "back", reg, MUTE)
R(ox-4, oy+24, ox+44, oy+38, AMB, AMBD)                       # strip, wider than the flat edge
P([(ox+30, oy+19), (ox+48, oy+19), (ox+50, oy+37), (ox+84, oy+88), (ox+74, oy+94), (ox+38, oy+43), (ox+30, oy+39)], CLIP, CLIPD)
L((ox+56, oy+84), (ox+90, oy+78), (60,110,190), 2)            # tape under the clip
L((ox+0, oy+40), (ox+40, oy+40), (15,110,86), 3)              # flat edge highlight
T(ox+210, oy+10, "LED strip, about 12 mm", bold); T(ox+210, oy+28, "overhangs the flat edge by ~1 mm", reg, MUTE)
L((ox+48, oy+30), (ox+206, oy+16))
T(ox+210, oy+62, "Wedge clip", bold); T(ox+210, oy+80, "tab pins the strip edge", reg, MUTE); T(ox+210, oy+96, "foot follows the slope, taped", reg, MUTE)
L((ox+60, oy+60), (ox+206, oy+70))
T(ox+210, oy+140, "Skinny flat edge, about 10 mm", bold); T(ox+210, oy+158, "gauge will give the exact width", reg, MUTE)
L((ox+22, oy+42), (ox+206, oy+146), (15,110,86))
T(ox+210, oy+186, "Back slopes out, up to ~43 mm", bold)
L((ox+120, oy+140), (ox+206, oy+190))
T(300, 780, "Strip is wider than the flat edge, so it overhangs a little.", reg, INK, "ma")
T(300, 800, "Tape holds it; wedge clips stop the edges peeling.", reg, INK, "ma")
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "strip_plan.png")
im.save(out); print(out)
