#!/usr/bin/env bash
# host-hygiene check | schedule: the disk alarm. Reads only; it never cleans, never kills, never talks to the network.
#   check [--dry] [--test] [--read]  read the guard (--read: just the readings, tab-separated, for the TUI), apply the warn / critical levels, notify at most once per level or cooldown
#   schedule on [--every MIN]     ask how often (shows the default or the last choice), install a launchd agent that runs `check`
#   snooze disk|memory|cpu 1h|4h|24h|tomorrow|off   keep one alarm quiet for a while (critical too: you asked for it)
#   schedule off | status         remove it | show what is installed and the last alarm state
# Levels: disk warn below min_free_gb, critical below hard_gb. Memory warn below mem_free_pct (15) % free, critical at half. CPU warn when the 5-min load reaches max_load, critical at twice. All from `config`.
# Quiet hours silence warn, never critical. Memory and CPU alerts name the heaviest apps and open the apps view; they never close anything.
# Test hooks (never needed in normal use): HH_NOW (epoch), HH_HOUR, HH_MEM_FREE_PCT, HH_LOAD5, HH_PS_FILE (apps.sh), HH_COOLDOWN_H, HH_NOTIFY_CMD (receives title, message), HH_LAUNCH_DIR, HH_NO_LAUNCHCTL=1.
set -u
HERE="$(cd "$(dirname "$0")" && pwd -P)"; HH="$HERE/host-hygiene.sh"
CFG="${HH_CONFIG:-$HOME/.config/host-hygiene/config}"; STATE="$(dirname "$CFG")/state"
LABEL="local.host-hygiene.check"; PLIST="${HH_LAUNCH_DIR:-$HOME/Library/LaunchAgents}/$LABEL.plist"
SUB="${1:-}"; [ $# -gt 0 ] && shift
cget() { "$HH" config get "$1" 2>/dev/null; }
st_get() { [ -f "$STATE" ] && sed -n "s/^$1=//p" "$STATE" | tail -1; }
st_set() { mkdir -p "$(dirname "$STATE")"; { [ -f "$STATE" ] && grep -v "^$1=" "$STATE"; echo "$1=$2"; } > "$STATE.tmp" 2>/dev/null; mv "$STATE.tmp" "$STATE"; }
rank() { case "$1" in crit) echo 2 ;; warn) echo 1 ;; *) echo 0 ;; esac; }

notify() {   # $1 title  $2 message  $3 click target: focus (default) | focus-perf (Memory) | focus-cpu (CPU)  -> which route was used
  local cmdf="$HERE/${3:-focus}.command"
  if [ -n "${HH_NOTIFY_CMD:-}" ]; then "$HH_NOTIFY_CMD" "$1" "$2" "${3:-focus}"; echo custom; return; fi
  local tn; tn="$(command -v terminal-notifier || true)"; [ -z "$tn" ] && [ -x /opt/homebrew/bin/terminal-notifier ] && tn=/opt/homebrew/bin/terminal-notifier
  if [ -n "$tn" ]; then "$tn" -title "$1" -message "$2" -group "hh-${3:-focus}" -execute "open -a Terminal '$cmdf'" >/dev/null 2>&1 && { echo terminal-notifier; return; }; fi
  osascript -e 'on run {t, m}' -e 'display notification m with title t' -e 'end run' "$1" "$2 Run: hh $(case "${3:-focus}" in focus-perf) echo perf ;; focus-cpu) echo focus perf cpu ;; *) echo focus ;; esac)" >/dev/null 2>&1 && { echo osascript; return; }
  echo none
}

in_quiet() {   # $1 = START-END or off, $2 = hour
  [ "$1" = off ] && return 1; local s="${1%-*}" e="${1#*-}" h="$2"
  if [ "$s" -lt "$e" ]; then [ "$h" -ge "$s" ] && [ "$h" -lt "$e" ]; else [ "$h" -ge "$s" ] || [ "$h" -lt "$e" ]; fi
}

top_apps() {   # the three heaviest closable apps, for the alarm text: "Google Chrome 6.3 GB, qemu 4.2 GB"
  "$HERE/apps.sh" --tsv 2>/dev/null | awk -F'\t' '$6!="system"{m=$5; printf "%s%s %s", (n++?", ":""), $2, (m>=1024?sprintf("%.1f GB",m/1024):sprintf("%d MB",m)); if(n==3) exit}'
}

# decide one resource: $1 name (state suffix) $2 level $3 title-warn $4 msg-warn $5 title-crit $6 msg-crit $7 target ; prints the action
decide() {
  local r="$1" level="$2" lk ak last lastat act h quiet cd now; now="${HH_NOW:-$(date +%s)}"; h="${HH_HOUR:-$(date +%H)}"; h=$((10#$h)); quiet="$(cget quiet_hours)"; cd="${HH_COOLDOWN_H:-6}"
  if [ "$r" = disk ]; then lk=level; ak=at; else lk="level_$r"; ak="at_$r"; fi
  last="$(st_get $lk)"; last="${last:-ok}"; lastat="$(st_get $ak)"; lastat="${lastat:-0}"
  if [ "$level" = ok ]; then act="none"; [ "$DRY" = 0 ] && [ "$last" != ok ] && st_set $lk ok
  elif [ "$(st_get snooze_$r)" -gt "$now" ] 2>/dev/null; then act="suppressed:snoozed"
  elif [ "$(cget notify)" = off ]; then act="suppressed:notify-off"
  elif [ "$level" = warn ] && in_quiet "$quiet" "$h"; then act="suppressed:quiet-hours"
  elif [ "$(rank "$level")" -le "$(rank "$last")" ] && [ $((now - lastat)) -lt $((cd * 3600)) ]; then act="suppressed:cooldown"
  else
    act="notify"
    if [ "$DRY" = 0 ]; then
      local t m rt; if [ "$level" = crit ]; then t="$5"; m="$6"; else t="$3"; m="$4"; fi
      rt="$(notify "$t" "$m" "$7")"; act="notified:$rt"; st_set $lk "$level"; st_set $ak "$now"
    fi
  fi
  echo "$act"
}

read_all() {   # `check --read`: one tab-separated line per resource and one for the alarms, whatever the alarm switches say; never notifies, never writes state
  local kv free soft hard lv fp mw l5 ml nc on loaded=no
  kv="$("$HH" guard --kv 2>/dev/null)"; free="$(printf '%s\n' "$kv" | sed -n 's/^free_gb=//p')"; soft="$(printf '%s\n' "$kv" | sed -n 's/^min_free_gb=//p')"; hard="$(printf '%s\n' "$kv" | sed -n 's/^hard_gb=//p')"; ml="$(printf '%s\n' "$kv" | sed -n 's/^max_load=//p')"
  [ -n "$free" ] && [ -n "$soft" ] && [ -n "$hard" ] || { echo "check: could not read the guard" >&2; return 1; }
  lv="$(awk -v f="$free" -v s="$soft" -v h="$hard" 'BEGIN{print (f<h)?"crit":((f<s)?"warn":"ok")}')"; printf 'disk\t%s\t%s\t%s\t%s\n' "$lv" "$free" "$soft" "$hard"
  fp="${HH_MEM_FREE_PCT:-$(memory_pressure 2>/dev/null | sed -n 's/.*free percentage: *\([0-9]*\)%.*/\1/p' | head -1)}"; mw="$(cget mem_free_pct)"; mw="${mw:-15}"
  if [ -n "$fp" ]; then lv="$(awk -v f="$fp" -v w="$mw" 'BEGIN{print (f<w/2)?"crit":((f<w)?"warn":"ok")}')"; printf 'memory\t%s\t%s\t%s\n' "$lv" "$fp" "$mw"; fi
  l5="${HH_LOAD5:-$(uptime | sed 's/.*load averages*: *//' | awk '{gsub(",","");print $2}')}"; nc="${HH_NCPU:-$(sysctl -n hw.ncpu 2>/dev/null)}"
  if [ -n "$l5" ] && [ -n "$ml" ]; then lv="$(awk -v l="$l5" -v m="$ml" 'BEGIN{print (l>=2*m)?"crit":((l>=m)?"warn":"ok")}')"; printf 'cpu\t%s\t%s\t%s\t%s\n' "$lv" "$l5" "$ml" "${nc:-0}"; fi
  local nw sr sv; nw="${HH_NOW:-$(date +%s)}"; for sr in disk mem cpu; do sv="$(st_get snooze_$sr)"; [ "${sv:-0}" -gt "$nw" ] 2>/dev/null && printf 'snooze\t%s\t%s\n' "$sr" "$sv"; done
  [ -f "$PLIST" ] && on=on || on=off
  printf 'alarms\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$on" "$(cget check_every_min)" "$(cget notify)" "$(cget quiet_hours)" "$(cget check_mem)" "$(cget check_cpu)" "$(cget mem_free_pct)"
}

do_check() {
  DRY=0; local test=0 rd=0 a; for a in "$@"; do case "$a" in --dry) DRY=1 ;; --test) test=1 ;; --read) rd=1 ;; *) echo "check: unknown argument $a" >&2; exit 2 ;; esac; done
  if [ "$test" = 1 ]; then local r; r="$(notify "host-hygiene test" "This is how a low-disk alert will look. Click to open the focused cleanup.")"; echo "check: test notification sent via $r"; return 0; fi
  if [ "$rd" = 1 ]; then read_all; return $?; fi
  local kv free soft hard level act
  kv="$("$HH" guard --kv 2>/dev/null)"
  free="$(printf '%s\n' "$kv" | sed -n 's/^free_gb=//p')"; soft="$(printf '%s\n' "$kv" | sed -n 's/^min_free_gb=//p')"; hard="$(printf '%s\n' "$kv" | sed -n 's/^hard_gb=//p')"
  [ -n "$free" ] && [ -n "$soft" ] && [ -n "$hard" ] || { echo "check: could not read the guard" >&2; exit 1; }
  level="$(awk -v f="$free" -v s="$soft" -v h="$hard" 'BEGIN{print (f<h)?"crit":((f<s)?"warn":"ok")}')"
  act="$(decide disk "$level" "Disk is getting low: $free GiB free" "Below your floor of $soft GiB. Click to free space." "Disk critically low: $free GiB free" "Below your hard stop of $hard GiB, so I refuse builds. Click to free space." focus)"
  echo "check: level=$level free=${free}GiB warn<$soft stop<$hard action=$act"
  if [ "$(cget check_mem)" != off ]; then   # memory: free percentage as macOS reports it; critical at half the warn level
    local fp mw mlevel tops; fp="${HH_MEM_FREE_PCT:-$(memory_pressure 2>/dev/null | sed -n 's/.*free percentage: *\([0-9]*\)%.*/\1/p' | head -1)}"; mw="$(cget mem_free_pct)"; mw="${mw:-15}"
    if [ -n "$fp" ]; then
      mlevel="$(awk -v f="$fp" -v w="$mw" 'BEGIN{print (f<w/2)?"crit":((f<w)?"warn":"ok")}')"; tops=""; [ "$mlevel" != ok ] && [ "$DRY" = 0 ] && tops="$(top_apps)"
      act="$(decide mem "$mlevel" "Memory is getting tight: $fp% free" "Most use: ${tops:-see the apps view}. Click for advice on what you could close." "Memory is critically low: $fp% free" "Most use: ${tops:-see the apps view}. Click for advice on what you could close." focus-perf)"
      echo "check: memory level=$mlevel free=${fp}% warn<${mw}% action=$act"
    fi
  fi
  if [ "$(cget check_cpu)" != off ]; then   # CPU: the 5-minute load average against max_load; critical at twice it
    local l5 ml clevel tops; l5="${HH_LOAD5:-$(uptime | sed 's/.*load averages*: *//' | awk '{gsub(",","");print $2}')}"; ml="$(printf '%s\n' "$kv" | sed -n 's/^max_load=//p')"
    if [ -n "$l5" ] && [ -n "$ml" ]; then
      clevel="$(awk -v l="$l5" -v m="$ml" 'BEGIN{print (l>=2*m)?"crit":((l>=m)?"warn":"ok")}')"; tops=""; [ "$clevel" != ok ] && [ "$DRY" = 0 ] && tops="$(top_apps)"
      act="$(decide cpu "$clevel" "CPU has been busy: load $l5" "Most use: ${tops:-see the apps view}. Click for advice on what you could close." "CPU is overloaded: load $l5" "Most use: ${tops:-see the apps view}. Click for advice on what you could close." focus-cpu)"
      echo "check: cpu level=$clevel load5=$l5 busy>=$ml action=$act"
    fi
  fi
}

ask_every() {   # prints minutes; shows the last choice, else the default
  local last def a; last="$(cget check_every_min)"; def="${last:-30}"
  while :; do
    printf 'How often should I check the disk, in minutes? (5-1440) [%s%s]: ' "$def" "$([ -n "$last" ] && echo ', last used' || echo ', default')" >&2
    read -r a </dev/tty || a=""; a="${a:-$def}"
    printf '%s' "$a" | grep -Eq '^[0-9]+$' && [ "$a" -ge 5 ] && [ "$a" -le 1440 ] && { echo "$a"; return; }
    echo "  a whole number of minutes between 5 and 1440, please." >&2
  done
}

sched_on() {
  local every="" a; while [ $# -gt 0 ]; do case "$1" in --every) every="${2:-}"; shift 2 ;; *) echo "schedule on: unknown argument $1" >&2; exit 2 ;; esac; done
  if [ -z "$every" ]; then if [ -t 0 ] && [ -t 1 ]; then every="$(ask_every)"; else every="$(cget check_every_min)"; every="${every:-30}"; fi; fi
  "$HH" config set check_every_min "$every" >/dev/null || exit 2
  mkdir -p "$(dirname "$PLIST")" || exit 1
  cat > "$PLIST" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$HH</string><string>check</string></array>
<key>StartInterval</key><integer>$((every * 60))</integer>
<key>RunAtLoad</key><true/>
<key>ProcessType</key><string>Background</string>
<key>LowPriorityIO</key><true/>
<key>Nice</key><integer>10</integer>
<key>StandardOutPath</key><string>/dev/null</string>
<key>StandardErrorPath</key><string>/dev/null</string>
<key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string><key>HOME</key><string>$HOME</string>$([ -n "${HH_CONFIG:-}" ] && printf '<key>HH_CONFIG</key><string>%s</string>' "$HH_CONFIG")</dict>
</dict></plist>
P
  plutil -lint "$PLIST" >/dev/null || { echo "schedule: wrote an invalid plist, removing it" >&2; rm -f "$PLIST"; exit 1; }
  if [ "${HH_NO_LAUNCHCTL:-0}" != 1 ]; then launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1; launchctl bootstrap "gui/$(id -u)" "$PLIST" || { echo "schedule: launchctl could not load it" >&2; exit 1; }; fi
  echo "Scheduled: every $every min I will check disk (warn below $(cget min_free_gb) GiB free, critical below $(cget hard_gb) GiB), memory (warn below $(cget mem_free_pct)% free) and CPU (load $(cget max_load) or more)."
  echo "  It only reads and notifies you. It never cleans anything and never closes an app. Remove it with: hh schedule off"
  command -v terminal-notifier >/dev/null 2>&1 || [ -x /opt/homebrew/bin/terminal-notifier ] || echo "  note: terminal-notifier is not installed, so alerts use a plain notice (no click action). brew install terminal-notifier"
}

sched_off() {
  [ -f "$PLIST" ] && [ "${HH_NO_LAUNCHCTL:-0}" != 1 ] && launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1   # only a job whose file is here: the label is machine-wide, so another HOME's job is left alone
  if [ -f "$PLIST" ]; then rm -f "$PLIST" "$STATE"; echo "Schedule removed. No background check is running."; else rm -f "$STATE"; echo "Nothing was scheduled."; fi
}

sched_status() {
  local loaded="no"; [ "${HH_NO_LAUNCHCTL:-0}" != 1 ] && launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1 && loaded="yes"
  if [ -f "$PLIST" ]; then echo "schedule: installed ($PLIST), loaded: $loaded"; else echo "schedule: not installed"; fi
  echo "  every: $(cget check_every_min) min (empty = never set; default 30)"; echo "  warn below: $(cget min_free_gb) GiB   critical below: $(cget hard_gb) GiB"
  echo "  notify: $(cget notify)   quiet hours: $(cget quiet_hours)   memory alarm: $(cget check_mem) (warn below $(cget mem_free_pct)% free)   cpu alarm: $(cget check_cpu) (5-min load >= $(cget max_load))"; echo "  last alarm: disk=$(st_get level) memory=$(st_get level_mem) cpu=$(st_get level_cpu)";   command -v terminal-notifier >/dev/null 2>&1 || [ -x /opt/homebrew/bin/terminal-notifier ] && echo "  notifier: terminal-notifier (click opens Terminal)" || echo "  notifier: plain notice (terminal-notifier not installed)"
}

snooze_cmd() {   # snooze disk|memory|cpu 1h|4h|24h|tomorrow|off: the alarm stays quiet until then (state file only; the reading itself is unchanged)
  local r="${1:-}" d="${2:-}" key until now; now="${HH_NOW:-$(date +%s)}"
  case "$r" in disk) key=snooze_disk ;; memory|mem) key=snooze_mem; r=memory ;; cpu) key=snooze_cpu ;; *) echo "snooze: disk | memory | cpu, then 1h | 4h | 24h | tomorrow | off" >&2; exit 2 ;; esac
  case "$d" in 1h) until=$((now + 3600)) ;; 4h) until=$((now + 14400)) ;; 24h) until=$((now + 86400)) ;; tomorrow) until="$(date -r "$now" -v+1d -v7H -v0M -v0S +%s)" ;; off) until=0 ;; *) echo "snooze: disk | memory | cpu, then 1h | 4h | 24h | tomorrow | off" >&2; exit 2 ;; esac
  st_set "$key" "$until"
  if [ "$until" = 0 ]; then echo "$r alarm: snooze cleared"; else echo "$r alarm snoozed until $(date -r "$until" '+%a %H:%M')"; fi
}

case "$SUB" in
  snooze) snooze_cmd "$@" ;;
  check) do_check "$@" ;;
  schedule) case "${1:-status}" in on) shift; sched_on "$@" ;; off) sched_off ;; status) sched_status ;; *) echo "schedule: on [--every MIN] | off | status" >&2; exit 2 ;; esac ;;
  *) echo "usage: host-hygiene.sh check [--dry|--test] | schedule on|off|status" >&2; exit 2 ;;
esac
