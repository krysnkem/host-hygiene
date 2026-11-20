#!/usr/bin/env bash
# Builds dist/host-hygiene-VERSION.tar.gz plus its SHA-256 from this checkout: no personal files, no build junk, and one interface binary per chip.
#   tools/make-release.sh [OUT_DIR]
#   HH_BIN_ARM64=path   the Apple Silicon build (default: tui/hh_tui, which must be arm64)
#   HH_BIN_X64=path     the Intel build (required; build it on an Intel runner or under Rosetta, see docs/INTEL-PLAN.md)
# Each binary must be a Mach-O for its chip and must answer `--version` with this VERSION (an x86_64 one is run under Rosetta when this Mac is arm64).
set -eu
D="$(cd "$(dirname "$0")/.." && pwd -P)"; V="$(cat "$D/VERSION")"; OUT="${1:-$D/dist}"; N="host-hygiene-$V"; T="$(mktemp -d)"
A="${HH_BIN_ARM64:-$D/tui/hh_tui}"; X="${HH_BIN_X64:-}"
die() { echo "make-release: $*" >&2; rm -rf "$T"; exit 2; }
[ -f "$A" ] || die "no Apple Silicon binary at $A (set HH_BIN_ARM64, or run tui/build.sh on an Apple Silicon Mac)"
[ -n "$X" ] && [ -f "$X" ] || die "set HH_BIN_X64 to the Intel binary (an x86_64 build of tui/bin/hh_tui.dart)"
file -b "$A" | grep -q "Mach-O.*arm64" || die "$A is not an arm64 Mach-O"
file -b "$X" | grep -q "Mach-O.*x86_64" || die "$X is not an x86_64 Mach-O"
chk() { local out; out="$($2 "$1" --version 2>&1)" || die "$1 does not run"; case "$out" in "hh_tui $V "*) ;; *) die "$1 reports '$out', expected version $V" ;; esac; }
chk "$A" ""
if [ "$(uname -m)" != arm64 ]; then chk "$X" ""
elif arch -x86_64 /usr/bin/true 2>/dev/null; then chk "$X" "arch -x86_64"
else echo "make-release: Rosetta is not available here, so the Intel binary was not run (only its architecture was checked)" >&2; fi
mkdir -p "$OUT" "$T/$N"
( cd "$D" && tar --exclude='./dist' --exclude='./.git' --exclude='./.gitignore' --exclude='./apply-log.txt' --exclude='./STATUS.md' --exclude='./docs/tui-designs.html' --exclude='./docs/tui-design-options.pdf' --exclude='./tui/hh_tui' --exclude='.dart_tool' --exclude='*.b' --exclude='.DS_Store' -cf - . ) | ( cd "$T/$N" && tar -xf - )
cp "$A" "$T/$N/tui/hh_tui-arm64"; cp "$X" "$T/$N/tui/hh_tui-x86_64"; chmod +x "$T/$N/tui/hh_tui-arm64" "$T/$N/tui/hh_tui-x86_64"
tar -C "$T" -czf "$OUT/$N.tar.gz" "$N"; ( cd "$OUT" && shasum -a 256 "$N.tar.gz" > "$N.tar.gz.sha256" )
echo "built $OUT/$N.tar.gz ($(du -k "$OUT/$N.tar.gz" | cut -f1) KB): tui/hh_tui-arm64 and tui/hh_tui-x86_64"; cat "$OUT/$N.tar.gz.sha256"; rm -rf "$T"
