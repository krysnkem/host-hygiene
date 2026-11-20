#!/usr/bin/env python3
# look-seam.py HOME ROWS COLS [RESIZE_ROWSxCOLS] [K=V ...]: drive the TUI in a pty until the pick list shows, print the screen (after an optional live resize). Needs pyte.
import pty, os, sys, time, select, struct, fcntl, termios, pyte
home, rows, cols = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]); rest = sys.argv[4:]
rs = None
if rest and "=" not in rest[0]: rs = tuple(int(x) for x in rest[0].split("x")); rest = rest[1:]
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env = {"HOME": home, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HH_SCRIPT": D + "/scripts/host-hygiene.sh", "HH_NO_PROMPT": "1", "HH_HOME": "0", "HH_MIN_MB": "1", "HH_SEED": "7",
       "TERM": "xterm-256color", "LANG": "en_US.UTF-8", "HH_DC_PS_FILE": "/dev/null", "HH_APPS_DIR": "/nonexistent"}
if "HH_ARCH" in os.environ: env["HH_ARCH"] = os.environ["HH_ARCH"]   # lets a test pick which chip's interface binary the launcher accepts
env.update(dict(a.split("=", 1) for a in rest))
pid, fd = pty.fork()
if pid == 0: os.execve(D + "/tui/hh_tui", [D + "/tui/hh_tui"], env)
def size(r, c): fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", r, c, 0, 0))
size(rows, cols); scr = pyte.Screen(cols, rows); st = pyte.ByteStream(scr)
def text(): return "\n".join(l.rstrip() for l in scr.display).rstrip()
def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: d = os.read(fd, 65536)
            except OSError: return
            st.feed(d)
def settle(goal, cap=60):
    t0 = time.time()
    while time.time() - t0 < cap:
        pump(0.3)
        if goal(text()): break
    pump(1.5)
ready = lambda t: "[ ]" in t or "Set the limits" in t or ("too small" in t.lower() and "Looking around" not in t)   # the fallback notice shows with the scan spinner; wait for the list behind it
settle(ready)
if rs:
    scr.resize(rs[0], rs[1]); size(rs[0], rs[1]); os.kill(pid, 28); pump(2.0)
print(text())
try: os.kill(pid, 9)
except Exception: pass
