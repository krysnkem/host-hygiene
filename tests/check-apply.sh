#!/usr/bin/env bash
# check-apply.sh: what `apply --run` does when an item is refused or fails, with and without --keep-going, and the one retry for "Directory not empty". Fake home only.
# Usage: check-apply.sh [SCRATCH_DIR]     bash 3.2.
D="$(cd "$(dirname "$0")/.." && pwd)"; S="${1:-$(mktemp -d)}"; mkdir -p "$S"; HH="$D/scripts/host-hygiene.sh"; pass=0; fail=0
ok() { pass=$((pass+1)); }; bad() { fail=$((fail+1)); echo "FAIL $1 :: $2"; }
eq() { [ "$2" = "$3" ] && ok || bad "$1" "want '$3' got '$2'"; }
has() { case "$2" in *"$3"*) ok ;; *) bad "$1" "missing '$3'" ;; esac; }; hasnt() { case "$2" in *"$3"*) bad "$1" "unexpected '$3'" ;; *) ok ;; esac; }
DEV="$S/home"; fresh() { rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null; }
ap() { HOME="$DEV" HH_NO_PROMPT=1 "$HH" apply "$@" --run --yes 2>&1; }
echo "== a refused item"
fresh; o="$(ap --target /nonexistent/x --target "$DEV/work/web/node_modules")"; has "default: stops on the refusal" "$o" "stopping on refusal"; [ -d "$DEV/work/web/node_modules" ] && ok || bad "default left the next item alone" "it was removed"
fresh; o="$(ap --keep-going --target /nonexistent/x --target "$DEV/work/web/node_modules")"; rc=$?; has "keep-going: the next item is processed" "$o" "done      ~/work/web/node_modules"; [ ! -d "$DEV/work/web/node_modules" ] && ok || bad "keep-going removed the next item" "still there"; has "and it says how many failed" "$o" "1 item(s) were refused or failed"; hasnt "and does not say it stopped" "$o" "stopping"
HOME="$DEV" "$HH" apply --keep-going --target /nonexistent/x --target "$DEV/work/web/build" --run --yes >/dev/null 2>&1; eq "exit code is 1 when any item failed" "$?" 1
echo "== a failing rm: one retry for Directory not empty"
fresh; mkdir -p "$S/shim"; printf '#!/bin/sh\n[ "$1" = -rf ] || exec /bin/rm "$@"\nn="%s/count"; c=$(cat "$n" 2>/dev/null || echo 0); echo $((c+1)) > "$n"\nif [ "$c" -lt "${SHIM_FAILS:-1}" ]; then echo "rm: $4: Directory not empty" >&2; exit 1; fi\nexec /bin/rm "$@"\n' "$S" > "$S/shim/rm"; chmod +x "$S/shim/rm"
rm -f "$S/count"; o="$(PATH="$S/shim:$PATH" SHIM_FAILS=1 ap --keep-going --target "$DEV/work/web/node_modules")"; has "one failure then success: the item is removed" "$o" "done      ~/work/web/node_modules"; eq "rm was tried twice" "$(cat "$S/count")" 2
fresh; rm -f "$S/count"; o="$(PATH="$S/shim:$PATH" SHIM_FAILS=9 ap --keep-going --target "$DEV/work/web/node_modules" --target "$DEV/work/app/build")"; has "a persistent failure is reported" "$o" "ERROR"; has "and says it continued" "$o" "continuing"
eq "each item was tried twice, and the second was still reached" "$(cat "$S/count")" 4
fresh; rm -f "$S/count"; o="$(PATH="$S/shim:$PATH" SHIM_FAILS=9 ap --target "$DEV/work/web/node_modules" --target "$DEV/work/app/build")"; has "without keep-going it stops" "$o" "stopping"; [ -d "$DEV/work/app/build" ] && ok || bad "without keep-going the next item is left" "it was removed"
echo "passed $pass, failed $fail"; [ "$fail" = 0 ]
