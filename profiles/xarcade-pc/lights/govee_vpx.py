#!/usr/bin/env python3
"""Govee Glide (H610A) cabinet lighting for Visual Pinball X + arcade on Bazzite.

Modes (switches automatically):
  play    VPX is running. Colors come from the table's backglass art.
          - DOF (via libdof's ArtNet output on 127.0.0.1) drives table-scripted
            flashers / strobe / beacon / undercab, when a DOF config exists
          - audio reacts on top: HDMI (music, callouts, SFX) and the
            "pinball_playfield" sink (mechanical thumps that feed the haptics)
  arcade  An arcade game launched from ES-DE is running (game-start/game-end
          hooks). Colors come from its marquee; reacts to game audio and flashes
          on X-Arcade button presses (P1 left half, P2 right half)
  attract Browsing vpinball or an arcade system in ES-DE: slow breathing glow in
          the selected game's colors (needs ES-DE "browsing custom events")
  idle    Anything else: hand the lights to Govee's own music mode (its mic)

  python3 govee_vpx.py [--dim 0.6] [--idle music|off|keep] [--debug]
  python3 govee_vpx.py --lights wled --wled-ip 192.168.0.xxx [--leds 240] [--offset 0.0] [--reverse]
                                   drive a WLED strip (Dig2go on the back of the TV) instead of the Govee bar
  python3 govee_vpx.py --force     play mode now, VPX or not (testing)
"""
import argparse
import json
import zlib
import colorsys
import math
import os
import random
import select
import signal
import socket
import struct
import subprocess
import threading
import time

import numpy as np

from b2s_palette import ARCADE_SYSTEMS, DEFAULT, game_palette, palette_for, steam_palette
from govee import Govee
from wled import Wled

IP = os.environ.get("GOVEE_IP", "")        # only used by the old Govee driver; WLED uses --wled-ip
N = 10
RATE = 48000
BLOCK = 512
FPS = 40
SFX_SINK = "pinball_playfield"
STATE_DIR = os.path.expanduser("~/govee/state")
ATTRACT_TIMEOUT = 15 * 60            # stop attract glow if nobody touches ES-DE for 15 min
DEBUG = False

# DOF port layout (LedWiz #1 in the DOF Config Tool == ArtNet DMX channels 1..26)
DOF = {
    "undercab": (1, 2, 3),
    "flashers": [(4, 5, 6), (7, 8, 9), (10, 11, 12), (13, 14, 15), (16, 17, 18)],   # OL, L, C, R, OR
    "strobe": 19,
    "beacon": 20,
    "flippers": (21, 22, 23),
    "knocker": 24,
    "shaker": 25,
}


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


# ----------------------------------------------------------------- inputs

def vpx_table():
    """(running, table_name or None) from VPinballX's command line."""
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/comm") as f:
                if not f.read().startswith("VPinballX"):
                    continue
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read().split(b"\0")
        except OSError:
            continue
        for a in args:
            if a.lower().endswith(b".vpx"):
                return True, os.path.basename(a.decode(errors="replace"))[:-4]
        return True, None
    return False, None


def es_selection():
    """What ES-DE has selected, written by our ES-DE event scripts."""
    try:
        path = os.path.join(STATE_DIR, "selected")
        age = time.time() - os.path.getmtime(path)
        with open(path) as f:
            system, game = (f.read().split("\n") + ["", ""])[:2]
        flag = os.path.join(STATE_DIR, "screensaver")
        # a screensaver flag only counts if no selection happened after it (ES-DE can be closed mid-screensaver
        # without sending screensaver-end, which would otherwise leave the flag stuck)
        saver = os.path.exists(flag) and os.path.getmtime(flag) > os.path.getmtime(path)
        return system.strip(), game.strip(), age, saver
    except OSError:
        return "", "", 1e9, False


def es_playing():
    """(system, rom) of the game ES-DE launched, from the game-start/game-end hooks."""
    path = os.path.join(STATE_DIR, "playing")
    try:
        if time.time() - os.path.getmtime(path) > 6 * 3600:      # stale (ES-DE killed mid-game)
            os.remove(path)
            return None
        with open(path) as f:
            system, rom = (f.read().split("\n") + ["", ""])[:2]
        return system.strip(), rom.strip()
    except OSError:
        return None


STEAM_APPS = os.path.expanduser("~/.local/share/Steam/steamapps")


def steam_game():
    """(appid, name) of a running Steam game, from Steam's 'reaper SteamLaunch AppId=N' wrapper.

    Non-Steam shortcuts (ES-DE itself, emulators) have AppIds >= 2^31 and are ignored."""
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read().split(b"\0")
        except OSError:
            continue
        if b"SteamLaunch" not in args:
            continue
        for a in args:
            if a.startswith(b"AppId="):
                appid = int(a[6:] or 0)
                if 0 < appid < 2 ** 31:
                    name = str(appid)
                    try:
                        with open(os.path.join(STEAM_APPS, f"appmanifest_{appid}.acf")) as m:
                            for line in m:
                                if line.strip().startswith('"name"'):
                                    name = line.split('"')[3]
                                    break
                    except OSError:
                        pass
                    return appid, name
    return None


RHYTHM = (("YARG Installs", "YARG"), ("clonehero", "Clone Hero"), ("CloneHero", "Clone Hero"),
          ("GHWT", "Guitar Hero World Tour"))
FRET_COLORS = ["#00d000", "#ff1010", "#ffd000", "#1060ff", "#ff7000"]      # green red yellow blue orange
PS_FRETS = {304: 0, 305: 1, 307: 2, 308: 3, 310: 4}      # PlayStation-mode guitar (hid-sony): X O triangle square L1
XBOX_FRETS = {304: 0, 305: 1, 308: 2, 307: 3, 310: 4}    # Xbox 360 guitar (xpad): A B Y X LB


class SACN(threading.Thread):
    """YARG's DMX output (sACN / E1.31, universe 1): its Rock Band stage-kit light show.
    Per fixture k (8 of them, 8 channels apart): dimmer, red, green, blue, yellow, fog, strobe."""
    PORT = 5568

    def __init__(self, universe=1):
        super().__init__(daemon=True)
        self.alive = True
        self.last = 0.0
        self.data = bytes(512)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(("", self.PORT))
        grp = socket.inet_aton(f"239.255.{universe >> 8}.{universe & 255}")
        try:
            self.sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, grp + socket.inet_aton("0.0.0.0"))
        except OSError:
            pass
        self.sock.settimeout(0.5)

    def run(self):
        while self.alive:
            try:
                pkt = self.sock.recv(1024)
            except OSError:
                continue
            if len(pkt) > 126 and pkt[4:16] == b"ASC-E1.17\0\0\0" and pkt[125] == 0:
                self.data = pkt[126:] + bytes(512)
                self.last = time.time()

    def live(self):
        return time.time() - self.last < 2

    def ch(self, c):                      # 1-based DMX channel -> 0..1
        return self.data[c - 1] / 255.0

    def fixtures(self):
        """8 colors (r,g,b) and a strobe level from the stage kit."""
        cols, strobe = [], 0.0
        for k in range(8):
            b = 8 * k
            dim = self.ch(b + 1) or 1.0
            r, g, bl, y = self.ch(b + 2), self.ch(b + 3), self.ch(b + 4), self.ch(b + 5)
            cols.append(np.clip(np.array([255 * (r + y), 255 * (g + 0.8 * y), 255 * bl]) * dim, 0, 255))
            strobe = max(strobe, self.ch(b + 7))
        return cols, strobe

    def stop(self):
        self.alive = False
        try:
            self.sock.close()
        except OSError:
            pass


class Screen(threading.Thread):
    """Low-res copy of what Game Mode shows (gamescope's PipeWire video node), for ambilight colors."""
    W, H = 48, 27

    def __init__(self):
        super().__init__(daemon=True)
        self.alive = True
        self.frame = None
        self.last = 0.0
        self.proc = None

    @staticmethod
    def node():
        try:
            dump = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5).stdout)
        except Exception:
            return None
        ids = [(int(o["info"]["props"].get("object.serial", 1 << 30)), o["id"]) for o in dump
               if o.get("info", {}).get("props", {}).get("node.name") == "gamescope"]
        return min(ids)[1] if ids else None          # the session's own node is the oldest

    def run(self):
        while self.alive:
            n = self.node()
            if n is None:
                time.sleep(3)
                continue
            cmd = ["gst-launch-1.0", "-q", "pipewiresrc", f"path={n}", "keepalive-time=150", "!", "videoconvert", "!", "videoscale", "!",
                   f"video/x-raw,format=RGB,width={self.W},height={self.H}", "!",
                   "fdsink", "fd=1"]
            self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            size = self.W * self.H * 3
            buf = b""
            while self.alive:
                chunk = self.proc.stdout.read(size - len(buf))
                if not chunk:
                    break
                buf += chunk
                if len(buf) == size:
                    self.frame = np.frombuffer(buf, np.uint8).reshape(self.H, self.W, 3).astype(float)
                    self.last = time.time()
                    buf = b""
            self.proc.kill()
            time.sleep(1)

    def live(self):
        return time.time() - self.last < 2

    def stop(self):
        self.alive = False
        if self.proc:
            self.proc.kill()


def strip_points(n):
    """(x, y) in 0..1 of each LED in the physical landscape frame. The strip starts bottom-middle-left, runs left,
    up the left side, across the top, down the right side and ends bottom-middle-right."""
    legs = [((0.47, 1), (0, 1), 29), ((0, 1), (0, 0), 34), ((0, 0), (1, 0), 58), ((1, 0), (1, 1), 34), ((1, 1), (0.53, 1), 19)]
    tot = sum(l[2] for l in legs)
    pts = []
    for (x0, y0), (x1, y1), k in legs:
        m = round(k * n / tot)
        pts += [(x0 + (x1 - x0) * (j + 0.5) / m, y0 + (y1 - y0) * (j + 0.5) / m) for j in range(m)]
    return (pts + [pts[-1]] * n)[:n]


def portrait_dir():
    try:
        st = json.load(open(os.path.expanduser("~/Emulation/tools/portrait/state.json")))
        if st.get("mode") != "portrait":
            return None
        return open(os.path.expanduser("~/Emulation/tools/portrait/direction")).read().strip() or "left"
    except Exception:
        return None


def ambi_pixels(frame, n, pts, rot):
    """Average a small patch just inside the screen edge nearest each LED."""
    h, w, _ = frame.shape
    out = np.zeros((n, 3))
    for i, (x, y) in enumerate(pts):
        if rot == "left":                    # TV turned so the physical left edge is the top of the picture
            x, y = 1 - y, x
        elif rot == "right":
            x, y = y, 1 - x
        cx = min(w - 1, int(x * w)); cy = min(h - 1, int(y * h))
        x0, x1 = max(0, cx - 3), min(w, cx + 4)
        y0, y1 = max(0, cy - 3), min(h, cy + 4)
        out[i] = frame[y0:y1, x0:x1].reshape(-1, 3).mean(0)
    v = out.max(1, keepdims=True)                 # richer color: push saturation, drop near-black
    out = np.clip((out - out.min(1, keepdims=True) * 0.35) * 1.25, 0, 255)
    return out * (v > 12)


def wants_ambi(steam=None, console=None):
    """Hand-picked colors win; everything else follows the screen."""
    if console:
        return True
    if steam:
        try:
            ov = json.load(open(os.path.expanduser("~/govee/table_colors.json"), encoding="utf-8"))
        except Exception:
            ov = {}
        return f"steam/{steam[0]}" not in ov and steam[1] not in ov
    return False


def rhythm_game():
    """Name of a running rhythm game (YARG, Clone Hero, GH World Tour); they are non-Steam shortcuts."""
    me = str(os.getpid())
    for pid in os.listdir("/proc"):
        if not pid.isdigit() or pid == me:
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read()
        except OSError:
            continue
        if b"SteamLaunch" in args or b"fretcap" in args:
            continue
        for key, name in RHYTHM:
            if key.encode() in args:
                return name
    return None


class Buttons(threading.Thread):
    """Reads X-Arcade / gamepad button presses straight from evdev."""

    EV_KEY = 1
    FMT = "llHHi"                     # struct input_event on 64-bit
    SIZE = struct.calcsize(FMT)
    SKIP = ("keyboard", "steamos-manager", "power", "video bus", "hd-audio", "pc speaker", "sleep", "lid")

    def __init__(self, only=None):
        super().__init__(daemon=True)
        self.lock = threading.Lock()
        self.pending = []             # (player, code); guitars: 1000+fret, 2000 = strum
        self.alive = True
        self.fds = {}
        self.only = only
        self.frets = {}
        for h in sorted(os.listdir("/sys/class/input"), key=lambda s: int(s[5:]) if s[5:].isdigit() else 0):
            if not h.startswith("event"):
                continue
            try:
                with open(f"/sys/class/input/{h}/device/name") as f:
                    name = f.read().strip()
            except OSError:
                continue
            if any(s in name.lower() for s in self.SKIP):
                continue
            if only and not any(k in name.lower() for k in (only, "crkd")):
                continue
            try:
                fd = os.open(f"/dev/input/{h}", os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                continue
            # X-Arcade shows up as two X-Box 360 pads: those are P1/P2 in order;
            # anything else (trackball, encoder) counts as P1
            pads = sum(1 for p, n in self.fds.values() if "x-box 360 pad" in n.lower())
            player = pads if "x-box 360 pad" in name.lower() else 0
            if only:
                player = len(self.fds)
                self.frets[fd] = PS_FRETS if "sony" in name.lower() or "playstation" in name.lower() else XBOX_FRETS
            self.fds[fd] = (player, name)
        if self.fds:
            log("buttons:", ", ".join(f"P{p + 1}={n}" for p, n in self.fds.values()))

    def run(self):
        while self.alive and self.fds:
            r, _, _ = select.select(list(self.fds), [], [], 0.5)
            for fd in r:
                try:
                    data = os.read(fd, self.SIZE * 32)
                except OSError:
                    continue
                for i in range(0, len(data) - self.SIZE + 1, self.SIZE):
                    _, _, typ, code, value = struct.unpack_from(self.FMT, data, i)
                    if typ == self.EV_KEY and value == 1:
                        if fd in self.frets:
                            code = 1000 + self.frets[fd][code] if code in self.frets[fd] else code
                        with self.lock:
                            self.pending.append((self.fds[fd][0], code))
                    elif typ == 3 and code == 17 and value != 0 and fd in self.frets:      # strum bar (hat Y)
                        with self.lock:
                            self.pending.append((self.fds[fd][0], 2000))

    def take(self):
        with self.lock:
            p, self.pending = self.pending, []
        return p

    def stop(self):
        self.alive = False
        for fd in self.fds:
            try:
                os.close(fd)
            except OSError:
                pass


def default_sink():
    return subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True).stdout.strip()


class Capture(threading.Thread):
    """Reads a sink's monitor via parec; queues per-band energies per block."""

    BANDS = {"low": (30, 180), "mid": (180, 3000), "high": (3000, 12000)}

    def __init__(self, sink):
        super().__init__(daemon=True)
        self.sink = sink
        self.lock = threading.Lock()
        self.pending = []
        self.proc = None
        self.alive = True
        self.blocks = 0
        freqs = np.fft.rfftfreq(BLOCK, 1 / RATE)
        self.masks = {k: (freqs >= lo) & (freqs < hi) for k, (lo, hi) in self.BANDS.items()}
        self.win = np.hanning(BLOCK)

    def run(self):
        cmd = ["parec", "-d", f"{self.sink}.monitor", "--format=float32le", "--channels=1",
               f"--rate={RATE}", "--raw", "--latency-msec=10"]
        self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        nbytes = BLOCK * 4
        while self.alive:
            buf = self.proc.stdout.read(nbytes)
            if not buf or len(buf) < nbytes:
                if self.alive:
                    err = self.proc.stderr.read().decode(errors="replace").strip()
                    log(f"capture of {self.sink} ended: {err or 'no output'}")
                break
            self.blocks += 1
            x = np.frombuffer(buf, dtype=np.float32)
            spec = np.abs(np.fft.rfft(x * self.win))
            e = {k: float(spec[m].mean()) for k, m in self.masks.items()}
            e["rms"] = float(np.sqrt((x ** 2).mean()))
            with self.lock:
                self.pending.append(e)
                if len(self.pending) > 64:
                    self.pending = self.pending[-64:]

    def take(self):
        with self.lock:
            p, self.pending = self.pending, []
        return p

    def stop(self):
        self.alive = False
        if self.proc:
            self.proc.terminate()


class ArtNetIn(threading.Thread):
    """Receives libdof's ArtNet DMX (universe 0) on UDP 6454."""

    def __init__(self):
        super().__init__(daemon=True)
        self.dmx = np.zeros(513, dtype=np.float32)     # 1-based channels
        self.last = 0.0
        self.packets = 0
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(("0.0.0.0", 6454))

    def run(self):
        while True:
            pkt, _ = self.sock.recvfrom(1024)
            if pkt[:8] != b"Art-Net\0" or pkt[8:10] != b"\x00\x50":     # OpDmx 0x5000, little endian
                continue
            if pkt[14] | (pkt[15] << 8):                                # only universe 0
                continue
            n = (pkt[16] << 8) | pkt[17]
            data = np.frombuffer(pkt[18:18 + n], dtype=np.uint8)
            self.dmx[1:1 + len(data)] = data / 255.0
            self.packets += 1
            if data.any():
                self.last = time.time()

    def ch(self, c):
        return float(self.dmx[c])

    def rgb(self, chans):
        return self.dmx[list(chans)] * 255


class Onset:
    """Energy jump vs. running average, with auto-gain and a refractory period."""

    def __init__(self, ratio, refractory):
        self.avg = None
        self.peak = 1e-6
        self.ratio = ratio
        self.refractory = refractory
        self.next_ok = 0.0

    def __call__(self, e, now):
        if self.avg is None:
            self.avg = e
        r = e / (self.avg + 1e-9)
        self.avg = self.avg * 0.9 + e * 0.1
        self.peak = max(e, self.peak * 0.9995)
        if r > self.ratio and e > self.peak * 0.12 and now >= self.next_ok:
            self.next_ok = now + self.refractory
            return min(1.0, 0.35 + 0.65 * e / self.peak)
        return 0.0


# Per-system attract colors for ES-DE browsing (any system not listed gets a stable color from its name).
SYSTEM_COLORS = {
    "nes": ["#e60012", "#b0b0b0", "#202020"], "famicom": ["#e60012", "#f0f0f0", "#b0b0b0"],
    "snes": ["#7a3fff", "#c8c8ff", "#e60012", "#3dbb3d"], "sfc": ["#7a3fff", "#c8c8ff", "#e60012", "#3dbb3d"],
    "n64": ["#e60012", "#00a040", "#2a6bff", "#ffd23f"], "gc": ["#6a4dff", "#b9a8ff", "#ffffff"],
    "wii": ["#00b4ff", "#e8f6ff", "#7ad6ff"], "wiiu": ["#00b4ff", "#ffffff"], "switch": ["#e60012", "#00c3e3"],
    "nds": ["#c8c8d0", "#2a6bff", "#ff4a8a"], "n3ds": ["#e60012", "#ffffff", "#ff8a1a"],
    "gb": ["#9bbc0f", "#8bac0f", "#306230"], "gbc": ["#9a3fff", "#3dd6c8", "#ff4a8a"], "gba": ["#5a3fff", "#c8b8ff", "#ff8a1a"],
    "genesis": ["#1a6bff", "#e8e8e8", "#101820"], "megadrive": ["#1a6bff", "#e8e8e8", "#101820"], "mastersystem": ["#e60012", "#1a1a1a", "#ffffff"],
    "segacd": ["#1a6bff", "#c8c8c8"], "sega32x": ["#ff6a1a", "#1a6bff"], "gamegear": ["#1a1a1a", "#1a6bff", "#e60012"],
    "saturn": ["#2a4bff", "#c8c8d8", "#101030"], "dreamcast": ["#ff6a1a", "#ffffff", "#2a6bff"],
    "psx": ["#c8c8d8", "#2a6bff", "#e60012", "#3dbb3d", "#ffd23f"], "ps2": ["#2a4bff", "#101030", "#7a9bff"],
    "ps3": ["#1a1a1a", "#c8c8d8", "#2a6bff"], "psp": ["#1a1a1a", "#2a6bff", "#c8c8d8"],
    "xbox": ["#3dbb3d", "#101810"], "xbox360": ["#7ad63d", "#e8e8e8"],
    "atari2600": ["#ff8a1a", "#5a3a1a", "#1a1a1a"], "atari5200": ["#ff8a1a", "#1a1a1a"], "atari7800": ["#ff4a1a", "#1a1a1a", "#c8c8c8"],
    "atarilynx": ["#ffd23f", "#1a1a1a"], "atarijaguar": ["#e60012", "#1a1a1a", "#ffffff"],
    "amiga": ["#e60012", "#ffffff", "#2a6bff"], "c64": ["#4a4aff", "#8a8aff", "#c8c8ff"], "dos": ["#3dff3d", "#ffb000", "#101010"],
    "pcengine": ["#ff8a1a", "#e8e8e8", "#1a1a1a"], "tg16": ["#ff8a1a", "#e8e8e8"], "neogeo": ["#ffc61f", "#e60012", "#2a6bff"],
    "neogeocd": ["#ffc61f", "#e60012", "#2a6bff"], "ngp": ["#1a1a1a", "#e60012", "#ffffff"],
    "steam": ["#1a9fff", "#c7d5e0", "#2a475e"], "scummvm": ["#ffb000", "#6a3a1a", "#3dbb3d"], "pico8": ["#ff004d", "#29adff", "#00e436", "#ffec27"],
    "naomi": ["#e60012", "#f0f0f0", "#2a2a2a"], "naomi2": ["#e60012", "#f0f0f0", "#2a2a2a"], "naomigd": ["#e60012", "#f0f0f0", "#2a2a2a"],
    "atomiswave": ["#2a8cff", "#ff8a1a", "#f0f0f0"], "model2": ["#2a6bff", "#e60012"], "model3": ["#2a6bff", "#e60012", "#f0f0f0"],
    "cps1": ["#e60012", "#ffd23f", "#2a6bff"], "cps2": ["#e60012", "#ffd23f", "#2a6bff"], "cps3": ["#e60012", "#ffd23f", "#2a6bff"],
}


def system_palette(system):
    """Colors for browsing a system in ES-DE: a hand-picked set, else a stable color derived from the name."""
    def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
    cols = SYSTEM_COLORS.get(system)
    if cols:
        return [rgb(c) for c in cols]
    h = (zlib.crc32(system.encode()) % 360) / 360.0
    return [tuple(int(255 * v) for v in colorsys.hsv_to_rgb((h + d) % 1, 0.85, 1.0)) for d in (0.0, 0.08, 0.55)]


# ----------------------------------------------------------------- looks

def _hex(h, default):
    try: return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)
    except Exception: return np.array(default, dtype=float)


def load_extras(table):
    """Per-table flash colors from ~/govee/table_extras.json: {"strobe": "#rrggbb", "beacon": "#rrggbb"}."""
    try:
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "table_extras.json")) as f:
            return json.load(f).get(table, {})
    except (OSError, ValueError):
        return {}


def pal_at(palette, x):
    """Smoothly interpolate around a palette, x in [0, 1)."""
    x = (x % 1) * len(palette)
    i = int(x)
    a, b = np.array(palette[i]), np.array(palette[(i + 1) % len(palette)])
    return a + (b - a) * (x - i)


def show_pixels(pal, style, now):
    """Six attract looks in a palette, one value per segment (N x 3, 0..255). Styles 0-2 are the original three."""
    n = len(pal)
    out = np.zeros((N, 3))
    for i in range(N):
        x = i / N
        if style == 0:                                         # flowing gradient + one comet
            p = (now * 0.65) % 1
            w = max(0.0, 1 - abs(((x - p + 0.5) % 1) - 0.5) / 0.14)
            out[i] = pal_at(pal, now * 0.09 + x) * 0.45 + pal_at(pal, p) * w * 0.85
        elif style == 1:                                       # two comets, opposite directions
            p1, p2 = (now * 0.55) % 1, (1 - now * 0.4) % 1
            w1 = max(0.0, 1 - abs(((x - p1 + 0.5) % 1) - 0.5) / 0.12)
            w2 = max(0.0, 1 - abs(((x - p2 + 0.5) % 1) - 0.5) / 0.12)
            out[i] = pal_at(pal, 0.0) * 0.2 + np.array(pal[0]) * w1 * 0.9 + np.array(pal[1 % n]) * w2 * 0.9
        elif style == 2:                                       # marquee chase of palette colors
            v = 0.5 + 0.5 * math.sin(now * 5.4 - i * 0.8)
            out[i] = np.array(pal[i % n]) * (0.15 + 0.7 * v * v)
        elif style == 3:                                       # aurora: two slow waves of color and light
            w1 = 0.5 + 0.5 * math.sin(now * 0.9 + x * 6.283)
            w2 = 0.5 + 0.5 * math.sin(now * 0.55 - x * 10.7 + 1.3)
            out[i] = pal_at(pal, w1 * 0.7 + now * 0.03) * (0.22 + 0.6 * w2)
        elif style == 4:                                       # twinkle: segments flare up one by one
            tw = max(0.0, math.sin(now * (1.6 + (i % 3) * 0.7) + i * 2.1)) ** 5
            out[i] = pal_at(pal, i / N) * 0.16 + pal_at(pal, (i * 0.37 + int(now * 0.6) * 0.21) % 1) * tw
        else:                                                  # scanner: one light sweeping back and forth
            pos = 0.5 + 0.5 * math.sin(now * 1.7)
            w = max(0.0, 1 - abs(x - pos * (N - 1) / N) / 0.17) ** 1.5
            out[i] = pal_at(pal, 0.0) * 0.12 + pal_at(pal, pos) * w
    return np.clip(out, 0, 255)


LED_COUNT = 174          # set from --leds at start-up
SHOW_COUNT = 10          # looks 0-5 are per-zone, 6-9 are per-LED


def pal_vec(pal, x):
    """Vectorised palette lookup, x an array in any range (wraps around the palette)."""
    cols = np.array(pal, float)
    n = len(cols)
    x = (np.asarray(x, float) % 1.0) * n
    i0 = np.floor(x).astype(int)
    f = (x - i0)[:, None]
    return cols[i0 % n] * (1 - f) + cols[(i0 + 1) % n] * f


def fullres_show(pal, style, now, n):
    """Per-LED looks, (n, 3) floats 0..255: 6 meteor rain, 7 plasma, 8 fire."""
    i = np.arange(n, dtype=float)
    theta = 2 * math.pi * i / n
    out = np.zeros((n, 3))
    if style == 6:                                             # meteors with fading tails, circling the ring
        for k, (speed, direction) in enumerate(((0.11, 1), (0.17, -1), (0.07, 1))):
            head = (direction * now * speed) % 1.0 * n
            d = ((head - i) * direction) % n                   # distance behind the head
            tail = n * 0.16
            val = np.where(d < tail * 1.8, np.exp(-d / (tail * 0.45)), 0.0)
            val = np.where(d < 2.0, 1.0, val)
            col = pal_vec(pal, np.array([k / 3.0 + now * 0.03]))[0]
            out += col[None, :] * val[:, None]
        out += pal_vec(pal, i / n) * 0.05
    elif style == 7:                                           # plasma: slow morphing colour fields
        v = (np.sin(2 * theta + now * 0.9) + np.sin(3 * theta - now * 0.6 + 1.0)
             + 0.6 * np.sin(5 * theta + now * 1.3 + 2.0))
        norm = (v + 2.6) / 5.2
        light = 0.35 + 0.55 * (0.5 + 0.5 * np.sin(norm * 2 * math.pi + now * 0.8))
        out = pal_vec(pal, norm + now * 0.03) * light[:, None]
    elif style == 9:                                           # rain: drops land at random spots and ripple outward
        for slot in range(8):
            period = 3.2
            t = now + slot * 0.41
            cycle = int(t // period)
            age = t % period
            pos = ((math.sin(cycle * 12.9898 + slot * 78.233) * 43758.5453) % 1.0) * n
            dist = np.abs(((i - pos + n / 2) % n) - n / 2)          # circular distance to the drop
            radius = age * 16.0
            ring = np.exp(-(((dist - radius) / 2.6) ** 2)) * max(0.0, 1.0 - age / period * 1.15)
            splash = np.exp(-dist / 1.6) * math.exp(-age * 7.0)
            col = pal_vec(pal, np.array([((cycle + slot) % 7) / 7.0]))[0]
            out += col[None, :] * (ring * 0.85 + splash)[:, None]
        out += pal_vec(pal, i / n + now * 0.01) * 0.04
    else:                                                      # fire: flickering heat run through the palette
        h1 = 0.5 + 0.5 * np.sin(i * 0.55 + now * 5.1 + 1.7 * np.sin(i * 0.13 + now * 1.9))
        h2 = 0.5 + 0.5 * np.sin(i * 1.37 - now * 7.3 + 0.9 * np.sin(i * 0.21 + now * 2.7))
        env = 0.55 + 0.45 * np.sin(theta * 3 + now * 0.4)
        heat = np.clip((0.55 * h1 + 0.45 * h2) * env * 1.25 - 0.12, 0.0, 1.0)
        c1 = np.array(pal[0], float)
        c2 = np.array(pal[1 % len(pal)], float)
        hot = c2 + (255 - c2) * 0.5
        xs = [0.0, 0.4, 0.75, 1.0]
        for ch in range(3):
            out[:, ch] = np.interp(heat, xs, [0.0, c1[ch], c2[ch], hot[ch]])
    return np.clip(out, 0, 255)


class PinballLights:
    def __init__(self, palette, dim, seed=0, extras=None):
        self.pal = palette
        self.dim = dim
        extras = extras or {}
        self.strobe_col = _hex(extras.get("strobe", "#ffffff"), (255, 255, 255))
        self.beacon_col = _hex(extras.get("beacon", "#ff3c00"), (255, 60, 0))
        self.style = seed % SHOW_COUNT  # attract-show style, fixed per table
        self.quiet = 0.0               # 0..1, how far into the quiet attract show we are
        self.quiet_since = None
        self.layer = np.zeros((N, 3))
        self.strobe = 0.0
        self.sparkle = np.zeros(N)
        self.glow = 0.0
        self.drift = random.random()
        self.accent = random.randrange(len(palette))
        self.hits = []
        self.mech = Onset(2.4, 0.06)
        self.big = Onset(3.5, 0.3)
        self.mid = Onset(2.2, 0.09)
        self.high = Onset(2.6, 0.08)
        self.music_peak = 1e-6
        self.dof = None
        self.stage = None                 # SACN receiver in rhythm mode
        self.beacon_phase = 0.0

    def hit(self, now, h):
        self.hits.append(now)
        c = random.randrange(N)
        spread = 1 + int(h * 3)
        col = np.array(self.pal[self.accent])
        for i in range(N):
            d = abs(i - c)
            if d <= spread:
                self.layer[i] = np.maximum(self.layer[i], col * h * (1 - d / (spread + 1.5)))

    def feed_mech(self, e, now):
        h = self.mech(e["low"] + 0.5 * e["mid"], now)
        if h:
            self.hit(now, max(h, 0.6))

    def feed_button(self, player, code, now):
        """X-Arcade press: P1 lights the left half, P2 the right; each button its own spot/color."""
        self.hits.append(now)
        if code >= 2000:                                 # guitar strum: quick white-gold sparkle
            for i in random.sample(range(N), 3):
                self.sparkle[i] = max(self.sparkle[i], 0.7)
            return
        if code >= 1000:                                 # guitar fret: its color on its fifth of the strip
            f = code - 1000
            col = np.array(_hex(FRET_COLORS[f], (255, 255, 255)))
            for i in range(N):
                w = max(0.0, 1 - abs(i - (f * 2 + 0.5)) / 1.6)
                self.layer[i] = np.maximum(self.layer[i], col * w)
            return
        if code in (311, 318) and self.pal and len(self.pal) == 5:     # guitar star power / tilt
            self.strobe_col = np.array([90, 170, 255])
            self.strobe = max(self.strobe, 1.0)
            return
        if code in (314, 315, 316):                      # BTN_SELECT/START/MODE (coin/start)
            self.strobe = max(self.strobe, 0.7)
            return
        half = (player % 2) * (N // 2)
        seg = half + code % (N // 2)
        col = np.array(self.pal[code % len(self.pal)])
        for i in range(half, half + N // 2):
            w = max(0.0, 1 - abs(i - seg) / 1.5)
            self.layer[i] = np.maximum(self.layer[i], col * w)

    def feed_game(self, e, now):
        self.music_peak = max(e["rms"], self.music_peak * 0.9995)
        level = min(1.0, e["rms"] / self.music_peak) if e["rms"] > 1e-4 else 0.0
        self.glow = self.glow * 0.92 + level * 0.08
        b = self.big(e["rms"], now)
        if b > 0.6:
            self.strobe = max(self.strobe, b)
            self.accent = random.randrange(len(self.pal))
        h = self.mid(e["low"] + e["mid"], now)
        if h:
            self.hit(now, h * 0.8)
        s = self.high(e["high"], now)
        if s:
            for i in random.sample(range(N), 1 + int(s * 2)):
                self.sparkle[i] = max(self.sparkle[i], s)

    def dof_layer(self, now, dt):
        """Table-scripted DOF toys mapped onto the 10 segments."""
        d = self.dof
        out = np.zeros((N, 3))
        under = d.rgb(DOF["undercab"])
        out += under * 0.7
        for k, chans in enumerate(DOF["flashers"]):          # 5 flashers -> segment pairs
            col = d.rgb(chans)
            out[2 * k] = np.maximum(out[2 * k], col)
            out[2 * k + 1] = np.maximum(out[2 * k + 1], col)
        flip = d.rgb(DOF["flippers"])
        out[0] = np.maximum(out[0], flip)
        out[N - 1] = np.maximum(out[N - 1], flip)
        if d.ch(DOF["beacon"]) > 0.05:                        # rotating beacon sweep
            self.beacon_phase += dt * 6
            for i in range(N):
                w = max(0.0, math.cos(self.beacon_phase - i * 0.7)) ** 4
                out[i] = np.maximum(out[i], self.beacon_col * w * d.ch(DOF["beacon"]))
        white = max(d.ch(DOF["strobe"]), d.ch(DOF["knocker"]))
        if white > 0.05:
            out += (self.strobe_col - out) * white
        if d.ch(DOF["shaker"]) > 0.05:
            out *= 0.7 + 0.3 * math.sin(now * 40)
        return out

    def attract_show(self, now):
        """Quiet-table animation in the table palette; style depends on the table."""
        if self.style >= 6:
            return None                    # drawn per LED by the engine
        return show_pixels(self.pal, self.style, now)

    def update_quiet(self, now, dt, dl):
        """The strip is 'quiet' when nothing is playing: no audio, no hits, no table flashers."""
        busy = self.glow > 0.08 or bool(self.hits) or self.strobe > 0.05 or self.sparkle.max() > 0.05
        if dl is not None and self.dof is not None:
            d = self.dof
            fl = max(max(d.rgb(c).max() for c in DOF["flashers"]), d.ch(DOF["strobe"]), d.ch(DOF["beacon"]))
            busy = busy or fl > 0.05
        if busy:
            self.quiet_since = None
        elif self.quiet_since is None:
            self.quiet_since = now
        target = 1.0 if (self.quiet_since is not None and now - self.quiet_since > 2.5) else 0.0
        self.quiet += (target - self.quiet) * min(1.0, dt * (1.2 if target else 6.0))

    def frame(self, now, dt):
        self.hits = [t for t in self.hits if now - t < 2.0]
        frenzy = min(1.0, max(0, len(self.hits) - 10) / 12)
        self.drift += dt * (0.02 + 0.3 * frenzy)
        dof_live = self.dof is not None and time.time() - self.dof.last < 20
        audio_gain = 0.45 if dof_live else 1.0          # DOF leads when the table drives it
        out = []
        dl = self.dof_layer(now, dt) if dof_live else None
        self.update_quiet(now, dt, dl)
        show = self.attract_show(now) if self.quiet > 0.01 else None
        stage = None
        if self.stage is not None and self.stage.live():
            cols, st = self.stage.fixtures()
            stage = [cols[min(7, round(i * 7 / (N - 1)))] for i in range(N)]
            if st > 0.05:
                self.strobe = max(self.strobe, 0.6 * (0.5 + 0.5 * math.sin(now * 60)))
            self.quiet = 0.0
        for i in range(N):
            wave = 0.5 + 0.5 * math.sin(now * 0.8 + i * 0.6)
            base = pal_at(self.pal, self.drift + i / N * 0.5) * (0.12 + 0.5 * self.glow * (0.6 + 0.4 * wave))
            if frenzy:
                base = base * (1 - frenzy) + pal_at(self.pal, i / N + now * 0.8) * 0.8 * frenzy
            if stage is not None:
                base = np.maximum(stage[i] * 0.9, base * 0.5)
            c = np.maximum(base, self.layer[i] * audio_gain)
            if show is not None:
                c = np.maximum(c, show[i] * self.quiet)
            if dl is not None:
                c = np.maximum(c * (0.6 if dl[i].max() > 20 else 1), dl[i])
            c = c + (np.array([255, 190, 60]) - c) * min(1, self.sparkle[i]) * 0.8 * audio_gain
            c = c + (self.strobe_col - c) * min(1, self.strobe) * audio_gain
            out.append(tuple(np.clip(c * self.dim, 0, 255)))
        self.layer *= 0.78
        self.sparkle *= 0.7
        self.strobe *= 0.55
        return out


EMBER_PAL = [(170, 18, 0), (255, 85, 0), (255, 165, 40)]


def idle_frame(now, dim):
    """Nothing selected or playing: slow, dim embers (the fire look in deep red and orange), per LED."""
    return np.clip(fullres_show(EMBER_PAL, 8, now * 0.55, LED_COUNT) * 0.5 * dim, 0, 255)


def attract_frame(palette, now, dim, seed=0):
    """ES-DE browsing: one of the six looks (chosen per game/system) with a gentle breathing swell."""
    breath = 0.8 + 0.2 * math.sin(now * 1.1)
    style = seed % SHOW_COUNT
    if style >= 6:
        return np.clip(fullres_show(palette, style, now, LED_COUNT) * breath * dim, 0, 255)
    px = show_pixels(palette, style, now) * breath * dim
    return [tuple(np.clip(c, 0, 255)) for c in px]


# ----------------------------------------------------------------- engine

def make_lights(args):
    """The lights the service talks to: the Govee bar (default) or a WLED strip. Both expose the same methods."""
    if getattr(args, "lights", "govee") == "wled":
        if not args.wled_ip: raise SystemExit("--lights wled needs --wled-ip")
        log(f"lights: WLED strip at {args.wled_ip} ({args.leds} LEDs)")
        return Wled(args.wled_ip, leds=args.leds, offset=args.offset, reverse=args.reverse)
    return Govee(IP)


class Controller:
    def __init__(self, args):
        self.args = args
        self.g = make_lights(args)
        self.mode = None
        self.streaming = False
        self.last_arm = 0.0
        self.artnet = None
        try:
            self.artnet = ArtNetIn()
            self.artnet.start()
        except OSError as e:
            log("ArtNet listener unavailable:", e)

    def arm(self):
        """(Re)enable per-segment streaming; the H610A drops back-to-back commands."""
        if not self.streaming:
            self.g.power(True)
            time.sleep(0.3)
            self.g.brightness(100)
            time.sleep(0.3)
            self.g.stream_mode(True)
            time.sleep(0.3)
            self.streaming = True
            self.last_arm = time.time()
        elif time.time() - self.last_arm > 2:
            self.g.stream_mode(True)
            self.last_arm = time.time()

    def send(self, frame):
        """A list of 10 zone colors, or a full (leds, 3) array for the per-LED looks."""
        if isinstance(frame, np.ndarray) and frame.ndim == 2 and hasattr(self.g, "send_pixels"):
            self.g.send_pixels(frame)
        else:
            self.g.segments(frame)

    def to_idle(self):
        if self.streaming:
            self.g.stream_mode(False)
            time.sleep(0.3)
            self.streaming = False
        if self.args.idle == "ambient":
            return                                    # run() streams the ambient frames
        if self.args.idle == "music":
            self.g.music(1, 100)
        elif self.args.idle == "off":
            self.g.power(False)

    def play(self, table=None, arcade=None, steam=None, rhythm=None, console=None):
        """VPX table (DOF + playfield + HDMI audio), or an ES-DE arcade game / Steam game
        (HDMI audio + buttons)."""
        ambi = wants_ambi(steam, console)
        if console:
            palette = system_palette(console[0])
            label = "CONSOLE " + "/".join(console)
            arcade = console
        elif rhythm:
            palette = [tuple(int(v) for v in _hex(c, (255, 255, 255))) for c in FRET_COLORS]
            label = f"RHYTHM {rhythm}"
            arcade = ("rhythm", rhythm)
        elif steam:
            palette = steam_palette(*steam)
            label = f"STEAM {steam[1]} ({steam[0]})"
            arcade = ("steam", str(steam[0]))
        elif arcade:
            palette = game_palette(*arcade)
            label = "ARCADE " + "/".join(arcade)
        else:
            palette = palette_for(table) if table else DEFAULT
            label = f"PLAY {table or '(unknown table)'}"
        log(f"{label}  palette=" + " ".join("#%02x%02x%02x" % tuple(c) for c in palette))
        sfx = None if arcade else Capture(SFX_SINK)
        game = Capture(default_sink())
        buttons = (Buttons("guitar") if rhythm else Buttons()) if arcade else None
        for th in (sfx, game, buttons):
            if th:
                th.start()
        lights = PinballLights(palette, self.args.dim, zlib.crc32(label.encode()), load_extras(table) if table else None)
        lights.dof = None if arcade else self.artnet
        screen = None
        if ambi and hasattr(self.g, "send_pixels"):
            screen = Screen()
            screen.start()
            pts = strip_points(self.args.leds)
            rot = portrait_dir()
            ambi_px = np.zeros((self.args.leds, 3))
            log("ambilight on" + (f" (portrait {rot})" if rot else ""))
        stage = None
        if rhythm:
            try:
                stage = SACN()
                stage.start()
                lights.stage = stage
            except OSError as e:
                log("sACN listener failed:", e)
        pk0 = self.artnet.packets if self.artnet else 0
        t0 = last = time.time()
        last_check = last_dbg = 0.0
        try:
            while True:
                t = time.time()
                now, dt = t - t0, t - last
                last = t
                for e in (sfx.take() if sfx else []):
                    lights.feed_mech(e, now)
                for e in game.take():
                    lights.feed_game(e, now)
                for player, code in (buttons.take() if buttons else []):
                    lights.feed_button(player, code, now)
                self.arm()
                segs = lights.frame(now, dt)
                if screen is not None and screen.live():
                    tgt = ambi_pixels(screen.frame, self.args.leds, pts, rot)
                    ambi_px += (tgt - ambi_px) * min(1.0, dt * 8)
                    px = ambi_px * (0.75 + 0.45 * lights.glow)
                    px = px + (lights.strobe_col - px) * min(1, lights.strobe) * 0.6
                    self.g.send_pixels(np.clip(px * self.args.dim, 0, 255))
                elif lights.style >= 6 and lights.quiet > 0.01 and hasattr(self.g, "send_pixels"):
                    base = self.g.pixels(segs)
                    show = fullres_show(lights.pal, lights.style, now, self.args.leds) * lights.quiet * self.args.dim
                    self.g.send_pixels(np.maximum(base, show))
                else:
                    self.g.segments(segs)
                if DEBUG and now - last_dbg >= 2:
                    pk = (self.artnet.packets - pk0) if self.artnet else 0
                    log(f"hits/2s={len(lights.hits)} glow={lights.glow:.2f} dof_packets={pk}")
                    last_dbg = now
                if not self.args.force and now - last_check > 1:
                    last_check = now
                    running, _ = vpx_table()
                    if console:
                        if running or es_playing() != console:
                            break
                    elif rhythm:
                        if running or rhythm_game() != rhythm:
                            break
                    elif steam:
                        if running or steam_game() != steam:
                            break
                    elif arcade and (running or es_playing() != arcade):
                        break
                    if not arcade and not running:
                        break
                time.sleep(1 / FPS)
        finally:
            for th in (sfx, game, buttons, stage if rhythm else None, screen):
                if th:
                    th.stop()
            if not arcade and self.artnet and self.artnet.packets > pk0:
                log(f"DOF was active this game ({self.artnet.packets - pk0} ArtNet packets)")

    def run(self):
        if self.args.force:
            self.play(None)
            return
        log("watching for VPX / ES-DE")
        t0 = time.time()
        while True:
            running, table = vpx_table()
            if running:
                self.mode = "play"
                self.play(table)
                self.mode = None
                continue
            rg = rhythm_game()
            if rg:
                self.mode = "rhythm"
                self.play(rhythm=rg)
                self.mode = None
                continue
            playing = es_playing()
            if playing and playing[0] in ARCADE_SYSTEMS:
                self.mode = "arcade"
                self.play(arcade=playing)
                self.mode = None
                continue
            if playing and playing[0] not in ("vpinball", "steam", "desktop", "ports"):
                self.mode = "console"
                self.play(console=playing)
                self.mode = None
                continue
            sg = steam_game()
            if sg:
                self.mode = "steam"
                self.play(steam=sg)
                self.mode = None
                continue
            system, game, age, saver = es_selection()
            want_attract = bool(system) and age < ATTRACT_TIMEOUT and not saver and not playing
            if want_attract:
                if self.mode != ("attract", system, game):
                    log("ATTRACT", f"{system}/{game}")
                    self.mode = ("attract", system, game)
                    if system == "vpinball" and game:
                        pal = palette_for(game)
                    elif system in ARCADE_SYSTEMS and game:
                        pal = game_palette(system, game)
                    else:
                        pal = system_palette(system)
                self.arm()
                self.send(attract_frame(pal, time.time() - t0, self.args.dim, zlib.crc32(f"{system}/{game}".encode())))
                time.sleep(1 / 25)
                continue
            if self.mode != "idle":
                log("IDLE")
                self.mode = "idle"
                self.to_idle()
            if self.args.idle == "ambient":
                self.arm()
                self.send(idle_frame(time.time() - t0, self.args.dim))
                time.sleep(1 / 25)
                continue
            time.sleep(0.5)


def main():
    global DEBUG
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--dim", type=float, default=0.6)
    ap.add_argument("--idle", choices=["ambient", "music", "off", "keep"], default="ambient")
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--lights", choices=["govee", "wled"], default="govee")
    ap.add_argument("--wled-ip", default=os.environ.get("WLED_IP"))
    ap.add_argument("--leds", type=int, default=int(os.environ.get("WLED_LEDS", "240")))
    ap.add_argument("--offset", type=float, default=float(os.environ.get("WLED_OFFSET", "0")))
    ap.add_argument("--reverse", action="store_true", default=os.environ.get("WLED_REVERSE") == "1")
    args = ap.parse_args()
    global LED_COUNT
    LED_COUNT = args.leds
    DEBUG = args.debug
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt))
    c = Controller(args)
    try:
        c.run()
    except KeyboardInterrupt:
        pass
    finally:
        c.to_idle()


if __name__ == "__main__":
    main()
