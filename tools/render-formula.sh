#!/usr/bin/env bash
# Prints the Homebrew formula for a release: tools/render-formula.sh VERSION SHA256  (template: packaging/homebrew/host-hygiene.rb)
set -eu
D="$(cd "$(dirname "$0")/.." && pwd -P)"; V="${1:?version}"; H="${2:?sha256}"
printf '%s' "$H" | grep -Eq '^[0-9a-f]{64}$' || { echo "render-formula: not a SHA-256: $H" >&2; exit 2; }
printf '%s' "$V" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "render-formula: not a version: $V" >&2; exit 2; }
sed -e "s/@VERSION@/$V/g" -e "s/@SHA256@/$H/g" "$D/packaging/homebrew/host-hygiene.rb"
