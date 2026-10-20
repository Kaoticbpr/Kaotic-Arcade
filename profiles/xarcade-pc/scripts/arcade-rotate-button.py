#!/usr/bin/env python3
"""X-Arcade button for the rotating TV: hold BOTH flipper buttons (LB + RB) for 5 seconds to flip between
landscape and portrait (arcade-rotate.sh: swaps the pinball + arcade settings and restarts into the portrait / landscape session).
Chord = the two flipper buttons (LB + RB in purple/pinball mode), on any pad.

Safety: it does nothing while a game/table is running, and it only acts when armed
(`touch ~/.config/arcade-rotate-button.armed`). Unarmed it just logs "chord detected" so the buttons can be verified.
Direction the TV turns: ~/Emulation/tools/portrait/direction contains left or right (default left)."""
import glob, os, select, subprocess, sys, time
import evdev
H = os.path.expanduser("~"); HOLD = 5.0
ARMED = H + "/.config/arcade-rotate-button.armed"; DIR = H + "/Emulation/tools/portrait/direction"
RAT = H + "/Emulation/tools/scripts/arcade-rotate.sh"; SW = H + "/Emulation/tools/scripts/portrait-switch.py"
KEYS = {evdev.ecodes.BTN_TL: 'LB', evdev.ecodes.BTN_TR: 'RB'}
log = lambda *m: print(time.strftime("%H:%M:%S"), *m, flush=True)

class Chord:
    """Pure state machine: feed key events, ask whether every pad has held the button for HOLD seconds."""
    def __init__(self, pads, hold=HOLD): self.pads, self.hold, self.down, self.fired = set(pads), hold, {}, False
    def feed(self, pad, pressed, now):
        # pad = (device, button); the chord needs each button name held on at least one device
        key = pad[1]; self.src = getattr(self, "src", {})
        if pressed: self.src.setdefault(pad, now)
        else: self.src.pop(pad, None)
        times = {}
        for (dev, b), t in self.src.items(): times[b] = min(times.get(b, t), t)
        self.down = times
        if not self.down: self.fired = False
    def ready(self, now):
        if self.fired or set(self.down) != self.pads: return False
        if all(now - t >= self.hold for t in self.down.values()): self.fired = True; return True
        return False

ESDE_APP = 3536773192
PCONF = H + "/.config/environment.d/91-arcade-portrait.conf"
def esde_on_screen():
    """True only when ES-DE itself is the focused app in Game Mode (not a Steam game, not a Steam menu)."""
    if os.path.exists(PCONF) and "STEAMCMD=\"" in open(PCONF).read():                       # Steam-less portrait session: ES-DE is the only app, so it is on screen unless a game runs
        return subprocess.run(["pgrep", "-x", "es-de"], stdout=subprocess.DEVNULL).returncode == 0
    r = subprocess.run(["xprop", "-root", "-display", ":0", "GAMESCOPE_FOCUSED_APP"], capture_output=True, text=True).stdout
    try: return int(r.split("=")[1].split(",")[0]) == ESDE_APP
    except Exception: return False

def game_running():
    pid = subprocess.run(["pgrep", "-x", "es-de"], capture_output=True, text=True).stdout.split()
    return bool(pid) and subprocess.run(["pgrep", "-P", pid[0]], stdout=subprocess.DEVNULL).returncode == 0

def mode():
    out = subprocess.run(["python3", SW, "status"], capture_output=True, text=True).stdout
    return "portrait" if "mode: portrait" in out else "landscape"

def act():
    if not os.path.exists(ARMED): log("chord detected (log only: not armed, nothing changed)"); return
    if not esde_on_screen(): log("chord ignored: ES-DE is not the app on screen (a Steam game or menu is)"); return
    if game_running(): log("chord ignored: a game is running"); return
    target = "landscape" if mode() == "portrait" else "portrait"
    side = open(DIR).read().strip() if os.path.exists(DIR) else "right"
    cmd = [RAT, target] + ([side] if target == "portrait" else [])
    log("switching:", " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True); log("result", r.returncode, (r.stdout + r.stderr).strip()[-200:])

def selftest():
    c = Chord({"LB", "RB"}, 3.0)
    c.feed(("p1", "LB"), True, 0); assert not c.ready(5)         # only one flipper button
    c.feed(("p2", "RB"), True, 1); assert not c.ready(3.5)       # RB held 2.5 s
    assert c.ready(4.1) and not c.ready(4.2)                     # fires once
    c.feed(("p1", "LB"), False, 5); c.feed(("p2", "RB"), False, 5); c.feed(("p1", "LB"), True, 6); c.feed(("p1", "RB"), True, 6)
    assert not c.ready(8.9) and c.ready(9.1)                     # can fire again; both buttons may be on one pad
    c = Chord({"LB", "RB"}, 3.0); c.feed(("p1", "LB"), True, 0); c.feed(("p2", "RB"), True, 0); c.feed(("p2", "RB"), False, 2); c.feed(("p2", "RB"), True, 2.5)
    assert not c.ready(3.2)                                      # letting go restarts the timer
    print("selftest ok"); sys.exit()

if "--selftest" in sys.argv: selftest()
log("started; armed" if os.path.exists(ARMED) else "started; log-only (not armed)")
while True:
    try:
        devs = [evdev.InputDevice(p) for p in sorted(set(glob.glob("/dev/input/by-id/usb-Baolian*event-joystick") + glob.glob("/dev/input/by-id/usb-X-Arcade*event-joystick")))]
        devs = [d for d in devs if any(k in d.capabilities().get(evdev.ecodes.EV_KEY, []) for k in KEYS)]
        if not devs: time.sleep(3); continue
        ch = Chord(set(KEYS.values())); log("watching", [d.name + " " + os.path.basename(d.path) for d in devs])
        while True:
            r, _, _ = select.select(devs, [], [], 0.25)
            for d in r:
                for e in d.read():
                    if e.type == evdev.ecodes.EV_KEY and e.code in KEYS: ch.feed((d.path, KEYS[e.code]), e.value != 0, time.time())
            if ch.ready(time.time()): act()
    except Exception as ex:
        log("error:", ex); time.sleep(2)
