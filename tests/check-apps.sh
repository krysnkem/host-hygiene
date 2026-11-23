#!/usr/bin/env bash
# check-apps.sh: the apps view and its guarantee. Processes collapse into apps, rank by impact, advice names what you could close,
# and nothing in the skill can close, kill or signal a process. Fixtures only; the real process table is never needed.
D="$(cd "$(dirname "$0")/.." && pwd)"; HH="$D/scripts/host-hygiene.sh"; AP="$D/scripts/apps.sh"; S="${1:-$(mktemp -d)}"; mkdir -p "$S"; pass=0; fail=0
PY="${HH_PYTHON:-python3}"
ok() { pass=$((pass+1)); }; bad() { fail=$((fail+1)); echo "FAIL $1 :: $2"; }
eq() { [ "$2" = "$3" ] && ok || bad "$1" "want '$3' got '$2'"; }
has() { case "$2" in *"$3"*) ok ;; *) bad "$1" "missing '$3'" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected '$3'" ;; *) ok ;; esac; }
PS="$S/ps.txt"; cat > "$PS" <<'P'
  PID  %CPU    RSS COMM
  10 1.0 2000000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
  11 2.0 1500000 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)
  12 1.0 1500000 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper (GPU).app/Contents/MacOS/Google Chrome Helper (GPU)
  20 40 800000 /opt/homebrew/bin/qemu-system-aarch64
  21 30 700000 /opt/homebrew/bin/qemu-system-aarch64
  30 35 99000 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
  31 0.1 9000 /usr/sbin/cfprefsd
  40 0.0 50000 /Applications/Notes.app/Contents/MacOS/Notes
  50 3.0 400000 /usr/local/bin/node
  60 0.0 800 weirdname
  70 9.0 600000 /Applications/Slack.app/Contents/MacOS/Slack
P
export HH_NCPU=10 HH_MEMSIZE=34359738368 HH_PS_FILE="$PS"
T="$("$AP" --tsv)"; col() { printf '%s\n' "$T" | awk -F'\t' -v n="$1" -v c="$2" '$2==n{print $c}'; }
echo "== grouping and ranking"
eq "Chrome's helpers are one app" "$(printf '%s\n' "$T" | awk -F'\t' '$2=="Google Chrome"' | wc -l | tr -d ' ')" 1
eq "Chrome counts its 3 processes" "$(col 'Google Chrome' 3)" 3; eq "Chrome memory is summed (5.0 GB)" "$(col 'Google Chrome' 5)" 4883; eq "Chrome is an app" "$(col 'Google Chrome' 6)" app
eq "qemu's two processes collapse" "$(col qemu-system-aarch64 3)" 2; eq "qemu cpu is summed" "$(col qemu-system-aarch64 4)" 70.0; eq "qemu is a tool" "$(col qemu-system-aarch64 6)" tool
eq "WindowServer is system" "$(col WindowServer 6)" system; eq "a /usr/sbin daemon is system" "$(col cfprefsd 6)" system; eq "node is a tool" "$(col node 6)" tool
eq "no helper name appears as its own row" "$(printf '%s\n' "$T" | grep -c 'Helper')" 0
eq "Chrome ranks first (most memory)" "$(printf '%s\n' "$T" | head -1 | cut -f2)" "Google Chrome"; eq "rank numbers run from 1" "$(printf '%s\n' "$T" | head -1 | cut -f1)" 1
eq "TOPN limits the rows" "$(HH_TOPN=3 "$AP" --tsv | wc -l | tr -d ' ')" 3
echo "== advice"
has "an app you can close is advised" "$(col 'Google Chrome' 7)" "Close Google Chrome (save first)"; eq "a quiet app gets no advice" "$(col Notes 7)" ""
has "qemu: emulator advice" "$(col qemu-system-aarch64 7)" "Android emulator"; has "system process: cannot close, indirect advice" "$(col WindowServer 7)" "fewer windows"; hasnt "system advice never says close the app" "$(col WindowServer 7)" "Close "
has "node: stop it where it started" "$(col node 7)" "developer tool"
o="$("$AP")"; has "report header says nothing is closed" "$o" "nothing is closed, killed or changed"; has "report lists apps" "$o" "Google Chrome"; has "advice carries the save-first warning" "$o" "Save your work first"
has "total says what closing would free" "$o" "would free about"; has "table shows processes per app" "$o" "PROCS"
o="$(HH_ADVISE_MB=100000 HH_ADVISE_CPU=9999 "$AP")"; has "nothing above the thresholds: no advice" "$o" "nothing stands out"
: > "$S/empty.txt"; printf '  PID  %%CPU    RSS COMM\n' > "$S/empty.txt"; o="$(HH_PS_FILE="$S/empty.txt" "$AP")"; has "empty process list does not crash" "$o" "nothing stands out"
has "hh perf is the apps report" "$("$HH" perf)" "apps by impact"
echo "== the guarantee: nothing closes, kills or signals a process"
bad_calls="$(grep -rnE '(^|[;&|(`[:space:]]|\$\()(kill|pkill|killall)([[:space:]]|$)' "$D"/scripts/*.sh "$D"/scripts/*.command 2>/dev/null | grep -vE '^\S+:[0-9]+:\s*#' | grep -v 'kill -0')"
eq "no kill, pkill or killall in any script" "$bad_calls" ""
eq "no quit or terminate through osascript" "$(grep -rnE 'osascript.*(quit|terminate)|NSRunningApplication|forceTerminate|SIGTERM|SIGKILL' "$D"/scripts "$D"/tui/lib "$D"/tui/bin | wc -l | tr -d ' ')" 0
eq "no process kill in the TUI" "$(grep -rnE 'killPid|\.kill\(|Process\.kill' "$D"/tui/lib "$D"/tui/bin | wc -l | tr -d ' ')" 0
eq "no Activity Monitor launch in any script or the TUI" "$(grep -rnE "open[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*['\"]?Activity Monitor|Activity Monitor\.app|launchApp" "$D"/scripts "$D"/tui/lib "$D"/tui/bin | grep -v '^[^:]*:[0-9]*:[[:space:]]*//' | wc -l | tr -d ' ')" 0
eq "no clipboard use in any script or the TUI" "$(grep -rnE '\b(pbcopy|pbpaste)\b|Clipboard\.|setData\(' "$D"/scripts "$D"/tui/lib "$D"/tui/bin | wc -l | tr -d ' ')" 0
if command -v dart >/dev/null 2>&1 && [ -d "$D/tui/.dart_tool" ] || [ -f "$D/tui/pubspec.lock" ]; then o="$(cd "$D/tui" && dart run tests/home_model.dart 2>&1 | tail -3)"; has "unit tests of the Home, apps and advice models" "$o" "0 failed"; hasnt "unit tests print no FAIL" "$o" "FAIL"; fi
before="$(ps -Aceo pid | wc -l)"; "$AP" >/dev/null; eq "the report leaves every process running" "$(( $(ps -Aceo pid | wc -l) - before < 5 ? 0 : 1 ))" 0
echo "== TUI: the Memory and CPU screens"
if "$PY" -c 'import pyte' 2>/dev/null; then
  DEV="$S/devhome"; rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; mkdir -p "$DEV/.config/host-hygiene"; printf 'min_free_gb=1\nhard_gb=1\nmax_load=999\nui=guided\n' > "$DEV/.config/host-hygiene/config"
  drv() { "$PY" "$D/tests/look-drive.py" "$DEV" 28 100 "$1" HH_BIN="$HH" HH_NO_PROMPT=0 HH_PS_FILE="$PS" HH_NCPU=10 HH_MEMSIZE=34359738368 HH_MEM_FREE_PCT=31 HH_LOAD5=12.5 "${@:2}" 2>&1 | grep -v ^WAIT; }
  o="$(drv '[["wait","Memory:",90],["snap","s"],["key","SPACE"],["snap","t"],["key","y"],["snap","y"],["key","y"],["key","DOWN"],["snap","d"],["key","TAB"],["sleep",1],["snap","cpu"],["key","TAB"],["key","r"],["sleep",2],["snap","r"],["key","ESC"],["sleep",1],["snap","back"]]' HH_ARGS="focus perf")"
  s0="$(printf '%s' "$o" | sed -n '/=== s/,/=== t/p')"
  has "focus perf opens Memory" "$s0" "Memory: 31% free, your line is 15% (ok)"; has "the screen says hh never closes anything" "$s0" "hh never closes anything for you"; has "one Chrome row" "$s0" "Google Chrome"; hasnt "no helper rows" "$s0" "Helper"
  eq "Chrome counts its 3 processes" "$(printf '%s\n' "$s0" | grep -cE 'Google Chrome +3 ')" 1; has "a system row is listed" "$s0" "WindowServer"
  has "directions for the selected app: Cmd-Q" "$s0" "Cmd-Q"; has "directions: force quit" "$s0" "Option-Cmd-Esc"; has "nothing ticked: a hint" "$s0" "Tick the apps you plan to close"
  t0="$(printf '%s' "$o" | sed -n '/=== t/,/=== y/p')"; has "space ticks the app" "$t0" "[x]"; has "the tally says what closing frees" "$t0" "Ticked 1: closing them would free about 4.8 GB"
  y0="$(printf '%s' "$o" | sed -n '/=== y/,/=== d/p')"; has "y shows a plain summary" "$y0" "Quitting Google Chrome would free about 4.8 GB. Save your work first."
  d0="$(printf '%s' "$o" | sed -n '/=== d/,/=== cpu/p')"; has "moving down changes the directions (qemu is a tool)" "$d0" "Ctrl-C"
  c0="$(printf '%s' "$o" | sed -n '/=== cpu/,/=== r/p')"; has "Tab flips to CPU" "$c0" "CPU: load 12.5 on 10 cores, your max is 999"; has "CPU ranks by CPU (qemu first)" "$(printf '%s\n' "$c0" | grep -nE 'qemu|Google Chrome' | head -1)" "qemu"
  hasnt "Esc leaves the screen" "$(printf '%s' "$o" | sed -n '/=== back/,$p')" "your line is"
  r0="$(printf '%s' "$o" | sed -n '/=== r/,/=== back/p')"; has "r rescans and keeps the screen" "$r0" "Memory:"
  o="$(drv '[["wait","CPU:",90],["snap","c"]]' HH_ARGS="focus perf cpu")"; has "focus perf cpu opens the CPU screen" "$o" "CPU: load 12.5 on 10 cores"
  o="$(drv '[["wait","Look",90],["sleep",12],["key","m"],["wait","Memory:",20],["snap","m"],["key","ESC"],["sleep",1],["key","c"],["wait","CPU:",20],["snap","c"]]' HH_ARGS="")"; has "m opens Memory from the journey" "$o" "Memory: 31% free"; has "c opens CPU from the journey" "$o" "CPU: load 12.5"
  o="$(drv '[["wait","space",150],["sleep",2],["snap","k"]]' HH_LOOK=cockpit HH_ARGS="")"; has "the cockpit key hint mentions m apps" "$o" "m apps"
  o="$(drv '[["wait","Memory:",90],["sleep",1],["snap","small"]]' HH_ARGS="focus perf" )"; has "wide enough shows the full hints" "$o" "esc or left back"
  for sz in "12 60" "10 70"; do r="${sz% *}"; c="${sz#* }"; o="$("$PY" "$D/tests/look-drive.py" "$DEV" $r $c '[["wait","Memory:",90],["sleep",1],["snap","s"],["key","TAB"],["sleep",1],["snap","c"]]' HH_BIN="$HH" HH_NO_PROMPT=0 HH_PS_FILE="$PS" HH_NCPU=10 HH_MEMSIZE=34359738368 HH_MEM_FREE_PCT=31 HH_LOAD5=12.5 HH_ARGS="focus perf" 2>&1 | grep -v ^WAIT)"; has "$r x $c: Memory header fits" "$o" "Memory: 31% free"; has "$r x $c: CPU after Tab" "$o" "CPU: load 12.5"; has "$r x $c: rows shown" "$o" "Google Chrome"; done
fi
echo "== ignored apps"
IC="$S/ign.cfg"; printf 'ignored_apps=Google Chrome\n' > "$IC"; o="$(HH_CONFIG="$IC" "$AP" --tsv)"; hasnt "an ignored app is left out of the table" "$o" "Google Chrome"; has "others stay" "$o" "$(printf '\tqemu')"
o="$(HH_CONFIG="$IC" "$AP")"; hasnt "and out of the advice" "$o" "Close Google Chrome"
printf 'ignored_apps= Google Chrome , qemu-system-aarch64\n' > "$IC"; o="$(HH_CONFIG="$IC" "$AP" --tsv)"; hasnt "spaces around names are trimmed" "$o" "qemu-system"; : > "$IC"; has "an empty list ignores nothing" "$(HH_CONFIG="$IC" "$AP" --tsv)" "Google Chrome"
echo "passed $pass, failed $fail"; [ "$fail" = 0 ]
