#!/usr/bin/env python3
"""Static checks for the table script, since VBScript can't run here.

    python3 tools/check_script.py      # after tools/build.py

Checks block nesting (Sub/If/For/Select/With/Do), and that every name the script
uses is declared (Option Explicit), a VBScript or VPX built-in, or a part on the table.
It is a linter, not an interpreter: it can't catch wrong logic or bad property names.
"""
import json
import re
import sys
from pathlib import Path

TABLE = Path(__file__).resolve().parent.parent
EXPANDED = TABLE / "build" / "expanded"

VBS_BUILTINS = """
and or not xor mod is eqv imp true false nothing empty null new me call set let dim const redim preserve
if then else elseif end sub function for each in to step next do loop while wend until select case with
exit option explicit on error resume goto byref byval private public randomize rem
abs array asc atn cbool cbyte ccur cdate cdbl chr cint clng cos createobject csng cstr date dateadd
datediff datepart dateserial datevalue day escape eval exp filter fix formatcurrency formatdatetime
formatnumber formatpercent getobject getref hex hour inputbox instr instrrev int isarray isdate isempty
isnull isnumeric isobject join lbound lcase left len loadpicture log ltrim mid minute month monthname
msgbox now oct replace rgb right rnd round rtrim scriptengine second sgn sin space split sqr strcomp
string strreverse tan time timer timeserial timevalue trim typename ubound ucase unescape vartype weekday
weekdayname year err executeglobal execute
vbnewline vbcrlf vbcr vblf vbtab vbwhite vbblack vbred vbgreen vbblue vbyellow vbcyan vbmagenta
vbtrue vbfalse vbobjecterror
""".split()

VPX_GLOBALS = """
leftflipperkey rightflipperkey lefttiltkey righttiltkey centertiltkey plungerkey startgamekey
addcreditkey addcreditkey2 mechanicaltilt leftmagnasave rightmagnasave lockbarkey exitgame
playsound stopsound playmusic endmusic nudge loadvalue savevalue activeball gettextfile
getballs getballid showdt rendermode version vpbuildversion gamestarted
""".split()


def strip(line):
    """Remove comments and string contents from one line."""
    out, in_str = [], False
    i = 0
    while i < len(line):
        ch = line[i]
        if in_str:
            if ch == '"':
                if i + 1 < len(line) and line[i + 1] == '"':
                    i += 2
                    continue
                in_str = False
                out.append('"')
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append('"')
        elif ch == "'":
            break
        else:
            out.append(ch)
        i += 1
    s = "".join(out)
    return re.sub(r"(?i)^\s*rem\b.*", "", s)


def statements(text):
    lines, buf, start = [], "", 0
    for n, raw in enumerate(text.splitlines(), 1):
        s = strip(raw).rstrip()
        if not buf:
            start = n
        if s.endswith(" _"):
            buf += s[:-1] + " "
            continue
        buf += s
        for part in buf.split(":"):
            if part.strip():
                lines.append((start, part.strip()))
        buf = ""
    return lines


def table_names():
    names = set()
    for f in (EXPANDED / "gameitems").glob("*.json"):
        data = json.loads(f.read_text())
        names.add(data[next(iter(data))]["name"].lower())
    for c in json.loads((EXPANDED / "collections.json").read_text()):
        names.add(c["name"].lower())
    names.add(json.loads((EXPANDED / "gamedata.json").read_text())["name"].lower())
    return names


def main():
    if not (EXPANDED / "script.vbs").exists():
        sys.exit("run tools/build.py first")
    text = (EXPANDED / "script.vbs").read_text()
    stmts = statements(text)
    errors = []

    # ---- block nesting
    stack = []
    openers = [
        (r"^(private |public )?sub\b", "sub", r"^end sub\b"),
        (r"^(private |public )?function\b", "function", r"^end function\b"),
        (r"^select case\b", "select", r"^end select\b"),
        (r"^with\b", "with", r"^end with\b"),
        (r"^for\b", "for", r"^next\b"),
        (r"^do\b", "do", r"^loop\b"),
        (r"^while\b", "while", r"^wend\b"),
    ]
    closers = {c: kind for _, kind, c in openers}
    closers[r"^end if\b"] = "if"
    for n, st in stmts:
        low = st.lower()
        if re.match(r"^if\b", low) and re.search(r"\bthen$", low):
            stack.append(("if", n))
            continue
        if re.match(r"^(elseif|else)\b", low):
            if not stack or stack[-1][0] != "if":
                errors.append(f"line {n}: {st.split()[0]} outside an If block")
            continue
        matched = False
        for pat, kind in closers.items():
            if re.match(pat, low):
                matched = True
                if not stack or stack[-1][0] != kind:
                    top = f"{stack[-1][0]} from line {stack[-1][1]}" if stack else "nothing"
                    errors.append(f"line {n}: '{st}' closes {top}")
                else:
                    stack.pop()
        if matched:
            continue
        for pat, kind, _ in openers:
            if re.match(pat, low):
                stack.append((kind, n))
    for kind, n in stack:
        errors.append(f"line {n}: {kind} is never closed")

    # ---- declarations
    known = set(VBS_BUILTINS) | set(VPX_GLOBALS) | table_names()
    for n, st in stmts:
        low = st.lower()
        m = re.match(r"^(?:private |public )?(?:sub|function)\s+(\w+)\s*(?:\((.*)\))?", low)
        if m:
            known.add(m.group(1))
            for param in (m.group(2) or "").split(","):
                param = re.sub(r"\b(byref|byval)\b", "", param).strip()
                if param:
                    known.add(param.split("(")[0].strip())
            continue
        m = re.match(r"^(?:dim|const|redim(?: preserve)?|private|public)\s+(.*)", low)
        if m:
            for decl in re.split(r",(?![^(]*\))", m.group(1)):
                name = re.match(r"\s*(\w+)", decl)
                if name:
                    known.add(name.group(1))
    # Event handlers like Bumper1_Hit are fine even if the part is missing, but report
    # handlers whose part doesn't exist: they never fire.
    parts = table_names()
    for n, st in stmts:
        m = re.match(r"^sub\s+(\w+?)_(hit|unhit|timer|spin|slingshot|dropped|collide|init|exit|keydown|keyup)\b",
                     st.lower())
        if m and m.group(1) not in parts:
            errors.append(f"line {n}: handler {st.split()[1].split('(')[0]} has no part named {m.group(1)}")

    for n, st in stmts:
        if re.match(r"(?i)^(sub|function|dim|const|end)\b", st):
            continue
        body = re.sub(r'"[^"]*"', '""', st)
        for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)", body):
            word = m.group(1).lower()
            if word not in known:
                errors.append(f"line {n}: '{m.group(1)}' is not declared ({st[:60]})")
                known.add(word)

    if errors:
        print("\n".join(errors))
        print(f"{len(errors)} problem(s)")
        sys.exit(1)
    print(f"script ok: {len(stmts)} statements checked")


if __name__ == "__main__":
    main()
