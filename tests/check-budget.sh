#!/usr/bin/env bash
# check-budget.sh: fail when a resource cap is exceeded. Timing caps are only enforced when the 1-minute load is below 8
# (otherwise: "SKIP-load", exit 0), because timings under load are not trustworthy. Size caps are always enforced. bash 3.2.
#   check-budget.sh [--home DIR | --real] [--tui]     (arguments go to bench.sh)
# Caps: guard < 0.2 s, profile < 1.0 s, plan warm < 5 s (fake developer home), TUI idle CPU < 1 %, TUI binary <= 9437184 bytes
# (the 2026-11-18 baseline 7975296 + growth; one binary per chip is shipped), skill folder <= 18000 KB (room for both chips' binaries; dist/ and .git are not counted).
HERE="$(cd "$(dirname "$0")" && pwd -P)"
OUT="$(bash "$HERE/bench.sh" "$@")"; echo "$OUT"
v() { printf '%s\n' "$OUT" | awk -v k="$1" '$1=="bench" && $2==k{print $3; exit}'; }
FAIL=0
over() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
chk() {   # name value cap kind(time|size)
  [ -n "$2" ] || return 0
  if over "$2" "$3"; then
    if [ "$4" = time ] && [ "$LOADHIGH" = 1 ]; then echo "SKIP-load $1 $2 > $3 (load $LOAD >= 8: not trustworthy)"; else echo "FAIL $1 $2 > cap $3"; FAIL=$((FAIL+1)); fi
  else echo "PASS $1 $2 <= $3"; fi
}
LOAD="$(v load1)"; LOADHIGH=0; over "$LOAD" 7.999 && LOADHIGH=1
chk guard_s "$(v guard_s)" 0.2 time
chk profile_s "$(v profile_s)" 1.0 time
chk plan_warm_s "$(v plan_warm_s)" 5 time
chk tui_idle_cpu_pct "$(v tui_idle_cpu_pct)" 1 time
chk binary_bytes "$(v binary_bytes)" 9437184 size
chk folder_kb "$(v folder_kb)" 18000 size
if [ "$FAIL" -gt 0 ]; then echo "budget: $FAIL cap(s) exceeded"; exit 1; fi
[ "$LOADHIGH" = 1 ] && echo "budget: timing caps skipped or advisory (SKIP-load), size caps passed" || echo "budget: ok"
exit 0
