# sched-prompt.py HH ANSWER...: run `host-hygiene.sh schedule on` in a pty, type each ANSWER at the prompt, print everything shown.
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], [sys.argv[1], "schedule", "on"])
out = b""
def rd(t):
    global out
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try: out += os.read(fd, 4096)
            except OSError: return
for a in sys.argv[2:]:
    rd(1.5); os.write(fd, (a + "\r").encode())
rd(2); print(out.decode(errors="replace").replace("\r", ""))
