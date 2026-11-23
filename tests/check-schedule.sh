#!/usr/bin/env bash
# check-schedule.sh: the disk alarm (check, schedule, focus). Fake homes and a stub notifier only: nothing is sent to the real notification centre, no real agent is loaded.
D="$(cd "$(dirname "$0")/.." && pwd)"; HH="$D/scripts/host-hygiene.sh"; S="${1:-$(mktemp -d)}"; mkdir -p "$S"; pass=0; fail=0
PY="${HH_PYTHON:-python3}"
ok() { pass=$((pass+1)); }; bad() { fail=$((fail+1)); echo "FAIL $1 :: $2"; }
eq() { [ "$2" = "$3" ] && ok || bad "$1" "want '$3' got '$2'"; }
has() { case "$2" in *"$3"*) ok ;; *) bad "$1" "missing '$3'" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected '$3'" ;; *) ok ;; esac; }
H="$S/h"; rm -rf "$H"; mkdir -p "$H"; NOTES="$H/notes.txt"; STUB="$S/stub.sh"; printf '#!/bin/sh\necho "$1 | $2 | click=$3" >> "%s"\n' "$NOTES" > "$STUB"; chmod +x "$STUB"
export HH_CONFIG="$H/config" HH_NOTIFY_CMD="$STUB" HH_LAUNCH_DIR="$H/la" HH_NO_LAUNCHCTL=1 HH_NOW=1000000 HH_HOUR=12 HH_MEM_FREE_PCT=90 HH_LOAD5=0   # memory and CPU healthy unless a test says otherwise
setc() { printf 'min_free_gb=%s\nhard_gb=%s\nmax_load=%s\n%s' "$1" "$2" "${4:-999}" "${3:-}" > "$HH_CONFIG"; }
act() { printf '%s\n' "$1" | head -1 | sed -n 's/.*action=//p'; }; actn() { printf '%s\n' "$1" | grep "^check: $2 " | sed -n 's/.*action=//p'; }
echo "== check: levels, cooldown, quiet hours"
rm -f "$H/state" "$NOTES"; setc 100000 1; o="$("$HH" check)"; eq "warn notifies" "$(act "$o")" "notified:custom"; has "warn text" "$(cat "$NOTES")" "Disk is getting low"
o="$("$HH" check)"; eq "cooldown holds the repeat" "$(act "$o")" "suppressed:cooldown"
o="$(HH_NOW=$((1000000+25200)) "$HH" check)"; eq "notifies again after the cooldown" "$(act "$o")" "notified:custom"
setc 900000 800000; o="$(HH_NOW=$((1000000+25300)) "$HH" check)"; eq "critical beats the cooldown" "$(act "$o")" "notified:custom"; has "critical text" "$(cat "$NOTES")" "critically low"
rm -f "$H/state"; setc 100000 1 'quiet_hours=22-7
'; o="$(HH_HOUR=23 "$HH" check)"; eq "quiet hours silence warn" "$(act "$o")" "suppressed:quiet-hours"
o="$(HH_HOUR=12 "$HH" check)"; eq "daytime is not quiet" "$(act "$o")" "notified:custom"
rm -f "$H/state"; setc 900000 800000 'quiet_hours=22-7
'; o="$(HH_HOUR=23 "$HH" check)"; eq "quiet hours never silence critical" "$(act "$o")" "notified:custom"
rm -f "$H/state"; setc 1 0.5; o="$("$HH" check)"; eq "above the floor: nothing" "$(act "$o")" "none"
setc 100000 1; "$HH" check >/dev/null; setc 1 0.5; "$HH" check >/dev/null; eq "recovery resets the level" "$(sed -n 's/^level=//p' "$H/state")" "ok"
rm -f "$H/state" "$NOTES"; setc 100000 1 'notify=off
'; o="$("$HH" check)"; eq "notify=off sends nothing" "$(act "$o")" "suppressed:notify-off"; [ ! -s "$NOTES" ] && ok || bad "notify=off wrote a note" "$(cat "$NOTES")"
rm -f "$H/state" "$NOTES"; setc 100000 1; o="$("$HH" check --dry)"; eq "--dry names the action" "$(act "$o")" "notify"; [ ! -s "$NOTES" ] && [ ! -f "$H/state" ] && ok || bad "--dry had side effects" ""
o="$("$HH" check --test)"; has "--test sends a test" "$o" "test notification sent"; "$HH" check --bogus >/dev/null 2>&1; eq "check rejects other args" "$?" 2
echo "== memory and CPU alarms"
PSF="$S/ps.txt"; printf '  PID  %%CPU    RSS COMM\n  1 1.0 2000000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome\n  2 2.0 1500000 /Applications/Google Chrome.app/Contents/Frameworks/X/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)\n  3 40 1000000 /opt/homebrew/bin/qemu-system-aarch64\n' > "$PSF"; export HH_PS_FILE="$PSF"
rm -f "$H/state" "$NOTES"; setc 1 0.5; o="$(HH_MEM_FREE_PCT=12 "$HH" check)"; eq "memory below 15% free: warn" "$(actn "$o" memory)" "notified:custom"; has "memory alarm names the heaviest apps" "$(cat "$NOTES")" "Google Chrome 3.3 GB"; has "memory alarm opens the apps view" "$(cat "$NOTES")" "click=focus-perf"; hasnt "disk alarm untouched" "$(cat "$NOTES")" "Disk"
o="$(HH_MEM_FREE_PCT=12 "$HH" check)"; eq "memory repeat is held by the cooldown" "$(actn "$o" memory)" "suppressed:cooldown"
o="$(HH_MEM_FREE_PCT=5 "$HH" check)"; eq "memory critical (below half the warn level) beats the cooldown" "$(actn "$o" memory)" "notified:custom"; has "critical text" "$(cat "$NOTES")" "critically low"
o="$(HH_MEM_FREE_PCT=50 "$HH" check)"; eq "memory recovered" "$(actn "$o" memory)" "none"; eq "recovery resets the memory level" "$(sed -n 's/^level_mem=//p' "$H/state")" ok
rm -f "$H/state" "$NOTES"; setc 1 0.5 "" 8; o="$(HH_LOAD5=9 "$HH" check)"; eq "load at max_load: cpu warn" "$(actn "$o" cpu)" "notified:custom"; has "cpu alarm text" "$(cat "$NOTES")" "CPU has been busy"; has "the CPU alarm click opens the CPU screen" "$(cat "$NOTES")" "click=focus-cpu"
o="$(HH_LOAD5=17 "$HH" check)"; eq "load at twice max_load: critical" "$(actn "$o" cpu)" "notified:custom"; has "cpu critical text" "$(cat "$NOTES")" "overloaded"
rm -f "$H/state" "$NOTES"; setc 1 0.5 "" 8; o="$(HH_LOAD5=7.9 "$HH" check)"; eq "load just below max_load: fine" "$(actn "$o" cpu)" "none"
rm -f "$H/state"; setc 1 0.5 'check_mem=off
check_cpu=off
'; o="$(HH_MEM_FREE_PCT=1 HH_LOAD5=99 "$HH" check)"; hasnt "check_mem=off: no memory line" "$o" "memory"; hasnt "check_cpu=off: no cpu line" "$o" "cpu level"
rm -f "$H/state" "$NOTES"; setc 1 0.5 'quiet_hours=22-7
' 8; o="$(HH_HOUR=23 HH_MEM_FREE_PCT=12 HH_LOAD5=9 "$HH" check)"; eq "quiet hours silence memory warn" "$(actn "$o" memory)" "suppressed:quiet-hours"; eq "quiet hours silence cpu warn" "$(actn "$o" cpu)" "suppressed:quiet-hours"
o="$(HH_HOUR=23 HH_MEM_FREE_PCT=5 "$HH" check)"; eq "quiet hours never silence memory critical" "$(actn "$o" memory)" "notified:custom"
rm -f "$H/state" "$NOTES"; setc 1 0.5 'mem_free_pct=30
'; o="$(HH_MEM_FREE_PCT=25 "$HH" check)"; eq "mem_free_pct is honoured" "$(actn "$o" memory)" "notified:custom"
rm -f "$H/state" "$NOTES"; setc 1 0.5; o="$(HH_MEM_FREE_PCT=12 "$HH" check --dry)"; eq "--dry names the memory action" "$(actn "$o" memory)" "notify"; [ ! -s "$NOTES" ] && [ ! -f "$H/state" ] && ok || bad "--dry had side effects" ""
for kv in "mem_free_pct 1" "mem_free_pct 81" "mem_free_pct abc" "check_mem maybe" "check_cpu 1"; do set -- $kv; "$HH" config set "$1" "$2" >/dev/null 2>&1; eq "config set $1 $2 is refused" "$?" 2; done
rm -f "$HH_CONFIG"; eq "check_mem defaults to on" "$("$HH" config get check_mem)" on; eq "check_cpu defaults to on" "$("$HH" config get check_cpu)" on; eq "mem_free_pct defaults to 15" "$("$HH" config get mem_free_pct)" 15
unset HH_PS_FILE
[ -x "$D/scripts/focus-perf.command" ] && ok || bad "focus-perf.command executable" ""; has "focus-perf.command opens the Memory screen" "$(cat "$D/scripts/focus-perf.command")" "focus perf mem"; [ -x "$D/scripts/focus-cpu.command" ] && ok || bad "focus-cpu.command executable" ""; has "focus-cpu.command opens the CPU screen" "$(cat "$D/scripts/focus-cpu.command")" "focus perf cpu"
echo "== check: cost"
setc 15 5; t0=$(perl -MTime::HiRes=time -e 'printf "%.3f",time'); "$HH" check --dry >/dev/null; t1=$(perl -MTime::HiRes=time -e 'printf "%.3f",time')
ld="$(uptime | sed 's/.*averages*: *//' | awk '{gsub(",","",$1); print int($1)}')"
if [ "${ld:-0}" -ge 8 ]; then echo "SKIP check timing (load $ld)"; else awk -v a="$t0" -v b="$t1" -v m="${HH_TIMING_LIMIT:-0.6}" 'BEGIN{exit !(b-a<m)}' && ok || bad "check takes under ${HH_TIMING_LIMIT:-0.6} s" "$(awk -v a="$t0" -v b="$t1" 'BEGIN{print b-a}')"; fi
echo "== config keys"
rm -f "$HH_CONFIG"; for kv in "check_every_min 4" "check_every_min 1441" "check_every_min abc" "notify maybe" "quiet_hours 25-3" "quiet_hours nonsense"; do set -- $kv; "$HH" config set "$1" "$2" >/dev/null 2>&1; eq "config set $1 $2 is refused" "$?" 2; done
"$HH" config set check_every_min 45 >/dev/null; eq "check_every_min saved" "$("$HH" config get check_every_min)" 45; "$HH" config set quiet_hours 22-7 >/dev/null; eq "quiet_hours saved" "$("$HH" config get quiet_hours)" 22-7
eq "notify defaults to on" "$("$HH" config get notify)" on; eq "quiet_hours defaults to off" "$(rm -f "$HH_CONFIG"; "$HH" config get quiet_hours)" off
echo "== schedule on / status / off"
setc 15 5; rm -rf "$H/la"; o="$("$HH" schedule on)"; P="$H/la/local.host-hygiene.check.plist"; [ -f "$P" ] && ok || bad "plist written" ""; has "default interval is 30" "$o" "every 30 min"
eq "plist valid" "$(plutil -lint "$P" >/dev/null 2>&1; echo $?)" 0; has "plist interval is seconds" "$(cat "$P")" "<integer>1800</integer>"; has "plist runs check" "$(cat "$P")" "<string>check</string>"
hasnt "plist keeps no log file" "$(cat "$P")" ".log"; has "plist is low priority" "$(cat "$P")" "<string>Background</string>"
o="$("$HH" schedule on --every 90)"; has "--every 90" "$o" "every 90 min"; eq "choice remembered" "$("$HH" config get check_every_min)" 90; has "plist follows" "$(cat "$P")" "<integer>5400</integer>"
"$HH" schedule on --every 2 >/dev/null 2>&1; eq "bad interval refused" "$?" 2; eq "refusal leaves the saved choice" "$("$HH" config get check_every_min)" 90
has "status says installed" "$("$HH" schedule status)" "installed"; has "status shows interval" "$("$HH" schedule status)" "every: 90 min"
if "$PY" -c 'import pty' 2>/dev/null; then
  o="$("$PY" "$D/tests/sched-prompt.py" "$HH" abc "")"; has "prompt shows the last choice" "$o" "[90, last used]"; has "prompt rejects text" "$o" "whole number"; has "Enter accepts the last choice" "$o" "every 90 min"
  rm -f "$HH_CONFIG"; setc 15 5; o="$("$PY" "$D/tests/sched-prompt.py" "$HH" "")"; has "first time shows the default" "$o" "[30, default]"
  o="$("$PY" "$D/tests/sched-prompt.py" "$HH" 120)"; has "typed interval is used" "$o" "every 120 min"; eq "typed interval saved" "$("$HH" config get check_every_min)" 120
fi
o="$("$HH" schedule off)"; has "off says removed" "$o" "removed"; [ ! -f "$P" ] && ok || bad "plist removed" ""; has "status after off" "$("$HH" schedule status)" "not installed"; has "off twice is harmless" "$("$HH" schedule off)" "Nothing was scheduled"
echo "== focus"
o="$("$HH" focus </dev/null 2>&1)"; has "focus without a terminal refuses" "$o" "needs an interactive terminal"
[ -x "$D/scripts/focus.command" ] && ok || bad "focus.command executable" ""; has "focus.command runs focus" "$(cat "$D/scripts/focus.command")" "host-hygiene.sh\" focus"
if "$PY" -c 'import pyte' 2>/dev/null; then
  DEV="$S/devhome"; rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; mkdir -p "$DEV/.config/host-hygiene"
  fr() { printf 'min_free_gb=%s\nhard_gb=1\nmax_load=999\nui=guided\n' "$1" > "$DEV/.config/host-hygiene/config"; "$PY" "$D/tests/look-drive.py" "$DEV" 24 100 '[["wait","Pick what to clear",150],["sleep",8],["snap","s"]]' HH_BIN="$HH" HH_ARGS=focus HH_NO_PROMPT=0 2>&1; }
  FREE="$("$HH" guard --kv | sed -n 's/^free_gb=//p')"
  o="$(fr 900000)"; has "focus: reports the gap" "$o" "I need about"; has "focus: ticks safe items" "$o" "[x]"; has "focus: says what is left" "$o" "still"
  o="$(fr 1)"; has "focus: above the floor ticks nothing" "$o" "above the floor"; hasnt "focus: nothing ticked" "$o" "[x]"
  o="$(fr "$(awk -v f="$FREE" 'BEGIN{print f+0.05}')")"; has "focus: small gap, ticks largest first" "$o" "I ticked"
  rm -f "$DEV/.config/host-hygiene/config"; o="$("$PY" "$D/tests/look-drive.py" "$DEV" 24 100 '[["wait","Pick what to clear|What should I call you|Limits",150],["snap","s"]]' HH_BIN="$HH" HH_ARGS=focus HH_NO_PROMPT=0 2>&1)"
  o="$(printf '%s' "$o" | grep -v ^WAIT)"; hasnt "focus skips onboarding" "$o" "What should I call you"; hasnt "focus skips the look question" "$o" "Choose how I should look"
fi
echo "== check --read: the TUI's readings, whatever the alarm switches say"
rm -f "$H/state" "$NOTES"; setc 15 5 'check_mem=off
check_cpu=off
notify=off
quiet_hours=22-7
check_every_min=45
'; o="$(HH_MEM_FREE_PCT=12 HH_LOAD5=3 HH_NCPU=8 "$HH" check --read)"
has "read: a disk line" "$(printf '%s\n' "$o" | cut -f1 | tr '\n' ' ')" "disk "; has "read: a memory line even with check_mem off" "$o" "$(printf 'memory\twarn\t12\t15')"
has "read: a cpu line even with check_cpu off" "$o" "$(printf 'cpu\tok\t3\t999')"; has "read: alarms line carries the settings" "$o" "$(printf 'alarms\toff\t45\toff\t22-7\toff\toff')"
eq "read never notifies" "$(cat "$NOTES" 2>/dev/null | wc -l | tr -d ' ')" 0; eq "read never writes the state file" "$([ -f "$H/state" ] && echo yes || echo no)" no
o="$(HH_MEM_FREE_PCT=5 "$HH" check --read | grep '^memory')"; has "read: memory critical at half the line" "$o" "$(printf 'memory\tcrit\t5')"
mkdir -p "$H/la"; : > "$H/la/local.host-hygiene.check.plist"; has "read: alarms on when the agent file exists" "$("$HH" check --read | grep '^alarms')" "$(printf 'alarms\ton')"; rm -f "$H/la/local.host-hygiene.check.plist"
echo "== snooze and ignore"
rm -f "$H/state" "$NOTES"; setc 100000 1; o="$("$HH" snooze disk 4h)"; has "snooze says until when" "$o" "disk alarm snoozed until"; eq "snooze writes its state key" "$(sed -n 's/^snooze_disk=//p' "$H/state")" "$((1000000+14400))"
o="$("$HH" check)"; eq "a snoozed alarm stays quiet" "$(act "$o")" "suppressed:snoozed"; [ ! -s "$NOTES" ] && ok || bad "snoozed alarm notified" "$(cat "$NOTES")"
setc 900000 800000; o="$("$HH" check)"; eq "snooze holds critical too" "$(act "$o")" "suppressed:snoozed"
o="$(HH_NOW=$((1000000+14401)) "$HH" check)"; eq "the alarm returns when the snooze ends" "$(act "$o")" "notified:custom"
rm -f "$H/state" "$NOTES"; setc 100000 1; "$HH" snooze memory 1h >/dev/null; o="$(HH_MEM_FREE_PCT=12 "$HH" check)"; eq "snoozing memory leaves disk alone" "$(act "$o")" "notified:custom"; eq "and silences memory" "$(actn "$o" memory)" "suppressed:snoozed"
has "read lists a running snooze" "$("$HH" check --read | grep '^snooze')" "$(printf 'snooze\tmem\t%s' $((1000000+3600)))"
"$HH" snooze memory off >/dev/null; hasnt "off clears it" "$("$HH" check --read)" "snooze"
tm="$("$HH" snooze cpu tomorrow)"; has "tomorrow names a time" "$tm" "cpu alarm snoozed until"; eq "tomorrow is 07:00" "$(date -r "$(sed -n 's/^snooze_cpu=//p' "$H/state")" +%H:%M)" "07:00"
"$HH" snooze fridge 1h >/dev/null 2>&1; eq "snooze rejects an unknown resource" "$?" 2; "$HH" snooze cpu soon >/dev/null 2>&1; eq "snooze rejects an unknown length" "$?" 2
rm -f "$H/state" "$NOTES"; setc 100000 1; o="$(HH_PS_FILE="$PSF" HH_MEM_FREE_PCT=12 "$HH" check)"; has "memory alarm names qemu before ignoring" "$(cat "$NOTES")" "qemu-system-aarch64"
rm -f "$H/state" "$NOTES"; setc 100000 1 'ignored_apps=qemu-system-aarch64
'; o="$(HH_PS_FILE="$PSF" HH_MEM_FREE_PCT=12 "$HH" check)"; hasnt "an ignored app is not named in the alarm" "$(cat "$NOTES")" "qemu"; has "the others still are" "$(cat "$NOTES")" "Google Chrome"
"$HH" config set ignored_apps "Google Chrome,qemu-system-aarch64" >/dev/null; eq "config get returns the list" "$("$HH" config get ignored_apps)" "Google Chrome,qemu-system-aarch64"
"$HH" config set ignored_apps "a=b" >/dev/null 2>&1; eq "ignored_apps rejects =" "$?" 2; "$HH" config set ignored_apps "" >/dev/null; eq "an empty list clears it" "$("$HH" config get ignored_apps)" ""
echo "passed $pass, failed $fail"; [ "$fail" = 0 ]
