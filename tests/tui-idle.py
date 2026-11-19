#!/usr/bin/env python3
# usage: [HH_LOOK=id] [HH_IDLE_MARK=text] tui-idle.py HOME [BINARY] ; (HH_LOOK picks the look; HH_IDLE_MARK is text that shows once Pick is up, default "space tick"; guided/cockpit: Selected, console: SIZE)  HOME needs ~/.config/host-hygiene/config so the Pick screen is reached. Prints "idle_cpu_pct <n>" and "idle_rss_kb <n>" last. Samples ps %cpu,rss 5x at Look (typing) and Pick (idle) screens, and CPU time delta over 10 s idle
import pty, os, sys, time, select, struct, fcntl, termios, subprocess
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
home = sys.argv[1]; binp = sys.argv[2] if len(sys.argv) > 2 else D + "/tui/hh_tui"
env = {"HOME": home, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HH_SCRIPT": D + "/scripts/host-hygiene.sh", "HH_NO_PROMPT": "1", "HH_HOME": "0", "HH_MIN_MB": "10",
       "HH_LOOK": os.environ.get("HH_LOOK", ""), "TERM": "xterm-256color", "LANG": "en_US.UTF-8", "HH_DC_PS_FILE": "/dev/null", "HH_APPS_DIR": "/nonexistent"}
pid, fd = pty.fork()
if pid == 0: os.execve(binp, [binp], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
buf = b""
def pump(t):
    global buf
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: d = os.read(fd, 65536)
            except OSError: return
            buf += d
def ps(): 
    o = subprocess.run(["ps","-o","%cpu=,rss=,cputime=","-p",str(pid)],capture_output=True,text=True).stdout.split()
    return o
def cpusec(t):   # ps cputime "M:SS.cc" -> seconds
    m, r = t.split(":"); return int(m) * 60 + float(r)
def snap(label, n=5, gap=1.0):
    for i in range(n):
        pump(gap); print(label, "ps %cpu rss(KB) cputime:", ps(), flush=True)
pump(0.3); snap("look", 5, 0.6)
# wait for speech to end and pick screen
t0=time.time()
while time.time()-t0 < 90 and os.environ.get("HH_IDLE_MARK", "space tick").encode() not in buf: pump(0.5)
pump(15)  # let speech finish
snap("pick", 5, 2.0)
a = ps(); pump(10); b = ps(); print("pick 10s window cputime before/after:", a[2], b[2])
print("idle_cpu_pct %.2f" % ((cpusec(b[2]) - cpusec(a[2])) / 10 * 100)); print("idle_rss_kb", b[1])
n0=len(buf); pump(5); print("bytes drawn in 5 s idle:", len(buf)-n0)
os.write(fd, b"q"); pump(0.5)
