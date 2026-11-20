#!/usr/bin/env bash
# Build the guided-journey TUI (needs a Dart SDK; Flutter ships one). Output: tui/hh_tui (a binary for the chip it is built on, ~8 MB; `hh_tui --version` names it).
set -eu
cd "$(dirname "$0")"
DART="$(command -v dart || echo "$HOME/dev-sdk/flutter/bin/cache/dart-sdk/bin/dart")"
"$DART" pub get && "$DART" analyze && "$DART" compile exe -DHH_VERSION="$(cat ../VERSION 2>/dev/null || echo dev)" bin/hh_tui.dart -o hh_tui && echo "built: $(pwd)/hh_tui"
