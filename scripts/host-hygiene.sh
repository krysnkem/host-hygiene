#!/usr/bin/env bash
# host-hygiene: find what eats storage and memory on this machine. Dry-run by default; only apply --run deletes.
#
#   host-hygiene.sh            (no arguments, in a terminal) guided journey (tui/hh_tui, Dart) or, if not built, the shell menu. HH_CLASSIC=1 forces the menu. Also: menu | hello (replay the intro)
#   host-hygiene.sh profile [--profile developer|non-developer]
#   host-hygiene.sh scan    [--profile P] [--tsv] [--min-mb N] [--root DIR ...]
#   host-hygiene.sh plan    [--profile P] [--min-mb N]   scan + exact command, freed, cost, best ratio first
#   host-hygiene.sh apply --target PATH [--target PATH ...] [--run] [--yes] [--ask-first-ok] [--keep-going]   (--keep-going: a refused or failed item does not stop the rest; the exit code is 1 if any failed)
#   host-hygiene.sh config [show | init | get KEY | set KEY VALUE]   thresholds + ui= look (guided|plain|cockpit|dashboard|spacemap|console) file; HH_LOOK beats ui=
#   host-hygiene.sh snooze disk|memory|cpu 1h|4h|24h|tomorrow|off   silence one alarm for a while (state file only)
#   host-hygiene.sh check | schedule [on|off|status] [--every MIN]   disk alarm: a launchd agent runs 'check'; below the floor it notifies, and a click opens 'focus'
#   host-hygiene.sh focus [perf [mem|cpu]]   (terminal) open straight on Pick with enough safe items ticked to get back above the floor; 'perf' opens the Memory screen ('perf cpu': the CPU screen)
#   host-hygiene.sh perf   running apps ranked by impact (processes collapsed into apps) with advice on what you could close. Never closes anything
#   host-hygiene.sh look [--web]   choose the look: a list in the terminal, or --web for pictures of all five designs in your browser (needs tui/hh_tui; the L key does it inside the TUI)
#   host-hygiene.sh guard [--min-free-gb N] [--hard-gb N] [--max-load N] [--quiet|--kv]
#        fast read-only gate for other tools. exit 0 ok | 1 below soft floor (disk<min or load>=max) | 2 hard stop (disk<hard)
#        thresholds: flag > env (HH_MIN_FREE_GB HH_HARD_GB HH_MAX_LOAD) > config file > built-in 15 / 5 / 8
#        --kv prints load= free_gb= status= and the limits in force
#
# profile  what machine this is, which toolchains and projects exist (no network, no writes)
# scan     ranked findings: size, class, owner, last-modified, removal command, cost; plus load
#          and the top CPU/memory processes. Changes nothing. Never kills anything.
#
# Data only: the catalog (../catalog/catalog.tsv) is read, never executed.
# Classes: safe-regenerable | ask-first | never. Anything unproven is ask-first, never safe.
# macOS first. Other systems exit 3 (stub), by design: nothing here is tested elsewhere.
set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
CATALOG="$HERE/../catalog/catalog.tsv"
# HH_TIMING=1: per-detector wall time to stderr as "time <name> <seconds>" (stdout and tsv are unchanged; costs one perl fork per mark, only when set)
if [ "${HH_TIMING:-0}" = 1 ]; then
  hh_clock() { perl -MTime::HiRes=time -e 'printf "%.2f", time' 2>/dev/null || echo "$SECONDS"; }
  HH_TLAST="$(hh_clock)"
  hh_mark() { local n; n="$(hh_clock)"; awk -v a="$HH_TLAST" -v b="$n" -v k="$1" 'BEGIN{printf "time %s %.2f\n", k, b-a}' >&2; HH_TLAST="$n"; }
else hh_mark() { :; }; fi
[ -f "$HERE/executors.sh" ] && . "$HERE/executors.sh"   # avdmanager / sdkmanager / fvm / rustup removals (R4)
[ -f "$HERE/devcatalog.sh" ] && . "$HERE/devcatalog.sh"   # developer-cache rows: gating, tool commands, guards (K3)
[ -f "$HERE/devcatalog2.sh" ] && . "$HERE/devcatalog2.sh"   # data/ml, devops, game rows: per-project and env rows, editor guards (K3b)
# The interface binary for this machine: tui/hh_tui-ARCH, then tui/hh_tui, and only if it is a Mach-O for this chip (read with `file`; nothing is run, so a wrong-chip or half-copied file cannot hang or print an error). HH_ARCH is a test seam.
tui_bin() { local a b; a="${HH_ARCH:-$(uname -m)}"; for b in "$HERE/../tui/hh_tui-$a" "$HERE/../tui/hh_tui"; do [ -x "$b" ] && file -b "$b" 2>/dev/null | grep -q "Mach-O.*$a" && { echo "$b"; return 0; }; done; return 1; }
case "${1:-}" in --tui-bin) tui_bin; exit $? ;; esac
case "${1:-}" in --version|-v|-V|version) cat "$HERE/../VERSION" 2>/dev/null || echo dev; exit 0 ;; esac
CMD="${1:-}"; [ $# -gt 0 ] && shift
case "$CMD" in check|schedule|snooze) exec "$HERE/schedule.sh" "$CMD" "$@" ;; esac   # scheduled disk check + launchd agent: own arguments, own script
MINFREE="${HH_MIN_FREE_GB:-}"; HARD="${HH_HARD_GB:-}"; MAXLOAD="${HH_MAX_LOAD:-}"; POS=""; QUIET=0; KV=0
FOCUS=1; WEBF=""; TARGETS=""; RUN=0; YES=0; ASKOK=0; KEEP=0; LOG="${HH_LOG:-${HH_CONFIG:+$(dirname "$HH_CONFIG")}}"; LOG="${LOG:-$HOME/.config/host-hygiene}/apply-log.txt"
FORCE_PROFILE=""; TSV=0; MIN_MB=50; ROOTS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) FORCE_PROFILE="$2"; shift 2 ;;
    --tsv) TSV=1; shift ;;
    --min-mb) MIN_MB="$2"; shift 2 ;;
    --target) TARGETS="$TARGETS
$2"; shift 2 ;;
    --run) RUN=1; shift ;;
    --yes) YES=1; shift ;;
    --ask-first-ok) ASKOK=1; shift ;;
    --keep-going) KEEP=1; shift ;;
    --log) LOG="$2"; shift 2 ;;
    --min-free-gb) MINFREE="$2"; shift 2 ;;
    --hard-gb) HARD="$2"; shift 2 ;;
    --max-load) MAXLOAD="$2"; shift 2 ;;
    --web) [ "$CMD" = look ] || { echo "unknown argument: --web" >&2; exit 2; }; WEBF=--web; shift ;;
    --quiet) QUIET=1; shift ;;
    --kv) KV=1; shift ;;
    --root) ROOTS="$ROOTS
$2"; shift 2 ;;
    -h|--help) sed -n "2,24p" "$0"; exit 0 ;;
    perf) if [ "$CMD" = focus ]; then FOCUS=perf; shift; else echo "unknown argument: $1" >&2; exit 2; fi ;;
    mem|cpu) if [ "$CMD" = focus ] && [ "$FOCUS" = perf ]; then FOCUS="perf-$1"; shift; else echo "unknown argument: $1" >&2; exit 2; fi ;;
    *) if [ "$CMD" = config ]; then POS="$POS $1"; shift; else echo "unknown argument: $1" >&2; exit 2; fi ;;
  esac
done
[ "$(uname -s)" = Darwin ] || { echo "host-hygiene: only macOS is implemented (stub for $(uname -s))" >&2; exit 3; }
case "$CMD" in
  profile|scan) ;;
  plan) ;;
  apply) ;;
  guard) ;;
  perf) exec "$HERE/apps.sh" ;;
  config) ;;
  look) ;;
  focus) [ -t 0 ] && [ -t 1 ] || { echo "host-hygiene focus needs an interactive terminal" >&2; exit 2; }
         TUIBIN="$(tui_bin)" || {   # no interface for this chip: show the text view instead of an error (a notification click lands here)
           echo "host-hygiene: the full interface is not available on this machine ($(uname -m)), so here is the text view. Build it with tui/build.sh, or see the README." >&2
           case "$FOCUS" in perf*) exec "$HERE/apps.sh" ;; *) HH_NO_PROMPT=1 "$0" guard; echo "  Run 'hh plan' to see what could be freed, or 'hh' for the menu."; exit 0 ;; esac; }
         HH_FOCUS="$FOCUS" HH_SCRIPT="$HERE/host-hygiene.sh" exec "$TUIBIN" ;;
  menu) exec "$HERE/menu.sh" ;;
  hello) exec "$HERE/intro.sh" ;;
  "") if [ -t 0 ] && [ -t 1 ]; then
       if [ "${HH_CLASSIC:-0}" != 1 ] && TUIBIN="$(tui_bin)"; then HH_SCRIPT="$HERE/host-hygiene.sh" exec "$TUIBIN"; fi
       exec "$HERE/menu.sh"
     fi; sed -n '2,23p' "$0"; exit 0 ;;
  -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
  *) echo "unknown command: $CMD" >&2; exit 2 ;;
esac

# ---- thresholds: flag > env > config file > built-in default ----------------------------------------
CFG="${HH_CONFIG:-$HOME/.config/host-hygiene/config}"
# The never-touch list: folder names (one per line in `protected` beside the config, or HH_PROTECT comma-separated). Anything at or under */NAME is class never and `apply` refuses it.
PROT_LIST="$( { [ -f "$(dirname "$CFG")/protected" ] && sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$(dirname "$CFG")/protected"; printf '%s\n' "${HH_PROTECT:-}" | tr ',' '\n'; } | grep -v '^$' )"
protected() { local n; [ -n "$PROT_LIST" ] || return 1; while IFS= read -r n; do case "$1" in */"$n"|*/"$n"/*) return 0 ;; esac; done <<< "$PROT_LIST"; return 1; }
cfg_get() { [ -f "$CFG" ] && sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+)?)[[:space:]]*$/\1/p" "$CFG" | tail -1; }
cfg_get_s() { [ -f "$CFG" ] && sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*([a-z]+)[[:space:]]*$/\1/p" "$CFG" | tail -1; }
UI_LOOKS="guided plain cockpit dashboard spacemap console"   # the ONE list of looks the TUI may draw; the TUI registry (tui/lib/look.dart) must know each id
cfg_get_t() { [ -f "$CFG" ] && sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*([^=]{1,40})[[:space:]]*$/\1/p" "$CFG" | tail -1; }   # free text (name, role): data only, never executed
ui_ok() { [ -n "$1" ] && case " $UI_LOOKS " in *" $1 "*) return 0 ;; esac; return 1; }
ui_eff() { if ui_ok "${HH_LOOK:-}"; then echo "$HH_LOOK"; else local v; v="$(cfg_get_s ui)"; if ui_ok "$v"; then echo "$v"; else echo guided; fi; fi; }
if [ "$CMD" = look ]; then   # choose the look: the chooser (terminal list, or the browser page with --web) lives in the TUI binary
  TUIBIN="$(tui_bin)" || { echo "host-hygiene: choosing a look needs the guided front end (tui/hh_tui), and it is not built here. Build it with tui/build.sh, or set it by hand: host-hygiene.sh config set ui <$UI_LOOKS>" >&2; exit 2; }
  [ -t 0 ] && [ -t 1 ] || { echo "host-hygiene look needs an interactive terminal (in scripts: config set ui <$UI_LOOKS>)" >&2; exit 2; }
  HH_SCRIPT="$HERE/host-hygiene.sh" "$TUIBIN" --pick-look $WEBF; rc=$?
  case $rc in
    0) HH_SCRIPT="$HERE/host-hygiene.sh" exec "$TUIBIN" ;;   # saved: open the TUI in the chosen look
    10) echo "No change: the look stays $(ui_eff)."; exit 0 ;;
    *) exit "$rc" ;;
  esac
fi
num() { printf '%s' "$1" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; }
config_init() {   # ask the user once; suggestions come from this host, not from a constant
  local ncpu diskg sug_soft sug_hard sug_load a b c
  ncpu="$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"; diskg="$(df -Pk "$HOME" | awk 'NR==2{printf "%d", $2/1048576}')"
  sug_soft="$(awk -v d="$diskg" 'BEGIN{v=d*0.03; if(v<15)v=15; printf "%d", v}')"; sug_hard=5
  sug_load="$(awk -v n="$ncpu" 'BEGIN{printf "%d", n*0.75+0.5}')"
  echo "host-hygiene: set the thresholds that 'guard' (and tools that call it) will use."
  echo "  This host: $ncpu CPU cores, ${diskg} GiB disk. Press Enter to accept a suggestion; change later with 'config set'."
  while :; do
    printf '  soft free-disk floor in GiB [%s] (below it: heavy work is risky): ' "$sug_soft"; read -r a </dev/tty; a="${a:-$sug_soft}"
    printf '  hard-stop free-disk in GiB  [%s] (below it: never start a build): ' "$sug_hard"; read -r b </dev/tty; b="${b:-$sug_hard}"
    printf '  max 1-minute load           [%s] (at/above it: timings unreliable): ' "$sug_load"; read -r c </dev/tty; c="${c:-$sug_load}"
    num "$a" && num "$b" && num "$c" && awk -v a="$a" -v b="$b" 'BEGIN{exit !(b<a)}' && break
    echo "  numbers only, and the hard stop must be smaller than the soft floor. Try again."
  done
  mkdir -p "$(dirname "$CFG")" && { echo "# host-hygiene thresholds (data only, never executed). Edit or use: host-hygiene.sh config set KEY VALUE"
    echo "min_free_gb=$a"; echo "hard_gb=$b"; echo "max_load=$c"; } > "$CFG" && echo "  saved to ${CFG/#$HOME/~}"
}
if [ "$CMD" = config ]; then
  set -- $POS; SUB="${1:-show}"
  case "$SUB" in
    init) [ -t 0 ] || { echo "config init needs a terminal" >&2; exit 2; }; config_init; exit 0 ;;
    set) k="${2:-}"; v="${3:-}"
         case "$k" in min_free_gb|hard_gb|max_load|ui|name|role|check_every_min|notify|quiet_hours|check_mem|check_cpu|mem_free_pct|ignored_apps) ;; *) echo "config set: key must be min_free_gb | hard_gb | max_load | ui | name | role | check_every_min | notify | quiet_hours | check_mem | check_cpu | mem_free_pct | ignored_apps" >&2; exit 2 ;; esac
         if [ "$k" = name ] || [ "$k" = role ]; then v="${*:3}"; printf '%s' "$v" | grep -Eq '^[^[:cntrl:]=]{1,40}$' || { echo "config set: $k must be 1-40 characters, no '=' and no control characters" >&2; exit 2; }
         elif [ "$k" = ignored_apps ]; then v="${*:3}"; [ -z "$v" ] || { [ "${#v}" -le 400 ] && printf '%s' "$v" | grep -Eq '^[^[:cntrl:]=]+$'; } || { echo "config set: ignored_apps must be app names separated by commas, up to 400 characters, no '=' and no control characters" >&2; exit 2; }
         elif [ "$k" = check_every_min ]; then printf '%s' "$v" | grep -Eq '^[0-9]+$' && [ "$v" -ge 5 ] && [ "$v" -le 1440 ] || { echo "config set: check_every_min must be a whole number of minutes, 5 to 1440" >&2; exit 2; }
         elif [ "$k" = mem_free_pct ]; then printf '%s' "$v" | grep -Eq '^[0-9]+$' && [ "$v" -ge 2 ] && [ "$v" -le 80 ] || { echo "config set: mem_free_pct must be a whole number, 2 to 80" >&2; exit 2; }
         elif [ "$k" = notify ] || [ "$k" = check_mem ] || [ "$k" = check_cpu ]; then case "$v" in on|off) ;; *) echo "config set: $k must be on or off" >&2; exit 2 ;; esac
         elif [ "$k" = quiet_hours ]; then printf '%s' "$v" | grep -Eq '^(off|([01]?[0-9]|2[0-3])-([01]?[0-9]|2[0-3]))$' || { echo "config set: quiet_hours must be off or START-END in 24h hours, e.g. 22-7" >&2; exit 2; }
         elif [ "$k" = ui ]; then ui_ok "$v" || { echo "config set: ui must be one of: $UI_LOOKS" >&2; exit 2; }
         else num "$v" || { echo "config set: value must be a number" >&2; exit 2; }; fi
         mkdir -p "$(dirname "$CFG")"; touch "$CFG"
         { grep -vE "^[[:space:]]*$k[[:space:]]*=" "$CFG"; echo "$k=$v"; } > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"; echo "$k=$v saved to ${CFG/#$HOME/~}"; exit 0 ;;
    get) case "${2:-}" in
           ui) ui_eff; exit 0 ;;
           name|role) cfg_get_t "$2"; exit 0 ;;
           ignored_apps) [ -f "$CFG" ] && sed -nE 's/^[[:space:]]*ignored_apps[[:space:]]*=(.*)$/\1/p' "$CFG" | tail -1; exit 0 ;;
           check_every_min) v="$(cfg_get check_every_min)"; echo "${v:-}"; exit 0 ;;
           notify|check_mem|check_cpu) v="$(cfg_get_s "$2")"; echo "${v:-on}"; exit 0 ;;
           mem_free_pct) v="$(cfg_get mem_free_pct)"; echo "${v:-15}"; exit 0 ;;
           quiet_hours) v="$(cfg_get_t quiet_hours)"; echo "${v:-off}"; exit 0 ;;
           min_free_gb|hard_gb|max_load) v="$(cfg_get "$2")"; case "$2" in min_free_gb) echo "${v:-15}" ;; hard_gb) echo "${v:-5}" ;; *) echo "${v:-8}" ;; esac; exit 0 ;;
           *) echo "config get: key must be min_free_gb | hard_gb | max_load | ui | name | role | check_every_min | notify | quiet_hours | check_mem | check_cpu | mem_free_pct | ignored_apps" >&2; exit 2 ;;
         esac ;;
    show) echo "config file: ${CFG/#$HOME/~} ($([ -f "$CFG" ] && echo present || echo 'absent: built-in defaults 15 / 5 / 8 apply'))"
          echo "  min_free_gb=${MINFREE:-$(cfg_get min_free_gb)}${MINFREE:+ (env)}"; echo "  hard_gb=${HARD:-$(cfg_get hard_gb)}${HARD:+ (env)}"; echo "  max_load=${MAXLOAD:-$(cfg_get max_load)}${MAXLOAD:+ (env)}"
          echo "  ui=$(ui_eff)${HH_LOOK:+ (env)} (looks: $UI_LOOKS)"; echo "  name=$(cfg_get_t name)  role=$(cfg_get_t role)   (asked once at first run; local only)"; echo "  empty = not set in the file, so the built-in default applies"; exit 0 ;;
    *) echo "config: show | init | get KEY | set KEY VALUE" >&2; exit 2 ;;
  esac
fi
F_MIN="$MINFREE"; F_HARD="$HARD"; F_LOAD="$MAXLOAD"   # explicit flag/env values always win, even after the first-run prompt
[ -z "$MINFREE" ] && MINFREE="$(cfg_get min_free_gb)"; MINFREE="${MINFREE:-15}"
[ -z "$HARD" ]    && HARD="$(cfg_get hard_gb)";        HARD="${HARD:-5}"
[ -z "$MAXLOAD" ] && MAXLOAD="$(cfg_get max_load)";    MAXLOAD="${MAXLOAD:-8}"
# first interactive run: ask once. Never when piped, quiet, --kv or HH_NO_PROMPT=1 (guard is called by other tools and must not block)
if [ -z "$(cfg_get min_free_gb)" ] && [ -t 0 ] && [ -t 1 ] && [ "${HH_NO_PROMPT:-0}" != 1 ] && [ "$QUIET" = 0 ] && [ "$KV" = 0 ] && [ "$RUN" = 0 ] && [ "$TSV" = 0 ]; then
  config_init && { MINFREE="${F_MIN:-$(cfg_get min_free_gb)}"; HARD="${F_HARD:-$(cfg_get hard_gb)}"; MAXLOAD="${F_LOAD:-$(cfg_get max_load)}"; }
  echo
fi
if [ "$CMD" = plan ]; then
  A=(); [ -n "$FORCE_PROFILE" ] && A=(--profile "$FORCE_PROFILE")
  if [ "$TSV" = 0 ]; then
  echo "== plan: read-only proposal, nothing is executed. cost 1 = rebuild/regenerate locally, 2 = re-download (network), 3 = data loss"
  printf '  %3s %7s %7s %-16s %-4s %s\n' "#" FREED CUMUL CLASS COST "TARGET  ->  COMMAND  (cost note)"
  fi
  # measured estimates for tools whose command frees only part of the directory
  hh_mark plan_startup
  SIMN="$(xcrun simctl list devices unavailable 2>/dev/null | grep -c '(')"; hh_mark plan_simctl
  DKB="$(docker system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null | awk -F'|' '$1!="Local Volumes"{v=$2; sub(/ .*/,"",v); u=v; gsub(/[0-9.]/,"",u); n=v; gsub(/[A-Za-z]/,"",n); m=(u=="GB")?1048576:(u=="MB")?1024:(u=="kB")?1:0.001; t+=n*m} END{if(NR) printf "%d",t; else print "x"}')"; hh_mark plan_docker
  "$0" scan ${A[@]+"${A[@]}"} --tsv --min-mb "$MIN_MB" | awk -F'\t' -v home="$HOME" -v simn="$SIMN" -v dkb="$DKB" -v tsv="$TSV" -v xa="$(hh_x_supported avdmanager)" -v xs="$(hh_x_supported sdkmanager)" -v xf="$(hh_x_supported "fvm ")" -v xr="$(hh_x_supported "rustup ")" -v dcs="$(type dc_supported_list >/dev/null 2>&1 && dc_supported_list)" '
    function base(p,  n,a){n=split(p,a,"/"); return a[n]}
    function sdk(p, pre,  n,a){n=split(p,a,"/"); return pre}
    function w(id){ if(id ~ /^project:|^gradle-transforms|^xcode-derived|^xcode-sim-caches|^npm-cache|^editor-cache|^user-logs|^gradle-daemon|^homebrew-cache|^unity-library|^unity-temp|^godot-project-cache|^unreal-intermediate|^jupyter-checkpoints/) return 1
                    if(id ~ /^android-avd|^docker-data|^xcode-sim-devices|^xcode-archives|^trash/) return 3; return 2 }
    function cmd(id,path,rem,  b,a,n,v){
      b=base(path)
      if(rem ~ /^report-only: /) return rem
      if(id=="android-avd"){sub(/\.avd$/,"",b); return "avdmanager delete avd -n " b}
      if(id=="android-ndk") return "sdkmanager --uninstall \"ndk;" b "\""
      if(id=="android-buildtools") return "sdkmanager --uninstall \"build-tools;" b "\""
      if(id=="android-platforms") return "sdkmanager --uninstall \"platforms;" b "\""
      if(id=="android-cmake") return "sdkmanager --uninstall \"cmake;" b "\""
      if(id=="android-sysimg"){n=split(path,a,"/"); return "sdkmanager --uninstall \"system-images;" a[n-1] ";" a[n] ";<abi: ls the dir>\""}
      if(id=="fvm-sdk") return "fvm remove " b
      if(id=="rustup-toolchains") return "rustup toolchain uninstall " b
      if(id=="pyenv-versions") return "pyenv uninstall " b
      if(id=="rbenv-versions") return "rbenv uninstall " b
      if(rem ~ /^rm-verified/) return "rm -rf -- \"" path "\"   [apply re-verifies first]"
      return rem
    }
    $2=="never"{next}
    {k=$1; u=""
     if($3=="xcode-sim-devices"){ if(simn==0){skip=skip "\n  skipped: " $4 " (0 unavailable simulators, `simctl delete unavailable` frees nothing; per-device removal is a manual choice)"; next} else {u="?"} }
     if($3=="docker-data"){ if(dkb=="x"){u="?"} else {k=dkb; u="<="} }
     n++; sz[n]=k; cl[n]=$2; id[n]=$3; pa[n]=$4; rm[n]=$6; co[n]=$7; ow[n]=$8; sc[n]=k/w($3); un[n]=u}
    END{
      for(i=1;i<=n;i++) idx[i]=i
      for(i=2;i<=n;i++){x=idx[i]; j=i-1; while(j>=1 && sc[idx[j]]<sc[x]){idx[j+1]=idx[j]; j--} idx[j+1]=x}
      for(k=1;k<=n;k++){ i=idx[k]; cum+=sz[i]; g=sz[i]/1048576; c=cum/1048576
        t=pa[i]; sub("^" home,"~",t)
        if(tsv){ c1=cmd(id[i],pa[i],rm[i]); sup=(c1 ~ /^(empty Trash|report-only)/)?"n":(c1 ~ /^avdmanager/)?xa:(c1 ~ /^sdkmanager/)?xs:(c1 ~ /^fvm /)?xf:(c1 ~ /^rustup /)?xr:(c1 ~ /^(pip|uv|go|composer|dotnet|pnpm|bun|npm|deno|corepack|pod|pyenv|rbenv) /)?((index(dcs, "," substr(c1,1,index(c1," ")-1) "=y,")>0)?"y":"n"):"y"
                 printf "%d\t%d\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", k, sz[i], cl[i], w(id[i]), id[i], pa[i], c1, sup, co[i], un[i]; continue }
        printf "  %3d %s%5.1fG %6.1fG %-16s %-4d %s\n      -> %s\n      (%s)\n", k, (un[i]==""?" ":un[i]), g, c, cl[i], w(id[i]), t, cmd(id[i],pa[i],rm[i]), co[i] }
      if(tsv){ if(skip!="") print "#" skip; if(xa=="n") print "#note avdmanager not found (PATH, ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk/cmdline-tools): AVD rows supported=n"; if(xs=="n") print "#note sdkmanager not found (PATH, ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk/cmdline-tools): SDK-package rows supported=n"; exit }
      print "  freed: <= means upper bound (docker: reclaimable images+containers+cache from `docker system df`, volumes excluded); ? means unmeasured" skip
    }'
  exit 0
fi
[ -f "$CATALOG" ] || { echo "catalog missing: $CATALOG" >&2; exit 2; }

hr() { awk -v k="$1" 'BEGIN{ s=k*1024; split("B K M G T",u," "); i=1; while(s>=1024&&i<5){s/=1024;i++} printf (i<3?"%.0f%s":"%.1f%s"), s, u[i] }'; }
age() { local m="$1" n; n="$(date +%s)"; [ -z "$m" ] || [ "$m" = 0 ] && { echo "?"; return; }; echo "$(( (n-m)/86400 ))d"; }
mtime() { stat -f %m "$1" 2>/dev/null || echo 0; }
kb() { du -sk "$1" 2>/dev/null | cut -f1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- toolchains -----------------------------------------------------------------------
detect_toolchains() {   # prints "id<TAB>evidence"
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}" f
  [ -d "$sdk" ] && printf 'android\t%s\n' "sdk present"
  [ -d "$HOME/.gradle" ] && printf 'gradle\t%s\n' "~/.gradle present"
  if have flutter; then f="$(dirname "$(dirname "$(command -v flutter)")")"
    printf 'dart\tflutter %s\n' "$(cat "$f/version" 2>/dev/null || echo '?')"
  elif have dart; then printf 'dart\t%s\n' "dart on PATH"
  elif [ -d "$HOME/.pub-cache" ]; then printf 'dart\t%s\n' "~/.pub-cache present"; fi
  have fvm && printf 'fvm\t%s\n' "$(ls "$HOME/fvm/versions" 2>/dev/null | paste -sd, -)"
  if [ -d "$HOME/Library/Developer/Xcode" ] || [ -d /Applications/Xcode.app ]; then
    printf 'xcode\t%s\n' "$(xcode-select -p 2>/dev/null || echo 'no developer dir')"; fi
  have docker && printf 'docker\t%s\n' "docker on PATH"
  have node && printf 'node\t%s\n' "node $(node -v 2>/dev/null)"
  { have cargo || [ -d "$HOME/.cargo" ]; } && printf 'rust\t%s\n' "cargo/rustup present"
  have brew && printf 'brew\t%s\n' "homebrew present"
  { have java && java -version >/dev/null 2>&1; } && printf 'java\t%s\n' "$(java -version 2>&1 | head -1)"
  have python3 && printf 'python\t%s\n' "$(python3 -V 2>&1)"
  { have go || [ -d "$HOME/go" ] || [ -d /usr/local/go ]; } && printf 'go\t%s\n' "go present"
  { have rbenv || [ -d "$HOME/.rbenv" ] || [ -d "$HOME/.rvm" ]; } && printf 'ruby\t%s\n' "rbenv/rvm present"
  { have composer || [ -d "$HOME/.composer" ]; } && printf 'php\t%s\n' "composer present"
  { have dotnet || [ -d "$HOME/.nuget" ] || [ -d "$HOME/.dotnet" ]; } && printf 'dotnet\t%s\n' "dotnet/nuget present"
  [ -d "$HOME/.konan" ] && printf 'kmp\t%s\n' "~/.konan present"
}

# ---- projects (git repos), pruning the places that are never projects --------------------
find_projects() {
  local r
  for r in ${ROOTS:-$HOME}; do
    find "$r" -maxdepth 5 \( -name Library -o -name node_modules -o -name .gradle -o -name .pub-cache \
      -o -name .Trash -o -name .android -o -name .cache -o -name Applications -o -name fvm -o -name .fvm \
      -o -name .cargo -o -name .rustup -o -name .npm -o -name .claude -o -name build -o -name .dart_tool \) -prune -o \
      -name .git -print 2>/dev/null | sed 's|/\.git$||'
  done | sort -u | while read -r p; do [ -d "$p/bin" ] && [ -d "$p/packages/flutter" ] && continue; echo "$p"; done
}
gradle_used_versions() {   # (scan reuses the PROJECTS list it already found: a second find over $HOME cost 4 s; apply, where PROJECTS is unset, still finds) versions named by any discovered project's gradle-wrapper.properties
  printf '%s\n' "${PROJECTS-$(find_projects)}" | while read -r p; do [ -n "$p" ] && find "$p" -maxdepth 5 -name gradle-wrapper.properties \
      -not -path '*/build/*' -not -path '*/node_modules/*' 2>/dev/null; done | xargs -I{} sed -nE 's/.*gradle-([0-9][0-9.]*)-(bin|all)\.zip.*/\1/p' {} 2>/dev/null | sed 's/\.0$//' | sort -u
}
kind_of() {   # repo path -> developer types by manifest (ids: flutter node rn frontend python go rust jvm android kmp ios ruby rails php dotnet maui)
  local p="$1" k="" f g x c
  shopt -s nullglob
  [ -f "$p/pubspec.yaml" ] && k="$k flutter"
  if [ -f "$p/package.json" ]; then k="$k node"
    grep -qsE '"(react-native|expo)"' "$p/package.json" && k="$k rn"
    if [ -f "$p/pnpm-workspace.yaml" ] || [ -f "$p/turbo.json" ] || [ -f "$p/nx.json" ] || [ -f "$p/lerna.json" ] || grep -qs '"workspaces"' "$p/package.json"; then k="$k frontend"; fi
  fi
  [ -f "$p/Cargo.toml" ] && k="$k rust"; [ -f "$p/go.mod" ] && k="$k go"
  for f in pyproject.toml requirements.txt Pipfile setup.py uv.lock; do [ -f "$p/$f" ] && { k="$k python"; break; }; done
  g=""; for f in build.gradle build.gradle.kts settings.gradle settings.gradle.kts pom.xml build.sbt; do [ -f "$p/$f" ] && { g=1; break; }; done
  if [ -n "$g" ]; then k="$k jvm"
    grep -qsE 'org\.jetbrains\.kotlin\.multiplatform|kotlin\("multiplatform"\)|kotlin-multiplatform' "$p"/build.gradle* "$p"/shared/build.gradle* "$p"/gradle/libs.versions.toml && k="$k kmp"
    { [ -f "$p/app/src/main/AndroidManifest.xml" ] || [ -f "$p/src/main/AndroidManifest.xml" ] || grep -qs 'com\.android\.' "$p"/build.gradle* "$p"/app/build.gradle*; } && k="$k android"
  fi
  case "$k" in *flutter*|*" rn"*) ;; *)   # a root-level Apple project (ios/ inside Flutter or React Native does not count)
    x=("$p"/*.xcodeproj "$p"/*.xcworkspace); { [ ${#x[@]} -gt 0 ] || [ -f "$p/Package.swift" ]; } && k="$k ios" ;; esac
  if [ -f "$p/Gemfile" ]; then k="$k ruby"; grep -qsE "^[[:space:]]*gem ['\"]rails['\"]" "$p/Gemfile" && k="$k rails"; fi
  [ -f "$p/composer.json" ] && k="$k php"
  c=("$p"/*.csproj "$p"/*.fsproj "$p"/*.sln)
  if [ ${#c[@]} -gt 0 ]; then k="$k dotnet"; grep -qsiE 'maui|Xamarin\.' "$p"/*.csproj && k="$k maui"; fi
  shopt -u nullglob
  echo "${k# }"
} </dev/null   # stdin closed: a grep whose glob matched nothing must not read the caller's project list


# ---- guard: instant, read-only (df + uptime only). Call before a build or an emulator boot --------
if [ "$CMD" = guard ]; then
  for v in "$MINFREE" "$HARD" "$MAXLOAD"; do printf '%s' "$v" | grep -Eq '^[0-9]+(\.[0-9]+)?$' || { echo "guard: thresholds must be numbers (got '$v')" >&2; exit 2; }; done
  G_LOAD="$(uptime | sed -E 's/.*averages?: ([0-9.]+).*/\1/')"
  G_FREE="$(df -Pk "$HOME" | awk 'NR==2{printf "%.1f", $4/1048576}')"
  G_ST="$(awk -v f="$G_FREE" -v h="$HARD" -v m="$MINFREE" -v l="$G_LOAD" -v x="$MAXLOAD" 'BEGIN{ if(f<h) print "stop"; else if(f<m||l>=x) print "low"; else print "ok" }')"
  if [ "$KV" = 1 ]; then echo "load=$G_LOAD"; echo "free_gb=$G_FREE"; echo "status=$G_ST"; echo "min_free_gb=$MINFREE"; echo "hard_gb=$HARD"; echo "max_load=$MAXLOAD"
  elif [ "$QUIET" = 0 ] || [ "$G_ST" != ok ]; then
    echo "guard $G_ST: ${G_FREE} GiB free (soft floor $MINFREE, hard stop $HARD), load $G_LOAD (limit $MAXLOAD)"
    [ "$G_ST" = stop ] && echo "  -> below the hard stop: do not start a build or boot an emulator; run 'host-hygiene.sh plan'"
    if [ "$G_ST" = low ]; then
      awk -v f="$G_FREE" -v m="$MINFREE" 'BEGIN{exit !(f<m)}' && echo "  -> disk below the soft floor: run 'host-hygiene.sh plan' to free space"
      awk -v l="$G_LOAD" -v x="$MAXLOAD" 'BEGIN{exit !(l>=x)}' && echo "  -> load at/above the limit: timings and ANRs are unreliable; close apps or wait"
    fi
  fi
  case "$G_ST" in ok) exit 0 ;; low) exit 1 ;; *) exit 2 ;; esac
fi

# ---- apply: act ONLY on explicit --target paths, re-verifying each one itself ----------------
if [ "$CMD" = apply ]; then
  [ -n "$TARGETS" ] || { echo "apply: give at least one --target PATH (see 'plan'); nothing to do" >&2; exit 2; }
  [ "$RUN" = 1 ] && [ "$YES" = 0 ] && [ ! -t 0 ] && { echo "apply --run needs a terminal for per-item approval, or --yes" >&2; exit 2; }
  PROJ_REL=" build .dart_tool ios/Pods android/.gradle android/build node_modules target "
  # classify TARGET -> sets CLS REM WHY ; returns 1 if refused
  classify() {
    local t="$1" top rel id needs pat cls rem cost f
    CLS=""; REM=""; WHY=""; CATID=""
    case "$t" in /*) ;; *) WHY="not absolute"; return 1 ;; esac
    case "$t" in *..*) WHY="contains .."; return 1 ;; esac
    protected "$t" && { WHY="protected: it is on your never-touch list"; return 1; }
    [ -L "$t" ] && { WHY="symlink"; return 1; }
    [ -e "$t" ] || { WHY="does not exist"; return 1; }
    [ "$t" = "$HOME" ] || [ "$t" = / ] && { WHY="refusing $t"; return 1; }
    # (a) catalog row (exact expansion of a glob)
    while IFS='|' read -r id needs pat cls rem cost; do
      pat="${pat/#\~/$HOME}"
      while IFS= read -r f; do
        [ "$f" = "$t" ] || continue
        [ "$cls" = never ] && { WHY="class never ($id)"; return 1; }
        case "$rem" in report-only*) WHY="report-only row ($id): apply never removes it; do it by hand (${rem#report-only: })"; return 1 ;; esac
        CLS="$cls"; REM="$rem"; CATID="$id"; WHY="catalog:$id"; return 0
      done < <(compgen -G "$pat")
    done < <(grep -vE '^\s*(#|$)' "$CATALOG")
    # (a1) K3b rows found by marker files, git or an environment variable (jupyter, .terraform, Unity/Godot/Unreal project dirs, TF_PLUGIN_CACHE_DIR)
    if type dc2_classify >/dev/null 2>&1; then dc2_classify "$t"; case $? in 0) return 0 ;; 2) return 1 ;; esac; fi
    # (a2) an unused Gradle version: ~/.gradle/caches/<ver> or ~/.gradle/wrapper/dists/gradle-<ver>-*  (re-check wrappers NOW)
    case "$t" in "$HOME"/.gradle/caches/[0-9]*|"$HOME"/.gradle/wrapper/dists/gradle-[0-9]*)
      local gv; gv="$(basename "$t" | sed -E 's/^gradle-//; s/-(bin|all)$//; s/\.0$//')"
      [ -n "$(gradle_used_versions)" ] || { WHY="no project wrapper found to compare against; refusing (cannot prove $gv unused)"; return 1; }
      if gradle_used_versions | grep -qx "$gv"; then WHY="Gradle $gv IS used by a project's wrapper"; return 1; fi
      CLS=ask-first; REM="rm-verified"; WHY="gradle-unused: no discovered project's wrapper uses $gv"; return 0 ;; esac
    # (b) per-project regenerable dir: inside a git repo AND git says it is ignored
    top="$(git -C "$(dirname "$t")" rev-parse --show-toplevel 2>/dev/null)" || { WHY="in no catalog row and not in a git repo"; return 1; }
    rel="${t#$top/}"
    case "$PROJ_REL" in *" $rel "*) ;; *)   # nested monorepo dirs (app/build): last component must be a known name
      case "$(basename "$t")" in build|.dart_tool|node_modules) ;; *) WHY="not a known regenerable name ($rel)"; return 1 ;; esac ;; esac
    git -C "$top" check-ignore -q "$rel" 2>/dev/null || { WHY="NOT git-ignored in $top"; return 1; }
    CLS=safe-regenerable; REM="rm-verified"; WHY="project dir, git-ignored in ${top/#$HOME/~}"; return 0
  }
  free_kb() { df -k / | awk 'NR==2{print $4}'; }
  N=0; TOTAL="$(printf '%s\n' "$TARGETS" | grep -c .)"
  [ "$RUN" = 1 ] && MODE=EXECUTE || MODE="DRY-RUN (add --run to execute)"
  if [ "$RUN" = 1 ]; then   # never delete without being able to record it
    mkdir -p "$(dirname "$LOG")" 2>/dev/null; { : >> "$LOG"; } 2>/dev/null || { echo "apply: cannot write the log ($LOG); refusing to delete anything unlogged" >&2; exit 2; }
  fi
  say() { echo "$*"; [ "$RUN" = 1 ] && echo "$*" >> "$LOG"; }
  say "== apply $MODE  $(date '+%F %T')  load $(uptime | sed 's/.*averages*: //')"
  B0="$(free_kb)"; say "   free before: $(hr "$B0")"
  FREED=0; DONE=0; FAILED=0
  while IFS= read -r T; do
    [ -z "$T" ] && continue; N=$((N+1)); T="${T%/}"
    if ! classify "$T"; then say "[$N/$TOTAL] REFUSED  ${T/#$HOME/~}  ($WHY)"; FAILED=$((FAILED+1)); [ "$RUN" = 1 ] && [ "$KEEP" = 0 ] && { say "stopping on refusal"; exit 1; }; continue; fi
    if [ "$CLS" = ask-first ] && [ "$ASKOK" = 0 ]; then say "[$N/$TOTAL] SKIPPED  ${T/#$HOME/~}  (ask-first: shared or costly; pass --ask-first-ok after reading its cost)"; continue; fi
    SZ="$(kb "$T")"; SHOW=""
    case "$REM" in
      rm-verified*) CMDLINE=(rm -rf -- "$T")
        if type dc_check_rm >/dev/null 2>&1 && ! dc_check_rm "$T" "$CATID"; then say "[$N/$TOTAL] REFUSED  ${T/#$HOME/~}  ($DWHY)"; FAILED=$((FAILED+1)); [ "$RUN" = 1 ] && [ "$KEEP" = 0 ] && { say "stopping on refusal"; exit 1; }; continue; fi ;;
      "docker system prune") CMDLINE=(docker system prune -f) ;;
      "npm cache clean --force") CMDLINE=(npm cache clean --force) ;;
      "brew cleanup -s") CMDLINE=(brew cleanup -s) ;;
      "flutter pub cache clean") CMDLINE=(flutter pub cache clean --force) ;;
      "xcrun simctl delete unavailable") CMDLINE=(xcrun simctl delete unavailable) ;;
      "avdmanager delete avd"*|"sdkmanager --uninstall"*|"fvm remove"*|"rustup toolchain uninstall"*)   # executors.sh: own-tool removal, guards re-run at execution
        if ! hh_x_prepare "$T" "$REM"; then say "[$N/$TOTAL] REFUSED  ${T/#$HOME/~}  ($XWHY)"; FAILED=$((FAILED+1)); [ "$RUN" = 1 ] && [ "$KEEP" = 0 ] && { say "stopping on refusal"; exit 1; }; continue; fi
        [ "$RUN" = 1 ] && say "   cost: $XCOST"; CMDLINE=(hh_x_run "$T" "$REM"); SHOW="${XCMD[*]}"; WHY="$WHY; cost: $XCOST" ;;
      *) if type dc_owns >/dev/null 2>&1 && dc_owns "$REM"; then   # devcatalog.sh: tool command, re-verified now and again at run time
           if ! dc_prepare "$T" "$CATID" "$REM"; then say "[$N/$TOTAL] REFUSED  ${T/#$HOME/~}  ($DWHY)"; FAILED=$((FAILED+1)); [ "$RUN" = 1 ] && [ "$KEEP" = 0 ] && { say "stopping on refusal"; exit 1; }; continue; fi
           [ "$RUN" = 1 ] && say "   cost: $DCOST"; CMDLINE=(dc_run "$T" "$CATID" "$REM"); SHOW="${DCMD[*]}"; WHY="$WHY; cost: $DCOST"
         else say "[$N/$TOTAL] SKIPPED  ${T/#$HOME/~}  (removal '$REM' is not supported by apply yet; run it by hand)"; continue; fi ;;
    esac
    if [ "$RUN" = 0 ]; then say "[$N/$TOTAL] WOULD $CLS  $(hr "$SZ")  ${T/#$HOME/~}  <- ${SHOW:-${CMDLINE[*]}}   ($WHY)"; continue; fi
    case "${CMDLINE[0]}" in rm|dc_run) if lsof -w +D "$T" 2>/dev/null | grep -q .; then say "[$N/$TOTAL] SKIPPED  ${T/#$HOME/~}  (files open by a running process)"; continue; fi ;; esac
    if [ "$YES" = 0 ]; then printf '[%s/%s] remove %s (%s, %s)? [y/N] ' "$N" "$TOTAL" "${T/#$HOME/~}" "$(hr "$SZ")" "$CLS"; read -r a </dev/tty; [ "$a" = y ] || { say "[$N/$TOTAL] declined  ${T/#$HOME/~}"; continue; }; fi
    say "[$N/$TOTAL] removing  $(hr "$SZ")  ${T/#$HOME/~}  ..."
    ERRF="$(mktemp -t hh-err.XXXXXX)"
    # An app's background helper can write into its folder while it is removed ("Directory not empty"): wait a moment and try once more.
    if "${CMDLINE[@]}" >/dev/null 2>"$ERRF" || { grep -q "Directory not empty" "$ERRF" && sleep 2 && "${CMDLINE[@]}" >/dev/null 2>"$ERRF"; }; then rm -f "$ERRF"; AF="$(kb "$T")"; AF="${AF:-0}"; G=$((SZ-AF)); [ "$G" -lt 0 ] && G=0
      say "[$N/$TOTAL] done      ${T/#$HOME/~}  (${SHOW:-${CMDLINE[*]}})  freed $(hr "$G") measured by du"; DONE=$((DONE+1)); FREED=$((FREED+G))
    else FAILED=$((FAILED+1)); say "[$N/$TOTAL] ERROR     ${SHOW:-${CMDLINE[*]}} failed; $([ "$KEEP" = 1 ] && echo continuing || echo stopping) ($(head -n 2 "$ERRF" | tr '\n' ' '))"; rm -f "$ERRF"; [ "$KEEP" = 1 ] || exit 1; fi
  done <<EOF2
$TARGETS
EOF2
  A1="$(free_kb)"
  say "   ran $DONE item(s), freed $(hr "$FREED") (du before/after per target); free after: $(hr "$A1") (delta $(hr $((A1-B0))); can lag: APFS purgeable, other writers)"
  [ "$FAILED" -gt 0 ] && say "   $FAILED item(s) were refused or failed (see above); the rest were processed"
  [ "$FAILED" -gt 0 ] && exit 1
  exit 0
fi

hh_mark startup
TC="$(detect_toolchains)"; hh_mark detect_toolchains
PROJECTS="$(find_projects)"; hh_mark find_projects
NDEV="$(printf '%s\n' "$PROJECTS" | while read -r p; do [ -n "$p" ] && { [ -n "$(kind_of "$p")" ] || { type dc2_marker_project >/dev/null 2>&1 && dc2_marker_project "$p"; }; } && echo x; done | wc -l | tr -d ' ')"
hh_mark profile_ndev
# java/python/brew are runtimes many non-developers have: shown by profile, not counted as developer signals
NTC="$(printf '%s\n' "$TC" | grep -cE '^(android|gradle|dart|fvm|xcode|docker|node|rust)')"
if [ -n "$FORCE_PROFILE" ]; then PROFILE="$FORCE_PROFILE"
elif [ "$NTC" -ge 2 ] || [ "$NDEV" -ge 1 ]; then PROFILE=developer; else PROFILE=non-developer; fi
has_tc() { [ "$1" = any ] && return 0; printf '%s\n' "$TC" | cut -f1 | grep -qx "$1"; }

host_summary() {
  local mem swap pg free_pg
  mem="$(sysctl -n hw.memsize)"; swap="$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $6" used of "$3}')"
  echo "os        $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
  echo "disk /    $(df -h / | awk 'NR==2{print $2" total, "$3" used, "$4" available"}')  (df)"
  echo "          $(diskutil info / 2>/dev/null | awk -F: '/Container Free Space/{gsub(/^ +/,"",$2); print "container free "$2}' | cut -d'(' -f1)(diskutil; the gap to df is purgeable space, (verify))"
  echo "snapshots $(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple') local Time Machine snapshot(s)"
  echo "memory    $((mem/1073741824)) GiB, swap ${swap:-n/a}"
  echo "load      $(uptime | sed 's/.*load averages*: //')   (guide: <8 fine, >8 timings untrustworthy)"
}

if [ "$CMD" = profile ] && [ "$TSV" = 1 ]; then   # machine-readable: meta / tc / proj rows (used by intro.sh)
  printf 'meta\tprofile\t%s\n' "$PROFILE"
  printf '%s\n' "$TC" | awk -F'\t' 'NF{printf "tc\t%s\t%s\n",$1,$2}'
  PROWS="$(printf '%s\n' "$PROJECTS" | while read -r p; do
    [ -z "$p" ] && continue; k="$(kind_of "$p")"; [ -z "$k" ] && continue
    m="$(mtime "$p/.git/index")"; [ "$m" = 0 ] && m="$(mtime "$p/.git")"
    a=0; [ $(( $(date +%s) - m )) -lt 7776000 ] && a=1
    printf 'proj\t%s\t%s\t%s\n' "$a" "$p" "$k"
  done)"
  [ -n "$PROWS" ] && printf '%s\n' "$PROWS"
  # appended rows, one per developer type: kind <id> <active projects> <all projects> <toolchain y|n>. Overlaps are folded:
  # node under rn/frontend, jvm under android/kmp, dotnet under maui, ruby under rails.
  { printf '%s\n' "$PROWS"; printf '%s\n' "$TC" | awk -F'\t' 'NF{print "tc\t"$1}'; } | awk -F'\t' '
    function fold(s,  t){ t=" " s " "
      if (t ~ / (rn|frontend) /) sub(/ node /," ",t); if (t ~ / (android|kmp) /) sub(/ jvm /," ",t)
      if (t ~ / maui /) sub(/ dotnet /," ",t); if (t ~ / rails /) sub(/ ruby /," ",t); return t }
    $1=="proj"{ n=split(fold($4),k," "); for(i=1;i<=n;i++){ all[k[i]]++; if($2==1) act[k[i]]++; seen[k[i]]=1 } }
    $1=="tc"{ tm["dart"]="flutter"; tm["android"]="android"; tm["xcode"]="ios"; tm["rust"]="rust"; tm["go"]="go"; tm["node"]="node"; tm["ruby"]="ruby"; tm["php"]="php"; tm["dotnet"]="dotnet"; tm["kmp"]="kmp"
      if($2 in tm){ tool[tm[$2]]=1; seen[tm[$2]]=1 } }
    END{ for(x in seen) printf "kind\t%s\t%d\t%d\t%s\n", x, act[x]+0, all[x]+0, (tool[x]?"y":"n") }' | sort -t"$(printf '\t')" -k3,3nr -k4,4nr -k2,2
  exit 0
fi
if [ "$CMD" = profile ]; then
  echo "== host";      host_summary
  echo "== profile     $PROFILE${FORCE_PROFILE:+ (forced)}   [$NTC toolchains, $NDEV dev projects]"
  echo "== toolchains"; printf '%s\n' "$TC" | awk -F'\t' '{printf "  %-8s %s\n",$1,$2}'
  echo "== projects (git repos with a manifest; * = touched in last 90d)"
  printf '%s\n' "$PROJECTS" | while read -r p; do
    [ -z "$p" ] && continue; k="$(kind_of "$p")"; [ -z "$k" ] && continue
    m="$(mtime "$p/.git/index")"; [ "$m" = 0 ] && m="$(mtime "$p/.git")"
    a=" "; [ $(( $(date +%s) - m )) -lt 7776000 ] && a="*"
    printf '  %s %-9s %-40s %s\n' "$a" "$(age "$m")" "${p/#$HOME/~}" "$k"
  done
  exit 0
fi

# ---- scan ------------------------------------------------------------------------------
# row: size_kb | class | id | path | mtime | removal | cost | owner
ROWS="$(mktemp)"; trap 'rm -f "$ROWS" "$ROWS.s"' EXIT
HH_ELAST=$SECONDS
emit() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" >> "$ROWS"
  # HH_TIMING=1: rows whose size/mtime work took >= 2 s (whole seconds, no fork); includes the du that produced $1
  if [ "${HH_TIMING:-0}" = 1 ]; then [ $((SECONDS-HH_ELAST)) -ge 2 ] && echo "time row:$3 $((SECONDS-HH_ELAST)) $4" >&2; HH_ELAST=$SECONDS; fi
}

# 1. catalog rows
grep -vE '^\s*(#|$)' "$CATALOG" | while IFS='|' read -r id needs pat cls rem cost; do
  [ "$PROFILE" = non-developer ] && [ "$needs" != any ] && continue
  has_tc "$needs" || { type dc_has >/dev/null 2>&1 && dc_has "$needs"; } || continue
  pat="${pat/#\~/$HOME}"
  compgen -G "$pat" | while IFS= read -r f; do
    [ -e "$f" ] || continue
    case "$id" in dot-cache|app-caches) type dc_has_child >/dev/null 2>&1 && dc_has_child "$f" && continue ;; esac
    c="$cls"; protected "$f" && c=never
    sz="$(awk -F'\t' -v p="$f" '$4==p{print $1; exit}' "$ROWS" 2>/dev/null)"   # the same path matched by an earlier row (e.g. Caches/Google): reuse its du, the later row is dropped by the dedupe anyway
    emit "${sz:-$(kb "$f")}" "$c" "$id" "$f" "$(mtime "$f")" "$rem" "$cost" "-"
  done
done

hh_mark catalog_rows
[ -f "$HERE/nondev.sh" ] && { . "$HERE/nondev.sh"; nondev_rows; }; hh_mark nondev_rows   # generic rows: old Downloads, large unused apps (read-only)
if [ "$PROFILE" = developer ]; then
  # 2. per-project regenerable dirs; safe only when git proves the path is ignored
  printf '%s\n' "$PROJECTS" | while read -r p; do
    [ -z "$p" ] && continue
    type dc2_project_rows >/dev/null 2>&1 && dc2_project_rows "$p"   # K3b: .ipynb_checkpoints, git-ignored .terraform
    hh_mark "pp_prev_tail+dc2_project_rows"
    for rel in build .dart_tool ios/Pods android/.gradle android/build node_modules target; do
      d="$p/$rel"; [ -d "$d" ] || continue
      case "$rel" in node_modules) [ -f "$p/package.json" ] || continue ;; target) [ -f "$p/Cargo.toml" ] || continue ;;
        build|.dart_tool|ios/Pods|android/*) [ -f "$p/pubspec.yaml" ] || [ -d "$p/android" ] || [ "$rel" != build ] || git -C "$p" check-ignore -q build 2>/dev/null || continue ;; esac
      if protected "$p"; then c=never; why="protected repo"
      elif git -C "$p" check-ignore -q "$rel" 2>/dev/null; then c=safe-regenerable; why="git-ignored"
      else c=ask-first; why="NOT git-ignored: verify before removing"; fi
      emit "$(kb "$d")" "$c" "project:$rel" "$d" "$(mtime "$d")" "rm-verified ($why)" "next build of this project is slower once" "${p/#$HOME/~}"
    done
    hh_mark pp_reldirs_du
    # 2b. the same dirs 1-3 levels down (monorepos: app/build, packages/x/node_modules);
    #     only when git proves them ignored; otherwise skipped (no manifest to justify asking)
    find "$p" -mindepth 2 -maxdepth 4 -type d \( -name .git -o -name node_modules -o -name build -o -name .dart_tool \) -prune -print 2>/dev/null |
    while IFS= read -r d; do
      case "$d" in */.git) continue ;; esac
      protected "$d" && continue
      git -C "$(dirname "$d")" check-ignore -q "$(basename "$d")" 2>/dev/null || continue
      emit "$(kb "$d")" safe-regenerable "project:$(basename "$d")" "$d" "$(mtime "$d")" "rm-verified (git-ignored)" "next build of this project is slower once" "${p/#$HOME/~}"
    done
  done

  hh_mark project_dirs_2_2b
  type dc2_extra_rows >/dev/null 2>&1 && dc2_extra_rows; hh_mark dc2_extra_rows   # K3b: TF_PLUGIN_CACHE_DIR, Unity/Godot/Unreal project dirs found by marker files

  # 3. Gradle versions that no project's wrapper uses (caches/<ver> and wrapper/dists/gradle-<ver>-*)
  USED="$(gradle_used_versions)"; hh_mark gradle_used_versions
  if [ -d "$HOME/.gradle/caches" ] && [ -n "$USED" ]; then
    for d in "$HOME"/.gradle/caches/[0-9]* "$HOME"/.gradle/wrapper/dists/gradle-[0-9]*; do
      [ -d "$d" ] || continue; b="$(basename "$d")"
      v="$(printf '%s' "$b" | sed -E 's/^gradle-//; s/-(bin|all)$//; s/\.0$//')"
      printf '%s\n' "$USED" | grep -qx "$v" && continue
      emit "$(kb "$d")" ask-first "gradle-unused" "$d" "$(mtime "$d")" "rm-verified (no discovered project's wrapper uses $v)" \
        "a project needing Gradle $v re-downloads/rebuilds it (verify project list is complete)" "-"
    done
  fi
fi

hh_mark catalog_and_projects_tail
awk -F'\t' '!seen[$4]++' "$ROWS" | sort -t"$(printf '\t')" -k1,1nr > "$ROWS.s"   # first catalog match wins, then rank

if [ "$TSV" = 1 ]; then
  awk -F'\t' -v m="$((MIN_MB*1024))" '$1>=m' "$ROWS.s"; exit 0
fi

echo "== host";   host_summary
echo "== profile $PROFILE   (read-only scan; nothing was changed or killed)"
echo "== storage findings >= ${MIN_MB} MB, largest first"
printf '  %7s  %-16s %-14s %5s  %s\n' SIZE CLASS ID AGE PATH
NOW="$(date +%s)"
awk -F'\t' -v m="$((MIN_MB*1024))" '$1>=m' "$ROWS.s" | while IFS="$(printf '\t')" read -r s c id path mt rem cost owner; do
  printf '  %7s  %-16s %-14s %5s  %s%s\n' "$(hr "$s")" "$c" "$id" "$(age "$mt")" "${path/#$HOME/~}" "$([ "$owner" != - ] && echo "  [$owner]")"
done
echo "== totals by class (sum of rows above; rows are leaf-level and do not overlap)"
awk -F'\t' -v m="$((MIN_MB*1024))" '$1>=m && $3!="downloads-old"{t[$2]+=$1} END{for(k in t) printf "%s\t%d\n",k,t[k]}' "$ROWS.s" | sort | while IFS="$(printf '\t')" read -r k v; do
  printf '  %-16s %s\n' "$k" "$(hr "$v")"; done
type nondev_report >/dev/null 2>&1 && nondev_report
echo "== processes: top 8 by CPU, top 8 by memory  (report only; no process is touched)"
ps -Aceo pid,pcpu,rss,comm -r | awk 'NR==1||NR<=9{printf "  cpu  %5s%%  %7s  %s\n",$2,($3>0?int($3/1024)"M":"-"),$4}' | tail -n +2
ps -Aceo pid,pmem,rss,comm -m | awk 'NR>1&&NR<=9{printf "  mem  %5s%%  %7s  %s\n",$2,int($3/1024)"M",$4}'
KNOWN='mds|mds_stores|mdworker|WindowServer|mediaanalysisd|WhatsApp|Telegram'
ps -Aceo pcpu,rss,comm | awk -v k="$KNOWN" 'NR>1 && $3 ~ "^("k")" && $1>10{printf "  note: %s is using %s%% CPU (known offender here). Measures in the plan phase; nothing is killed.\n",$3,$1}'
[ -x "$HERE/perf.sh" ] && "$HERE/perf.sh" advice
