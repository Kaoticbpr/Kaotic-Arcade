#!/usr/bin/env python3
"""Table view for the TV layout: the table keeps its author's tilt (inclination) and field of view, fills the screen from
top to bottom, and is slid to the right of the backglass/score boxes WITHOUT leaning.

Why camera mode: VPX's old 'legacy' view mode cannot shift the picture sideways except by moving the camera, which makes the
table lean. Camera mode has a lens shift (ViewDTHOfs/ViewDTVOfs = pure image translation, no perspective change). So every
table is expressed as a camera-mode view: same tilt + FOV as the author's, camera distance solved so the playfield spans the
screen height, HOfs solved so the table sits as far right as the screen allows.

The projection below is the VPX 10.8 camera-mode pipeline (src/renderer/ViewSetup.cpp ComputeMVP) written out for a table
seen from straight above its centre line (camera x = table centre, no viewport rotation):
  scaled = ((x-R/2)*sx + R/2, (y-B/2)*sy + B/2, z*sz)          scene scale about the playfield centre
  t      = scaled - eye,  eye = (R/2 + vx, B + vy, vz)
  y1 = ty*cos(i) - tz*sin(i);  z1 = ty*sin(i) + tz*cos(i);  depth = -z1;  up = -y1
  x_ndc = (tx/depth + 0.01*HOfs) / (aspect*tan(F/2));   y_ndc = (up/depth - 0.01*VOfs) / tan(F/2)
  inclination i = -pi + atan2(-vy - (L/100)*B, -vz)   (L = 'LookAt' percent)
"""
import math, os, struct, sys, json

ASPECT = 1920 / 1080
SCREEN_W, SCREEN_H = 1920, 1080
LEFT_PX, RIGHT_PX = 816, 1914        # table must stay inside this part of the screen (backglass/score boxes cover x < 800)
TOP_MARGIN, BOTTOM_MARGIN = 0.035, 0.0   # NDC margins: playfield top edge a bit below the screen top, bottom edge on it
WALL_MARGIN, WALL_Z = 12.0, 90.0     # side rails stick out of the playfield rectangle and are tall

def read_view(vpx):
    """Table size and the author's desktop view from the .vpx."""
    import olefile
    d = olefile.OleFileIO(vpx).openstream("GameStg/GameData").read()
    r, i = {}, 0
    while i + 8 <= len(d):
        n = struct.unpack("<i", d[i:i + 4])[0]; tag = d[i + 4:i + 8].decode("latin-1")
        r.setdefault(tag, d[i + 8:i + 4 + n]); i += 4 + n
        if tag == "ENDB": break
    f = lambda t, default=None: struct.unpack("<f", r[t][:4])[0] if t in r else default
    v = {"left": f("LEFT"), "top": f("TOPX"), "right": f("RGHT"), "bottom": f("BOTM"),
         "mode": struct.unpack("<i", r["VSM0"][:4])[0] if "VSM0" in r else 0,
         "lookat": f("INCL"), "fov": f("FOVX"), "vx": f("XLTX"), "vy": f("XLTY"), "vz": f("XLTZ"),
         "sx": f("SCLX", 1.0), "sy": f("SCLY", 1.0), "sz": f("SCLZ", 1.0)}
    if v["mode"] == 1:   # camera mode: inclination follows from the eye position and the look-at point
        v["inc"] = -math.pi + math.atan2(-v["vy"] - (v["lookat"] / 100.0) * v["bottom"], -v["vz"])
        v["inc"] %= 2 * math.pi
        if v["inc"] > math.pi: v["inc"] -= 2 * math.pi
    else:                # legacy: LookAt is the inclination in degrees
        v["inc"] = math.radians(v["lookat"])
    return v

def project(P, eye, inc, fov, hofs, vofs, R, B, sx, sy, sz):
    """Table point (x, y, z) -> (x_ndc, y_ndc), or None if behind the camera."""
    x = (P[0] - R / 2) * sx + R / 2; y = (P[1] - B / 2) * sy + B / 2; z = P[2] * sz
    tx, ty, tz = x - eye[0], y - eye[1], z - eye[2]
    y1 = ty * math.cos(inc) - tz * math.sin(inc); z1 = ty * math.sin(inc) + tz * math.cos(inc)
    depth, up = -z1, -y1
    if depth <= 1: return None
    T = math.tan(math.radians(fov) / 2)
    return ((tx / depth + 0.01 * hofs) / (ASPECT * T), (up / depth - 0.01 * vofs) / T)

def px(ndc): return ((ndc[0] + 1) / 2 * SCREEN_W, (1 - ndc[1]) / 2 * SCREEN_H)

def solve(v, top_margin=TOP_MARGIN, bottom_margin=BOTTOM_MARGIN, left_px=LEFT_PX, right_px=RIGHT_PX):
    """Camera-mode settings (dict of ViewDT* keys) for table view v."""
    R, B = v["right"], v["bottom"]; i, F = v["inc"], v["fov"]
    sx, sy, sz = v["sx"], v["sy"], v["sz"]; T = math.tan(math.radians(F) / 2)
    y_top = (v["top"] - B / 2) * sy + B / 2; y_bot = (B - B / 2) * sy + B / 2; H = y_bot - y_top
    shrunk = False
    for _ in range(40):
        a, b = 1 - top_margin, 1 - bottom_margin
        p = (math.cos(i) - a * T * math.sin(i)) / (a * T); q = (math.cos(i) + b * T * math.sin(i)) / (b * T)
        u = -H * q / (p + q); w = u + H
        yc = y_top - u; d = -u * p                                # camera looks at table y = yc from distance d
        eye = (R / 2, yc + d * math.sin(i), d * math.cos(i))      # eye in scaled space
        vx, vy, vz = eye[0] - R / 2, eye[1] - B, eye[2]
        L = 100.0 * (1 - yc / B)
        xs = []                                                   # horizontal extent with no lens shift
        for cx in (v["left"] - WALL_MARGIN, R + WALL_MARGIN):
            for cy in (v["top"], B):
                for cz in (0.0, WALL_Z):
                    n = project((cx, cy, cz), eye, i, F, 0, 0, R, B, sx, sy, sz)
                    if n: xs.append(n[0])
        lo, hi = min(xs), max(xs)
        width_px = (hi - lo) / 2 * SCREEN_W
        break                                                     # never zoom or move vertically: the caller shrinks the backglass boxes instead
    target_hi = (right_px / SCREEN_W) * 2 - 1
    shift = target_hi - hi                                        # NDC shift to the right
    hofs = shift * ASPECT * T / 0.01
    return {"ViewDTMode": 1, "ViewDTPlayerX": round(vx, 2), "ViewDTPlayerY": round(vy, 2), "ViewDTPlayerZ": round(vz, 2),
            "ViewDTLookAt": round(L, 3), "ViewDTFOV": round(F, 3), "ViewDTHOfs": round(hofs, 3), "ViewDTVOfs": 0,
            "ViewDTLayback": 0, "ViewDTRotation": 0,
            "ViewDTScaleX": round(sx, 4), "ViewDTScaleY": round(sy, 4), "ViewDTScaleZ": round(sz, 4),
            "_shrunk": shrunk, "_width_px": round(width_px)}      # (keys starting with _ are information, not settings)

def settings_to_eye(s, R, B):
    """Camera-mode ViewDT settings -> (eye in scaled space, inclination)."""
    eye = (R / 2 + s["ViewDTPlayerX"], B + s["ViewDTPlayerY"], s["ViewDTPlayerZ"])
    inc = -math.pi + math.atan2(-s["ViewDTPlayerY"] - (s["ViewDTLookAt"] / 100.0) * B, -s["ViewDTPlayerZ"])
    inc %= 2 * math.pi
    if inc > math.pi: inc -= 2 * math.pi
    return eye, inc

def corners_px(s, v):
    """Where the playfield corners (and the wall tops) land on screen for settings s."""
    eye, inc = settings_to_eye(s, v["right"], v["bottom"]); R, B = v["right"], v["bottom"]
    out = {}
    for name, (cx, cy) in {"TL": (v["left"], v["top"]), "TR": (R, v["top"]), "BL": (v["left"], B), "BR": (R, B)}.items():
        n = project((cx, cy, 0), eye, inc, s["ViewDTFOV"], s["ViewDTHOfs"], s["ViewDTVOfs"], R, B, v["sx"], v["sy"], v["sz"])
        out[name] = tuple(round(c) for c in px(n)) if n else None
    return out

if __name__ == "__main__":
    for vpx in sys.argv[1:]:
        v = read_view(vpx); s = solve(v)
        print(os.path.basename(vpx)[:-4], "| author:", "camera" if v["mode"] == 1 else "legacy", "inc=%.1f" % math.degrees(v["inc"]),
              "fov=%.1f" % v["fov"], "scale=%g,%g,%g" % (v["sx"], v["sy"], v["sz"]))
        print("   ", {k: s[k] for k in ("ViewDTPlayerY", "ViewDTPlayerZ", "ViewDTLookAt", "ViewDTHOfs")}, corners_px(s, v))
