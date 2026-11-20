#!/usr/bin/env python3
# Drive the TUI in a pty and print the Look screen once Hy has said everything. Usage: look-driver.py HOME ROWS COLS
# Needs pyte. Environment is stripped: HOME and a safe PATH only (plus what the TUI needs).
import pty, os, sys, time, select, struct, fcntl, termios, pyte
home, rows, cols = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env = {"HOME": home, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HH_SCRIPT": D + "/scripts/host-hygiene.sh", "HH_NO_PROMPT": "1", "HH_HOME": "0", "HH_MIN_MB": "1",
       "TERM": "xterm-256color", "LANG": "en_US.UTF-8", "HH_DC_PS_FILE": "/dev/null", "HH_APPS_DIR": "/nonexistent"}
if "HH_ARCH" in os.environ: env["HH_ARCH"] = os.environ["HH_ARCH"]   # lets a test pick which chip's interface binary the launcher accepts
pid, fd = pty.fork()
if pid == 0: os.execve(D + "/tui/hh_tui", [D + "/tui/hh_tui"], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
scr = pyte.Screen(cols, rows); st = pyte.ByteStream(scr)
def text(): return "\n".join(l.rstrip() for l in scr.display)
def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try: d = os.read(fd, 65536)
            except OSError: return
            if not d: return
            st.feed(d)
# Collect every distinct screen line while Hy types (a short terminal only shows the newest line of speech), until the limits question.
seen = []; t0 = time.time()
def snap():
    for l in text().split("\n"):
        l = l.strip(" │╭╮╰╯─")
        if l and l not in seen: seen.append(l)
while time.time() - t0 < 120:
    r, _, _ = select.select([fd], [], [], 0.05)   # snapshot after every chunk so no typed character is missed
    if r:
        try: d = os.read(fd, 4096)
        except OSError: break
        if not d: break
        st.feed(d); snap()
    if "Set the limits" in text(): break
pump(0.5)
import re
seen = [re.sub(r"^\(.{3}\)\s+", "", l.replace("▌", "")).strip() for l in seen]
seen = [l for i, l in enumerate(seen) if l and not any(m.startswith(l) for m in seen[i + 1:]) and "Looking around" not in l and not l.startswith(("1 Look", "Set the limits", "❯", "←"))]
print(" ".join(seen))   # one line: the wrapped fragments of Hy's speech, in order
try: os.kill(pid, 9)
except Exception: pass
