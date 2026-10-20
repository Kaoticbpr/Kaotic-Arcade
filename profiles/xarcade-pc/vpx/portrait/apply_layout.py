#!/usr/bin/env python3
"""Apply per-table portrait layout overrides: apply_layout.py "<table>" key=value ... [--also "<table2>" ...]
Updates overrides.json, regenerates p2/<table>.ini, copies it into ~/Emulation/tools/portrait/ini (the portrait source) and, when the TV is
in portrait mode, into the live table folder too. Refuses while VPX is running."""
import importlib.util, json, os, shutil, subprocess, sys
H = os.path.expanduser("~"); PP = H + "/pinball-portrait"; V = H + "/Emulation/roms/vpinball"; P = H + "/Emulation/tools/portrait"
SRC_ONLY = "--src-only" in sys.argv
if not SRC_ONLY and subprocess.run(["pgrep", "-f", "[V]PinballX_BGFX"], stdout=subprocess.DEVNULL).returncode == 0: sys.exit("VPX is running (use --src-only to save for the next switch)")
args = [a for a in sys.argv[1:] if a != "--src-only"]; name = args[0]
kv = {a.split("=")[0]: float(a.split("=")[1]) for a in args[1:] if "=" in a}
extra = args[args.index("--also") + 1:] if "--also" in args else []
ov = json.load(open(PP + "/overrides.json")); ov.setdefault(name, {}).update(kv)
shutil.copy(PP + "/overrides.json", PP + "/overrides.json.bak-apply"); json.dump(ov, open(PP + "/overrides.json", "w"), indent=1)
spec = importlib.util.spec_from_file_location("gi", PP + "/gen_ini.py"); gi = importlib.util.module_from_spec(spec); spec.loader.exec_module(gi)
portrait = json.load(open(P + "/state.json")).get("mode") == "portrait"
for n in [name] + extra:
    txt = gi.build(n)[0]
    open(f"{PP}/p2/{n}.ini", "w").write(txt); open(f"{P}/ini/{n}.ini", "w").write(txt)
    if portrait and not SRC_ONLY: open(f"{V}/{n}.ini", "w").write(txt)
    print("updated", n, "(live too)" if portrait else "(portrait source only; applies at next portrait switch)")
