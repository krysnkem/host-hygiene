#!/usr/bin/env bash
# perf.sh: R6 CPU/memory report + advice. Read-only: reads ps/uptime/AVD config, writes nothing, kills nothing.
#   perf.sh [report]      load, top CPU, top memory, advice
#   perf.sh advice        advice only (used by `host-hygiene.sh scan`)
# Test seams: HH_PS_FILE = ps output fixture (header + "pid pcpu rss(KB) comm"), HH_UPTIME_FILE = uptime text,
#             HH_AVD_DIR = AVD directory (default ~/.android/avd), HH_TOPN (default 8).
set -u
MODE="${1:-report}"; N="${HH_TOPN:-8}"; AVD="${HH_AVD_DIR:-$HOME/.android/avd}"
PS_OUT="$(if [ -n "${HH_PS_FILE:-}" ]; then cat "$HH_PS_FILE"; else ps -Aceo pid,pcpu,rss,comm; fi)"
UP="$(if [ -n "${HH_UPTIME_FILE:-}" ]; then cat "$HH_UPTIME_FILE"; else uptime; fi)"
L1="$(printf '%s' "$UP" | sed 's/.*load averages*: *//' | awk '{gsub(/,/,"");print $1}')"
ROWS="$(printf '%s\n' "$PS_OUT" | awk 'NR>1 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ {c=$4; for(i=5;i<=NF;i++)c=c" "$i; print $1"\t"$2"\t"$3"\t"c}')"
TOPC="$(printf '%s\n' "$ROWS" | sort -t"$(printf '\t')" -k2,2nr | head -n "$N")"
TOPM="$(printf '%s\n' "$ROWS" | sort -t"$(printf '\t')" -k3,3nr | head -n "$N")"

if [ "$MODE" != advice ]; then
  echo "== cpu/memory  (report only; nothing is killed)"
  echo "load      $(printf '%s' "$UP" | sed 's/.*load averages*: *//')   (1/5/15 min; guide: <8 fine, >8 numbers untrustworthy)"
  if awk -v l="$L1" 'BEGIN{exit !(l>=8)}'; then echo "          load $L1 is at/above 8: the figures below are NOT trustworthy; re-measure when idle"; fi
  echo "  top $N by CPU (pcpu is a decayed average, ps and top differ by sampling)"
  printf '%s\n' "$TOPC" | awk -F'\t' '{printf "    cpu %6s%%  %7dM  %s\n",$2,$3/1024,$4}'
  echo "  top $N by memory (rss)"
  printf '%s\n' "$TOPM" | awk -F'\t' '{printf "    mem %7dM  %5s%%  %s\n",$3/1024,$2,$4}'
fi

TOP="$(printf '%s\n%s\n' "$TOPC" "$TOPM" | cut -f4)"
has() { printf '%s\n' "$TOP" | grep -Eq "$1"; }
out=""
add() { out="$out$1
"; }
if has '^(mds|mds_stores|mdworker|mdworker_shared|corespotlightd)'; then
  add "  Spotlight (mds/mdworker) is in the top list: it is indexing. Exclude build-heavy folders by hand (this tool never changes it):"
  add "    System Settings > Spotlight > Search Privacy... > + > pick ~/.gradle, ~/.android and each project's build/ (in the picker press Cmd+Shift+. to show hidden folders)."
  add "    Effect on load: (unmeasured)."
fi
has '^WindowServer$' && add "  WindowServer is in the top list: it follows screen/animation load; fewer windows, a lower display scale, or closing emulator windows helps. Nothing is killed."
has '^mediaanalysisd' && add "  mediaanalysisd is in the top list: Photos analysing the library; it settles when Photos has finished (leave the Mac on power, idle). Nothing is killed."
if has '^(WhatsApp|Telegram|Slack|Discord|Signal|Messenger|zoom\.us|Microsoft Teams)'; then
  add "  A chat app is in the top list: close it during measured builds/emulator runs (your call; nothing is closed for you)."
fi
if has 'qemu-system|^emulator'; then
  add "  Emulator (qemu) is in the top list. Fewer concurrent emulators and lower RAM help. AVD hw.ramSize (read-only from $AVD):"
  found=0
  for ini in "$AVD"/*.avd/config.ini; do
    [ -f "$ini" ] || continue; found=1
    r="$(sed -n 's/^hw\.ramSize *= *//p' "$ini" | head -1 | tr -cd '0-9')"
    n="$(basename "$(dirname "$ini")" .avd)"
    if [ -z "$r" ]; then add "    $n: hw.ramSize not set (suggest: leave default or set 2048)"
    elif [ "$r" -gt 2048 ] 2>/dev/null; then add "    $n: $r MB now; suggest 2048 (proposal, (verify) the app still runs)"
    else add "    $n: $r MB now; already modest, suggest keeping it and running fewer emulators at once"; fi
  done
  [ "$found" = 0 ] && add "    no AVD config.ini found under $AVD"
  add "    Edit by hand: Android Studio > Device Manager > edit AVD > Show Advanced Settings > RAM (or hw.ramSize in config.ini with the emulator stopped)."
fi
if [ -n "$out" ]; then echo "== advice (suggestions only; never applied, no process is killed)"; printf '%s' "$out"
elif [ "$MODE" != advice ]; then echo "== advice: no known offender in the top $N lists"; fi
exit 0
