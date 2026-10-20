#!/usr/bin/env python3
"""Per-table fixes for the TV layout, kept in ~/Emulation/tools/vpx-table-fixes.json so they survive reinstalls and
layout changes. Applied by vpx-layout.py (camera) and vpx-add.py / this script (hidden objects).

  {"<table name>": {"camera": {"ViewDTHOfs": 30, ...},          # corrections on top of vpx-layout.CAMERA
                    "hide":   ["Primitive001", "ax??"],         # objects not drawn (e.g. a desktop backbox model);
                                                                # '?' / '*' wildcards match object names
                    "note":   "why"}}

usage: vpx-tablefix.py "<table>" hide NAME [NAME...]     add objects to hide, rewrite the table's sidecar block
       vpx-tablefix.py "<table>" camera KEY=VAL [...]   add camera corrections, rewrite the table's ini
       vpx-tablefix.py "<table>" vbs 'STATEMENT'       add a one-line script tweak (runs after the table script loads)
       vpx-tablefix.py "<table>" replace 'OLD' 'NEW'   change a script line (e.g. stop it re-showing a hidden object)
       vpx-tablefix.py "<table>" ini Section.Key=VAL    any other setting in the table's own ini (e.g. Player.EmissionScale=0.7)
       vpx-tablefix.py "<table>" note TEXT
       vpx-tablefix.py "<table>" apply                  (re)apply both
"""
import json, os, re, sys, importlib.util

H = os.path.expanduser("~")
FIXES = f"{H}/Emulation/tools/vpx-table-fixes.json"
TABLES = f"{H}/Emulation/roms/vpinball"
HERE = os.path.dirname(os.path.abspath(__file__))
MARK_BEGIN = "' KaoticBPR table fix (vpx-tablefix.py) - begin"
MARK_END = "' KaoticBPR table fix (vpx-tablefix.py) - end"

def load():
    return json.load(open(FIXES)) if os.path.exists(FIXES) else {}

def save(d):
    json.dump(d, open(FIXES, "w"), indent=1, sort_keys=True)

def _mod(name):
    s = importlib.util.spec_from_file_location(name.replace("-", "_"), os.path.join(HERE, name + ".py"))
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m

def glob_rx(p):
    """Shell-style wildcard -> VBScript RegExp: * and ? as usual, [..] character classes kept, the rest literal."""
    out, i = "^", 0
    while i < len(p):
        c = p[i]
        if c == "*": out += ".*"
        elif c == "?": out += "."
        elif c == "[" and "]" in p[i:]:
            j = p.index("]", i); out += p[i:j + 1]; i = j
        else: out += re.escape(c)
        i += 1
    return out + "$"

def hide_block(names, vbs=()):
    """VBScript appended to the table's sidecar script: hides the listed objects once the script has loaded."""
    pats = [n.lower() for n in names]
    lines = [MARK_BEGIN, "On Error Resume Next", "Dim kbprEl, kbprN"]
    for p in pats:
        if not any(c in p for c in "*?"):
            lines.append(f"{p}.Visible = 0")          # direct (fast) for plain names
    wild = [p for p in pats if any(c in p for c in "*?")]
    if wild:                                          # VBScript has no Like operator: wildcards become a RegExp
        rx = "|".join(glob_rx(p) for p in wild)
        lines.append("Dim kbprRx : Set kbprRx = New RegExp : kbprRx.IgnoreCase = True")
        lines.append(f'kbprRx.Pattern = "{rx}"')
        lines.append("For Each kbprEl In GetElements")
        lines.append("  If kbprRx.Test(kbprEl.Name) Then kbprEl.Visible = 0")
        lines.append("Next")
    lines += list(vbs)                                # extra one-line script tweaks for this table
    lines += ["On Error Goto 0", MARK_END]
    return "\n".join(lines)

def apply_hide(table, names, vbs=(), replace=()):
    side = f"{TABLES}/{table}.vbs"
    if os.path.exists(side):
        text = open(side, encoding="latin-1").read()
    else:
        text, _ = _script(table)
    for a, b in replace:                              # e.g. a table that keeps switching a hidden object back on
        text = text.replace(a, b)
    text = re.sub(re.escape(MARK_BEGIN) + r".*?" + re.escape(MARK_END) + r"\n?", "", text, flags=re.S).rstrip("\n")
    if names or vbs: text += "\n\n" + hide_block(names, vbs) + "\n"
    open(side, "w", encoding="latin-1").write(text)

def _script(table):
    src = open(os.path.join(HERE, "vpx-add.py")).read()
    ns = {}; argv = sys.argv; sys.argv = ["x"]
    try: exec(src[:src.index("def meta_from_name")], ns)
    finally: sys.argv = argv
    return ns["script_info"](f"{TABLES}/{table}.vpx")

def apply(table):
    fx = load().get(table, {})
    layout = _mod("vpx-layout")
    layout.layout_table(f"{TABLES}/{table}.vpx")         # writes CAMERA + this table's camera corrections
    if "hide" in fx or "vbs" in fx or "replace" in fx:
        apply_hide(table, fx.get("hide", []), fx.get("vbs", []), fx.get("replace", []))

if __name__ == "__main__":
    table, cmd, args = sys.argv[1], sys.argv[2], sys.argv[3:]
    d = load(); fx = d.setdefault(table, {})
    if cmd == "hide":
        fx["hide"] = sorted(set(fx.get("hide", [])) | set(args))
    elif cmd == "camera":
        cam = fx.setdefault("camera", {})
        for kv in args:
            k, v = kv.split("="); cam[k] = float(v) if "." in v else int(v)
    elif cmd == "vbs":                                 # e.g. vbs 'Table1.BackdropImage_DT = ""'
        fx["vbs"] = fx.get("vbs", []) + [" ".join(args)]
    elif cmd == "replace":                             # replace 'OLD TEXT' 'NEW TEXT' in the table's script
        fx["replace"] = fx.get("replace", []) + [[args[0], args[1]]]
    elif cmd == "score_h":                             # height of the DMD/score box under the backglass
        fx["score_h"] = int(args[0])
    elif cmd == "ini":                                 # ini Player.EmissionScale=0.7 (any section of the table's ini)
        for kv in args:
            k, v = kv.split("=", 1); sec, key = k.split(".", 1)
            fx.setdefault("ini", {}).setdefault(sec, {})[key] = v
    elif cmd == "note":
        fx["note"] = " ".join(args)
    save(d); apply(table)
    print(table, json.dumps(d.get(table, {})))
