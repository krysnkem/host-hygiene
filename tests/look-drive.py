#!/usr/bin/env python3
# look-drive.py HOME ROWS COLS 'STEPS_JSON' [K=V ...]: drive the TUI in a pty (needs pyte). Environment is stripped; K=V overrides (HH_LOOK=cockpit, HH_ARGS='--pick-look --web' = command-line arguments for the binary, PATH=shim:..., HH_BIN=other binary).
# Steps: ["wait", "text" or "a|b" (any of), cap_s] | ["key", NAME_or_chars] | ["resize", rows, cols] (prints "RESIZE_MS n": time until the screen shows what it shows 3 s later) | ["snap", name] | ["type", chars] (one key at a time) | ["settle", s] (screen unchanged for s seconds) | ["mark", name] (prints MARK name epoch) | ["sleep", s] | ["send", chars]
# Prints one block per snap ("=== name" then the screen), "WAIT text ok|MISSING", and a final "ALIVE true|false". Scratch homes only.
import re, pty, os, sys, time, select, struct, fcntl, termios, pyte, json
home, rows, cols = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]); steps = json.loads(sys.argv[4]); extra = dict(a.split("=", 1) for a in sys.argv[5:])
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env = {"HOME": home, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HH_SCRIPT": D + "/scripts/host-hygiene.sh", "HH_NO_PROMPT": "1", "HH_HOME": "0", "HH_MIN_MB": "10", "HH_SEED": "7",
       "TERM": "xterm-256color", "LANG": "en_US.UTF-8", "HH_DC_PS_FILE": "/dev/null", "HH_APPS_DIR": "/nonexistent"}
env.update(extra); binp = env.pop("HH_BIN", D + "/tui/hh_tui"); args = env.pop("HH_ARGS", "").split()
pid, fd = pty.fork()
if pid == 0: os.execve(binp, [binp] + args, env)
def sz(r, c): fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", r, c, 0, 0))
pend = b""; chunks = []; raw = bytearray(); sz(rows, cols); scr = pyte.Screen(cols, rows); st = pyte.ByteStream(scr); alive = True
def text(): return "\n".join(l.rstrip() for l in scr.display).rstrip()
def norm(x): return re.sub(" +", " ", re.sub("[▁▂▃▄▅▆▇]+", "▁", re.sub(r"\d", "#", x)))   # live numbers and the Dashboard history sparkline change without a repaint being late
def pump(t):
    global alive
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.02)
        if r:
            try: d = os.read(fd, 65536)
            except OSError: alive = False; return
            if not d: alive = False; return
            raw.extend(d); chunks.append(len(d))
            # a real terminal ends an unterminated OSC at the next ESC and ignores APC; pyte does not, and went blind after the first TUI exit (a program started after another one)
            # a read can end between an OSC/APC and the ESC that closes it, and then the lookahead below cannot see it, so pyte swallowed everything after (an intermittent blind screen); hold an unfinished one back until the next read
            global pend
            pend += d; m = re.search(rb"(?:\x1b\][^\x1b\x07]*)+\x1b?$|\x1b_[^\x1b]*\x1b?$|\x1b$", pend); hold = b""
            if m: hold, pend = pend[m.start():], pend[:m.start()]
            st.feed(re.sub(rb"\x1b_[^\x1b]*\x1b\\", b"", re.sub(rb"\x1b\](?:11[01]|10[01])(?=\x1b)", b"", pend))); pend = hold
K = {"DOWN": "\x1b[B", "UP": "\x1b[A", "LEFT": "\x1b[D", "RIGHT": "\x1b[C", "ENTER": "\r", "SPACE": " ", "PGDN": "\x1b[6~", "END": "\x1b[F", "ESC": "\x1b", "TAB": "\t", "BS": "\x7f"}
def waitfor(w, cap):
    t0 = time.time()
    while time.time() - t0 < cap and alive:
        pump(0.2)
        if w in text(): return True
    return False
def waitany(ws, cap):
    t0 = time.time()
    while time.time() - t0 < cap and alive:
        pump(0.2)
        if any(w in text() for w in ws): return True
    return False
for s in steps:
    k = s[0]
    if k == "wait": ok = waitany(s[1].split("|"), s[2] if len(s) > 2 else 60); print("WAIT", s[1], "ok" if ok else "MISSING"); pump(0.8)
    elif k == "key" or k == "send": os.write(fd, K.get(s[1], s[1]).encode()); pump(0.6)
    elif k == "resize":
        sz(s[1], s[2]); scr.resize(s[1], s[2]); t0 = time.time(); seen = []
        while time.time() - t0 < 3.2 and alive: pump(0.02); seen.append((time.time() - t0, norm(text())))
        final = seen[-1][1] if seen else ""; ms = next((int(t * 1000) for t, x in seen if x == final), -1)
        print("RESIZE_MS", ms)
        if ms > 300 and seen:   # show what kept changing (live numbers, a spinner) so a late repaint can be told from live data
            for a, b in zip(seen[len(seen) // 10][1].split("\n"), final.split("\n")):
                if a != b: print("RESIZE_DIFF", repr(a), "->", repr(b))
    elif k == "snap": pump(0.4); print("=== " + s[1]); print(text())
    elif k == "type":
        for ch in s[1]: os.write(fd, ch.encode()); pump(0.05)
        pump(0.4)
    elif k == "settle":   # wait until the screen has not changed for s[1] seconds (cap 25 s)
        last, t_last, t0 = text(), time.time(), time.time()
        while time.time() - t0 < 25 and time.time() - t_last < s[1] and alive:
            pump(0.1); x = text()
            if x != last: last, t_last = x, time.time()
    elif k == "mark": print("MARK", s[1], int(time.time()))
    elif k == "sleep": pump(s[1])
# pyte has no alternate screen and swallows text after an unterminated OSC, so what a program prints after the TUI leaves is read from the raw bytes
if raw.rfind(b"\x1b[?1049l") > raw.rfind(b"\x1b[?1049h"): print("RAW", raw.split(b"\x1b[?1049l")[-1].decode("utf-8", "replace").replace("\r", " ").replace("\n", " ").strip()[:300])
if extra.get("HH_DRIVE_RAW"): open(extra["HH_DRIVE_RAW"], "wb").write(bytes(raw)); open(extra["HH_DRIVE_RAW"] + ".chunks", "w").write(json.dumps(chunks))   # the exact bytes the program wrote, for telling a program bug from a pyte parsing artifact
print("ALIVE", "true" if alive else "false")
if not alive:
    for _ in range(50):
        try: r = os.waitpid(pid, os.WNOHANG)
        except Exception: break
        if r[0]: print("EXIT", os.WEXITSTATUS(r[1])); break
        time.sleep(0.1)
try: os.kill(pid, 9)
except Exception: pass
