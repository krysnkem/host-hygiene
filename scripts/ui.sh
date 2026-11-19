# host-hygiene UI helpers (sourced by intro.sh and menu.sh). Animation only on a terminal; plain text otherwise.
B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; CYN=$'\033[36m'; MAG=$'\033[35m'
TTY=0; [ -t 1 ] && TTY=1

typeline() {   # typeline "text" : reveal like typing (fast), then newline
  if [ "$TTY" = 1 ]; then local t="$1" i; for ((i=0;i<${#t};i++)); do printf '%s' "${t:$i:1}"; sleep 0.012; done; printf '\n'; else printf '%s\n' "$1"; fi
}
spin() {   # spin "label" cmd args... : runs cmd, shows an animated spinner + elapsed seconds. Output of cmd -> $SPIN_OUT (file). rc = cmd's rc
  local label="$1"; shift; SPIN_OUT="$(mktemp)"
  if [ "$TTY" = 0 ]; then "$@" > "$SPIN_OUT" 2>/dev/null; return $?; fi
  "$@" > "$SPIN_OUT" 2>/dev/null & local pid=$! f=0 t0; t0=$(date +%s)
  local fr=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏); printf '\033[?25l'
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r\033[2K  %s%s%s %s %s(%ss)%s' "$CYN" "${fr[$((f%10))]}" "$R" "$label" "$D" "$(( $(date +%s)-t0 ))" "$R"; f=$((f+1)); sleep 0.1
  done
  wait "$pid"; local rc=$?
  printf '\r\033[2K  %s✓%s %s %s(%ss)%s\n' "$GRN" "$R" "$label" "$D" "$(( $(date +%s)-t0 ))" "$R"; printf '\033[?25h'
  return $rc
}
meter() {   # meter DONE TOTAL [width] -> ▰▰▰▱▱
  local d="$1" t="$2" w="${3:-20}" n i o=""; [ "$t" -gt 0 ] || t=1; n=$(( d*w/t )); for ((i=0;i<w;i++)); do [ "$i" -lt "$n" ] && o="${o}▰" || o="${o}▱"; done; printf '%s' "$o"
}
rule() { local n="$1" i o=""; for ((i=0;i<n;i++)); do o="${o}─"; done; printf '%s' "$o"; }
frame() {   # frame "Title" : a header rule
  local w; w="$(tput cols 2>/dev/null || echo 80)"; [ "$w" -gt 64 ] && w=64
  local t=" $1 "; local pad=$(( w-${#t}-7 )); [ "$pad" -lt 2 ] && pad=2
  printf '\n  %s╭─%s%s%s%s%s╮%s\n' "$MAG" "$R$B" "$t" "$R$MAG" "$(rule "$pad")" "" "$R"
}
frame_end() { local w; w="$(tput cols 2>/dev/null || echo 80)"; [ "$w" -gt 64 ] && w=64; printf '  %s╰%s╯%s\n' "$MAG" "$(rule $((w-6)))" "$R"; }
logo() { printf '%s  ╭───────────────────────────╮%s\n  %s│%s  %s◆ host-hygiene%s           %s│%s\n  %s│%s  %skeep your machine light%s  %s│%s\n  %s╰───────────────────────────╯%s\n' "$MAG" "$R" "$MAG" "$R" "$B" "$R" "$MAG" "$R" "$MAG" "$R" "$D" "$R" "$MAG" "$R" "$MAG" "$R"; }
