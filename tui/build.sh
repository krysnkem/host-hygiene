#!/usr/bin/env bash
# Build the guided-journey TUI (needs a Dart SDK; Flutter ships one). Output: tui/hh_tui (macOS arm64 binary, ~7.5 MB).
set -eu
cd "$(dirname "$0")"
DART="$(command -v dart || echo "$HOME/dev-sdk/flutter/bin/cache/dart-sdk/bin/dart")"
"$DART" pub get && "$DART" analyze && "$DART" compile exe bin/hh_tui.dart -o hh_tui && echo "built: $(pwd)/hh_tui"
