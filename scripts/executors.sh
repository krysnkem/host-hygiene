#!/usr/bin/env bash
# host-hygiene executors for items that are removed with their OWN tool, not rm:
#   Android AVDs (avdmanager), SDK packages (sdkmanager), fvm Flutter versions (fvm), rustup toolchains (rustup).
# Sourced by host-hygiene.sh (apply and plan). Defines functions only; runs nothing. Bash 3.2.
# All four are ask-first: the caller (apply) already demands a per-item yes AND --ask-first-ok.
# Every guard below runs at apply time, again right before the tool is called.

hh_x_sdk() { printf '%s' "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"; }

# hh_x_tool NAME -> prints the path of the tool (PATH first, then the SDK's cmdline-tools), rc 1 if absent
hh_x_tool() {
  local n="$1" p d r
  p="$(command -v "$n" 2>/dev/null)" && { printf '%s' "$p"; return 0; }
  case "$n" in avdmanager|sdkmanager)
    for r in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
      [ -n "$r" ] || continue
      for d in "$r"/cmdline-tools/latest/bin "$r"/cmdline-tools/*/bin "$r"/tools/bin; do
        [ -x "$d/$n" ] && { printf '%s' "$d/$n"; return 0; }
      done
    done ;;
  esac
  return 1
}

# is the removal command text in a catalog row one of ours?
hh_x_owns() { case "$1" in "avdmanager delete avd"*|"sdkmanager --uninstall"*|"fvm remove"*|"rustup toolchain uninstall"*) return 0 ;; esac; return 1; }

# a name that is safe to pass to a tool and to compare
hh_x_name_ok() { case "$1" in ""|.*|*/*|*[!A-Za-z0-9._+-]*) return 1 ;; esac; return 0; }

# AVD names in use by a running emulator: qemu/emulator processes with "-avd NAME" or "@NAME", plus adb
hh_x_running_avds() {
  ps -Ao command= 2>/dev/null | awk '/qemu-system|\/emulator|emulator64/ { for(i=1;i<=NF;i++){ if($i=="-avd"&&i<NF) print $(i+1); else if(substr($i,1,1)=="@"&&length($i)>1) print substr($i,2) } }'
  if command -v adb >/dev/null 2>&1; then
    adb devices 2>/dev/null | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device"{print $1}' | while IFS= read -r s; do
      adb -s "$s" emu avd name 2>/dev/null | head -n 1 | tr -d '\r'
    done
  fi
}

# hh_x_prepare TARGET REMTEXT -> rc 0: XCMD (array), XCOST set. rc 1: XWHY says why it is refused.
hh_x_prepare() {
  local t="$1" rem="$2" b par tool
  XCMD=(); XCOST=""; XWHY=""
  b="$(basename "$t")"
  case "$rem" in
  "avdmanager delete avd"*)
    case "$t" in "$HOME"/.android/avd/*.avd) ;; *) XWHY="not under ~/.android/avd"; return 1 ;; esac
    b="${b%.avd}"; hh_x_name_ok "$b" || { XWHY="unsafe AVD name '$b'"; return 1; }
    tool="$(hh_x_tool avdmanager)" || { XWHY="avdmanager not found (PATH or SDK cmdline-tools)"; return 1; }
    if hh_x_running_avds | grep -qxF "$b"; then XWHY="AVD '$b' is in use by a running emulator; close it first"; return 1; fi
    XCMD=("$tool" delete avd -n "$b")
    XCOST="emulator data and installed apps are lost; the AVD must be recreated to use it again" ;;
  "fvm remove"*)
    case "$t" in "$HOME"/fvm/versions/*) ;; *) XWHY="not under ~/fvm/versions"; return 1 ;; esac
    hh_x_name_ok "$b" || { XWHY="unsafe version name '$b'"; return 1; }
    tool="$(hh_x_tool fvm)" || { XWHY="fvm not found on PATH"; return 1; }
    local used; used="$(hh_x_fvm_pins "$b")" || { XWHY="no discovered project found to compare against; cannot prove $b unused"; return 1; }
    [ -n "$used" ] && { XWHY="Flutter $b is pinned by $used"; return 1; }
    [ -L "$HOME/fvm/default" ] && [ "$(basename "$(readlink "$HOME/fvm/default")")" = "$b" ] && { XWHY="Flutter $b is the fvm global default"; return 1; }
    XCMD=("$tool" remove "$b")
    XCOST="re-download about 1 GB if any project needs Flutter $b again" ;;
  "rustup toolchain uninstall"*)
    case "$t" in "$HOME"/.rustup/toolchains/*) ;; *) XWHY="not under ~/.rustup/toolchains"; return 1 ;; esac
    hh_x_name_ok "$b" || { XWHY="unsafe toolchain name '$b'"; return 1; }
    tool="$(hh_x_tool rustup)" || { XWHY="rustup not found on PATH"; return 1; }
    local def="" out st
    out="$("$tool" default 2>&1)" && def="$(printf '%s\n' "$out" | head -n 1 | awk '{print $1}')"
    st="$(sed -nE 's/^default_toolchain[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$HOME/.rustup/settings.toml" 2>/dev/null | head -n 1)"
    [ -z "$def" ] && [ -z "$st" ] && { XWHY="cannot determine the default toolchain; refusing"; return 1; }
    { [ "$b" = "$def" ] || [ "$b" = "$st" ] || { [ -n "$st" ] && case "$b" in "$st"-*) true ;; *) false ;; esac; }; } && { XWHY="$b is the active default toolchain"; return 1; }
    XCMD=("$tool" toolchain uninstall "$b")
    XCOST="re-download if a project needs $b (rust-toolchain file, cargo +$b)" ;;
  "sdkmanager --uninstall"*)
    local sdk rel pkg abis n
    sdk="$(hh_x_sdk)"
    case "$t" in "$sdk"/*) rel="${t#$sdk/}" ;; *) XWHY="not under the Android SDK ($sdk)"; return 1 ;; esac
    case "$rel" in
      ndk/*|build-tools/*|platforms/*|cmake/*) hh_x_name_ok "${rel#*/}" || { XWHY="unsafe package name"; return 1; }
        pkg="${rel%%/*};${rel#*/}" ;;
      system-images/*/*) # android-34/google_apis -> needs the single abi below it
        hh_x_name_ok "$(basename "$(dirname "$rel")")" || { XWHY="unsafe package name"; return 1; }
        abis="$(ls "$t" 2>/dev/null)"; n="$(printf '%s\n' "$abis" | grep -c .)"
        [ "$n" = 1 ] || { XWHY="system image has $n ABI dirs; remove it by hand with sdkmanager"; return 1; }
        pkg="system-images;$(basename "$(dirname "$rel")");$(basename "$rel");$abis"
        local sd="system-images/$(basename "$(dirname "$rel")")/$(basename "$rel")/"
        if grep -Fqs "$sd" "$HOME"/.android/avd/*.avd/config.ini 2>/dev/null; then XWHY="an AVD's config.ini uses this system image"; return 1; fi ;;
      *) XWHY="not an SDK package directory ($rel)"; return 1 ;;
    esac
    tool="$(hh_x_tool sdkmanager)" || { XWHY="sdkmanager not found (PATH or SDK cmdline-tools)"; return 1; }
    XCMD=("$tool" "--sdk_root=$sdk" --uninstall "$pkg")
    XCOST="re-download when a build, or an AVD, needs $pkg again" ;;
  *) XWHY="no executor for '$rem'"; return 1 ;;
  esac
  return 0
}

# hh_x_run TARGET REMTEXT: what apply executes as CMDLINE. Re-verifies, runs the tool, checks the path is gone.
hh_x_run() {
  hh_x_prepare "$1" "$2" || { echo "re-verification refused: $XWHY" >&2; return 1; }
  "${XCMD[@]}" >/dev/null || return 1
  [ -e "$1" ] && { echo "tool reported success but $1 still exists" >&2; return 1; }
  return 0
}

# plan: is the tool for this removal text present? (prints y or n)
hh_x_supported() {
  case "$1" in
    avdmanager*) hh_x_tool avdmanager >/dev/null && echo y || echo n ;;
    sdkmanager*) hh_x_tool sdkmanager >/dev/null && echo y || echo n ;;
    "fvm "*) hh_x_tool fvm >/dev/null && echo y || echo n ;;
    "rustup "*) hh_x_tool rustup >/dev/null && echo y || echo n ;;
    *) echo n ;;
  esac
}

# fvm: versions pinned by discovered projects. rc 1 if no project found at all. Prints "path" of the first pin.
hh_x_fvm_pins() {
  local v="$1" projs p f hit="" any=0
  projs="$(find_projects)"
  while IFS= read -r p; do
    [ -z "$p" ] && continue; any=1
    for f in "$p/.fvmrc" "$p/.fvm/fvm_config.json"; do
      [ -f "$f" ] || continue
      if grep -Eq "\"(flutter|flutterSdkVersion)\"[[:space:]]*:[[:space:]]*\"$(printf '%s' "$v" | sed 's/[.+]/\\&/g')(@[a-z]+)?\"" "$f"; then hit="${f/#$HOME/~}"; break 2; fi
    done
    # a .fvm/flutter_sdk symlink also names the pinned version
    if [ -L "$p/.fvm/flutter_sdk" ] && [ "$(basename "$(readlink "$p/.fvm/flutter_sdk")")" = "$v" ]; then hit="${p/#$HOME/~}/.fvm/flutter_sdk"; break; fi
  done <<EOF
$projs
EOF
  [ "$any" = 1 ] || return 1
  printf '%s' "$hit"
}
