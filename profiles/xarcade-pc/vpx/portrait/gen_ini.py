#!/usr/bin/env python3
"""Portrait (1080x1920) per-table settings: auto-fit Window view + backglass/DMD strip across the top."""
import os, sys, glob, re, importlib.util
H = os.path.expanduser("~"); V = H + "/Emulation/roms/vpinball"
spec = importlib.util.spec_from_file_location("lay", H + "/Emulation/tools/scripts/vpx-layout.py")
lay = importlib.util.module_from_spec(spec); spec.loader.exec_module(lay)
STRIP_H = 210; GAP = 10
NO_DMD = ("Cirqus Voltaire", "Tom and Jerry")          # these tables show their own display inside the table
def build(name):
    b2s = f"{V}/{name}.directb2s"
    h1000 = lay.art_height(b2s, keep_grill=False, W=1000, max_h=5000) if os.path.exists(b2s) else 750
    bgw = max(200, min(520, round(STRIP_H * 1000 / h1000)))
    try: _ov0 = __import__("json").load(open(H + "/pinball-portrait/overrides.json")).get(name, {})
    except Exception: _ov0 = {}
    dmd = (not name.startswith(NO_DMD)) or bool(_ov0.get("dmd_on"))
    if _ov0.get("dmd_off"): dmd = False
    sx = bgw + GAP; sw = 1080 - sx - GAP; sh = min(STRIP_H - 15, sw // 4)
    t = ["[Player]", "BGSet = 0", "PlayfieldFullScreen = 1", "BallAntiStretch = 1", "CabinetAutofitMode = 1",
         "ScreenPlayerZ = 84.960663", "ScreenPlayerY = 15.083796", "ScreenWidth = 0.0", "ScreenHeight = 0.0", "ScreenInclination = 0.0", "",
         "[Backglass]", "BackglassOutput = 2", "BackglassWndX = 0", "BackglassWndY = 0", f"BackglassWidth = {bgw}", f"BackglassHeight = {STRIP_H}", ""]
    if dmd:
        t += ["[ScoreView]", "ScoreViewOutput = 2", f"ScoreViewWndX = {sx}", "ScoreViewWndY = 0", f"ScoreViewWidth = {sw}", f"ScoreViewHeight = {sh}", ""]
    else:
        t += ["[ScoreView]", "ScoreViewOutput = 0", ""]
    t += ["[TableOverride]", "ViewDTMode = 2", "ViewDTRotation = 0.0", "ViewDTHOfs = 0.0",
          "ViewDTScaleX = 0.89", "ViewDTScaleY = 0.89", "ViewDTScaleZ = 0.89", "ViewDTVOfs = 12.0",
          "ViewDTWindowTop = 190.955978", "ViewDTWindowBot = 0.197218", ""]
    txt = "\n".join(t)
    if name.startswith("Tales of the Arabian Nights"):
        txt = txt.replace("BGSet = 0", "BGSet = 1")
        txt = txt.split("[TableOverride]")[0] + "[TableOverride]\nViewCabRotation = 0.0\nViewCabScaleX = 0.89\nViewCabScaleY = 0.89\nViewCabScaleZ = 0.89\nViewCabVOfs = 12.0\n"
    import json
    try: ov = json.load(open(H + "/pinball-portrait/overrides.json")).get(name, {})
    except Exception: ov = {}
    if "VOfs" in ov:
        txt = txt.replace("ViewDTVOfs = 12.0", f"ViewDTVOfs = {ov['VOfs']}").replace("ViewCabVOfs = 12.0", f"ViewCabVOfs = {ov['VOfs']}")
    if "ScaleX" in ov:
        txt = txt.replace("ViewDTScaleX = 0.89", f"ViewDTScaleX = {ov['ScaleX']}")
    if "Shrink" in ov:
        txt = re.sub(r"(ViewDTScale[XYZ] = )([\d.]+)", lambda m: f"{m.group(1)}{float(m.group(2)) * ov['Shrink']:.4f}", txt)
    if ov.get("bg_off"):
        txt = txt.replace("BackglassOutput = 2", "BackglassOutput = 0")
    if "dmd_aspect" in ov and dmd:
        nsh = STRIP_H; nsw = round(nsh * ov["dmd_aspect"])
        txt = re.sub(r"ScoreViewWidth = \d+", f"ScoreViewWidth = {nsw}", txt)
        txt = re.sub(r"ScoreViewHeight = \d+", f"ScoreViewHeight = {nsh}", txt)
    if ov.get("hide_b2s_dmd"):
        txt = txt.rstrip("\n") + "\n\n[Plugin.B2SLegacy]\nBackglassDMDOverlay = 0\nScoreViewDMDOverlay = 0\nB2SHideB2SDMD = 1\nB2SHideDMD = 1\n"
    if "strip_h" in ov:                     # taller strip: scale the backglass up (same shape) and refit the DMD beside it
        sh_ = int(ov["strip_h"]); bgw2 = round(bgw * sh_ / STRIP_H)
        txt = re.sub(r"BackglassWidth = \d+", f"BackglassWidth = {bgw2}", txt)
        txt = re.sub(r"BackglassHeight = \d+", f"BackglassHeight = {sh_}", txt)
        if dmd:
            sx2 = bgw2 + GAP; sw2 = 1080 - sx2 - GAP; shh = min(sh_ - 15, sw2 // 4)
            txt = re.sub(r"ScoreViewWndX = \d+", f"ScoreViewWndX = {sx2}", txt)
            txt = re.sub(r"ScoreViewWidth = \d+", f"ScoreViewWidth = {sw2}", txt)
            txt = re.sub(r"ScoreViewHeight = \d+", f"ScoreViewHeight = {shh}", txt)
    if "stretch_x" in ov or "stretch_y" in ov:       # extra width/height on top of everything above (applied last)
        sx_ = float(ov.get("stretch_x", 1.0)); sy_ = float(ov.get("stretch_y", 1.0))
        def _m(key, f):
            nonlocal txt
            txt = re.sub(r"(%s = )([\d.]+)" % key, lambda m: f"{m.group(1)}{float(m.group(2)) * f:.4f}", txt)
        _m("ViewDTScaleX", sx_); _m("ViewDTScaleY", sy_); _m("ViewDTScaleZ", sy_)
    if ov.get("bg_right"):                            # mirror the strip: backglass on the right, DMD/score view on the left
        for w in ("Backglass", "ScoreView"):
            mx = re.search(w + r"WndX = (\d+)", txt); mw = re.search(w + r"Width = (\d+)", txt)
            if mx and mw: txt = re.sub(w + r"WndX = \d+", f"{w}WndX = {1080 - int(mx.group(1)) - int(mw.group(1))}", txt)
    if ov.get("player_extra"):                        # extra [Player] keys for this table, e.g. graphics tweaks
        txt = txt.replace("[Player]\n", "[Player]\n" + "".join(f"{k} = {v}\n" for k, v in ov["player_extra"].items()), 1)
    return txt, bgw, dmd
if __name__ == "__main__":
    os.makedirs(H + "/pinball-portrait/p2", exist_ok=True)
    for f in sorted(glob.glob(V + "/*.vpx")):
        n = os.path.basename(f)[:-4]; txt, bgw, dmd = build(n)
        open(f"{H}/pinball-portrait/p2/{n}.ini", "w").write(txt); print(f"{n}: backglass {bgw}x{STRIP_H}, dmd {dmd}")
