#!/usr/bin/env bash
# Removes what install.sh added, and the alarm job if you turned it on. Your config (~/.config/host-hygiene) is left alone unless you pass --purge.
set -u
HERE="$(cd "$(dirname "$0")" && pwd -P)"; PREFIX="$HOME/.local/bin"; PURGE=0
while [ $# -gt 0 ]; do case "$1" in --prefix) PREFIX="${2:?}"; shift 2 ;; --purge) PURGE=1; shift ;; *) echo "uninstall: unknown argument $1" >&2; exit 2 ;; esac; done
"$HERE/scripts/host-hygiene.sh" schedule off 2>/dev/null || true
[ -f "$PREFIX/hh" ] && grep -q host-hygiene.sh "$PREFIX/hh" && rm -f "$PREFIX/hh" && echo "removed $PREFIX/hh"
[ -L "$HOME/.claude/skills/host-hygiene" ] && [ "$(readlink "$HOME/.claude/skills/host-hygiene")" = "$HERE" ] && rm -f "$HOME/.claude/skills/host-hygiene" && echo "removed the Claude skill link"
if [ "$PURGE" = 1 ]; then rm -rf "$HOME/.config/host-hygiene" && echo "removed ~/.config/host-hygiene"; else echo "kept ~/.config/host-hygiene (config, state, never-touch list); --purge removes it"; fi
echo "this folder ($HERE) was not deleted."
