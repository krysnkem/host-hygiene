#!/usr/bin/env bash
# UI Phase 1+2: all six looks. ui= config, HH_LOOK, fallback to the plain look, `config get/set` round trip.
# Usage: check-look.sh [SCRATCH_DIR]   (TUI part needs pyte: HH_PYTHON=a python with it, and tui/hh_tui built)
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"; S="${1:-$(mktemp -d)}"; mkdir -p "$S"; HH="$D/scripts/host-hygiene.sh"
PY="${HH_PYTHON:-python3}"; "$PY" -c 'import pyte' 2>/dev/null && TUI=1 || TUI=0
pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1 :: $2"; }
eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want '$3' got '$2'"; }
has() { printf '%s' "$2" | grep -Fq -- "$3" && ok "$1" || bad "$1" "missing '$3'"; }
hasnt() { printf '%s' "$2" | grep -Fq -- "$3" && bad "$1" "unexpected '$3'" || ok "$1"; }
C="$S/cfg"; rm -f "$C"
g() { env -u HH_LOOK HH_CONFIG="$C" "$@" "$HH" config get ui; }
echo "== config get/set round trip"
eq "default is guided (no file)" "$(g)" guided
env HH_CONFIG="$C" "$HH" config set ui plain >/dev/null; eq "set ui=plain, get plain" "$(g)" plain
has "file holds ui=plain" "$(cat "$C")" "ui=plain"
env HH_CONFIG="$C" "$HH" config set min_free_gb 20 >/dev/null; eq "numeric set leaves ui" "$(g)" plain
eq "numeric get" "$(env HH_CONFIG="$C" "$HH" config get min_free_gb)" 20
eq "numeric get default" "$(env HH_CONFIG="$C" "$HH" config get max_load)" 8
env HH_CONFIG="$C" "$HH" config set ui guided >/dev/null; eq "set ui=guided back" "$(g)" guided
eq "one ui line only" "$(grep -c '^ui=' "$C")" 1
env HH_CONFIG="$C" "$HH" config set ui bogus 2>/dev/null; eq "bogus ui rejected (exit 2)" "$?" 2
eq "rejected value not stored" "$(g)" guided
printf 'ui=weird\n' > "$C"; eq "unknown ui in file -> guided" "$(g)" guided
printf 'ui=plain\n' > "$C"; eq "HH_LOOK beats config" "$(HH_LOOK=guided env HH_CONFIG="$C" "$HH" config get ui)" guided
eq "HH_LOOK=plain beats config guided" "$(printf 'ui=guided\n' > "$C"; HH_LOOK=plain env HH_CONFIG="$C" "$HH" config get ui)" plain
eq "unknown HH_LOOK ignored, config used" "$(printf 'ui=plain\n' > "$C"; HH_LOOK=nope env HH_CONFIG="$C" "$HH" config get ui)" plain
has "config show lists ui" "$(env -u HH_LOOK HH_CONFIG="$C" "$HH" config show)" "ui=plain"
echo "== every look id: config round trip, HH_LOOK, unknown fallback"
for L in guided plain cockpit dashboard spacemap console; do
  env HH_CONFIG="$C" "$HH" config set ui "$L" >/dev/null; eq "set/get ui=$L" "$(g)" "$L"
  eq "HH_LOOK=$L beats ui=guided" "$(printf 'ui=guided\n' > "$C"; HH_LOOK=$L env HH_CONFIG="$C" "$HH" config get ui)" "$L"
done
env HH_CONFIG="$C" "$HH" config set ui Cockpit 2>/dev/null; eq "ids are case-sensitive (Cockpit rejected)" "$?" 2
printf 'ui=cockpit\n' > "$C"; eq "unknown HH_LOOK falls to ui=" "$(HH_LOOK=zzz env HH_CONFIG="$C" "$HH" config get ui)" cockpit
printf 'ui=dashbord\n' > "$C"; eq "misspelt ui= falls to guided" "$(g)" guided
has "UI_LOOKS lists all six" "$(grep '^UI_LOOKS=' "$HH")" "guided plain cockpit dashboard spacemap console"
eq "UI_LOOKS defined once" "$(grep -c '^UI_LOOKS=' "$HH")" 1
if [ "$TUI" = 0 ] || [ ! -x "$D/tui/hh_tui" ]; then echo "SKIP TUI part: need pyte (HH_PYTHON) and tui/hh_tui"; echo "passed $pass, failed $fail"; [ "$fail" = 0 ]; exit; fi
echo "== TUI looks (fake home, pty)"
H="$S/home"; rm -rf "$H"; bash "$D/tests/make-dev-home.sh" "$H" >/dev/null; mkdir -p "$H/.config/host-hygiene"
setcfg() { printf 'min_free_gb=1\nhard_gb=0.5\nmax_load=999\n%s' "$1" > "$H/.config/host-hygiene/config"; }
run() { "$PY" "$D/tests/look-seam.py" "$H" "$@"; }
setcfg ""; o="$(run 24 80)"; has "default look is guided (stepper)" "$o" "2 Pick"; has "default shows Hy" "$o" "Hy"
setcfg "ui=plain"; o="$(run 24 80)"; has "ui=plain: plain header" "$o" "host-hygiene  Pick"; hasnt "ui=plain: no stepper" "$o" "2 Pick"; has "ui=plain: list drawn" "$o" "[ ]"
setcfg "ui=weird"; o="$(run 24 80)"; has "unknown ui falls back to guided" "$o" "2 Pick"
setcfg "ui=plain"; o="$(run 24 80 HH_LOOK=guided)"; has "HH_LOOK=guided beats ui=plain" "$o" "2 Pick"
setcfg ""; o="$(run 24 80 HH_LOOK=plain)"; has "HH_LOOK=plain beats config" "$o" "host-hygiene  Pick"
setcfg ""; o="$(run 24 80 HH_LOOK_MIN=200x60)"; has "look too big: plain with hint" "$o" "Too small for the Guided journey look"; has "fallback still shows the list" "$o" "[ ]"
o="$(run 24 80 HH_LOOK_MIN=200x60 HH_LOOK=plain)"; hasnt "plain itself never falls back" "$o" "Too small for"
o="$(run 8 60 HH_LOOK=plain)"; has "plain at 8x60 shows the list" "$o" "[ ]"; has "plain at 8x60 shows the keys" "$o" "q quit"
o="$(run 10 70 HH_LOOK_MIN=100x30)"; has "plain at 10x70 via fallback" "$o" "[ ]"
o="$(run 5 60)"; has "below 30x6 keeps the too-small message" "$o" "Too small"
o="$(run 24 80 8x60 HH_LOOK_MIN=100x30)"; has "live resize into fallback keeps the list" "$o" "[ ]"
setcfg ""; rm -f "$H/.config/host-hygiene/config"; printf 'ui=plain\n' > "$H/.config/host-hygiene/config"; o="$(run 24 80)"; has "ui-only config still asks for limits" "$o" "Set the limits"
for L in cockpit dashboard spacemap console; do setcfg "ui=$L"; o="$(run 30 100)"; case $L in spacemap) w="Space map" ;; *) w="v look:" ;; esac; has "config ui=$L draws the $L look" "$o" "$w"; done
[ "${HH_MATRIX:-1}" = 0 ] || . "$D/tests/look-matrix.sh"
echo "passed $pass, failed $fail"; [ "$fail" = 0 ]
