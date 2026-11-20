#!/usr/bin/env python3
"""pty-run.py CMD [ARGS...]: run CMD with a terminal for stdin and stdout, print what it wrote, exit with its status (124 after 20 s). For tests of scripts that insist on a tty."""
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
out, end = b"", time.time() + 20
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.5)
    if r:
        try: d = os.read(fd, 4096)
        except OSError: break
        if not d: break
        out += d
    else:
        p, st = os.waitpid(pid, os.WNOHANG)
        if p: break
else:
    sys.stdout.write(out.decode("utf-8", "replace").replace("\r", "")); sys.exit(124)
try: _, st = os.waitpid(pid, 0)
except ChildProcessError: st = 0
sys.stdout.write(out.decode("utf-8", "replace").replace("\r", "")); sys.exit(os.waitstatus_to_exitcode(st))
