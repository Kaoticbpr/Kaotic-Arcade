#!/usr/bin/env python3
"""Keep the X-Arcade away from ES-DE / SDL games while Steam has the controller in Game Mode.
Steam Input is deliberately OFF for ES-DE (arcade maps are bound to the raw pads), so Steam cannot pause their input
itself. While a Steam menu or page is open, or while the Steam (guide) button is held for a Steam combo such as
Steam + D-pad down = start/stop recording, X input focus on the games display (:1) is moved to the root window;
SDL ignores controller input without focus. Focus goes back to the same window afterwards.
Menu signal: gamescope sets GAMESCOPE_FOCUSED_APP on :0 to 769 (Steam) while Steam has focus."""
import glob, threading, time
from Xlib import display, X
import evdev
STEAM, GUIDE_GRACE = 769, 0.5
log = lambda *m: print(time.strftime("%H:%M:%S"), *m, flush=True)
state = {"guide": False, "released": 0.0}

def guide_watch():
    """Follow BTN_MODE (the Steam/guide button) on every X-Arcade pad; reopen devices when they reconnect."""
    while True:
        try:
            devs = [evdev.InputDevice(p) for p in glob.glob("/dev/input/by-id/usb-Baolian*event-joystick") + glob.glob("/dev/input/by-id/usb-X-Arcade*event-joystick")]
            if not devs: time.sleep(3); continue
            held = {d.path: False for d in devs}
            import select
            while True:
                r, _, _ = select.select(devs, [], [], 5)
                for d in r:
                    for e in d.read():
                        if e.type == evdev.ecodes.EV_KEY and e.code == evdev.ecodes.BTN_MODE:
                            held[d.path] = e.value != 0
                            g = any(held.values())
                            if not g and state["guide"]: state["released"] = time.time()
                            state["guide"] = g
        except Exception as ex:
            log("guide watch:", ex); state["guide"] = False; time.sleep(2)

threading.Thread(target=guide_watch, daemon=True).start()
d0 = display.Display(":0"); d1 = display.Display(":1")
root0 = d0.screen().root; root1 = d1.screen().root
A_FOCUS = d0.intern_atom("GAMESCOPE_FOCUSED_APP")
saved = None
log("started")
while True:
    try:
        p = root0.get_full_property(A_FOCUS, X.AnyPropertyType)
        focus = int(p.value[0]) if p and len(p.value) else None
        steam = focus == STEAM          # any Steam menu or full Steam page (Settings, Library) has the controller
        guide = state["guide"] or time.time() - state["released"] < GUIDE_GRACE
        pause = steam or guide
        if pause and saved is None:
            w = d1.get_input_focus().focus
            saved = w if hasattr(w, "id") and w.id not in (0, 1, root1.id) else False
            if saved:
                d1.set_input_focus(root1, X.RevertToPointerRoot, X.CurrentTime); d1.sync()
                log("paused (%s): unfocused" % ("steam" if steam else "guide"), hex(saved.id))
        elif not pause and saved is not None:
            if saved:
                try: d1.set_input_focus(saved, X.RevertToPointerRoot, X.CurrentTime); d1.sync(); log("resumed: refocused", hex(saved.id))
                except Exception as e: log("refocus failed", e)
            saved = None
    except Exception as e:
        log("error", e); time.sleep(1)
        try: d0 = display.Display(":0"); d1 = display.Display(":1"); root0 = d0.screen().root; root1 = d1.screen().root
        except Exception: pass
    time.sleep(0.05)
