#!/usr/bin/env bash
# check-arch.sh: which interface binary hh picks for this chip, and what `hh focus` does when none can run. Fake trees and a `file` shim only; nothing real is started.
# Usage: check-arch.sh [SCRATCH_DIR]     bash 3.2. Uses tests/pty-run.py (a pty) for the focus cases.
D="$(cd "$(dirname "$0")/.." && pwd)"; S="${1:-$(mktemp -d)}"; mkdir -p "$S"; pass=0; fail=0
ok() { pass=$((pass+1)); }; bad() { fail=$((fail+1)); echo "FAIL $1 :: $2"; }
eq() { [ "$2" = "$3" ] && ok || bad "$1" "want '$3' got '$2'"; }
has() { case "$2" in *"$3"*) ok ;; *) bad "$1" "missing '$3'" ;; esac; }; hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected '$3'" ;; *) ok ;; esac; }
T="$S/t"; rm -rf "$T"; mkdir -p "$T/tui" "$S/bin"; cp -R "$D/scripts" "$T/scripts"; HHT="$T/scripts/host-hygiene.sh"
# A `file` that reads "# ARCH=x" from our fake binaries, so tests need no real Mach-O files.
printf '#!/bin/sh\nf="$2"; a="$(sed -n "s/^# ARCH=//p" "$f" 2>/dev/null | head -1)"; if [ -n "$a" ]; then echo "Mach-O 64-bit executable $a"; else echo "ASCII text executable"; fi\n' > "$S/bin/file"; chmod +x "$S/bin/file"
fake() { printf '#!/bin/sh\n# ARCH=%s\necho "FAKE-TUI focus=$HH_FOCUS"\n' "$2" > "$T/tui/$1"; chmod +x "$T/tui/$1"; }
pick() { env PATH="$S/bin:$PATH" HH_ARCH="$1" "$HHT" --tui-bin 2>/dev/null; echo "rc=$?"; }
echo "== which binary"
o="$(pick arm64)"; eq "no binary: none" "$o" "rc=1"
fake hh_tui-x86_64 x86_64; o="$(pick arm64)"; eq "only the Intel binary on Apple Silicon: none (it cannot run)" "$o" "rc=1"
o="$(pick x86_64)"; eq "the Intel binary on Intel" "$o" "$T/scripts/../tui/hh_tui-x86_64
rc=0"
fake hh_tui-arm64 arm64; o="$(pick arm64)"; eq "both present: the one for this chip" "$o" "$T/scripts/../tui/hh_tui-arm64
rc=0"
rm "$T/tui/hh_tui-"*; fake hh_tui arm64; o="$(pick arm64)"; eq "legacy hh_tui for this chip" "$o" "$T/scripts/../tui/hh_tui
rc=0"; o="$(pick x86_64)"; eq "legacy hh_tui for the other chip: none" "$o" "rc=1"
printf '#!/bin/sh\necho plain\n' > "$T/tui/hh_tui"; chmod +x "$T/tui/hh_tui"; o="$(pick arm64)"; eq "an executable that is not a Mach-O: none" "$o" "rc=1"
fake hh_tui arm64; chmod -x "$T/tui/hh_tui"; o="$(pick arm64)"; eq "not executable: none" "$o" "rc=1"
real="$("$D/scripts/host-hygiene.sh" --tui-bin 2>/dev/null)"; if [ -x "$D/tui/hh_tui" ]; then eq "the real binary runs here" "$real" "$D/scripts/../tui/hh_tui"; fi
echo "== hh focus without a usable interface"
PSF="$S/ps.txt"; printf '  PID  %%CPU    RSS COMM\n  1 1.0 2000000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome\n' > "$PSF"; rm -f "$T/tui/"*
run() { env PATH="$S/bin:$PATH" HH_ARCH=arm64 HH_PS_FILE="$PSF" HH_CONFIG="$S/cfg" python3 "$D/tests/pty-run.py" "$HHT" "$@" </dev/null 2>&1; }
o="$(run focus perf cpu)"; has "says why" "$o" "not available on this machine"; has "shows the text report for a CPU click" "$o" "apps by impact"; has "names the app" "$o" "Google Chrome"; hasnt "no bare error" "$o" "needs the built front end"
o="$(run focus perf mem)"; has "memory click: text report too" "$o" "apps by impact"
o="$(run focus)"; has "disk click: the guard line" "$o" "free"; has "and the next step" "$o" "hh plan"
fake hh_tui-x86_64 x86_64; o="$(run focus perf cpu)"; has "the wrong chip's binary is not launched" "$o" "not available on this machine"; hasnt "and never started" "$o" "FAKE-TUI"
fake hh_tui-arm64 arm64; o="$(run focus perf cpu)"; has "the right binary is launched" "$o" "FAKE-TUI focus=perf-cpu"; o="$(run focus perf mem)"; has "with the memory screen asked for" "$o" "FAKE-TUI focus=perf-mem"
o="$(env PATH="$S/bin:$PATH" HH_ARCH=arm64 "$HHT" focus </dev/null 2>&1; echo "rc=$?")"; has "a script (no terminal) still gets the error and exit 2" "$o" "rc=2"
echo "== release packaging (tools/make-release.sh)"
MR="$D/tools/make-release.sh"
if [ -x "$D/tui/hh_tui" ] && file -b "$D/tui/hh_tui" | grep -q "Mach-O.*arm64"; then
  o="$("$MR" "$S/rel" 2>&1; echo "rc=$?")"; has "no Intel binary given: refuses" "$o" "set HH_BIN_X64"; has "with exit 2" "$o" "rc=2"
  o="$(HH_BIN_X64="$D/tui/hh_tui" "$MR" "$S/rel" 2>&1; echo "rc=$?")"; has "an arm64 file given as the Intel one: refuses" "$o" "is not an x86_64 Mach-O"
  o="$(HH_BIN_ARM64="$S/ps.txt" HH_BIN_X64="$D/tui/hh_tui" "$MR" "$S/rel" 2>&1; echo "rc=$?")"; has "a text file given as the arm64 one: refuses" "$o" "is not an arm64 Mach-O"
  if [ -n "${HH_TEST_X64:-}" ] && [ -f "$HH_TEST_X64" ]; then   # full build when an Intel binary is supplied (HH_TEST_X64=path)
    rm -rf "$S/rel"; o="$(HH_BIN_X64="$HH_TEST_X64" "$MR" "$S/rel" 2>&1; echo "rc=$?")"; has "both binaries: builds" "$o" "rc=0"; L="$(tar -tzf "$S/rel"/host-hygiene-*.tar.gz)"
    has "the archive has the arm64 binary" "$L" "tui/hh_tui-arm64"; has "and the Intel binary" "$L" "tui/hh_tui-x86_64"; hasnt "and no unnamed legacy binary" "$L" "tui/hh_tui
"; hasnt "and no personal files" "$L" "apply-log"; hasnt "and no git metadata" "$L" ".git/"
  fi
fi
echo "passed $pass, failed $fail"; [ "$fail" = 0 ]
