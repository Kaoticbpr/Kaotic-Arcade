#!/usr/bin/env python3
"""Fire TV control over ADB (network). usage: tv.py on|off|status|pair
Keys live in ~/govee/adbkey(.pub). First run pops an 'Allow USB debugging?' prompt on the TV: choose Always allow."""
import os, subprocess, sys, time
from adb_shell.adb_device import AdbDeviceTcp
from adb_shell.auth.keygen import keygen
from adb_shell.auth.sign_pythonrsa import PythonRSASigner

IP = os.environ.get("TV_IP", "")
if not IP:
    sys.exit("Set TV_IP (and TV_MAC for wake-up) first, e.g.  TV_IP=192.168.1.50 TV_MAC=aabbccddeeff python3 tv.py on")
KEY = os.path.expanduser("~/govee/adbkey")
if not os.path.exists(KEY):
    keygen(KEY)
signer = PythonRSASigner(open(KEY + ".pub").read(), open(KEY).read())


def connect(wait=30):
    dev = AdbDeviceTcp(IP, 5555, default_transport_timeout_s=10)
    dev.connect(rsa_keys=[signer], auth_timeout_s=wait)
    return dev


def awake(dev):
    out = dev.shell("dumpsys power | grep -E 'mWakefulness=|Display Power'")
    return "Awake" in out


def wol():
    """Wake-on-LAN magic packet: wakes the Fire TV from standby when its network is down."""
    import socket
    mac = bytes.fromhex(os.environ["TV_MAC"].replace(":", "").replace("-", ""))
    pkt = bytes([255]) * 6 + mac * 16
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    for _ in range(3):
        s.sendto(pkt, (".".join(IP.split(".")[:3] + ["255"]), 9))
        s.sendto(pkt, ("255.255.255.255", 7))
        s.sendto(pkt, (IP, 9))


cmd = (sys.argv[1] if len(sys.argv) > 1 else "status").lower()
if cmd == "on":
    wol()
    time.sleep(6)
dev = None
for attempt in range(3 if cmd == "on" else 1):
    try:
        dev = connect(60 if cmd == "pair" else 15)
        break
    except Exception as e:
        err = e
        time.sleep(3)
if dev is None:
    e = err
    if True:
        print("cannot reach the TV:", e)
        sys.exit(2 if cmd == "on" else 1)
if cmd in ("status", "pair"):
    print("connected; awake =", awake(dev))
elif cmd == "on":
    if not awake(dev):
        dev.shell("input keyevent KEYCODE_WAKEUP")
    print("awake =", awake(dev))
elif cmd == "off":
    dev.shell("input keyevent KEYCODE_SLEEP")
    time.sleep(1)
    print("awake =", awake(dev))
dev.close()
