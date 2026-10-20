#!/usr/bin/env python3
"""Render test for per-table portrait layouts (headless, silent). usage: layout_test.py <tag> <table name> [key=value ...]
key=value overrides (VOfs, Shrink, ScaleX) replace the table's entries in a COPY of overrides.json used only for this test.
Writes ~/pinball-portrait/rot/<tag>.ini and .png. Never touches live files or overrides.json."""
import json, os, subprocess, sys, importlib.util
H = os.path.expanduser("~"); PP = H + "/pinball-portrait"; V = H + "/Emulation/roms/vpinball"
tag, name = sys.argv[1], sys.argv[2]
kv = dict(a.split("=") for a in sys.argv[3:])
spec = importlib.util.spec_from_file_location("gi", PP + "/gen_ini.py"); gi = importlib.util.module_from_spec(spec)
real_open = open
ov = json.load(real_open(PP + "/overrides.json")); ov.setdefault(name, {}).update({k: float(v) for k, v in kv.items()})
json.dump(ov, real_open(PP + "/rot/_ov_test.json", "w"))
src = real_open(PP + "/gen_ini.py").read().replace('H + "/pinball-portrait/overrides.json"', 'H + "/pinball-portrait/rot/_ov_test.json"')
exec(compile(src.replace('if __name__ == "__main__":', 'if False:'), "gen_ini_test", "exec"), gi.__dict__)
txt, bgw, dmd = gi.build(name)
ini = f"{PP}/rot/{tag}.ini"; real_open(ini, "w").write(txt)
print(txt.split("[TableOverride]")[1].strip().replace("\n", " | "))
env = dict(os.environ, SDL_AUDIODRIVER="dummy")
subprocess.run(["gamescope", "--backend", "headless", "-W", "1080", "-H", "1920", "-w", "1080", "-h", "1920", "-r", "60", "--",
                PP + "/runh.sh", ini, f"{V}/{name}.vpx", f"rot/{tag}"], env=env, cwd=PP, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(["pkill", "-x", "VPinballX_BGFX"]); print("done", tag)
