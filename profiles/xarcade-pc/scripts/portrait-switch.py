#!/usr/bin/env python3
"""Swap landscape <-> portrait settings for the rotating TV: pinball tables (VPX .ini/.vbs) and vertical arcade
games (RetroArch per-game .cfg).

  portrait-switch.py portrait | landscape | status   [--dry-run]

Portrait sets live in ~/Emulation/tools/portrait/{ini,vbs,ra/<core>}. Before swapping, each live file is backed up
to .../landscape-backup and recorded in state.json; `landscape` restores exactly that (files that did not exist are
removed again). Run only with VPX and RetroArch closed. Install new tables/games while in landscape mode."""
import hashlib, json, os, shutil, subprocess, sys
H = os.path.expanduser("~"); V = H + "/Emulation/roms/vpinball"; P = H + "/Emulation/tools/portrait"
RA = H + "/.var/app/org.libretro.RetroArch/config/retroarch/config"
BK = P + "/landscape-backup"; ST = P + "/state.json"
args = sys.argv[1:]; dry = "--dry-run" in args; args = [a for a in args if a != "--dry-run"]
mode = args[0] if args else "status"
state = json.load(open(ST)) if os.path.exists(ST) else {"mode": "landscape", "files": {}}
def running(name): return subprocess.run(["pgrep", "-f", f"[{name[0]}]{name[1:]}"], stdout=subprocess.DEVNULL).returncode == 0
def pairs():
    """(portrait source, live destination) for everything that can be swapped."""
    out = []
    for kind in ("ini", "vbs"):
        d = f"{P}/{kind}"
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            if f.endswith("." + kind) and os.path.exists(f"{V}/{f.rsplit('.', 1)[0]}.vpx"): out.append((f"{d}/{f}", f"{V}/{f}"))
    d0 = f"{P}/ra"
    for core in sorted(os.listdir(d0)) if os.path.isdir(d0) else []:
        for f in sorted(os.listdir(f"{d0}/{core}")):
            if f.endswith(".cfg"): out.append((f"{d0}/{core}/{f}", f"{RA}/{core}/{f}"))
    return out
def bkname(live): return hashlib.md5(live.encode()).hexdigest()[:16] + "-" + os.path.basename(live)
if mode == "status":
    ntab = len({k for k in state["files"] if k.startswith(V)}); nra = len([k for k in state["files"] if k.startswith(RA)])
    print("mode:", state["mode"], f"| pinball files swapped: {ntab} | arcade configs swapped: {nra}"); sys.exit()
if mode not in ("portrait", "landscape"): sys.exit("usage: portrait-switch.py portrait|landscape|status [--dry-run]")
if running("VPinballX_BGFX") or running("retroarch"): sys.exit("Close Visual Pinball / RetroArch first.")
if mode == "portrait":
    if state["mode"] == "portrait": sys.exit("Already in portrait mode.")
    os.makedirs(BK, exist_ok=True); files = {}
    for src, live in pairs():
        files[live] = os.path.exists(live)
        if dry: continue
        if os.path.exists(live): shutil.copy2(live, f"{BK}/{bkname(live)}")
        shutil.copy2(src, live)
    print(("would swap " if dry else "swapped ") + f"{len(files)} files")
    if not dry: json.dump({"mode": "portrait", "files": files}, open(ST, "w"), indent=1)
else:
    if state["mode"] != "portrait": sys.exit("Already in landscape mode.")
    for live, existed in state["files"].items():
        if dry: continue
        bk = f"{BK}/{bkname(live)}"
        if existed and os.path.exists(bk): shutil.copy2(bk, live)
        elif not existed and os.path.exists(live): os.remove(live)
    print(("would restore " if dry else "restored ") + f"{len(state['files'])} files")
    if not dry: json.dump({"mode": "landscape", "files": {}}, open(ST, "w"), indent=1)
