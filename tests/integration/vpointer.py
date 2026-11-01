#!/usr/bin/env python3
"""Virtual pointer for a test compositor, raw Wayland wire protocol.
Usage: vpointer.py W H x y wheel|touch N   (run with the test WAYLAND_DISPLAY)
       vpointer.py W H x y hover MILLISECONDS
       vpointer.py W H x y click 1
       vpointer.py W H x y drag DX
Moves to x,y, waits, then scrolls or drags horizontally by DX screen pixels."""
import os, socket, struct, sys, time

def pad(s):
    b = s.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)

class W:
    def __init__(self):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"]))
        self.next = 2
    def new(self):
        i = self.next; self.next += 1; return i
    def send(self, obj, op, body=b""):
        self.s.sendall(struct.pack("<II", obj, ((8 + len(body)) << 16) | op) + body)

w = W()
registry = w.new()
w.send(1, 1, struct.pack("<I", registry))
done = w.new()
w.send(1, 0, struct.pack("<I", done))
buf = b""; globs = {}; synced = False
while not synced:
    buf += w.s.recv(65536)
    while len(buf) >= 8:
        obj, x = struct.unpack("<II", buf[:8]); size = x >> 16; op = x & 0xffff
        if len(buf) < size: break
        body = buf[8:size]; buf = buf[size:]
        if obj == registry and op == 0:
            name, n = struct.unpack("<II", body[:8])
            iface = body[8:8 + n - 1].decode()
            ver = struct.unpack("<I", body[8 + ((n + 3) & ~3):8 + ((n + 3) & ~3) + 4])[0]
            globs[iface] = (name, ver)
        if obj == done: synced = True

name, ver = globs["zwlr_virtual_pointer_manager_v1"]
mgr = w.new()
w.send(registry, 0, struct.pack("<I", name) + pad("zwlr_virtual_pointer_manager_v1") + struct.pack("<II", 1, mgr))
vp = w.new()
w.send(mgr, 0, struct.pack("<II", 0, vp))

W_, H, x, y, mode, n = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], int(sys.argv[6])
t = lambda: int(time.monotonic() * 1000) & 0xffffffff
fixed = lambda v: int(v * 256)
w.send(vp, 1, struct.pack("<IIIII", t(), x, y, W_, H)); w.send(vp, 4)
time.sleep(0.2 if mode == "click" else 1.2)
# Nudge, so the surface sees motion after mapping.
w.send(vp, 1, struct.pack("<IIIII", t(), x + 1, y, W_, H)); w.send(vp, 4)
time.sleep(0.15 if mode == "click" else 0.6)
if mode == "hover":
    time.sleep(n / 1000)
    sys.exit(0)
if mode == "click":
    w.send(vp, 2, struct.pack("<III", t(), 272, 1)); w.send(vp, 4)
    time.sleep(0.08)
    w.send(vp, 2, struct.pack("<III", t(), 272, 0)); w.send(vp, 4)
    time.sleep(0.3)
    sys.exit(0)
if mode == "drag":
    w.send(vp, 2, struct.pack("<III", t(), 272, 1))
    w.send(vp, 4)
    time.sleep(0.15)
    for step in range(1, 41):
        w.send(vp, 1, struct.pack("<IIIII", t(), round(x + 1 + n * step / 40), y, W_, H))
        w.send(vp, 4)
        time.sleep(0.025)
    w.send(vp, 2, struct.pack("<III", t(), 272, 0))
    w.send(vp, 4)
    time.sleep(0.5)
    sys.exit(0)
for i in range(n):
    if mode == "wheel":
        w.send(vp, 5, struct.pack("<I", 0))  # source wheel
        w.send(vp, 7, struct.pack("<IIii", t(), 0, fixed(15), 1))
        w.send(vp, 4)
        time.sleep(0.2)
    else:
        for k in range(10):
            w.send(vp, 5, struct.pack("<I", 1))  # source finger
            w.send(vp, 3, struct.pack("<IIi", t(), 0, fixed(8)))
            w.send(vp, 4)
            time.sleep(0.016)
        w.send(vp, 5, struct.pack("<I", 1))
        w.send(vp, 6, struct.pack("<II", t(), 0))
        w.send(vp, 4)
        time.sleep(0.3)
time.sleep(0.5)
