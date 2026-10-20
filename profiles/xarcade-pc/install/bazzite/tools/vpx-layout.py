#!/usr/bin/env python3
"""Screen layout for Visual Pinball on the 1080p widescreen TV (desktop-cabinet style, like the popular VPForums setups).

Left side:  the backglass, 780 px wide, its height following each table's backglass art (the .directb2s image minus
            the grill strip, hidden via Plugin.B2SLegacy B2SHideGrill = 1) so it is never stretched, and right under it
            the DMD / score display box (VPX ScoreView, 4:1) for tables that have one.
Right side: the table, seen from the same angled camera on every table (VPX "Camera" view mode, shifted right), filling
            the full height with the cabinet's backbox kept off-screen. Tables keep their own desktop background art.
Everything is written into each table's own "<table>.ini" (the .vpx is never touched).
VPX 10.8.1 quirk: with supersampling (Player AAFactor > 1) embedded windows misplace, keep 1.0.
Run after adding tables (vpx-add.py does) - only while VPX is closed.
"""
import base64, glob, json, os, re, struct

H = os.path.expanduser("~")
INI = f"{H}/.local/share/VPinballX/10.8/VPinballX.ini"
TABLES = f"{H}/Emulation/roms/vpinball"
SCREEN_H = 1080
X, Y, W = 0, 0, 800                     # backglass box flush in the top-left corner of the 1920x1080 screen
DEFAULT_H, GAP = 450, 0                 # score display sits right under the backglass, like a real backbox
SCORE_H = round(W / 4)                  # DMD box keeps the 4:1 shape of a DMD
# Each table keeps its author's tilt and field of view; vpx-view.py rebuilds it as a camera-mode view that fills the screen
# top to bottom and sits on the right of the backglass/score boxes with a pure lens shift (no leaning).
# Per-table tweaks in vpx-table-fixes.json: "view": {"top_margin": 0.05, "right_px": 1900, ...} (see vpx-view.solve) or
# "camera": {"ViewDTHOfs": 20, ...} to override single keys.
CAMERA = {}
VIEW_KEYS = ("ViewDTMode", "ViewDTLookAt", "ViewDTFOV", "ViewDTLayback", "ViewDTRotation", "ViewDTPlayerX",
             "ViewDTPlayerY", "ViewDTPlayerZ", "ViewDTHOfs", "ViewDTVOfs", "ViewDTScaleX", "ViewDTScaleY",
             "ViewDTScaleZ", "ViewDTWindowTop", "ViewDTWindowBot")

def legacy_mod():
    import importlib.util
    spec = importlib.util.spec_from_file_location("vpx_legacy", os.path.join(os.path.dirname(os.path.abspath(__file__)), "vpx-legacy.py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m

def solved_view(vpx, opts):
    import importlib.util
    spec = importlib.util.spec_from_file_location("vpx_view", os.path.join(os.path.dirname(os.path.abspath(__file__)), "vpx-view.py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m.solve(m.read_view(vpx), **opts)

NL = chr(10)
# Only these keep the camera-mode slide to the right (checked by the user on screen); all others stay on their stored default view
SLIDE_TABLES = {"Black Rose (Bally 1992)", "Creature from the Black Lagoon (Bally 1992)"}

def remove_keys(path, section, keys):
    if not os.path.exists(path): return
    lines = open(path, encoding="utf-8").read().split(NL); out = []; cur = None
    for l in lines:
        if l.startswith("["): cur = l.strip()[1:-1]
        if cur == section and any(re.match(rf"^{re.escape(k)}\s*=", l) for k in keys): continue
        out.append(l)
    open(path, "w", encoding="utf-8").write(NL.join(out).rstrip(NL) + NL)

# Per-table camera corrections (and hidden objects) live in vpx-table-fixes.json, see vpx-tablefix.py
FIXES = f"{H}/Emulation/tools/vpx-table-fixes.json"

def table_fixes(name):
    return (json.load(open(FIXES)) if os.path.exists(FIXES) else {}).get(name, {})

def set_keys(path, section, values):
    lines = open(path, encoding="utf-8").read().split("\n") if os.path.exists(path) else []
    start = next((i for i, l in enumerate(lines) if l.strip() == f"[{section}]"), None)
    if start is None:
        if lines and lines[-1].strip(): lines.append("")
        lines.append(f"[{section}]"); start = len(lines) - 1
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("[")), len(lines))
    while end > start + 1 and not lines[end - 1].strip(): end -= 1     # new keys go before the blank line
    for key, val in values.items():
        for i in range(start + 1, end):
            if re.match(rf"^{re.escape(key)}\s*=", lines[i]):
                lines[i] = f"{key} = {val}"; break
        else:
            lines.insert(end, f"{key} = {val}"); end += 1
    open(path, "w", encoding="utf-8").write("\n".join(lines).rstrip("\n") + "\n")

def grill_height(b2s):
    g = re.search(rb'<GrillHeight Value="(\d+)"', open(b2s, "rb").read())
    return int(g.group(1)) if g else 0

def art_height(b2s, keep_grill=False, W=W, max_h=SCREEN_H - Y):
    """Height of the backglass box for this table's art (grill removed unless the DMD is shown in it)."""
    try:
        x = open(b2s, "rb").read()
        img = base64.b64decode(re.search(rb'<BackglassImage[^>]*Value="([^"]+)"', x).group(1)[:200])
        if img[:4] != b"\x89PNG": return DEFAULT_H
        w, h = struct.unpack(">II", img[16:24])
        if not keep_grill: h -= grill_height(b2s)
        return max(120, min(max_h, round(W * h / w)))
    except Exception:
        return DEFAULT_H

BG_WIDTHS = (800, 760, 720, 680, 640, 600, 560, 520, 480, 440, 400)      # backglass/score width tried from large to small until the table fits beside it

def layout_table(vpx):
    base = vpx[:-4]; ini = base + ".ini"; b2s = base + ".directb2s"; name = os.path.basename(base)
    fx = table_fixes(name)
    text = open(ini, encoding="utf-8").read() if os.path.exists(ini) else ""
    score = "ScoreViewOutput = 2" in text
    # DMD shown in the backglass's own display window (like a real cabinet): keep the grill, VPX finds the window
    dmd_in_bg = re.search(r"^BackglassDMDOverlay\s*=\s*1", text, re.M)
    ratio = fx.get("score_h", W / 4) / W                      # score box height / width (4:1 DMD, or e.g. 16:9 PuP video)
    cam, bgw = None, W
    try:                                                         # the author's own view, only slid right (vpx-legacy.py); no zoom, no vertical change
        lg = legacy_mod()
        v = lg.read(vpx); st, Tp = lg.slide(v, **fx.get("view", {}))
        cam = dict(st)
        for bgw in range(W, 290, -10):                           # the backglass/score boxes give way, never the table
            h_try = art_height(b2s, keep_grill=bool(dmd_in_bg), W=bgw, max_h=SCREEN_H - Y - ((GAP + round(bgw * ratio)) if score else 0)) if os.path.exists(b2s) else DEFAULT_H
            rows = h_try + ((GAP + round(bgw * ratio)) if score else 0)
            if lg.left_px(st, v, Tp, rows) - 8 >= bgw: break
    except Exception as e: print("view not solved for", name, e)
    fitf = f"{H}/Emulation/tools/vpx-fit.json"                  # measured on screen by vpx-fit.py: wins over the model
    fit = (json.load(open(fitf)) if os.path.exists(fitf) else {}).get(name)
    if fit:
        try:
            v0 = legacy_mod().read(vpx); st0, _ = legacy_mod().default_view(v0)
            cam = dict(st0); cam["ViewDTHOfs"] = fit["hofs"]; bgw = fit["bgw"]
        except Exception as e: print("fit not applied for", name, e)
    if name not in SLIDE_TABLES:                                 # everything else: the author's stored default view, untouched (no camera overrides)
        cam = {}
        try:
            lg = legacy_mod(); v = lg.read(vpx); st, Tp = lg.default_view(v); lg.LEFT_MARGIN = 50.0
            for bgw in range(W, 290, -10):
                h_try = art_height(b2s, keep_grill=bool(dmd_in_bg), W=bgw, max_h=SCREEN_H - Y - ((GAP + round(bgw * ratio)) if score else 0)) if os.path.exists(b2s) else DEFAULT_H
                rows = h_try + ((GAP + round(bgw * ratio)) if score else 0)
                if lg.left_px(st, v, Tp, rows) - 8 >= bgw: break
        except Exception as e: print("backglass width not computed for", name, e)
    cam = {**(cam or {}), **fx.get("camera", {})} if name in SLIDE_TABLES else {}
    remove_keys(ini, "TableOverride", [k for k in VIEW_KEYS if k not in cam])
    if cam: set_keys(ini, "TableOverride", cam)
    for section, vals in fx.get("ini", {}).items():          # other per-table settings, e.g. brightness
        set_keys(ini, section, vals)
    if not os.path.exists(b2s): return None
    score_h = round(bgw * ratio)
    h = art_height(b2s, keep_grill=bool(dmd_in_bg), W=bgw, max_h=SCREEN_H - Y - ((GAP + score_h) if score else 0))
    set_keys(ini, "Backglass", {"BackglassWndX": X, "BackglassWndY": Y, "BackglassWidth": bgw, "BackglassHeight": h})
    if score:
        set_keys(ini, "ScoreView", {"ScoreViewWndX": X, "ScoreViewWndY": Y + h + GAP, "ScoreViewWidth": bgw, "ScoreViewHeight": score_h})
    return h

if __name__ == "__main__":
    set_keys(INI, "Plugin.B2SLegacy", {"B2SHideGrill": 1})
    set_keys(INI, "Backglass", {"BackglassWndX": X, "BackglassWndY": Y, "BackglassWidth": W, "BackglassHeight": DEFAULT_H})
    for vpx in sorted(glob.glob(f"{TABLES}/*.vpx")):
        h = layout_table(vpx)
        print(f"{os.path.basename(vpx)[:-4]:52} backglass 800x{h}")
