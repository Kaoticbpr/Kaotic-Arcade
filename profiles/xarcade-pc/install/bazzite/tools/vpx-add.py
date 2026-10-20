#!/usr/bin/env python3
"""KaoticBPR Arcade pinball table installer (runs on the mini PC; driven by the laptop's Pinball Table Installer).

usage: vpx-add.py <staging folder> <table name, base64> [--refresh]
       vpx-add.py --apply-pending          (called by arcade-env.sh before ES-DE starts)

Sorts whatever was dropped (loose files, folders or zips) into Visual Pinball X's layout:
  table .vpx, backglass .directb2s, PinMAME ROM zips, Serum (.cRZ/.cROMc) or VNI (.pal/.vni) colors,
  table music, AltSound packs, PuP packs, a user-supplied .vbs fix, and a wheel/logo image.
Then it reads the table script to learn its ROM name, applies the known Linux fix (ROM lamps report 1 instead
of True, so "controller.lamp(n)=true" never matches), makes ES-DE artwork (backglass -> cover, wheel -> marquee)
and adds the ES-DE Pinball entry. ES-DE is only restarted with --refresh and when no game is running.
"""
import base64, io, json, os, re, shutil, subprocess, sys, tempfile, time, zipfile

H = os.path.expanduser("~")
V = f"{H}/Emulation/roms/vpinball"
PM = f"{V}/pinmame"
MED = f"{H}/Emulation/tools/downloaded_media/vpinball"
GL = f"{H}/ES-DE/gamelists/vpinball/gamelist.xml"
PENDING = f"{H}/Emulation/tools/vpx-pending-gamelist.json"
VPX = f"{H}/Applications/VPinballX/VPinballX_BGFX"
ESDE_ID = (3536773192 << 32) | 0x02000000
IMG = (".png", ".jpg", ".jpeg", ".apng", ".webp", ".gif")
SKIP = (".txt", ".pdf", ".docx", ".doc", ".rtf", ".url", ".nfo", ".md", ".ini", ".db", ".exe")

def say(*a): print(*a, flush=True)

class Item:
    """A file found loose or inside a zip (one level of nested zips is opened too)."""
    def __init__(self, name, size, reader):
        self.name, self.size, self._reader = name, size, reader
        self.low = name.lower(); self.base = os.path.basename(name)
    def read(self): return self._reader()

def scan(stage):
    items = []
    def add_zip(zf, label, depth):
        for info in zf.infolist():
            if info.is_dir(): continue
            n = info.filename
            if n.lower().endswith(".zip") and depth < 1:
                try:
                    data = zf.read(n); inner = zipfile.ZipFile(io_bytes(data))
                    if is_rom_zip(inner):          # ROM zip packed inside the table zip: keep it whole
                        it = Item(f"{label}/{n}", len(data), (lambda d=data: d)); it.rom = True; items.append(it); continue
                    add_zip(inner, f"{label}/{n}", depth + 1); continue
                except zipfile.BadZipFile: pass
            items.append(Item(f"{label}/{n}", info.file_size, (lambda z=zf, m=n: z.read(m))))
            items[-1].zipgroup = label
    for root, _, files in os.walk(stage):           # .rar / .7z downloads (e.g. Siggi's POTC) are unpacked first
        for f in files:
            if f.lower().endswith((".rar", ".7z")):
                p = os.path.join(root, f); out = p + "_unpacked"; os.makedirs(out, exist_ok=True)
                cmd = ["unrar", "x", "-o+", "-inul", p, out + "/"] if f.lower().endswith(".rar") else ["7z", "x", "-y", f"-o{out}", p]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)   # (this 7z can't open RAR5)
                if os.path.isdir(out): os.remove(p)
    for root, dirs, files in os.walk(stage):
        dirs[:] = [d for d in dirs if d.lower() != "_old"]   # old versions kept by the user beside the new download
        for f in files:
            p = os.path.join(root, f); rel = os.path.relpath(p, stage)
            if f.lower().endswith(".zip"):
                try:
                    zf = zipfile.ZipFile(p)
                    if is_rom_zip(zf): items.append(Item(rel, os.path.getsize(p), (lambda q=p: open(q, "rb").read()))); items[-1].rom = True; continue
                    add_zip(zf, rel, 0); continue
                except zipfile.BadZipFile: pass
            items.append(Item(rel, os.path.getsize(p), (lambda q=p: open(q, "rb").read())))
    return items

def io_bytes(b):
    import io; return io.BytesIO(b)

def is_rom_zip(zf):
    names = [n.lower() for n in zf.namelist() if not n.endswith("/")]
    bad = (".vpx", ".directb2s", ".crz", ".cromc", ".crom", ".pal", ".vni", ".pac", ".mp3", ".ogg", ".wav", ".mp4", ".pdf",
           ".docx", ".png", ".jpg", ".csv", ".vbs", ".pup", ".zip")
    chips = [n for n in names if not n.endswith(".txt")]      # official Williams ROM zips carry LICENSE/RELEASE.TXT
    return bool(chips) and not any(n.endswith(bad) for n in names)

def script_info(vpx_path):
    """Extract the table script into a temp folder (hard link, so nothing is written next to the real table)."""
    tmp = tempfile.mkdtemp(prefix="vpxadd-", dir=f"{H}/.cache")
    link = f"{tmp}/t.vpx"
    try: os.link(vpx_path, link)
    except OSError: shutil.copy(vpx_path, link)
    env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    subprocess.run([VPX, "-PrefPath", f"{tmp}/pref", "-ExtractVBS", link], env=env, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=180)
    vbs = f"{tmp}/t.vbs"
    text = open(vbs, encoding="latin-1").read() if os.path.exists(vbs) else ""
    shutil.rmtree(tmp, ignore_errors=True)
    return text, rom_name(text)

def rom_name(text):
    """PinMAME ROM the script runs, or None for tables that don't use a ROM (originals like Primus/TNA also define
    a cGameName, but only for their backglass). Commented-out lines are ignored (FunHouse keeps an old fh_L9 one)."""
    code = "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("'"))
    if not re.search(r"\bLoadVPM\b|VPinMAME\.Controller", code, re.I): return None
    m = re.search(r'cGameName\s*=\s*"([^"]+)"', code, re.I) or re.search(r'\.GameName\s*=\s*"([^"]+)"', code, re.I)
    return m.group(1) if m else None

LAMP_TRUE = re.compile(r"(controller\.(?:lamp|switch|solenoid)\s*\(\s*[^)]*\))\s*=\s*(true|false)\b", re.I)

COND = re.compile(r"^(\s*(?:else\s*if|elseif|if|while|do\s+while|do\s+until|loop\s+while|loop\s+until)\b)(.*?)(\bthen\b.*)?$", re.I)

def linux_fix(text):
    """ROM lamps/switches report 1/0 on Linux, so '= true' / '= false' comparisons never match.
    Only conditions are rewritten (If/ElseIf/While/Until lines, up to 'Then'); assignments are left alone."""
    n = 0; out = []
    sub = lambda m: f"CBool({m.group(1)})" if m.group(2).lower() == "true" else f"(Not CBool({m.group(1)}))"
    for line in text.split("\n"):
        m = COND.match(line)
        if m:
            cond, k = LAMP_TRUE.subn(sub, m.group(2))
            if k: line = m.group(1) + cond + (m.group(3) or ""); n += k
        out.append(line)
    if not n: return None, 0
    fixed = "\n".join(out)
    hdr = ("' KaoticBPR Arcade Linux fix (vpx-add.py): ROM lamps/switches report 1 instead of True on Linux,\n"
           "' so controller.lamp(n)=true style checks were rewritten as CBool(...).\n")
    return hdr + fixed, n

EARLY_WMS = re.compile(r'LoadVPM\s+"[^"]*"\s*,\s*"S[3-7]\.VBS"', re.I)
VPM_INIT = re.compile(r"^(\s*)vpmInit\s+Me\s*$", re.I | re.M)

def early_williams_fix(text):
    """Williams System 3-7 sound boards (S67S: 6802 + DAC) go silent except for speech when PinMAME runs
    time-fenced to VPX physics (VPX 10.8.1 rev 5436, verified on Firepower). Turn the fence off for these tables."""
    if not EARLY_WMS.search(text): return text, False
    # Sound DIP 1+2 (dip bank 0, bits 0-1) select electronic sound + speech instead of chimes. Scripts often
    # write .dip(0)=&h00; on Windows people flip them in VPinMAME's F6 menu, which doesn't exist here.
    text = re.sub(r"(\.dip\(0\)\s*=\s*&h)([0-9a-f]+)", lambda m: m.group(1) + format(int(m.group(2), 16) | 3, "02x"), text, flags=re.I)
    if "HasTimeFence = False" in text: return text, True
    m = VPM_INIT.search(text)
    if not m: return text, False
    line = m.group(0) + "\n" + m.group(1) + "On Error Resume Next : HasTimeFence = False : Controller.TimeFence = 0 : On Error Goto 0   ' KaoticBPR: early Williams sound board needs PinMAME unsynced"
    return text[:m.start()] + line + text[m.end():], True

SCORETEXT_VIS = re.compile(r"(\bScoreText\.Visible[ \t]*=[ \t]*+)[^:'\r\n]+?(?=\s*(?:$|:|'|\belse\b|\bend\s+if\b))", re.I | re.M)
DMD_HIDE_MARK = "' KaoticBPR: DMD shown under the backglass"

def dmd_fix(text):
    """ROM tables show their DMD in VPX's ScoreView box under the backglass, like a real cabinet; the DMD the table
    draws itself in desktop view (a text box named ScoreText on every table so far) is hidden."""
    if not re.search(r"UseVPMDMD|\bScoreText\b", text, re.I): return text, False
    text = SCORETEXT_VIS.sub(lambda m: m.group(1) + "0", text)
    if DMD_HIDE_MARK not in text:
        text = text.rstrip("\n") + f"\n\n{DMD_HIDE_MARK} (vpx-add.py) - the table's own corner DMD is hidden\nOn Error Resume Next : ScoreText.Visible = 0 : On Error Goto 0\n"
    return text, True

def backglass_art(data, name):
    """ES-DE cover + screenshot from the .directb2s backglass image. The base64 in the XML carries line-break
    entities (&#xD;&#xA;) that must be removed before decoding, or the PNG is corrupt and ES-DE shows nothing."""
    m = re.search(rb'<BackglassImage[^>]*Value="([^"]+)"', data)
    if not m: return False
    dec = lambda v: base64.b64decode(re.sub(rb"&#x?[0-9A-Fa-f]+;|\s", b"", v))
    from PIL import Image
    im = Image.open(io.BytesIO(dec(m.group(1)))); im.load()
    # Some backglasses (Cirqus Voltaire) keep only a partial base image and draw the full art as an always-on
    # "bulb" layer on top; paint those full-size always-on layers over the base like B2S does.
    for b in re.finditer(rb"<Bulb\s([^>]*)>", data):
        a = b.group(1); at = lambda k: (re.search(k + rb'="(-?\d+)"', a) or [None, b"0"])[1]
        img = re.search(rb' Image="([^"]+)"', a)
        if not img or at(rb"Visible") != b"1" or at(rb"InitialState") != b"1" or at(rb"RomID") != b"0": continue
        if int(at(rb"Width")) * int(at(rb"Height")) < 0.8 * im.width * im.height: continue
        try:
            layer = Image.open(io.BytesIO(dec(img.group(1)))).convert("RGBA")
            layer = layer.resize((int(at(rb"Width")), int(at(rb"Height"))))
            im = im.convert("RGBA"); im.alpha_composite(layer, (int(at(rb"LocX")), int(at(rb"LocY"))))
        except Exception: pass
    im = im.convert("RGB")
    g = re.search(rb'<GrillHeight Value="(\d+)"', data)     # the ES-DE backbox has its own speaker panel + DMD,
    if g and 0 < int(g.group(1)) < im.height // 2:           # so leave the backglass's own grill strip off
        im = im.crop((0, 0, im.width, im.height - int(g.group(1))))
    if im.width > 1280: im = im.resize((1280, round(im.height * 1280 / im.width)), Image.LANCZOS)
    im.save(f"{MED}/screenshots/{name}.png", optimize=True)    # screenshot only: as a cover too the theme showed it twice
    return True

def _norm(s): return re.sub(r"[^a-z0-9]+", " ", s.lower().replace("&", " and ")).strip()

def matched_wheel(name):
    """All ES-DE pinball wheels come from one set so the carousel looks consistent: the VPX Media Database
    (github.com/superhac/vpinmediadb, by Virtual Pinball Spreadsheet table id). Looks the table up by
    'Title (Maker Year)'; returns False (use the wheel that came with the table) if offline or no sure match."""
    import urllib.request
    m = re.match(r"(.+?)\s*\(([^()]*?)\s+((?:19|20)\d\d)\)\s*$", name)
    if not m: return False
    title, maker, year = _norm(m.group(1)), _norm(m.group(2)), int(m.group(3))
    db_path = f"{H}/.cache/vpsdb.json"
    try:
        if not os.path.exists(db_path) or time.time() - os.path.getmtime(db_path) > 7 * 86400:
            urllib.request.urlretrieve("https://virtualpinballspreadsheet.github.io/vps-db/db/vpsdb.json", db_path)
        db = json.load(open(db_path, encoding="utf-8"))
        # also try the title without edition/mod tags, e.g. "No Good Gofers - Rawds Edition" -> "No Good Gofers"
        base_ = re.sub(r"\s+-\s+.*$", "", m.group(1))
        base_ = re.sub(r"(?i)\b(vpw|mod|remaster(ed)?|edition|deluxe|hd|4k)\b.*$", "", base_).strip()
        hits = []
        for title_ in dict.fromkeys([title, _norm(base_)]):
            hits = [g for g in db if _norm(g.get("name", "")) == title_ and abs((g.get("year") or 0) - year) <= 1
                    and (maker in _norm(g.get("manufacturer", "")) or _norm(g.get("manufacturer", "")) in maker)]
            if len(hits) == 1: break
        if len(hits) != 1: return False
        tmp = f"{H}/.cache/vpxadd-vpswheel.png"
        urllib.request.urlretrieve(f"https://raw.githubusercontent.com/superhac/vpinmediadb/main/{hits[0]['id']}/wheel.png", tmp)
        from PIL import Image
        im = Image.open(tmp); im.load()
        if im.width > 500: im = im.resize((500, round(im.height * 500 / im.width)), Image.LANCZOS)
        im.save(f"{MED}/marquees/{name}.png", optimize=True); os.remove(tmp)
        return True
    except Exception:
        return False

def pup_files(items):
    """PuP pack files -> path under pupvideos/. Packs come either inside a 'pupvideos' folder or as a bare
    '<pack>/screens.pup ...' folder/zip (TNA). Windows helper programs (.bat/.exe) are left out."""
    roots = set()
    for i in items:
        p = i.name.replace("\\", "/")
        if p.lower().endswith("/screens.pup") and "pup-pack_options" not in p.lower() and "pupvideos" not in p.lower():
            roots.add(p[: -len("/screens.pup")])
    out = []
    for i in items:
        p = i.name.replace("\\", "/")
        if i.low.endswith((".bat", ".exe", ".dll")): continue
        if "pupvideos" in i.low:
            out.append((i, p[p.lower().index("pupvideos") + len("pupvideos"):].lstrip("/")))
            continue
        root = next((r for r in roots if p.startswith(r + "/")), None)
        if root: out.append((i, root.split("/")[-1] + "/" + p[len(root) + 1:]))
    return out

def pup_one_screen(pack_dir):
    """Many PuP packs ship several screen layouts (PuP-Pack_Options/<option>/*.pup, normally applied with a Windows
    .bat). This TV has the backglass box with the DMD box under it, so use the 'Full DMD' layout: PuP videos and
    scores in the DMD box, the real backglass art in the backglass box. Returns the option used, or None."""
    od = os.path.join(pack_dir, "PuP-Pack_Options")
    if not os.path.isdir(od): return None
    opts = sorted(d for d in os.listdir(od) if os.path.isdir(os.path.join(od, d)))
    pick_ = next((d for d in opts if re.search(r"full\s*_?dmd", d, re.I) and not re.search(r"\bvr\b", d, re.I)), None)
    if not pick_: return None
    for f in os.listdir(os.path.join(od, pick_)):
        if f.lower().endswith(".pup"): shutil.copy(os.path.join(od, pick_, f), os.path.join(pack_dir, f))
    return pick_

def meta_from_name(name):
    m = re.search(r"\(([^()]*?)\s+((?:19|20)\d\d)\)", name)
    maker, year = (m.group(1).strip(), m.group(2)) if m else ("", "")
    if maker.lower() in ("original", "vpx original"): maker = "Original"
    short = re.sub(r"\s*\([^)]*\)\s*$", "", name).strip() or name
    return short, maker, year

def xml(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&apos;").replace('"', "&quot;")

def gamelist_entry(fname, name, notes):
    short, maker, year = meta_from_name(name)
    desc = f"{short} - {maker + ' ' if maker and maker != 'Original' else ''}{year + ' ' if year else ''}pinball table for Visual Pinball X."
    if maker == "Original": desc = f"{short} - original Visual Pinball table{' (' + year + ')' if year else ''}."
    if notes: desc += " " + " ".join(notes)
    e = [f"\t<game>", f"\t\t<path>./{xml(fname)}</path>", f"\t\t<name>{xml(short)}</name>", f"\t\t<desc>{xml(desc)}</desc>"]
    if year: e.append(f"\t\t<releasedate>{year}0101T000000</releasedate>")
    if maker: e += [f"\t\t<developer>{xml(maker)}</developer>", f"\t\t<publisher>{xml(maker)}</publisher>"]
    e += ["\t\t<genre>Pinball</genre>", "\t</game>"]
    return fname, "\n".join(e) + "\n"

def write_gamelist(entries):
    os.makedirs(os.path.dirname(GL), exist_ok=True)
    t = open(GL, encoding="utf-8").read() if os.path.exists(GL) else '<?xml version="1.0"?>\n<gameList>\n</gameList>\n'
    for fname, block in entries:
        t = re.sub(r"\t<game>\n\t\t<path>\./" + re.escape(xml(fname)) + r"</path>.*?</game>\n", "", t, flags=re.S)
        t = t.replace("</gameList>", block + "</gameList>")
    open(GL, "w", encoding="utf-8").write(t)

def esde_running(): return subprocess.run(["pgrep", "-x", "es-de"], stdout=subprocess.DEVNULL).returncode == 0

def game_running():
    pid = subprocess.run(["pgrep", "-x", "es-de"], capture_output=True, text=True).stdout.split()
    return bool(pid) and subprocess.run(["pgrep", "-P", pid[0]], stdout=subprocess.DEVNULL).returncode == 0

def restart_esde(entries):
    subprocess.run(["pkill", "-TERM", "-x", "es-de"])
    for _ in range(80):
        if not esde_running() and subprocess.run(["pgrep", "-f", "[r]eaper SteamLaunch AppId=3536773192"],
                                                 stdout=subprocess.DEVNULL).returncode != 0: break
        time.sleep(0.5)
    write_gamelist(entries)
    subprocess.Popen(["steam", "-ifrunning", f"steam://rungameid/{ESDE_ID}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def queue(entries):
    q = json.load(open(PENDING)) if os.path.exists(PENDING) else []
    q = [x for x in q if x[0] not in {e[0] for e in entries}] + entries
    json.dump(q, open(PENDING, "w"))

def apply_pending():
    if os.path.exists(PENDING) and not esde_running():
        write_gamelist([tuple(x) for x in json.load(open(PENDING))]); os.remove(PENDING)

def install(stage, name, refresh):
    for d in (V, f"{PM}/roms", f"{PM}/altcolor", f"{PM}/altsound", f"{V}/music", f"{V}/pupvideos",
              f"{MED}/covers", f"{MED}/screenshots", f"{MED}/marquees"):
        os.makedirs(d, exist_ok=True)
    items = scan(stage)
    pick = lambda pred: sorted([i for i in items if pred(i)], key=lambda i: -i.size)
    tables = pick(lambda i: i.low.endswith(".vpx"))
    if not tables: say("ERROR: no .vpx table file found in what was sent."); return 1
    notes, warn = [], []
    fname = f"{name}.vpx"
    open(f"{V}/{fname}", "wb").write(tables[0].read()); say(f"Table      -> {fname}")
    if len(tables) > 1: warn.append(f"several .vpx files were sent; used the biggest ({tables[0].base})")

    b2s = pick(lambda i: i.low.endswith(".directb2s"))
    if b2s:
        data = b2s[0].read(); open(f"{V}/{name}.directb2s", "wb").write(data); say(f"Backglass  -> {name}.directb2s")
        if backglass_art(data, name): say("Artwork    -> ES-DE picture from the backglass")
    else: warn.append("no backglass (.directb2s) was sent - the table still plays")

    text, rom = script_info(f"{V}/{fname}")
    say(f"ROM name   -> {rom or 'none (this table does not use a ROM)'}")
    # Score display: ROM tables get VPX's ScoreView (the DMD / score digits) drawn in the picture right under the
    # backglass, like a real cabinet, through a per-table settings file "<table>.ini" next to the table.
    ini = f"{V}/{name}.ini"
    import importlib.util         # backglass box + score display positions (see vpx-layout.py)
    spec = importlib.util.spec_from_file_location("vpx_layout", os.path.join(os.path.dirname(os.path.abspath(__file__)), "vpx-layout.py"))
    layout = importlib.util.module_from_spec(spec); spec.loader.exec_module(layout)
    pups = pup_files(items)
    b2s_path = f"{V}/{name}.directb2s"      # backglass files with their own score panel (Parent="DMD"), e.g. Primus
    b2s_scores = os.path.exists(b2s_path) and b'Parent="DMD"' in open(b2s_path, "rb").read()
    pup = bool(pups) or b2s_scores
    if rom or pup:   # DMD / score display (or a PuP pack's DMD) in its own box under the backglass; the table's own one is hidden, see dmd_fix
        layout.set_keys(ini, "ScoreView", {"ScoreViewOutput": 2})   # merged, keeps the table's other settings
        say("Scores     -> DMD / score display shown under the backglass")
    elif os.path.exists(ini) and "ScoreViewOutput = 2" in open(ini, errors="ignore").read():
        layout.set_keys(ini, "ScoreView", {"ScoreViewOutput": 0})   # left over from an older version of this table
    h = layout.layout_table(f"{V}/{name}.vpx")
    if h:
        w_ = re.search(r"^BackglassWidth\s*=\s*(\d+)", open(f"{V}/{name}.ini").read(), re.M)
        say(f"Layout     -> table on its own default view (unchanged); backglass {w_.group(1) if w_ else 800}x{h} + score display top-left, sized to stay clear of the table")

    roms = [i for i in items if getattr(i, "rom", False)]
    for r in {r.base.lower(): r for r in roms}.values():
        open(f"{PM}/roms/{r.base}", "wb").write(r.read()); say(f"ROM        -> pinmame/roms/{r.base}")
    if rom and not any(f.lower() == f"{rom.lower()}.zip" for f in os.listdir(f"{PM}/roms")):   # PinMAME matches ROM names case-insensitively
        warn.append(f"ROM {rom}.zip is missing - the table will not start until it is added")

    serum = pick(lambda i: i.low.endswith((".crz", ".cromc", ".crom")))
    if serum:
        pref = [s for s in serum if "gradient" in s.low] or serum
        s = pref[0]; r = os.path.splitext(s.base)[0]
        os.makedirs(f"{PM}/altcolor/{r}", exist_ok=True)
        open(f"{PM}/altcolor/{r}/{s.base}", "wb").write(s.read()); say(f"Colors     -> pinmame/altcolor/{r}/{s.base}")
        if len({x.name for x in serum}) > 1: say(f"             ({len(serum)} color versions were included; used {s.name})")
        notes.append("Colorized display.")
    if any(i.low.endswith(".pac") for i in items):
        warn.append("a .pac color pack was included - those only work on PIN2DMD display hardware, so it was skipped")
    vni = {os.path.splitext(i.low)[1]: i for i in items if i.low.endswith((".pal", ".vni"))}
    if vni and rom:
        os.makedirs(f"{PM}/altcolor/{rom}", exist_ok=True)
        for ext, i in vni.items(): open(f"{PM}/altcolor/{rom}/pin2dmd{ext}", "wb").write(i.read())
        say(f"Colors     -> pinmame/altcolor/{rom}/pin2dmd.pal/.vni"); notes.append("Colorized display.")

    music = [i for i in items if (i.low.endswith((".mp3", ".ogg")) or (i.low.endswith(".wav") and "/music/" in "/" + i.low.replace("\\", "/")))
             and "altsound" not in i.low and "pup" not in i.low]      # .wav only from a Music folder (Primus ships its songs as .wav)
    for i in music:
        parts = i.name.replace("\\", "/").split("/")
        sub = parts[[p.lower() for p in parts].index("music") + 1:-1] if "music" in [p.lower() for p in parts] else []
        dst = os.path.join(V, "music", *sub); os.makedirs(dst, exist_ok=True)
        open(os.path.join(dst, i.base), "wb").write(i.read())
    if music: say(f"Music      -> music/ ({len(music)} tracks)")

    alts = [i for i in items if "altsound" in i.low and not i.low.endswith(SKIP)]
    if alts and rom:
        for i in alts:
            rel = i.name.replace("\\", "/"); rel = rel[rel.lower().index("altsound") + len("altsound"):].lstrip("/")
            rel = rel.split("/", 1)[1] if rel.split("/", 1)[0].lower() == rom.lower() and "/" in rel else rel
            dst = os.path.join(PM, "altsound", rom, os.path.dirname(rel)); os.makedirs(dst, exist_ok=True)
            open(os.path.join(dst, os.path.basename(rel)), "wb").write(i.read())
        say(f"AltSound   -> pinmame/altsound/{rom}/ ({len(alts)} files)")
    for i, rel in pups:
        dst = os.path.join(V, "pupvideos", os.path.dirname(rel)); os.makedirs(dst, exist_ok=True)
        open(os.path.join(dst, os.path.basename(rel)), "wb").write(i.read())
    if pups:
        say(f"PuP pack   -> pupvideos/ ({len(pups)} files)")
        for pack in sorted({rel.split("/")[0] for _, rel in pups}):
            opt = pup_one_screen(os.path.join(V, "pupvideos", pack))
            if opt: say(f"PuP layout -> '{opt}' (videos + scores in the DMD box under the backglass, one TV)")
        shot_ = f"{MED}/screenshots/{name}.png"
        if not os.path.exists(f"{V}/{name}.directb2s") and not os.path.exists(shot_):
            # no backglass file: the ES-DE backbox picture is a still frame of the PuP pack's backglass video
            vids = [os.path.join(r, f) for pack in {rel.split("/")[0] for _, rel in pups}
                    for r, _, fs in os.walk(os.path.join(V, "pupvideos", pack)) for f in fs
                    if f.lower().endswith(".mp4") and "backglass" in (r + "/" + f).lower()]
            vids.sort(key=lambda f: (os.path.basename(f).lower() != "backglass.mp4", -os.path.getsize(f)))
            for vid in vids[:1]:
                tmp_ = f"{H}/.cache/vpxadd-bgframe.png"
                subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "6", "-i", vid, "-frames:v", "1", tmp_])
                if os.path.exists(tmp_):
                    from PIL import Image
                    Image.open(tmp_).convert("RGB").resize((1280, 720)).save(shot_); os.remove(tmp_)
                    say("Artwork    -> ES-DE picture from the PuP backglass video")

    user_vbs = pick(lambda i: i.low.endswith(".vbs") and "pupvideos" not in i.low)
    sidecar = f"{V}/{name}.vbs"
    base_text = user_vbs[0].read().decode("latin-1") if user_vbs else text
    fixed, n = linux_fix(base_text)
    out = fixed or base_text
    if n: say(f"Linux fix  -> applied ({n} ROM light/switch checks fixed)")
    out, synced = early_williams_fix(out)
    if synced: say("Sound fix  -> early Williams sound board: PinMAME runs unsynced so its effects play")
    hid = False
    if rom: out, hid = dmd_fix(out)
    if user_vbs: say(f"Script     -> using the included {user_vbs[0].base}")
    tfx = layout.table_fixes(name); fixes_hide = tfx.get("hide") or tfx.get("vbs") or tfx.get("replace")
    if user_vbs or n or synced or hid or fixes_hide:
        open(sidecar, "w", encoding="latin-1").write(out)
        if fixes_hide:      # objects this table must not draw on the TV (e.g. a desktop backbox), see vpx-tablefix.py
            tf = importlib.util.spec_from_file_location("vpx_tablefix", os.path.join(os.path.dirname(os.path.abspath(__file__)), "vpx-tablefix.py"))
            tfm = importlib.util.module_from_spec(tf); tf.loader.exec_module(tfm); tfm.apply_hide(name, tfx.get("hide", []), tfx.get("vbs", []), tfx.get("replace", []))
            say(f"Table fix  -> TV fixes from vpx-table-fixes.json re-applied ({tfx.get('note', 'see file')})")
    elif os.path.exists(sidecar):
        os.remove(sidecar)

    wheels = [i for i in items if i.low.endswith(IMG) and "pupvideos" not in i.low and "altcolor" not in i.low]
    wheels.sort(key=lambda i: (not any(k in i.low for k in ("wheel", "logo")), -i.size))
    if matched_wheel(name):
        say("Wheel      -> ES-DE marquee (matching chrome-ring wheel from the VPX Media Database)")
    elif wheels:
        tmp = f"{H}/.cache/vpxadd-wheel{os.path.splitext(wheels[0].base)[1]}"
        open(tmp, "wb").write(wheels[0].read())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-frames:v", "1", "-update", "1", f"{MED}/marquees/{name}.png"])
        os.remove(tmp); say("Wheel      -> ES-DE marquee")

    entry = [gamelist_entry(fname, name, sorted(set(notes)))]
    if not esde_running():
        write_gamelist(entry); say("ES-DE      -> added to the Pinball list")
    elif refresh and not game_running():
        say("ES-DE      -> restarting ES-DE so the table shows up now...")
        restart_esde(entry)
    else:
        queue(entry)
        say("ES-DE      -> a game is running, so the table will appear the next time ES-DE starts")
    for w in warn: say(f"NOTE: {w}")
    say("DONE")
    return 0

if __name__ == "__main__":
    if sys.argv[1:] == ["--apply-pending"]:
        apply_pending(); sys.exit(0)
    stage, name = sys.argv[1], base64.b64decode(sys.argv[2]).decode("utf-8").strip()
    name = re.sub(r'[\\/:*?"<>|]', "", name)
    rc = install(stage, name, "--refresh" in sys.argv)
    shutil.rmtree(stage, ignore_errors=True)
    sys.exit(rc)
