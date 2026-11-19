#!/usr/bin/env bash
# apps.sh: running processes collapsed into APPS (Chrome's 30 helpers are one row), ranked by impact, with advice. Read-only:
# it reads ps and the hardware size and nothing else. It never closes, kills or signals anything; it only says what you could close.
#   apps.sh [report]     the ranked table, then advice
#   apps.sh --tsv        rank, app, procs, cpu%, mem MB, kind, advice (one row per app) for the TUI
# impact = share of RAM + share of all CPU cores. kind: app (an .app you can quit) | tool (a command-line or helper program) | system (macOS itself).
# Apps named in the config's ignored_apps (comma-separated) are left out of the table, the advice and the alarm text.
# Seams: HH_PS_FILE (ps text: header + "pid pcpu rss comm", comm may be a full path), HH_NCPU, HH_MEMSIZE (bytes), HH_TOPN (default 10), HH_ADVISE_MB (300), HH_ADVISE_CPU (25).
set -u
MODE="${1:-report}"; N="${HH_TOPN:-10}"
NCPU="${HH_NCPU:-$(sysctl -n hw.ncpu 2>/dev/null || echo 8)}"; RAMB="${HH_MEMSIZE:-$(sysctl -n hw.memsize 2>/dev/null || echo 17179869184)}"
IGN="$(sed -nE 's/^[[:space:]]*ignored_apps[[:space:]]*=(.*)$/\1/p' "${HH_CONFIG:-$HOME/.config/host-hygiene/config}" 2>/dev/null | tail -1)"   # apps the user chose to never hear about
PS_OUT="$(if [ -n "${HH_PS_FILE:-}" ]; then cat "$HH_PS_FILE"; else ps -Axo pid,pcpu,rss,comm; fi)"
ROWS="$(printf '%s\n' "$PS_OUT" | awk -v ncpu="$NCPU" -v ramkb="$((RAMB / 1024))" -v ign="$IGN" -v amb="${HH_ADVISE_MB:-300}" -v acpu="${HH_ADVISE_CPU:-25}" '
  function base(p,  n,a){n=split(p,a,"/"); return a[n]}
  function hint(name,kind,  b){
    b=tolower(name)
    if(name=="WindowServer") return "follows how much is on screen: fewer windows, a lower display scale, or fewer emulator windows"
    if(name=="kernel_task") return "macOS managing heat and I/O; nothing to close. Find what else is busy above"
    if(name ~ /^(mds|mds_stores|mdworker|mdworker_shared|corespotlightd)/) return "Spotlight indexing; it settles on its own. Exclude build folders in System Settings > Spotlight"
    if(name ~ /^mediaanalysisd/) return "Photos analysing your library; it settles when the Mac is idle on power"
    if(name ~ /Virtualization/) return "a virtual machine host: stop the VM from the app that started it (Docker Desktop, UTM, Parallels)"
    if(name ~ /^qemu-system|^emulator/) return "Android emulator: close emulator windows you are not using, or run fewer at once"
    if(b ~ /docker/) return "Docker: stop containers you do not need, or quit Docker Desktop from its menu-bar icon"
    if(name ~ /^(node|java|gradle|dart|flutter|kotlin|python|ruby|go|cargo|rustc)/) return "a developer tool: stop it in the terminal or IDE that started it (check it is not mid-build)"
    return ""
  }
  NR>1 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ && $3 ~ /^[0-9]+$/ {
    p=$4; for(i=5;i<=NF;i++) p=p" "$i
    kind="tool"; name=base(p)
    if (match(p, /[^\/]+\.app\//)) { name=substr(p,RSTART,RLENGTH-5); kind="app" }
    else if (p ~ /^\/(System|sbin|bin|Library\/Apple)\// || p ~ /^\/usr\/(bin|sbin|libexec|lib|standalone)\// || name ~ /^(kernel_task|launchd|WindowServer|mds|mds_stores|mdworker|mdworker_shared|corespotlightd|mediaanalysisd|coreaudiod|bluetoothd|powerd|opendirectoryd|distnoted|cfprefsd)$/) kind="system"
    if (name ~ /^(WindowServer|kernel_task)$/) kind="system"
    k=kind"\t"name; cpu[k]+=$2; mem[k]+=$3; cnt[k]++
  }
  END{
    ni=split(ign,ia,","); for(i=1;i<=ni;i++){gsub(/^ +| +$/,"",ia[i]); if(ia[i]!="") skip[ia[i]]=1}
    for(k in cnt){ split(k,f,"\t"); kind=f[1]; name=f[2]; if(name in skip) continue
      mb=mem[k]/1024; score=mem[k]/ramkb*100 + cpu[k]/ncpu
      h=hint(name,kind); adv=""
      if (kind=="app" && (mb>=amb || cpu[k]>=acpu)) adv="Close " name " (save first)" (h!=""?"; "h:"")
      else if (kind=="app" && h!="" && (mb>=amb || cpu[k]>=acpu)) adv=h
      else if (kind!="app" && (mb>=amb || cpu[k]>=acpu) && h!="") adv=h
      else if (kind=="tool" && (mb>=amb || cpu[k]>=acpu)) adv="Stop " name " from where you started it, if you are not using it"
      printf "%.4f\t%s\t%d\t%.1f\t%.0f\t%s\t%s\n", score, name, cnt[k], cpu[k], mb, kind, adv
    }
  }' | sort -t"$(printf '\t')" -k1,1nr | head -n "$N" | awk -F'\t' '{printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\n", NR,$2,$3,$4,$5,$6,$7}')"
if [ "$MODE" = --tsv ]; then printf '%s\n' "$ROWS"; exit 0; fi
FREEP="$(memory_pressure 2>/dev/null | sed -n 's/.*free percentage: *\([0-9]*\)%.*/\1/p' | head -1)"
UP="$(if [ -n "${HH_UPTIME_FILE:-}" ]; then cat "$HH_UPTIME_FILE"; else uptime; fi)"; LOAD="$(printf '%s' "$UP" | sed 's/.*load averages*: *//')"
echo "== apps by impact  (processes collapsed into their app; report only: nothing is closed, killed or changed)"
echo "memory    $(awk -v b="$RAMB" 'BEGIN{printf "%.0f GB", b/1073741824}') installed${FREEP:+, $FREEP% free}      load $LOAD ($NCPU cores)"
printf '  %2s  %-30s %5s %8s %8s  %s\n' "#" APP PROCS CPU MEM KIND
printf '%s\n' "$ROWS" | awk -F'\t' '{m=$5; ms=(m>=1024)?sprintf("%.1f GB",m/1024):sprintf("%d MB",m); printf "  %2d  %-30.30s %5d %7.0f%% %8s  %s\n",$1,$2,$3,$4,ms,$6}'
ADV="$(printf '%s\n' "$ROWS" | awk -F'\t' '$7!=""')"
if [ -n "$ADV" ]; then
  echo "== advice  (suggestions only; nothing is closed for you. Save your work first; figures are approximate)"
  printf '%s\n' "$ADV" | awk -F'\t' '{printf "  %d. %s (%d process%s, %.0f%% CPU, %s): %s\n",$1,$2,$3,($3==1?"":"es"),$4,($5>=1024?sprintf("%.1f GB",$5/1024):sprintf("%d MB",$5)),$7}'
  printf '%s\n' "$ADV" | awk -F'\t' '$6!="system"{m+=$5;c+=$4;n++} END{if(n>1) printf "  Closing the %d you can close would free about %s and roughly %.0f%% of one core.\n", n, (m>=1024?sprintf("%.1f GB",m/1024):sprintf("%d MB",m)), c}'
else echo "== advice: nothing stands out. No app is above $((${HH_ADVISE_MB:-300})) MB or ${HH_ADVISE_CPU:-25}% of a core."; fi
awk -v l="$(printf '%s' "$LOAD" | awk '{gsub(",","");print $1}')" 'BEGIN{ if (l>=8) print "  note: load is " l ", at or above 8: CPU figures are not trustworthy right now" }'
