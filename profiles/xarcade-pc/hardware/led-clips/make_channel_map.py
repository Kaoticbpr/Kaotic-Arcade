"""Draws where the 150 mm channels go on the TV (back view, landscape) as a phone-friendly PNG."""
import os
from PIL import Image, ImageDraw, ImageFont
S = 2
W, H = 600*S, 560*S
im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
fnt = lambda n, b=False: ImageFont.truetype(r"C:\Windows\Fonts\%s.ttf" % ("arialbd" if b else "arial"), n*S)
reg, bold, big = fnt(13), fnt(14, True), fnt(17, True)
INK, MUTE, AMB = (40,40,40), (100,100,100), (239,159,39)
def T(x, y, t, f=reg, c=INK, a="la"): d.text((x*S, y*S), t, font=f, fill=c, anchor=a)
def R(x0, y0, x1, y1, fill=None, out=None, w=1): d.rectangle([x0*S, y0*S, x1*S, y1*S], fill=fill, outline=out, width=int(w*S))
def L(p, q, c=MUTE, w=1): d.line([p[0]*S, p[1]*S, q[0]*S, q[1]*S], fill=c, width=int(w*S))

SC = 460/963.0                      # px per mm
x0, y0 = 70, 85
x1, y1 = x0 + 963*SC, y0 + 559*SC
T(300, 18, "Where the 150 mm channels go", big, INK, "ma")
T(300, 36, "Back of the TV, landscape. 18 channels total", reg, MUTE, "ma")
R(x0, y0, x1, y1, (232,231,226), (95,94,90), 1.5)
R(x0+205*SC*0.9, y0+130*SC*0.9, x1-205*SC*0.9, y1-130*SC*0.9, (210,209,204), (150,149,144))
T((x0+x1)/2, (y0+y1)/2, "Ports and bracket", reg, MUTE, "ma")
T((x0+x1)/2, (y0+y1)/2+16, "(nothing goes here)", reg, MUTE, "ma")
# continuous strip around the edge, drawn under the channels
L((x0, y0), (x1, y0), AMB, 3); L((x1, y0), (x1, y1), AMB, 3); L((x1, y1), (x0, y1), AMB, 3); L((x0, y1), (x0, y0), AMB, 3)
CH = 150*SC
def run(a, b, n, horiz, fixed):
    """n channels of 150 mm spread evenly between a and b along one side."""
    gap = ((b - a) - n*CH) / (n - 1) if n > 1 else 0
    for i in range(n):
        s = a + i*(CH+gap)
        if horiz: R(s, fixed-4, s+CH, fixed+4, (45,45,45), (0,0,0))
        else:     R(fixed-4, s, fixed+4, s+CH, (45,45,45), (0,0,0))
m = 15*SC
run(x0+m, x1-m, 6, True, y0)                         # top
run(y0+m, y1-m, 3, False, x0); run(y0+m, y1-m, 3, False, x1)   # left, right
mid = (x0+x1)/2
run(x0+m, mid-m, 3, True, y1); run(mid+m, x1-m, 3, True, y1)   # bottom, two panels
L((mid, y1-12), (mid, y1+12), (90,90,90), 1.5); T(mid, y1+14, "seam", reg, MUTE, "ma")
T((x0+x1)/2, y0-28, "Top: 6 channels", bold, INK, "ma")
T(x0-10, (y0+y1)/2, "Left:", bold, INK, "ra"); T(x0-10, (y0+y1)/2+16, "3", bold, INK, "ra")
T(x1+10, (y0+y1)/2, "Right:", bold, INK); T(x1+10, (y0+y1)/2+16, "3", bold, INK)
T((x0+mid)/2, y1+32, "Bottom left: 3", bold, INK, "ma"); T((mid+x1)/2, y1+32, "Bottom right: 3", bold, INK, "ma")
R(34, y1-6, 62, y1+22, (60,110,190), (30,60,120)); T(48, y1+26, "Controller", reg, INK, "ma")
R(70, 490, 90, 500, (45,45,45), (0,0,0)); T(98, 487, "= one 150 mm channel", reg, INK)
L((300, 495), (330, 495), AMB, 3); T(338, 487, "= strip, runs all the way round", reg, INK)
T(70, 520, "Leave ~15 mm gaps at corners and at the seam: the strip bends or steps across there.", reg, INK)
T(70, 538, "Strip needs ~3 m of the 4 m. Cut the rest off at a cut point.", reg, INK)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "channel_map.png")
im.save(out); print(out)
