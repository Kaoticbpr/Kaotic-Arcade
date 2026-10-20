#!/usr/bin/env python3
"""Exact camera for a table's own default ('legacy') desktop view, written the way VPX 10.8.1 computes it
(ViewSetup::ComputeMVP + FitCameraToVertices), then rebuilt as the identical camera-mode view with a lens shift:
same zoom, same tilt, same vertical position - only the horizontal position changes (pure image translation, no lean).
usage: vpx-legacy.py TABLE.vpx [...]"""
import math, struct, sys, os
PHYS_SKIN = 25.0
ASPECT, SW, SH = 1920 / 1080, 1920, 1080

def _recs(d):
    i, out = 4, []
    while i + 8 <= len(d):
        n = struct.unpack("<i", d[i:i + 4])[0]
        if n < 4 or i + 4 + n > len(d): break
        out.append((d[i + 4:i + 8].decode("latin-1"), d[i + 8:i + 4 + n])); i += 4 + n
        if out[-1][0] == "ENDB": break
    return out

def read(vpx):
    import olefile
    o = olefile.OleFileIO(vpx)
    d = o.openstream("GameStg/GameData").read(); r, i = {}, 0
    while i + 8 <= len(d):
        n = struct.unpack("<i", d[i:i + 4])[0]; tag = d[i + 4:i + 8].decode("latin-1")
        r.setdefault(tag, d[i + 8:i + 4 + n]); i += 4 + n
        if tag == "ENDB": break
    f = lambda t, dflt=0.0: struct.unpack("<f", r[t][:4])[0] if t in r else dflt
    v = dict(left=f("LEFT"), top=f("TOPX"), right=f("RGHT"), bottom=f("BOTM"),
             mode=struct.unpack("<i", r["VSM0"][:4])[0] if "VSM0" in r else 0,
             inc=f("INCL"), fov=f("FOVX"), vx=f("XLTX"), vy=f("XLTY"), vz=f("XLTZ"),
             sx=f("SCLX", 1.0), sy=f("SCLY", 1.0), sz=f("SCLZ", 1.0), layback=f("LAYB"), rot=f("ROTA"), hof=f("HOF0"), vof=f("VOF0"))
    n = 0
    while True:
        try: it = o.openstream(f"GameStg/GameItem{n}").read()
        except Exception: break
        n += 1; t = struct.unpack("<i", it[:4])[0]
        if t not in (0, 12, 21): continue
        rc = _recs(it); g = lambda tag, dflt=0.0: next((struct.unpack("<f", b[:4])[0] for k, b in rc if k == tag and len(b) >= 4), dflt)
        if t == 0: v.setdefault("surf", []).append((g("HTBT"), g("HTTP")))
        else:
            pts, cur = [], None
            for k, b in rc:
                if k == "DPNT": cur = [0, 0, 0]; pts.append(cur)
                elif k == "VCEN" and cur is not None: cur[0], cur[1] = struct.unpack("<ff", b[:8])
                elif k == "POSZ" and cur is not None: cur[2] = struct.unpack("<f", b[:4])[0]
            if not pts: continue
            if t == 12:                                              # ramp outline: the path widened sideways by half the (bottom -> top) width
                wb, wt = g("WDBT"), g("WDTP"); n_ = len(pts); out = []
                for k_, p in enumerate(pts):
                    a_, b_ = pts[max(k_ - 1, 0)], pts[min(k_ + 1, n_ - 1)]
                    dx_, dy_ = b_[0] - a_[0], b_[1] - a_[1]; ln_ = math.hypot(dx_, dy_) or 1.0
                    hw = (wb + (wt - wb) * (k_ / (n_ - 1 or 1))) / 2
                    out += [(p[0] - dy_ / ln_ * hw, p[1] + dx_ / ln_ * hw), (p[0] + dy_ / ln_ * hw, p[1] - dx_ / ln_ * hw)]
                xs = [q[0] for q in out]; ys = [q[1] for q in out]; w = 0
                z0 = min(g("HTBT"), g("HTTP")) + min(p[2] for p in pts); z1 = max(g("HTBT"), g("HTTP")) + max(p[2] for p in pts)
            else:
                xs = [p[0] for p in pts]; ys = [p[1] for p in pts]; w = g("WDTP") / 2 + 2; z0 = z1 = g("HTHI")
            v.setdefault("box", []).append((min(xs) - w, min(ys) - w, max(xs) + w, max(ys) + w, z0 + 2 * PHYS_SKIN, z1 + 2 * PHYS_SKIN))
    return v

def bounds(v):
    pts = []
    for z0, z1 in v.get("surf", []):
        for x in (v["left"], v["right"]):
            for y in (v["top"], v["bottom"]):
                pts += [(x, y, z0), (x, y, z1)]
    for x0, y0, x1, y1, z0, z1 in v.get("box", []):
        for x in (x0, x1):
            for y in (y0, y1):
                pts += [(x, y, z0), (x, y, z1)]
    return pts

def legacy(v):
    """The author's default view -> camera-mode settings with the SAME picture (HOfs 0), plus helpers."""
    F = max(v["fov"], 1.0); T = math.tan(math.radians(F) / 2); inc = math.radians(v["inc"]); s, c = math.sin(inc), math.cos(inc)
    k = math.tan(math.radians(v["layback"]) / 2)
    P = [(x, y - k * z, z) for x, y, z in bounds(v)]
    sy_, sx_ = T, T * ASPECT
    ymax = ymin = xmax = xmin = None
    ys = [(c * y - s * z, s * y + c * z, x) for x, y, z in P]
    maxy = max(Y + sy_ * Z for Y, Z, x in ys); miny = min(Y - sy_ * Z for Y, Z, x in ys)
    maxx = max(x + sx_ * Z for Y, Z, x in ys); minx = min(x - sx_ * Z for Y, Z, x in ys)
    ydist = (maxy - miny) / (2 * sy_); xdist = (maxx - minx) / (2 * sx_)
    fit = ((maxx + minx) / 2, (maxy + minx * 0 + miny) / 2, max(ydist, xdist) + v["vz"])
    pos = (v["vx"] - fit[0], v["vy"] - fit[1], -fit[2])
    return dict(F=F, T=T, inc=inc, pos=pos, fit=fit)

def project_legacy(v, L, p):
    x, y, z = p; s, c = math.sin(L["inc"]), math.cos(L["inc"]); k = math.tan(math.radians(v["layback"]) / 2); y = y - k * z
    X = x + L["pos"][0]; Y = c * y - s * z + L["pos"][1]; Zc = s * y + c * z + L["pos"][2]
    D = -v["sz"] * Zc
    if D <= 1: return None
    xn = v["sx"] * X / D / (ASPECT * L["T"]); yn = -v["sy"] * Y / D / L["T"]
    return ((xn + 1) / 2 * SW, (1 - yn) / 2 * SH)

def camera(v, L, right_px=1914, margin=4.0):
    """Camera-mode settings reproducing the default picture, then slid right until the table's right edge reaches right_px."""
    sx, sy, sz = v["sx"], v["sy"], v["sz"]; ey = sy / sz; ex_over_ey = sx / sy
    Fp = 2 * math.degrees(math.atan(L["T"] / ey)); Tp = math.tan(math.radians(Fp) / 2)
    i = L["inc"]; s, c = math.sin(i), math.cos(i); d = -L["pos"][2]; py = L["pos"][1]
    eye_y = -py * c + d * s; eye_z = py * s + d * c
    R, B = v["right"], v["bottom"]; vx = -ex_over_ey * (R / 2 + L["pos"][0]) ; vy = eye_y - B; vz = eye_z
    Lk = 100.0 * (-vy + vz * math.tan(i)) / B
    st = dict(ViewDTMode=1, ViewDTPlayerX=round(vx, 3), ViewDTPlayerY=round(vy, 3), ViewDTPlayerZ=round(vz, 3), ViewDTLookAt=round(Lk, 4),
              ViewDTFOV=round(Fp, 4), ViewDTHOfs=0.0, ViewDTVOfs=0.0, ViewDTLayback=0, ViewDTRotation=0,
              ViewDTScaleX=round(ex_over_ey, 5), ViewDTScaleY=1.0, ViewDTScaleZ=1.0)
    return st, Tp

def cam_project(st, v, p, Tp):
    R, B = v["right"], v["bottom"]
    x = (p[0] - R / 2) * st["ViewDTScaleX"] + R / 2; y = (p[1] - B / 2) * st["ViewDTScaleY"] + B / 2; z = p[2] * st["ViewDTScaleZ"]
    eye = (R / 2 + st["ViewDTPlayerX"], B + st["ViewDTPlayerY"], st["ViewDTPlayerZ"])
    i = -math.pi + math.atan2(-st["ViewDTPlayerY"] - st["ViewDTLookAt"] / 100.0 * B, -st["ViewDTPlayerZ"]); i %= 2 * math.pi
    if i > math.pi: i -= 2 * math.pi
    tx, ty, tz = x - eye[0], y - eye[1], z - eye[2]
    y1 = ty * math.cos(i) - tz * math.sin(i); z1 = ty * math.sin(i) + tz * math.cos(i); D = -z1
    if D <= 1: return None
    xn = (tx / D + 0.01 * st["ViewDTHOfs"]) / (ASPECT * Tp); yn = (-y1 / D - 0.01 * st["ViewDTVOfs"]) / Tp
    return ((xn + 1) / 2 * SW, (1 - yn) / 2 * SH)

RIGHT_MARGIN, LEFT_MARGIN = 170.0, 190.0     # cabinet rails / side geometry stick out of the playfield rectangle (measured on Black Rose)

def default_view(v):
    """The author's own desktop view as camera-mode settings (HOfs 0 for a legacy view), and tan(FOV/2)."""
    if v["mode"] == 1:
        F = max(v["fov"], 1.0)
        return dict(ViewDTMode=1, ViewDTPlayerX=v["vx"], ViewDTPlayerY=v["vy"], ViewDTPlayerZ=v["vz"], ViewDTLookAt=v["inc"], ViewDTFOV=F,
                    ViewDTHOfs=v["hof"], ViewDTVOfs=v["vof"], ViewDTLayback=0, ViewDTRotation=0,
                    ViewDTScaleX=v["sx"], ViewDTScaleY=v["sy"], ViewDTScaleZ=v["sz"]), math.tan(math.radians(F) / 2)
    if v["mode"] == 0 and abs(v["rot"]) < 0.01:
        return camera(v, legacy(v))
    raise ValueError("unsupported view mode %s / rotation %s" % (v["mode"], v["rot"]))

def _edge(st, v, Tp, x, rows=(-30, 1110), zs=(0.0, 60.0)):
    out = []
    for y in [v["top"] + (v["bottom"] - v["top"]) * k / 80.0 for k in range(81)]:
        for z in zs:
            p = cam_project(st, v, (x, y, z), Tp)
            if p and rows[0] <= p[1] <= rows[1]: out.append(p)
    return out

def slide(v, right_px=1914):
    """Default view slid right (lens shift only) until the table's right edge touches right_px. Returns (settings, tan(FOV/2))."""
    st, Tp = default_view(v)
    edge = _edge(st, v, Tp, v["right"] + RIGHT_MARGIN)
    dx = right_px - max(p[0] for p in edge)
    st = dict(st); st["ViewDTHOfs"] = round(st["ViewDTHOfs"] + (2 * dx / SW) * ASPECT * Tp / 0.01, 3)
    return st, Tp

def left_px(st, v, Tp, last_row):
    """Left-most screen x the table reaches in the rows 0..last_row (where the backglass/score boxes sit)."""
    e = _edge(st, v, Tp, v["left"] - LEFT_MARGIN, rows=(-30, last_row))
    return min(p[0] for p in e) if e else float(SW)

if __name__ == "__main__":
    for f in sys.argv[1:]:
        v = read(f); L = legacy(v); st, Tp = camera(v, L)
        print(os.path.basename(f)[:40], "mode", v["mode"], "inc", v["inc"], "fov", v["fov"], "lb", v["layback"], "rot", v["rot"], "scale", v["sx"], v["sy"], v["sz"], "surf", len(v.get("surf", [])), "box", len(v.get("box", [])))
        zs = v.get("surf", []); print("   z surf", (min(a for a, b in zs), max(b for a, b in zs)) if zs else None)
        err = 0; res = []
        for p in [(0, 0, 0), (v["right"], 0, 0), (0, v["bottom"], 0), (v["right"], v["bottom"], 0), (v["right"], v["bottom"], 50), (v["right"], 0, 50), (v["right"] / 2, v["bottom"] / 2, 0)]:
            a = project_legacy(v, L, p); b = cam_project(st, v, p, Tp); res.append((tuple(round(q) for q in a), tuple(round(q) for q in b)))
        print("   legacy vs camera:", res[:4])
        print("   extremes (rows):", min(project_legacy(v, L, p)[1] for p in bounds(v)), max(project_legacy(v, L, p)[1] for p in bounds(v)))
