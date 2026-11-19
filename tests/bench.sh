#!/usr/bin/env bash
# bench.sh: repeatable resource numbers for host-hygiene. Read-only. bash 3.2.
#   bench.sh [--home DIR | --real] [--tui]
#     --home DIR  run guard/profile/plan with env -i HOME=DIR (default: a fresh fake developer home from make-dev-home.sh in a temp dir)
#     --real      use the real HOME and real PATH (read-only scans; plan can take a while)
#     --tui       also sample the TUI idle CPU and RSS in a pty (needs python3; ~45 s; needs DIR/.config/host-hygiene/config)
# Output: "bench <key> <value>" lines; keys: load1 guard_s profile_s plan_cold_s plan_warm_s binary_bytes folder_kb [tui_idle_cpu_pct tui_idle_rss_kb].
# plan_cold uses an empty app-size cache, plan_warm the cache that run filled (see nondev.sh nd_appkb). Seconds come from perl Time::HiRes.
HERE="$(cd "$(dirname "$0")" && pwd -P)"; D="$(dirname "$HERE")"; HH="$D/scripts/host-hygiene.sh"
MODE=fake; HOME_DIR=""; TUI=0
while [ $# -gt 0 ]; do case "$1" in --home) MODE=home; HOME_DIR="$2"; shift 2 ;; --real) MODE=real; shift ;; --tui) TUI=1; shift ;; *) echo "usage: bench.sh [--home DIR | --real] [--tui]" >&2; exit 2 ;; esac; done
SCR="$(mktemp -d "${TMPDIR:-/tmp}/hh-bench.XXXXXX")"; trap 'rm -rf "$SCR"' EXIT
if [ "$MODE" = fake ]; then HOME_DIR="$SCR/home"; bash "$HERE/make-dev-home.sh" "$HOME_DIR" >/dev/null 2>&1; fi
SAFE=/usr/bin:/bin:/usr/sbin:/sbin
run() {   # run NAME args... : wall seconds of a command, stdout/stderr discarded; HH_* env passes through env -i or not
  perl -MTime::HiRes=time -e '$t=time; if(!($p=fork)){ open STDIN,"<","/dev/null"; open STDOUT,">","/dev/null"; open STDERR,">&STDOUT"; exec @ARGV; exit 127 } waitpid($p,0); printf "%.2f", time-$t' -- "$@"
}
if [ "$MODE" = real ]; then E=(env HH_NO_PROMPT=1); else E=(env -i HOME="$HOME_DIR" PATH="$SAFE" HH_NO_PROMPT=1 HH_MIN_MB=10); fi
CACHE="$SCR/appcache"
echo "bench uptime $(uptime | sed 's/^ *//')"
echo "bench load1 $(uptime | sed -E 's/.*averages?: ([0-9.]+).*/\1/')"
echo "bench guard_s $(run "${E[@]}" "$HH" guard --quiet)"
echo "bench profile_s $(run "${E[@]}" "$HH" profile --tsv)"
echo "bench plan_cold_s $(run "${E[@]}" HH_CACHE_DIR="$CACHE" "$HH" plan --tsv)"
echo "bench plan_warm_s $(run "${E[@]}" HH_CACHE_DIR="$CACHE" "$HH" plan --tsv)"
echo "bench binary_bytes $(stat -f %z "$D/tui/hh_tui" 2>/dev/null || echo 0)"
echo "bench folder_kb $(du -sk "$D" 2>/dev/null | cut -f1)"
if [ "$TUI" = 1 ] && command -v python3 >/dev/null 2>&1 && [ -x "$D/tui/hh_tui" ]; then
  mkdir -p "$HOME_DIR/.config/host-hygiene"; [ -f "$HOME_DIR/.config/host-hygiene/config" ] || printf 'min_free_gb=15\nhard_gb=5\nmax_load=8\n' > "$HOME_DIR/.config/host-hygiene/config"
  python3 -I "$HERE/tui-idle.py" "$HOME_DIR" 2>/dev/null | awk '$1=="idle_cpu_pct"{print "bench tui_idle_cpu_pct " $2} $1=="idle_rss_kb"{print "bench tui_idle_rss_kb " $2}'
fi
