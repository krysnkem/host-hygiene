#!/usr/bin/env bash
# check-home.sh: the Home screen (Storage, Memory, CPU, Alarms, Settings): where it appears, what each key opens, and that nothing is closed. Fake homes only.
# Usage: HH_PYTHON=<python with pyte> check-home.sh [SCRATCH_DIR]     Needs tui/hh_tui built. bash 3.2.
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"; S="${1:-$(mktemp -d)}"; mkdir -p "$S"; HH="$D/scripts/host-hygiene.sh"; PY="${HH_PYTHON:-python3}"; pass=0; fail=0
"$PY" -c 'import pyte' 2>/dev/null || { echo "SKIP: need pyte (HH_PYTHON)"; exit 0; }; [ -x "$D/tui/hh_tui" ] || { echo "SKIP: tui/hh_tui not built"; exit 0; }
ok() { pass=$((pass+1)); }; bad() { fail=$((fail+1)); echo "FAIL $1 :: $2"; }
has() { case "$2" in *"$3"*) ok ;; *) bad "$1" "missing '$3'" ;; esac; }; hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected '$3'" ;; *) ok ;; esac; }
DEV="$S/devhome"; rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; mkdir -p "$DEV/.config/host-hygiene"
cfg() { printf 'min_free_gb=%s\nhard_gb=1\nmax_load=8\nui=%s\n' "${2:-100000}" "$1" > "$DEV/.config/host-hygiene/config"; }
sect() { printf '%s' "$1" | sed -n "/=== $2/,/=== $3/p"; }
drv() { local r="$1" c="$2" st="$3"; shift 3; "$PY" "$D/tests/look-drive.py" "$DEV" "$r" "$c" "$st" HH_BIN="$HH" HH_NO_PROMPT=0 HH_HOME=1 HH_MEM_FREE_PCT=31 HH_LOAD5=12.5 HH_NCPU=10 HH_MEMSIZE=34359738368 "$@" 2>&1 | grep -v ^WAIT; }
W='"wait","Home|home|need attention|need|Everything looks fine",150'
echo "== Home appears after the scan, in each look and size"
for L in console cockpit guided dashboard spacemap; do cfg $L
  o="$(drv 24 80 "[[$W],[\"sleep\",1],[\"snap\",\"h\"]]")"; has "$L 24x80: Storage row" "$o" "Storage"; has "$L 24x80: Memory row" "$o" "Memory"; has "$L 24x80: CPU row" "$o" "CPU"; has "$L 24x80: Alarms" "$o" "Alarms"; has "$L 24x80: Settings" "$o" "Settings"
  if [ "$L" = cockpit ]; then has "$L 24x80: storage floor in the panel" "$o" "floor 100000 GiB"; else has "$L 24x80: storage is below the floor" "$o" "below the 100000 GiB floor"; fi; hasnt "$L 24x80: Pick is not shown first" "$o" "Pick what to clear"
done
for sz in "12 60" "10 70"; do set -- $sz; cfg console; o="$(drv $1 $2 "[[$W],[\"sleep\",1],[\"snap\",\"h\"]]")"; has "console $1x$2: rows fit" "$o" "Storage"; has "console $1x$2: CPU row" "$o" "CPU"; done
echo "== keys: open each area and come back"
cfg console; o="$(drv 24 80 "[[$W],[\"key\",\"s\"],[\"wait\",\"Pick what to clear|hh console\",60],[\"sleep\",1],[\"snap\",\"pick\"],[\"key\",\"ESC\"],[\"sleep\",1],[\"snap\",\"back\"]]")"
has "s opens Storage (the pick list)" "$(sect "$o" pick back)" "work/app/build"; has "Esc from Storage returns to Home" "$(sect "$o" back zzz)" "m Memory"
o="$(drv 24 80 "[[$W],[\"key\",\"m\"],[\"wait\",\"Memory: \",30],[\"snap\",\"m\"],[\"key\",\"ESC\"],[\"sleep\",1],[\"snap\",\"back\"],[\"key\",\"c\"],[\"wait\",\"CPU: load\",30],[\"snap\",\"c\"],[\"key\",\"ESC\"],[\"sleep\",1],[\"snap\",\"back2\"]]")"
has "m opens Memory" "$(sect "$o" m back)" "Memory: 31% free"; has "Esc from Memory returns to Home" "$(sect "$o" back c)" "c CPU"; has "c opens CPU" "$(sect "$o" c back2)" "CPU: load 12.5"; has "Esc from CPU returns to Home" "$(sect "$o" back2 zzz)" "g Settings"
o="$(drv 24 80 "[[$W],[\"key\",\"DOWN\"],[\"key\",\"DOWN\"],[\"key\",\"ENTER\"],[\"wait\",\"CPU: load\",30],[\"snap\",\"e\"]]")"; has "arrows and Enter open the highlighted area" "$o" "CPU: load 12.5"
o="$(drv 24 80 "[[$W],[\"key\",\"r\"],[\"sleep\",3],[\"snap\",\"r\"]]")"; has "r rescans and stays on Home" "$o" "m Memory"
o="$(drv 24 80 "[[$W],[\"key\",\"q\"],[\"sleep\",2]]")"; has "q quits from Home" "$o" "ALIVE false"
echo "== Alarms and Settings forms: the same config keys the CLI writes"
cfg console; LD="$S/launch"; rm -rf "$LD" "$S/notified"; mkdir -p "$LD"; printf '#!/bin/sh\necho "$@" >> "%s/notified"\n' "$S" > "$S/notify.sh"; chmod +x "$S/notify.sh"; PL="$LD/local.host-hygiene.check.plist"
fdrv() { drv 24 100 "$1" HH_LAUNCH_DIR="$LD" HH_NO_LAUNCHCTL=1 HH_NOTIFY_CMD="$S/notify.sh"; }
o="$(fdrv "[[$W],[\"key\",\"a\"],[\"wait\",\"Check every\",30],[\"snap\",\"a\"],[\"key\",\"ENTER\"],[\"wait\",\"saved\",30],[\"snap\",\"on\"],[\"key\",\"ENTER\"],[\"wait\",\"alarms off\",30],[\"snap\",\"off\"]]")"
a="$(sect "$o" a on)"; has "Alarms rows" "$a" "Disk floor"; has "Alarms: memory line" "$a" "Memory line"; has "Alarms: quiet hours" "$a" "Quiet hours"; has "Alarms: test alert" "$a" "Test alert"; has "Alarms: checks start off" "$a" "Checks        off"
has "Enter on Checks turns alarms on" "$(sect "$o" on off)" "alarms on"; has "the schedule is the same launchd job as hh schedule on" "$(ls "$PL" 2>&1)" "local.host-hygiene.check.plist"; hasnt "Enter again turns it off (plist gone)" "$(ls "$PL" 2>&1)" "check.plist
"
o="$(fdrv "[[$W],[\"key\",\"a\"],[\"wait\",\"Check every\",30],[\"key\",\"DOWN\"],[\"key\",\"ENTER\"],[\"key\",\"BS\"],[\"key\",\"BS\"],[\"type\",\"45\"],[\"key\",\"ENTER\"],[\"wait\",\"saved\",30],[\"snap\",\"e\"]]")"
has "editing a number saves it" "$(sect "$o" e zzz)" "45 min"; has "the config line is the CLI's" "$(cat "$DEV/.config/host-hygiene/config")" "check_every_min=45"
o="$(fdrv "[[$W],[\"key\",\"a\"],[\"wait\",\"Check every\",30],[\"key\",\"DOWN\"],[\"key\",\"ENTER\"],[\"key\",\"BS\"],[\"key\",\"BS\"],[\"type\",\"3\"],[\"key\",\"ENTER\"],[\"wait\",\"must be\",30],[\"snap\",\"x\"]]")"
has "a bad value shows the CLI's own message" "$(sect "$o" x zzz)" "5 to 1440"; has "and is not saved" "$(cat "$DEV/.config/host-hygiene/config")" "check_every_min=45"
o="$(fdrv "[[$W],[\"key\",\"a\"],[\"wait\",\"Check every\",30],[\"key\",\"t\"],[\"wait\",\"test notification\",30],[\"snap\",\"t\"]]")"
has "t sends the test alert" "$(sect "$o" t zzz)" "test notification sent"; has "through the notify command" "$(cat "$S/notified" 2>&1)" "host-hygiene test"
o="$(fdrv "[[$W],[\"key\",\"a\"],[\"wait\",\"Check every\",30],[\"key\",\"ESC\"],[\"sleep\",1],[\"snap\",\"b\"]]")"; has "Esc from Alarms returns to Home" "$(sect "$o" b zzz)" "g Settings"
o="$(fdrv "[[$W],[\"key\",\"g\"],[\"wait\",\"Look\",30],[\"key\",\"DOWN\"],[\"key\",\"ENTER\"],[\"type\",\"Ada\"],[\"key\",\"ENTER\"],[\"wait\",\"saved\",30],[\"snap\",\"s\"],[\"key\",\"UP\"],[\"key\",\"ENTER\"],[\"wait\",\"Choose a look\",30],[\"snap\",\"l\"]]")"
has "Settings shows the name saved" "$(sect "$o" s l)" "Ada"; has "the name is the CLI's config line" "$(cat "$DEV/.config/host-hygiene/config")" "name=Ada"; has "Enter on Look opens the chooser" "$(sect "$o" l zzz)" "Choose a look"
for f in form_view.dart form_model.dart; do hasnt "no process control in $f" "$(grep -vE '^\s*//' "$D/tui/lib/$f" | grep -E 'Process\.(kill|start|run)|killPid|pkill|killall|pbcopy|Activity Monitor' )" "Process"; done
echo "== after a clear: back to the menu, then Storage shows a fresh pick"
cfg console; rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; mkdir -p "$DEV/.config/host-hygiene"; cfg console
o="$(drv 24 100 "[[$W],[\"key\",\"s\"],[\"wait\",\"Pick what to clear|hh console\",60],[\"key\",\"s\"],[\"key\",\"ENTER\"],[\"wait\",\"Remove\",20],[\"key\",\"RIGHT\"],[\"key\",\"ENTER\"],[\"wait\",\"for the menu\",120],[\"snap\",\"d\"],[\"key\",\"ENTER\"],[\"sleep\",1],[\"snap\",\"h\"],[\"key\",\"s\"],[\"sleep\",1],[\"snap\",\"p\"]]")"
has "the finished screen offers the menu" "$(sect "$o" d h)" "for the menu"; has "Enter returns to Home" "$(sect "$o" h p)" "m Memory"; hasnt "Storage after a clear is the pick list, not the old result" "$(sect "$o" p zzz)" "for the menu"
rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; mkdir -p "$DEV/.config/host-hygiene"
echo "== ignore (i), restore (Settings) and snooze (z)"
PSF="$S/ps.txt"; printf '  PID  %%CPU    RSS COMM\n  1 1.0 2000000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome\n  3 40 1000000 /opt/homebrew/bin/qemu-system-aarch64\n' > "$PSF"
cfg console; rm -f "$DEV/.config/host-hygiene/state"
o="$(drv 24 100 "[[$W],[\"key\",\"m\"],[\"wait\",\"Google Chrome\",60],[\"snap\",\"m0\"],[\"key\",\"i\"],[\"wait\",\"is ignored\",30],[\"snap\",\"m1\"],[\"key\",\"ESC\"],[\"wait\",\"1 app ignored\",30],[\"snap\",\"h\"]]" HH_PS_FILE="$PSF")"
has "Memory lists the app before" "$(sect "$o" m0 m1)" "Google Chrome"; has "i says it is ignored" "$(sect "$o" m1 h)" "Google Chrome is ignored"; has "the config line is the CLI's" "$(cat "$DEV/.config/host-hygiene/config")" "ignored_apps=Google Chrome"
hasnt "the ignored app leaves the list" "$(sect "$o" m1 h | grep -v 'is ignored')" "Google Chrome"; has "Home counts the ignored apps" "$(sect "$o" h zzz)" "1 app ignored"
o="$(drv 24 100 "[[$W],[\"key\",\"g\"],[\"wait\",\"Look\",30],[\"key\",\"DOWN\"],[\"key\",\"DOWN\"],[\"key\",\"DOWN\"],[\"snap\",\"s\"],[\"key\",\"ENTER\"],[\"wait\",\"named in alarms again\",30],[\"snap\",\"r\"]]" HH_PS_FILE="$PSF")"
has "Settings lists the ignored app" "$(sect "$o" s r)" "Google Chrome"; has "Enter restores it" "$(sect "$o" r zzz)" "named in alarms again"; hasnt "the config no longer ignores it" "$(cat "$DEV/.config/host-hygiene/config")" "Google Chrome"
o="$(drv 24 100 "[[$W],[\"key\",\"m\"],[\"wait\",\"Memory: \",30],[\"key\",\"z\"],[\"wait\",\"snoozed until\",30],[\"snap\",\"z\"]]" HH_PS_FILE="$PSF")"
has "z snoozes the memory alarm" "$o" "snoozed until"; has "the state file holds it" "$(cat "$DEV/.config/host-hygiene/state" 2>&1)" "snooze_mem="
echo "== hh focus (an alarm click): opens on Pick, and Home is still reachable after a clear"
rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; mkdir -p "$DEV/.config/host-hygiene"; cfg console
o="$(drv 24 100 "[[\"wait\",\"Pick what to clear|hh console\",90],[\"snap\",\"p\"],[\"key\",\"s\"],[\"key\",\"ENTER\"],[\"wait\",\"Remove\",20],[\"key\",\"RIGHT\"],[\"key\",\"ENTER\"],[\"wait\",\"for the menu\",120],[\"snap\",\"d\"],[\"key\",\"ENTER\"],[\"sleep\",1],[\"snap\",\"h\"]]" HH_FOCUS=1)"
hasnt "focus mode opens on Pick, not Home" "$(sect "$o" p d)" "m Memory"; has "its finished screen offers the menu" "$(sect "$o" d h)" "for the menu"; has "Enter reaches Home" "$(sect "$o" h zzz)" "m Memory"
rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; mkdir -p "$DEV/.config/host-hygiene"
echo "== look keys work on Home"
cfg cockpit; o="$(drv 24 100 "[[$W],[\"key\",\"v\"],[\"sleep\",2],[\"snap\",\"v\"]]")"; hasnt "v changes the Home look (cockpit panels are gone)" "$o" "╭─ Storage [s]"; has "the new look still shows Home" "$o" "Storage"
echo "== where Home does not appear"
cfg console; o="$(drv 24 80 '[["wait","Pick what to clear|hh console",150],["sleep",1],["snap","p"]]' HH_HOME=0)"; has "HH_HOME=0 goes straight to Pick" "$o" "work/app/build"
o="$(drv 24 100 '[["wait","Pick what to clear|hh console",150],["sleep",1],["snap","p"]]' HH_ARGS=focus)"; hasnt "hh focus opens Pick, not Home" "$o" "m Memory"
o="$(drv 24 80 "[[\"wait\",\"Memory: \",90],[\"key\",\"ESC\"],[\"wait\",\"c CPU\",90],[\"snap\",\"b\"]]" HH_ARGS="focus perf")"; has "focus perf: Esc from the screen lands on Home" "$(sect "$o" b zzz)" "c CPU"
echo "== first run: limits question, then Home"
printf 'ui=console\n' > "$DEV/.config/host-hygiene/config"; o="$(drv 24 100 "[[\"wait\",\"Set the limits\",150],[\"snap\",\"q\"],[\"key\",\"ENTER\"],[$W],[\"sleep\",1],[\"snap\",\"h\"]]")"
has "the limits question comes first" "$(sect "$o" q h)" "Set the limits"; hasnt "Home is not shown before the limits are answered" "$(sect "$o" q h)" "m Memory"; has "after the limits, Home" "$(sect "$o" h zzz)" "m Memory"
echo "== nothing is closed"
cfg console; sleep 40 & SENT=$!; drv 24 80 "[[$W],[\"key\",\"m\"],[\"wait\",\"Memory: \",30],[\"key\",\"SPACE\"],[\"key\",\"ESC\"],[\"key\",\"q\"],[\"sleep\",1]]" >/dev/null; ps -p $SENT >/dev/null 2>&1 && ok || bad "a bystander process" "ended while hh ran"
for f in home_view.dart home_panels.dart home_keys.dart; do hasnt "no process control in $f" "$(grep -vE '^\s*//' "$D/tui/lib/$f" | grep -E 'Process\.(kill|start|run)|killPid|pkill|killall|pbcopy|Activity Monitor' )" "Process"; done
echo "passed $pass, failed $fail"; [ "$fail" = 0 ]
