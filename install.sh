#!/usr/bin/env bash
# Installs the `hh` command for this checkout. Touches only what it prints; `./uninstall.sh` undoes it.
#   ./install.sh [--prefix DIR] [--claude]
#   --prefix DIR  where the `hh` wrapper goes (default ~/.local/bin)
#   --claude      also link this folder as a Claude Code skill (~/.claude/skills/host-hygiene)
set -eu
HERE="$(cd "$(dirname "$0")" && pwd -P)"; PREFIX="$HOME/.local/bin"; CLAUDE=0
while [ $# -gt 0 ]; do case "$1" in --prefix) PREFIX="${2:?--prefix needs a folder}"; shift 2 ;; --claude) CLAUDE=1; shift ;; *) echo "install: unknown argument $1" >&2; exit 2 ;; esac; done
[ "$(uname -s)" = Darwin ] || { echo "host-hygiene is macOS only" >&2; exit 3; }
chmod +x "$HERE"/scripts/*.sh "$HERE"/scripts/*.command 2>/dev/null || true
mkdir -p "$PREFIX"; printf '#!/bin/sh\nexec "%s/scripts/host-hygiene.sh" "$@"\n' "$HERE" > "$PREFIX/hh"; chmod +x "$PREFIX/hh"
echo "installed: $PREFIX/hh  (host-hygiene $(cat "$HERE/VERSION"))"
case ":$PATH:" in *":$PREFIX:"*) ;; *) echo "note: $PREFIX is not on your PATH. Add it, or run $PREFIX/hh directly." ;; esac
if T="$("$HERE/scripts/host-hygiene.sh" --tui-bin 2>/dev/null)"; then echo "interface: $(basename "$T") for this $(uname -m) Mac"
else echo "note: no interface binary for this Mac ($(uname -m)), so hh uses the plain shell menu. Take a release archive (it carries one for each chip), or build one with tui/build.sh (needs a Dart SDK)."; fi
if [ "$CLAUDE" = 1 ]; then
  D="$HOME/.claude/skills/host-hygiene"; mkdir -p "$HOME/.claude/skills"
  if [ -e "$D" ] && [ ! -L "$D" ]; then echo "not linking the Claude skill: $D already exists and is not a link" >&2; else ln -sfn "$HERE" "$D"; echo "linked: $D -> $HERE"; fi
fi
echo "try: hh      (add 'hh schedule on' later for disk, memory and CPU alarms)"
