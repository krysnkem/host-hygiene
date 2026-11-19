# host-hygiene developer-cache catalog support (K3). SOURCED by host-hygiene.sh. Defines functions only. bash 3.2.
# Rows live in catalog/catalog.tsv (section "developer caches"). This file adds:
#   dc_has NEEDS        extra toolchain gating for the new needs ids (node python go rust jvm php dotnet ruby cocoapods),
#                       dir- or tool-based, so a home only shows rows for what it really has
#   dc_owns REM         is the removal text one of the tool commands handled here?
#   dc_prepare T ID REM re-verify at apply time and build DCMD (tool command) or refuse (DWHY says why)
#   dc_run T ID REM     what apply executes: re-verify, run the tool, check
#   dc_check_rm T ID    extra guards before an rm-verified row (open by a running process, IDE or daemon running)
#   dc_supported_list   ",word=y,word=n," for plan --tsv column 8
# The tool's own command is used where one exists. Before it runs we ask the tool WHICH directory it would clear
# and refuse unless that is the target (an env override such as PIP_CACHE_DIR would otherwise empty another dir).

# process list; HH_DC_PS_FILE is a test seam (a ps fixture)
dc_ps() { if [ -n "${HH_DC_PS_FILE:-}" ]; then cat "$HH_DC_PS_FILE" 2>/dev/null; else ps -Ao command= 2>/dev/null; fi; }
dc_have() { command -v "$1" >/dev/null 2>&1; }
dc_dir() { [ -d "$1" ]; }

dc_has() {
  case "$1" in
    node) dc_have node || dc_have npm || dc_have pnpm || dc_have bun || dc_have deno || dc_dir "$HOME/.npm" || dc_dir "$HOME/Library/pnpm" || dc_dir "$HOME/.bun" ;;
    python) dc_have uv || dc_have pip3 || dc_have pip || dc_have pyenv || dc_dir "$HOME/Library/Caches/pip" || dc_dir "$HOME/.cache/uv" || dc_dir "$HOME/.pyenv" ;;
    go) dc_have go || dc_dir "$HOME/go" || dc_dir "$HOME/Library/Caches/go-build" ;;
    jvm) dc_have java || dc_dir "$HOME/.konan" || dc_dir "$HOME/Library/Caches/JetBrains" || dc_dir "$HOME/.sdkman" ;;
    php) dc_have composer || dc_dir "$HOME/.composer" ;;
    dotnet) dc_have dotnet || dc_dir "$HOME/.nuget" ;;
    ruby) dc_have rbenv || dc_dir "$HOME/.rbenv" ;;
    cocoapods) dc_have pod || dc_dir "$HOME/.cocoapods" || dc_dir "$HOME/Library/Caches/CocoaPods" ;;
    ml|devops|game) type dc2_has >/dev/null 2>&1 && dc2_has "$1" ;;   # K3b, scripts/devcatalog2.sh
    *) return 1 ;;
  esac
}

# tool lookup: PATH first, then the tool's usual install dir (a package manager is often not on PATH)
dc_tool() {
  local n="$1" p d
  p="$(command -v "$n" 2>/dev/null)" && { printf '%s' "$p"; return 0; }
  case "$n" in
    pnpm) set -- "$HOME/Library/pnpm" "$HOME/.local/share/pnpm" ;;
    bun) set -- "$HOME/.bun/bin" ;;
    deno) set -- "$HOME/.deno/bin" ;;
    pyenv) set -- "$HOME/.pyenv/bin" ;;
    rbenv) set -- "$HOME/.rbenv/bin" ;;
    uv) set -- "$HOME/.local/bin" "$HOME/.cargo/bin" ;;
    go) set -- /usr/local/go/bin "$HOME/go/bin" ;;
    pod) set -- "$HOME/.rbenv/shims" ;;
    composer) set -- "$HOME/.composer/vendor/bin" ;;
    *) return 1 ;;
  esac
  for d in "$@"; do [ -x "$d/$n" ] && { printf '%s' "$d/$n"; return 0; }; done
  return 1
}
dc_pip() {   # sets DPIP array
  local p; DPIP=()
  p="$(dc_tool pip3)" && { DPIP=("$p"); return 0; }
  p="$(dc_tool pip)" && { DPIP=("$p"); return 0; }
  if p="$(dc_tool python3)" && "$p" -m pip --version >/dev/null 2>&1; then DPIP=("$p" -m pip); return 0; fi
  return 1
}

# `bun pm cache [rm]` refuses to run outside a project ("No package.json was found"): give it a throwaway one
dc_bunwd() { DBUNWD="${TMPDIR:-/tmp}/hh-bun-cwd"; mkdir -p "$DBUNWD" && [ -f "$DBUNWD/package.json" ] || echo '{}' > "$DBUNWD/package.json"; }

dc_owns() {
  case "$1" in
    "pip cache purge"|"uv cache clean"|"go clean -modcache"|"go clean -cache"|"composer clear-cache"|"dotnet nuget locals global-packages --clear"|"pnpm store prune"|"bun pm cache rm"|"npm cache npx rm"|"deno clean"|"corepack cache clean"|"pod cache clean --all") return 0 ;;
    "pyenv uninstall"*|"rbenv uninstall"*) return 0 ;;
  esac
  return 1
}

dc_cost() { grep -vE '^\s*(#|$)' "$CATALOG" | awk -F'|' -v i="$1" '$1==i{print $6; exit}'; }
dc_rp() { ( cd -P "$1" 2>/dev/null && pwd -P ); }
# dc_same TARGET TOOLDIR [under]: tool dir equals target (or, with "under", lies inside it)
dc_same() {
  local a b; a="$(dc_rp "$1")"; b="$(dc_rp "$2")"
  [ -n "$a" ] && [ -n "$b" ] || return 1
  [ "$a" = "$b" ] && return 0
  [ "${3:-}" = under ] && case "$b" in "$a"/*) return 0 ;; esac
  return 1
}

# version pins for pyenv / rbenv: .python-version / .ruby-version / .tool-versions of discovered projects, plus the global file
dc_ver_pins() {   # KIND(python|ruby) VERSION -> prints first hit; rc 1 if no project found at all
  local kind="$1" v="$2" p f hit="" any=0 projs gfile
  [ "$kind" = python ] && gfile="$HOME/.pyenv/version" || gfile="$HOME/.rbenv/version"
  [ -f "$gfile" ] && grep -qxF "$v" "$gfile" && hit="${gfile/#$HOME/~} (global)"
  projs="$(find_projects)"
  while IFS= read -r p; do
    [ -z "$p" ] && continue; any=1; [ -n "$hit" ] && break
    for f in "$p/.${kind}-version" "$p/.tool-versions"; do
      [ -f "$f" ] || continue
      if grep -qwF -- "$v" "$f"; then hit="${f/#$HOME/~}"; break 2; fi
    done
  done <<EOF
$projs
EOF
  [ "$any" = 1 ] || return 1
  printf '%s' "$hit"
}

dc_prepare() {
  local t="$1" id="$2" rem="$3" tool td="" b under="" kind hit
  DCMD=(); DCOST="$(dc_cost "$id")"; DWHY=""
  b="$(basename "$t")"
  case "$id" in
    pip-cache) dc_pip || { DWHY="pip not found (pip3, pip or python3 -m pip); run 'python3 -m pip cache purge' by hand"; return 1; }
      td="$("${DPIP[@]}" cache dir 2>/dev/null)"; DCMD=("${DPIP[@]}" cache purge) ;;
    uv-cache) tool="$(dc_tool uv)" || { DWHY="uv not found"; return 1; }
      td="$("$tool" cache dir 2>/dev/null)"; DCMD=("$tool" cache clean) ;;
    go-mod-cache) tool="$(dc_tool go)" || { DWHY="go not found"; return 1; }
      td="$("$tool" env GOMODCACHE 2>/dev/null)"; DCMD=("$tool" clean -modcache) ;;
    go-build-cache) tool="$(dc_tool go)" || { DWHY="go not found"; return 1; }
      td="$("$tool" env GOCACHE 2>/dev/null)"; DCMD=("$tool" clean -cache) ;;
    composer-cache) tool="$(dc_tool composer)" || { DWHY="composer not found"; return 1; }
      td="$("$tool" config cache-dir -g 2>/dev/null | tail -n 1)"; DCMD=("$tool" clear-cache) ;;
    nuget-packages) tool="$(dc_tool dotnet)" || { DWHY="dotnet not found"; return 1; }
      td="$(DOTNET_NOLOGO=1 DOTNET_CLI_TELEMETRY_OPTOUT=1 "$tool" nuget locals global-packages --list 2>/dev/null | tr -d '\r' | sed -n 's/^global-packages: *//p' | head -n 1)"; DCMD=("$tool" nuget locals global-packages --clear) ;;
    pnpm-store) tool="$(dc_tool pnpm)" || { DWHY="pnpm not found"; return 1; }
      td="$("$tool" store path 2>/dev/null)"; under=under; DCMD=("$tool" store prune) ;;
    bun-cache) tool="$(dc_tool bun)" || { DWHY="bun not found"; return 1; }
      dc_bunwd; td="$(cd "$DBUNWD" && "$tool" pm cache 2>/dev/null | tail -n 1)"; DCMD=("$tool" pm cache rm) ;;
    npm-npx-cache) tool="$(dc_tool npm)" || { DWHY="npm not found"; return 1; }
      td="$("$tool" config get cache 2>/dev/null)/_npx"; DCMD=("$tool" cache npx rm) ;;
    deno-cache) tool="$(dc_tool deno)" || { DWHY="deno not found"; return 1; }
      td="$(NO_COLOR=1 "$tool" info 2>/dev/null | sed "s/$(printf '\033')\[[0-9;]*m//g" | sed -n 's/^DENO_DIR location: *//p' | head -n 1)"; DCMD=("$tool" clean) ;;
    corepack-cache) tool="$(dc_tool corepack)" || { DWHY="corepack not found"; return 1; }
      td="${COREPACK_HOME:-$HOME/.cache/node/corepack}"; DCMD=("$tool" cache clean) ;;
    cocoapods-cache) tool="$(dc_tool pod)" || { DWHY="pod (CocoaPods) not found"; return 1; }
      [ -z "${CP_CACHE_DIR:-}" ] || td="$CP_CACHE_DIR"; [ -n "$td" ] || td="$HOME/Library/Caches/CocoaPods"; DCMD=("$tool" cache clean --all) ;;
    pyenv-versions|rbenv-versions)
      case "$id" in pyenv-versions) kind=python; tool="$(dc_tool pyenv)" || { DWHY="pyenv not found"; return 1; }; td="$HOME/.pyenv/versions"
          case "$t" in "$td"/*) ;; *) DWHY="not under ~/.pyenv/versions"; return 1 ;; esac ;;
        *) kind=ruby; tool="$(dc_tool rbenv)" || { DWHY="rbenv not found"; return 1; }; td="$HOME/.rbenv/versions"
          case "$t" in "$td"/*) ;; *) DWHY="not under ~/.rbenv/versions"; return 1 ;; esac ;;
      esac
      hh_x_name_ok "$b" || { DWHY="unsafe version name '$b'"; return 1; }
      hit="$(dc_ver_pins "$kind" "$b")" || { DWHY="no discovered project found to compare against; cannot prove $b unused"; return 1; }
      [ -n "$hit" ] && { DWHY="$b is pinned by $hit"; return 1; }
      DCMD=("$tool" uninstall -f "$b"); td="$t" ;;
    *) DWHY="no executor for '$rem'"; return 1 ;;
  esac
  [ -n "$td" ] || { DWHY="the tool did not say which directory it would clear; refusing"; return 1; }
  dc_same "$t" "$td" $under || { DWHY="the tool would clear ${td/#$HOME/~}, not this path (env override?); refusing"; return 1; }
  return 0
}

dc_run() {
  dc_prepare "$1" "$2" "$3" || { echo "re-verification refused: $DWHY" >&2; return 1; }
  if [ "$2" = bun-cache ]; then ( cd "$DBUNWD" && "${DCMD[@]}" >/dev/null ) || return 1   # bun pm cache needs a package.json in the cwd
  else "${DCMD[@]}" >/dev/null || return 1; fi
  case "$2" in pyenv-versions|rbenv-versions) [ -e "$1" ] && { echo "tool reported success but $1 still exists" >&2; return 1; } ;; esac
  return 0
}

# guards for rm-verified rows of the developer catalog (called by apply right before the rm)
dc_check_rm() {   # T ID -> rc 1 with DWHY
  local t="$1" id="$2" rp gid
  DWHY=""; [ -n "$id" ] || return 0   # only catalog rows; project dirs / gradle-unused keep their own checks
  rp="$(dc_rp "$t")"; [ -n "$rp" ] || { DWHY="cannot resolve $t"; return 1; }
  case "$rp" in "$(dc_rp "$HOME")"/*) ;; *) DWHY="resolves outside \$HOME ($rp)"; return 1 ;; esac
  if dc_ps | awk -v hhp="$rp/" 'index($0, hhp) && $0 !~ /awk -v hhp/ {f=1} END{exit !f}'; then DWHY="a running process executes something inside it"; return 1; fi
  # the target's own row plus every specific row that lies inside it: applying ~/Library/Caches/JetBrains through the generic
  # app-caches row must get the intellij guard, ~/.gradle/caches the transforms guard, and so on
  for gid in $id $(dc_child_ids "$rp"); do
    case "$gid" in
      intellij-caches) dc_ps | grep -qE '/(IntelliJ IDEA|PyCharm|WebStorm|GoLand|CLion|RubyMine|PhpStorm|Rider|DataGrip|RustRover|Android Studio)[^/]*\.app/' && { DWHY="a JetBrains IDE is running; close it first"; return 1; } ;;
      gradle-transforms) dc_ps | grep -q '[G]radleDaemon' && { DWHY="a Gradle daemon is running; run 'gradle --stop' first"; return 1; } ;;
      *) type dc2_guard >/dev/null 2>&1 && { dc2_guard "$gid" || return 1; } ;;   # K3b editor / terraform guards
    esac
  done
  return 0
}

# ids of specific (non-generic) catalog rows with a path at or inside directory $1 (real path)
dc_child_ids() {
  local f="$1" id needs pat cls rem cost g
  while IFS='|' read -r id needs pat cls rem cost; do
    case "$id" in dot-cache|app-caches|app-cache-google|trash) continue ;; esac
    pat="${pat/#\~/$HOME}"
    while IFS= read -r g; do
      [ -n "$g" ] || continue; g="$(dc_rp "$g")"
      case "$g" in "$f"|"$f"/*) echo "$id"; break ;; esac
    done < <(compgen -G "$pat")
  done < <(grep -vE '^\s*(#|$)' "$CATALOG")
}

dc_supported_list() {
  local out="," w
  for w in pip uv go composer dotnet pnpm bun npm deno corepack pod pyenv rbenv; do
    case "$w" in pip) dc_pip && out="$out$w=y," || out="$out$w=n," ;;
      *) dc_tool "$w" >/dev/null && out="$out$w=y," || out="$out$w=n," ;; esac
  done
  printf '%s' "$out"
}

# a generic cache row (dot-cache, app-caches) whose directory CONTAINS a more specific catalog row would double-count it
# (~/Library/Caches/JetBrains/<ide> under app-caches' ~/Library/Caches/JetBrains, ~/.cache/node/corepack under ~/.cache/node).
# rc 0 = such a row exists under F, so the generic row is left out and the specific one speaks for it.
dc_has_child() {
  local f="$1" id needs pat cls rem cost g
  while IFS='|' read -r id needs pat cls rem cost; do
    case "$id" in dot-cache|app-caches|app-cache-google|trash) continue ;; esac
    pat="${pat/#\~/$HOME}"
    case "$pat" in "$f"/*) compgen -G "$pat" >/dev/null && return 0 ;; esac
  done < <(grep -vE '^\s*(#|$)' "$CATALOG")
  return 1
}
