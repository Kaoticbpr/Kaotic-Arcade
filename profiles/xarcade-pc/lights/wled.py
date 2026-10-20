"""WLED transport for the cabinet lighting service (a drop-in for govee.Govee: same methods).

Colour data goes to WLED as DDP over UDP (port 4048), which WLED treats as "realtime": it takes over the LEDs while packets arrive and
falls back to its own effect 2.5 s after they stop.  Power / brightness / idle effect use WLED's JSON API.

The service thinks in a handful of colour segments (10 for the Govee bar).  Here they are spread along the whole strip as a smooth
gradient, so a strip around the back of the TV glows as one band.  The strip rotates with the TV, so the layout never changes.

  Wled(ip, leds=240, offset=0.0, reverse=False, ring=True)
     offset   0..1  rotates where segment 0 sits along the strip (start of strip = 0)
     reverse        flips the direction of the gradient
     ring           treat the strip as a loop (the last pixel blends back to the first) - true for a strip around a TV
"""
import json
import queue
import socket
import threading
import time
import urllib.request

import numpy as np

DDP_PORT = 4048
MAX_PIXELS_PER_PACKET = 480          # 1440 data bytes: the DDP maximum
IDLE_EFFECTS = ("Gravcenter", "Gravimeter", "Juggles", "Waterfall", "Rainbow")   # first one this WLED build has


class Wled:
    def __init__(self, ip, leds=240, offset=0.0, reverse=False, ring=True, http_port=80, ddp_port=DDP_PORT, max_amps=2.5):
        self.ip, self.leds, self.offset, self.reverse, self.ring = ip, int(leds), float(offset), bool(reverse), bool(ring)
        self.http = f"http://{ip}:{http_port}"
        self.addr = (ip, ddp_port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.seq = 0
        self.max_amps = max_amps
        self._fx = None
        self._q = queue.Queue(maxsize=64)
        self._dead_until = 0.0
        threading.Thread(target=self._worker, daemon=True).start()

    # ----------------------------------------------------------- JSON API
    def _json(self, state=None, path="/json/state"):
        try:
            data = json.dumps(state).encode() if state is not None else None
            req = urllib.request.Request(self.http + path, data=data, headers={"Content-Type": "application/json"} if data else {})
            with urllib.request.urlopen(req, timeout=1.5) as r:
                return json.loads(r.read().decode() or "null")
        except Exception:
            return None

    # State changes run on a background thread so a slow or dead strip can never stall the lighting loop (frames use UDP and never wait).
    def _worker(self):
        while True:
            job = self._q.get()
            if time.time() < self._dead_until:                      # strip unreachable: skip until the back-off ends
                continue
            try:
                ok = job() is not None
            except Exception:
                ok = False
            self._dead_until = 0.0 if ok else time.time() + 10.0

    def _post(self, fn):
        try: self._q.put_nowait(fn)
        except queue.Full: pass

    def power(self, on):
        self._post(lambda: self._json({"on": bool(on)}))

    def brightness(self, pct):
        self._post(lambda: self._json({"on": True, "bri": max(1, min(255, int(round(max(1, min(100, pct)) * 2.55))))}))

    def color(self, r, g, b):
        self._post(lambda: self._json({"on": True, "seg": [{"col": [[int(r), int(g), int(b)]], "fx": 0}]}))

    def stream_mode(self, on):
        """DDP needs no mode switch; leaving realtime is automatic (timeout) so there is nothing to do here."""
        return

    def _pick_effect(self):
        if self._fx is None:
            names = self._json(path="/json/effects") or []
            self._fx = next((names.index(n) for n in IDLE_EFFECTS if n in names), 0)
        return self._fx

    def music(self, style=1, sensitivity=100):
        """Idle: hand the strip to a sound-reactive WLED effect (needs the Dig2go's microphone build, which is the default)."""
        self._post(lambda: self._json({"on": True, "seg": [{"fx": self._pick_effect(), "sx": 128, "ix": int(max(1, min(100, sensitivity)) * 2.55)}]}))

    # ----------------------------------------------------------- colour streaming
    def pixels(self, colors, gradient=True):
        """Spread the segment colours over the strip. Returns an (leds, 3) uint8 array."""
        cols = np.array(colors, float).reshape(-1, 3)
        n = len(cols)
        if n == 0: return np.zeros((self.leds, 3), np.uint8)
        pos = (np.arange(self.leds) + 0.5) / self.leds                 # 0..1 along the strip
        if self.reverse: pos = 1.0 - pos
        pos = (pos + self.offset) % 1.0 if self.ring else np.clip(pos + self.offset, 0, 1)
        if not gradient:                                               # hard segments
            idx = np.minimum((pos * n).astype(int), n - 1)
            return cols[idx].astype(np.uint8)
        x = pos * n - 0.5                                              # segment centres at 0.5/n, 1.5/n, ...
        i0 = np.floor(x).astype(int); f = (x - i0)[:, None]
        if self.ring: a, b = cols[i0 % n], cols[(i0 + 1) % n]
        else: a, b = cols[np.clip(i0, 0, n - 1)], cols[np.clip(i0 + 1, 0, n - 1)]
        return np.clip(a * (1 - f) + b * f, 0, 255).astype(np.uint8)

    def segments(self, colors, gradient=True):
        self.send_pixels(self.pixels(colors, gradient))

    def send_pixels(self, px):
        data = np.asarray(px, np.uint8).reshape(-1, 3)
        for start in range(0, len(data), MAX_PIXELS_PER_PACKET):
            chunk = data[start:start + MAX_PIXELS_PER_PACKET].tobytes()
            last = start + MAX_PIXELS_PER_PACKET >= len(data)
            hdr = bytes([0x40 | (0x01 if last else 0), self.seq & 0x0F, 0x01, 0x01]) + (start * 3).to_bytes(4, "big") + len(chunk).to_bytes(2, "big")
            self.sock.sendto(hdr + chunk, self.addr)
        self.seq = (self.seq + 1) % 15 + 1

    # ----------------------------------------------------------- one-time setup helper
    def info(self):
        return self._json(path="/json/info")

    def set_power_limit(self, milliamps=None):
        """Cap the strip's current in WLED itself (the kit's supply is 3 A).  Needs WLED >= 0.13; changes apply after WLED reboots."""
        ma = int((milliamps or self.max_amps * 1000))
        return self._json({"hw": {"led": {"maxpwr": ma}}}, path="/json/cfg")
