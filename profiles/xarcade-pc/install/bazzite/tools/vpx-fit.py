#!/usr/bin/env python3
"""Measure each table on screen and slide it right. For every table: render its default view (camera-mode copy of it) twice, the 2nd shifted
by a known lens shift; picture content that moved with the shift IS the table, so its real left/right edges show up (backdrops, backglass
and DMD stay put). Then HOfs is set so the table's right edge sits at the screen edge and the backglass/DMD width is chosen so it never
overlaps the table. Results: ~/Emulation/tools/vpx-fit.json (read by vpx-layout.py).
usage: vpx-fit.py INDEX... (1-based position in the ES-DE pinball list; ES-DE must be showing the FIRST of them when started, the rest
are reached with DOWN; use --from N to say which index ES-DE is currently on)"""
import sys, os, json, time, subprocess, importlib.util, math, re
from PIL import Image, ImageChops
H = os.path.expanduser("~"); T = H + "/Emulation/tools/scripts"; V = H + "/Emulation/roms/vpinball"
LOG = H + "/.local/share/VPinballX/10.8/vpinball.log"; FIT = H + "/Emulation/tools/vpx-fit.json"
ORDER = [l.split("\t")[0] for l in open(H + "/.cache/vpx-loudness/results.tsv").read().splitlines() if l and not l.startswith("done")]
def load(n, f):
    s = importlib.util.spec_from_file_location(n, T + "/" + f); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
LG = load("lg", "vpx-legacy.py"); LY = load("ly", "vpx-layout.py")
def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)
def sh(c): return subprocess.run(c, shell=True, capture_output=True, text=True).stdout
def pad(*a): subprocess.run(["python3", T + "/esde-pad.py", *a])
def running(): return sh("pgrep -x VPinballX_BGFX").split()
def kill():
    sh("pkill -x VPinballX_BGFX")
    for _ in range(30):
        if not running(): break
        time.sleep(1)
    time.sleep(4)
def on_list():
    sh("gamescopectl screenshot /tmp/fitl.png"); time.sleep(1.5)
    a = Image.open("/tmp/fitl.png").convert("L").resize((1920, 1080)).crop((350, 0, 1400, 45)); b = Image.open("/tmp/topbar_ref.png").convert("L").crop((350, 0, 1400, 45))
    d = ImageChops.difference(a, b).resize((1, 1), Image.BOX).getpixel((0, 0)); return d < 14
def ensure_list():
    for _ in range(4):
        if on_list(): return
        log("not on the ES-DE list (screensaver?) - waking it"); pad("DOWN", "wait:1.5")
    raise RuntimeError("ES-DE list not showing")
def launch(expect):
    ensure_list(); pad("A")
    for _ in range(45):
        if running(): break
        time.sleep(1)
    else: raise RuntimeError("nothing launched")
    pid = running()[0]
    cmd = next((a for a in open("/proc/%s/cmdline" % pid, "rb").read().decode("utf-8", "ignore").split(chr(0)) if a.endswith(".vpx")), "")
    got = os.path.basename(cmd)[:-4]
    if got != expect:
        kill(); raise RuntimeError(f"expected {expect!r} but ES-DE launched {got!r}")
    for _ in range(80):
        if f"[{pid}]" in sh(f"grep 'Startup done' {LOG} | tail -3") and f"[Player::Player" in sh(f"grep 'Startup done' {LOG} | tail -1"): break
        time.sleep(1)
    time.sleep(14)
def shot(path):
    sh("gamescopectl screenshot /tmp/fit.png"); time.sleep(2)
    Image.open("/tmp/fit.png").convert("L").resize((1920, 1080)).save(path); return Image.open(path)
def write_view(name, st, tiny):
    ini = f"{V}/{name}.ini"
    LY.remove_keys(ini, "TableOverride", [k for k in LY.VIEW_KEYS if k not in st])
    LY.set_keys(ini, "TableOverride", st)
    if tiny and os.path.exists(f"{V}/{name}.directb2s"):
        LY.set_keys(ini, "Backglass", {"BackglassWidth": 120, "BackglassHeight": 80})
        if "ScoreViewOutput = 2" in open(ini).read(): LY.set_keys(ini, "ScoreView", {"ScoreViewWidth": 120, "ScoreViewHeight": 30, "ScoreViewWndY": 80})
def analyse(A, B, dpx):
    W, Hh = 960, 540
    a = A.resize((W, Hh)); b = B.resize((W, Hh)); d = int(round(dpx / 2))
    static = ImageChops.difference(a, b)
    moved = Image.new("L", (W, Hh), 255); moved.paste(ImageChops.difference(a.crop((0, 0, W - d, Hh)), b.crop((d, 0, W, Hh))), (0, 0))
    bs = static.resize((W // 8, Hh // 8), Image.BOX); bm = moved.resize((W // 8, Hh // 8), Image.BOX)
    ps, pm = bs.load(), bm.load(); cols = W // 8; rows = Hh // 8
    mask = [[(ps[i, j] > 9 and pm[i, j] < 0.55 * ps[i, j]) for i in range(cols)] for j in range(rows)]
    colcount = [sum(mask[j][i] for j in range(rows)) for i in range(cols)]
    right = max((i for i in range(cols) if colcount[i] >= 3), default=None)
    left_row = [min((i for i in range(cols) if mask[j][i]), default=None) for j in range(rows)]
    return (right + 1) * 16 if right is not None else None, [None if x is None else x * 16 for x in left_row], mask
def process(name, idx):
    ini = f"{V}/{name}.ini"; vpx = f"{V}/{name}.vpx"; bk = f"/tmp/fit_{idx}.ini"
    open(bk, "w").write(open(ini).read())
    v = LG.read(vpx); st0, Tp = LG.default_view(v); h0 = st0["ViewDTHOfs"]; dh = 6.0
    pxh = 0.01 / (LG.ASPECT * Tp) * 960; log(name, "default h0", h0, "px/unit", round(pxh, 2))
    try:
        write_view(name, dict(st0), True); launch(name); A = shot(f"/tmp/fit/{idx:02d}_A.png"); kill()
        stB = dict(st0); stB["ViewDTHOfs"] = round(h0 + dh, 3)
        write_view(name, stB, True); launch(name); B = shot(f"/tmp/fit/{idx:02d}_B.png"); kill()
    finally:
        open(ini, "w").write(open(bk).read())
    right, left_row, mask = analyse(A, B, dh * pxh)
    if right is None: log("  NO table edge found"); return None
    shift = 1914 - 8 - right; hofs = round(h0 + shift / pxh, 3)
    # backglass / DMD width: largest that stays left of the (shifted) table
    fx = LY.table_fixes(name); score = "ScoreViewOutput = 2" in open(ini).read(); ratio = fx.get("score_h", 800 / 4) / 800
    b2s = f"{V}/{name}.directb2s"; dmd_in_bg = re.search(r"^BackglassDMDOverlay\s*=\s*1", open(ini).read(), re.M); bgw = 300
    for w in range(800, 290, -10):
        sh_ = round(w * ratio) if score else 0
        h = LY.art_height(b2s, keep_grill=bool(dmd_in_bg), W=w, max_h=1080 - sh_) if os.path.exists(b2s) else 450
        last_row = (h + sh_) // 16 + 1
        lefts = [l for j, l in enumerate(left_row) if l is not None and j <= last_row]
        left_min = (min(lefts) + shift) if lefts else 1920
        if left_min - 8 >= w: bgw = w; break
    res = {"hofs": hofs, "bgw": bgw, "right_before": right, "shift_px": round(shift)}
    log("  RESULT", res); return res
if __name__ == "__main__":
    os.makedirs("/tmp/fit", exist_ok=True)
    args = sys.argv[1:]; cur = int(args[args.index("--from") + 1]) if "--from" in args else None
    todo = [int(a) for a in args if a.isdigit()]
    fit = json.load(open(FIT)) if os.path.exists(FIT) else {}
    for idx in todo:
        if cur is None: cur = idx
        ensure_list()
        while cur < idx: pad("DOWN", "wait:1"); cur += 1
        while cur > idx: pad("UP", "wait:1"); cur -= 1
        ensure_list()
        name = ORDER[idx - 1]
        try: r = process(name, idx)
        except Exception as e:
            log("ABORT", name, e); kill(); break
        if r:
            fit[name] = r; json.dump(fit, open(FIT, "w"), indent=1, sort_keys=True)
            LY.layout_table(f"{V}/{name}.vpx")
    log("FINISHED")
