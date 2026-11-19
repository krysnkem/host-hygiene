#!/usr/bin/env bash
# Builds dist/host-hygiene-VERSION.tar.gz plus its SHA-256 from this checkout: no personal files, no build junk.
set -eu
D="$(cd "$(dirname "$0")/.." && pwd -P)"; V="$(cat "$D/VERSION")"; OUT="${1:-$D/dist}"; N="host-hygiene-$V"; T="$(mktemp -d)"
mkdir -p "$OUT" "$T/$N"
( cd "$D" && tar --exclude='./dist' --exclude='./.git' --exclude='./.gitignore' --exclude='./apply-log.txt' --exclude='./STATUS.md' --exclude='./docs/tui-designs.html' --exclude='./docs/tui-design-options.pdf' --exclude='.dart_tool' --exclude='.git' --exclude='*.b' --exclude='.DS_Store' -cf - . ) | ( cd "$T/$N" && tar -xf - )
tar -C "$T" -czf "$OUT/$N.tar.gz" "$N"; ( cd "$OUT" && shasum -a 256 "$N.tar.gz" > "$N.tar.gz.sha256" )
echo "built $OUT/$N.tar.gz ($(du -k "$OUT/$N.tar.gz" | cut -f1) KB)"; cat "$OUT/$N.tar.gz.sha256"; rm -rf "$T"
