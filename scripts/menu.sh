#!/usr/bin/env bash
# host-hygiene guided CLI: arrow-key menus, space-to-tick checklist, live totals.
# Opens with `host-hygiene.sh` (no arguments) or `host-hygiene.sh menu`. Needs a terminal.
# It only calls the same subcommands you can run by hand (profile, scan, plan, apply, guard, config).
# Keys: up/down move, Enter choose, space tick, a = tick all "safe", n = untick all, q = back/quit.
set -u
HERE_UI="$(cd "$(dirname "$0")" && pwd -P)"; HH="$HERE_UI/host-hygiene.sh"
[ -t 0 ] && [ -t 1 ] || { echo "host-hygiene menu needs an interactive terminal (use the subcommands in scripts)" >&2; exit 2; }
CFG="${HH_CONFIG:-$HOME/.config/host-hygiene/config}"
. "$HERE_UI/ui.sh"; REV=$'\033[7m'
COLS="$(tput cols 2>/dev/null || echo 80)"; ROWS="$(tput lines 2>/dev/null || echo 24)"
cleanup() { printf '\033[?25h'; }; trap cleanup EXIT; trap 'echo; exit 0' INT

hr() { awk -v k="$1" 'BEGIN{ s=k*1024; split("B K M G T",u," "); i=1; while(s>=1024&&i<5){s/=1024;i++} printf (i<3?"%.0f%s":"%.1f%s"), s, u[i] }'; }
trunc() { printf '%s' "$1" | cut -c1-$((COLS-1)); }
key() {   # one keypress -> UP DOWN ENTER SPACE or the character
  local k r; IFS= read -rsn1 k || { echo QUIT; return; }
  if [ "$k" = $'\033' ]; then IFS= read -rsn2 -t 1 r || true
    case "$r" in '[A') echo UP ;; '[B') echo DOWN ;; *) echo ESC ;; esac
  elif [ -z "$k" ]; then echo ENTER; elif [ "$k" = " " ]; then echo SPACE; else echo "$k"; fi
}
pause() { printf '\n%s  press any key to return %s' "$D" "$R"; IFS= read -rsn1 _ || true; echo; }
ask() { local a; printf '%s' "$1" >&2; read -r a || { echo >&2; exit 0; }; echo "${a:-$2}"; }

# select TITLE opt1 opt2 ... -> sets SEL (0-based) ; returns 1 on q/esc
select_one() {
  local title="$1"; shift; local n=$#; local -a opts=("$@"); local cur=0 first=1 j k
  printf '\033[?25l'
  while :; do
    [ "$first" = 0 ] && printf '\033[%dA' $((n+2)); first=0
    printf '\033[2K%s%s%s\n' "$B" "$title" "$R"
    for ((j=0;j<n;j++)); do
      if [ "$j" = "$cur" ]; then printf '\033[2K %s❯ %s%s\n' "$REV" "${opts[$j]}" "$R"; else printf '\033[2K   %s\n' "${opts[$j]}"; fi
    done
    printf '\033[2K%s  ↑/↓ move · Enter choose · q back%s\n' "$D" "$R"
    k="$(key)"
    case "$k" in UP) cur=$(( (cur+n-1)%n )) ;; DOWN) cur=$(( (cur+1)%n )) ;; ENTER) SEL=$cur; printf '\033[?25h'; return 0 ;; q|QUIT|ESC) printf '\033[?25h'; return 1 ;; esac
  done
}

pickp() { local n=$#; eval "printf '%s' \"\${$(( (RANDOM % n) + 1 ))}\""; }
GKV=""; refresh() { GKV="$("$HH" guard --kv </dev/null 2>/dev/null)"; gv() { printf '%s\n' "$GKV" | sed -n "s/^$1=//p"; }; }
banner() {
  refresh; local st line c="$GRN"; st="$(gv status)"
  case "$st" in
    low) c="$YEL"; line="$(pickp "Heads up, things are getting tight." "I'd go easy on heavy work for now." "We're below one of your limits, so a cleanup might help.")" ;;
    stop) c="$RED"; line="$(pickp "Space is critically low. Please don't start a build yet." "Hold off on builds and emulators, there's barely any room left." "We're at the hard stop. Let's free some space first.")" ;;
    *) line="$(pickp "All good here." "Everything looks healthy." "Plenty of room, nothing to worry about." "Smooth sailing.")" ;;
  esac
  [ -t 1 ] && clear; logo; printf '\n  %s●%s %s\n' "$c" "$R" "$line"
  printf '%s  %s GiB free · load %s · your limits: %s / %s GiB, load %s%s\n\n' "$D" "$(gv free_gb)" "$(gv load)" "$(gv min_free_gb)" "$(gv hard_gb)" "$(gv max_load)" "$R"
}

# ---- Free up space: scan -> tick items -> confirm -> apply ----------------------------------------
free_up() {
  local min; min="$(ask "  Only list items bigger than how many MB? [50] > " 50)"; printf '%s' "$min" | grep -Eq '^[0-9]+$' || min=50
  local tmp; spin "Sniffing out what is taking space (about a minute)" "$HH" plan --tsv --min-mb "$min"; tmp="$SPIN_OUT"
  local -a KB CL ID PA CMD SUP NOTE UN; local n=0 line k kb cl w id pa cmd sup note un
  while IFS=$'\t' read -r k kb cl w id pa cmd sup note un; do
    case "$k" in '#'*|'') continue ;; esac
    KB[$n]="$kb"; CL[$n]="$cl"; ID[$n]="$id"; PA[$n]="$pa"; CMD[$n]="$cmd"; SUP[$n]="$sup"; NOTE[$n]="$note"; UN[$n]="$un"; n=$((n+1))
  done < "$tmp"; grep '^#' "$tmp" | sed 's/^#//' | sed 's/^/  /'; rm -f "$tmp"
  [ "$n" = 0 ] && { echo "  $(pickp "Spotless. Nothing bigger than ${min} MB to clear." "Nothing worth clearing above ${min} MB. Well kept." "Clean as a whistle. Nothing over ${min} MB.")"; pause; return; }
  local -a ON; local j; for ((j=0;j<n;j++)); do ON[$j]=0; done
  local cur=0 top=0 view=$((ROWS-9)); [ "$view" -gt "$n" ] && view=$n; [ "$view" -lt 4 ] && view=4; [ "$view" -gt "$n" ] && view=$n
  local first=1 L=$((view+4)) kk tot cnt tag colr mark ptr txt
  printf '\n%sTick what to remove%s  (%sgreen = safe to rebuild%s · %syellow = shared/costly, read the cost line%s · dim = do by hand)\n' "$B" "$R" "$GRN" "$R" "$YEL" "$R"
  printf '\033[?25l'
  while :; do
    [ "$first" = 0 ] && printf '\033[%dA' "$L"; first=0
    tot=0; cnt=0; for ((j=0;j<n;j++)); do [ "${ON[$j]}" = 1 ] && { tot=$((tot+KB[j])); cnt=$((cnt+1)); }; done
    for ((j=top;j<top+view;j++)); do
      ptr=" "; [ "$j" = "$cur" ] && ptr="❯"
      case "${CL[$j]}" in safe-regenerable) colr="$GRN"; tag="safe  " ;; *) colr="$YEL"; tag="ask   " ;; esac
      if [ "${SUP[$j]}" = n ]; then colr="$D"; tag="manual"; mark="   "; else mark="[ ]"; [ "${ON[$j]}" = 1 ] && mark="[x]"; fi
      txt="$(trunc "$ptr $mark $(printf '%7s' "${UN[$j]}$(hr "${KB[$j]}")") $tag ${PA[$j]/#$HOME/~}")"
      if [ "$j" = "$cur" ]; then printf '\033[2K%s%s%s%s\n' "$REV" "$colr" "$txt" "$R"; else printf '\033[2K%s%s%s\n' "$colr" "$txt" "$R"; fi
    done
    printf '\033[2K%s  ↳ %s%s\n' "$D" "$(trunc "${NOTE[$cur]}")" "$R"
    if [ "${SUP[$cur]}" = n ]; then printf '\033[2K%s  ↳ by hand: %s%s\n' "$D" "$(trunc "${CMD[$cur]}")" "$R"; else printf '\033[2K%s  ↳ will run: %s%s\n' "$D" "$(trunc "${CMD[$cur]}")" "$R"; fi
    printf '\033[2K  %sSelected: %d item(s), about %s%s\n' "$B" "$cnt" "$(hr "$tot")" "$R"
    printf '\033[2K%s  ↑/↓ move · space tick · a all safe · n none · Enter continue · q cancel%s\n' "$D" "$R"
    kk="$(key)"
    case "$kk" in
      UP) [ "$cur" -gt 0 ] && cur=$((cur-1)); [ "$cur" -lt "$top" ] && top=$cur ;;
      DOWN) [ "$cur" -lt $((n-1)) ] && cur=$((cur+1)); [ "$cur" -ge $((top+view)) ] && top=$((cur-view+1)) ;;
      SPACE) [ "${SUP[$cur]}" = y ] && { [ "${ON[$cur]}" = 1 ] && ON[$cur]=0 || ON[$cur]=1; } ;;
      a) for ((j=0;j<n;j++)); do [ "${SUP[$j]}" = y ] && [ "${CL[$j]}" = safe-regenerable ] && ON[$j]=1; done ;;
      n) for ((j=0;j<n;j++)); do ON[$j]=0; done ;;
      q|QUIT|ESC) printf '\033[?25h\n  Cancelled, nothing removed.\n'; pause; return ;;
      ENTER) [ "$cnt" -gt 0 ] && break ;;
    esac
  done
  printf '\033[?25h\n'
  echo "  You chose:"; local asks=0 args=()
  for ((j=0;j<n;j++)); do [ "${ON[$j]}" = 1 ] || continue; printf '    %s%7s%s  %s\n         %s%s%s\n' "$B" "$(hr "${KB[$j]}")" "$R" "${PA[$j]/#$HOME/~}" "$D" "${NOTE[$j]}" "$R"
    args+=(--target "${PA[$j]}"); [ "${CL[$j]}" = ask-first ] && asks=1; done
  [ "$asks" = 1 ] && printf '  %sSome are shared or costly to regenerate (yellow). Read their cost lines above.%s\n' "$YEL" "$R"
  echo; select_one "  Remove these $cnt item(s) now? (a log is written; this cannot be undone)" "No, go back" "Yes, remove them" || { echo "  Nothing removed."; pause; return; }
  [ "$SEL" = 1 ] || { echo "  Nothing removed."; pause; return; }
  echo; local flags=(--run --yes); [ "$asks" = 1 ] && flags+=(--ask-first-ok)
  refresh; local f0; f0="$(gv free_gb)"
  local out; out="$(mktemp)"; printf '  %sOn it. Removing one item at a time...%s\n' "$D" "$R"
  local cur tot
  "$HH" apply "${flags[@]}" "${args[@]}" | tee "$out" | while IFS= read -r line; do
    case "$line" in
      \[*/*\]\ removing*) cur="${line#\[}"; cur="${cur%%/*}"; tot="${line#*/}"; tot="${tot%%\]*}"; printf '\r\033[2K  %s %s/%s  %s' "$(meter $((cur-1)) "$tot")" "$cur" "$tot" "$(trunc "$(echo "$line" | sed 's/.*removing *[^ ]* *//; s/ *\.\.\.$//')")" ;;
      \[*/*\]\ done*) cur="${line#\[}"; cur="${cur%%/*}"; tot="${line#*/}"; tot="${tot%%\]*}"; printf '\r\033[2K  %s%s%s %s/%s\n' "$GRN" "$(meter "$cur" "$tot")" "$R" "$cur" "$tot" ;;
      \[*REFUSED*|\[*SKIPPED*|\[*ERROR*|\[*declined*) printf '\r\033[2K  %s%s%s\n' "$YEL" "$line" "$R" ;;
    esac
  done
  local freed ran; freed="$(sed -n 's/.*freed \([0-9.]*[BKMGT]*\) (du.*/\1/p' "$out" | tail -1)"; ran="$(sed -n 's/.*ran \([0-9]*\) item.*/\1/p' "$out" | tail -1)"; rm -f "$out"
  refresh; local f1; f1="$(gv free_gb)"
  echo
  if [ "${ran:-0}" -gt 0 ]; then
    printf '  %s\n' "$(pickp "Done. I cleared ${freed:-0B} across ${ran} item(s)." "All set: ${freed:-0B} gone, ${ran} item(s) cleaned up." "That's ${ran} item(s) and ${freed:-0B} off your disk.")"
    printf '  %sFree space: %s → %s GiB. macOS can take a moment to report it, so the number may lag.%s\n' "$D" "$f0" "$f1" "$R"
    echo "  $(pickp "Nice, lighter already." "Room to breathe again." "Tidy.")"
  else echo "  $(pickp "Nothing needed removing after all." "No changes this time.")"; fi
  local m=0; for ((j=0;j<n;j++)); do [ "${SUP[$j]}" = n ] && { [ "$m" = 0 ] && echo && echo "  Not done by the tool (run by hand if you want them):"; m=1; printf '    %s\n' "${CMD[$j]}"; }; done
  pause
}

settings() {
  while :; do
    echo; "$HH" config show | sed 's/^/  /'; echo
    select_one "Settings" "Change soft free-disk floor (GiB)" "Change hard-stop free disk (GiB)" "Change max load" "Back" || return
    case "$SEL" in 0) key=min_free_gb ;; 1) key=hard_gb ;; 2) key=max_load ;; *) return ;; esac
    local v; v="$(ask "  New value for $key > " "")"; [ -n "$v" ] && "$HH" config set "$key" "$v" | sed 's/^/  /'
  done
}

change_look() {   # the chooser lives in the TUI binary; the classic menu only hands over to it
  local bin="$HERE_UI/../tui/hh_tui"
  if [ -x "$bin" ]; then HH_SCRIPT="$HH" "$bin" --pick-look; local rc=$?; printf '\033[?25h'
    case "$rc" in 0) echo "  Saved. The new look is used the next time you run host-hygiene.sh without HH_CLASSIC=1." ;; 10) echo "  No change." ;; *) echo "  The chooser could not start (exit $rc)." ;; esac
  else echo "  Changing the look needs the guided front end (tui/hh_tui), which is not built here. Build it with tui/build.sh."; fi
  pause
}

help_screen() {
  cat <<EOF

  ${B}How to read this${R}
  ${GRN}safe${R}    can be rebuilt by its own tool (project build folders, caches). Removing it costs one slower build.
  ${YEL}ask${R}     shared or costly to get back (Gradle and pub caches, emulators, Docker, SDK files). Read the cost line.
  ${D}manual${R}  the tool will not delete it for you; it shows the command to run yourself.
  Never offered: Downloads, Documents, anything git tracks, and any folder on your never-touch list.
  Nothing is deleted without your final "Yes", and every removal is logged.
EOF
  pause
}

[ -f "$CFG" ] || { "$(dirname "$HH")/intro.sh"; "$HH" config init || true; echo; }
while :; do
  banner
  select_one "What would you like to do?" "Check this machine" "See what is using space" "Free up space" "Can I build right now?" "Settings" "Change look" "How to read the results" "Quit" || { echo; exit 0; }
  case "$SEL" in
    0) echo; spin "Checking your toolchains and projects" "$HH" profile; frame "Your machine"; sed 's/^/  /' "$SPIN_OUT"; frame_end; rm -f "$SPIN_OUT"; pause ;;
    1) m="$(ask "  Only list items bigger than how many MB? [50] > " 50)"; printf '%s' "$m" | grep -Eq '^[0-9]+$' || m=50; echo; spin "Sniffing out what is taking space (about a minute)" "$HH" scan --min-mb "$m"; frame "What is using space"; sed 's/^/  /' "$SPIN_OUT"; frame_end; rm -f "$SPIN_OUT"; pause ;;
    2) free_up ;;
    3) echo; spin "Checking disk and load" "$HH" guard; rc=$?; frame "Can I build?"; sed 's/^/  /' "$SPIN_OUT"; [ "$rc" = 0 ] && echo "  ${GRN}✓ Go ahead.${R}" || echo "  ${YEL}! Not right now (see above).${R}"; frame_end; rm -f "$SPIN_OUT"; pause ;;
    4) settings ;;
    5) change_look ;;
    6) help_screen ;;
    *) exit 0 ;;
  esac
done
