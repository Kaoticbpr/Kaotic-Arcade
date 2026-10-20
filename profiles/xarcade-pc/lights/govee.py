"""Minimal Govee LAN client: whole-device commands plus per-segment 'razer' streaming."""
import base64
import json
import socket
import time

PORT = 4003


class Govee:
    def __init__(self, ip):
        self.addr = (ip, PORT)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def _send(self, cmd, data):
        self.sock.sendto(json.dumps({"msg": {"cmd": cmd, "data": data}}).encode(), self.addr)

    def power(self, on):
        self._send("turn", {"value": 1 if on else 0})

    def brightness(self, pct):
        self._send("brightness", {"value": max(1, min(100, int(pct)))})

    def color(self, r, g, b):
        self._send("colorwc", {"color": {"r": int(r), "g": int(g), "b": int(b)}, "colorTemInKelvin": 0})

    @staticmethod
    def _packet(payload):
        cs = 0
        for b in payload:
            cs ^= b
        return base64.b64encode(bytes(payload + [cs])).decode()

    def stream_mode(self, on):
        """Enable/disable per-segment streaming (DreamView-style)."""
        self._send("razer", {"pt": self._packet([0xBB, 0x00, 0x01, 0xB1, 1 if on else 0])})

    def pt_real(self, *payloads, repeat=2):
        """Send raw 19-byte+checksum device frames (padded), repeated like the app does."""
        frames = []
        for p in payloads:
            pkt = list(p) + [0] * (19 - len(p))
            cs = 0
            for b in pkt:
                cs ^= b
            frames.append(base64.b64encode(bytes(pkt + [cs])).decode())
        for i in range(repeat):
            self._send("ptReal", {"command": frames})
            if i < repeat - 1:
                time.sleep(0.3)

    def music(self, style=1, sensitivity=100):
        """Switch to the device's own Music Mode, listening on its built-in mic."""
        self.stream_mode(False)
        self.pt_real([0x33, 0x05, 0x13, int(style) & 255, max(0, min(100, int(sensitivity)))])

    def segments(self, colors, gradient=False):
        """colors: list of (r, g, b) tuples, one per segment."""
        payload = [0xBB, 0x00, 2 + 3 * len(colors), 0xB0, 1 if gradient else 0, len(colors)]
        for r, g, b in colors:
            payload += [int(r) & 255, int(g) & 255, int(b) & 255]
        self._send("razer", {"pt": self._packet(payload)})
