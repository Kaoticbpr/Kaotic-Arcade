#!/usr/bin/env python3
"""Set VPinballX.ini values: vpxset.py 'Section.Key=Value' or 'Section::Key.With.Dots=Value' ...
(keys may already exist empty or be missing)."""
import os, re, sys, shutil, time
INI = os.environ.get("VPXSET_INI") or os.path.expanduser("~/.local/share/VPinballX/10.8/VPinballX.ini")

def setval(lines, section, key, value):
    sec_re = re.compile(r"^\[(.+)\]\s*$")
    cur, start, end = None, None, len(lines)
    for i, l in enumerate(lines):
        m = sec_re.match(l)
        if m:
            if cur == section: end = i; break
            cur = m.group(1)
            if cur == section: start = i
    if start is None:
        lines += ["", f"[{section}]", f"{key} = {value}"]; return
    for i in range(start + 1, end):
        if re.match(rf"^{re.escape(key)}\s*=", lines[i]):
            lines[i] = f"{key} = {value}"; return
    lines.insert(end, f"{key} = {value}")

if __name__ == "__main__":
    if not os.environ.get("VPXSET_NOBACKUP"): shutil.copy(INI, INI + ".bak-" + time.strftime("%Y%m%d%H%M%S"))
    lines = open(INI, encoding="utf-8").read().split("\n")
    for arg in sys.argv[1:]:
        k, v = arg.split("=", 1)
        sec, key = k.split("::", 1) if "::" in k else k.rsplit(".", 1)
        setval(lines, sec, key, v)
        print(f"[{sec}] {key} = {v}")
    open(INI, "w", encoding="utf-8").write("\n".join(lines))
