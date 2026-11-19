#!/usr/bin/env bash
# Build a throwaway developer-like HOME for testing host-hygiene. Usage: make-dev-home.sh DIR
# Everything is fake. Run host-hygiene with: env -i HOME=DIR PATH=/usr/bin:/bin:/usr/sbin:/sbin ...
# (the stripped PATH guarantees no real docker/flutter/npm/brew/xcrun can be called by `apply`).
set -eu
H="${1:?usage: make-dev-home.sh DIR}"; rm -rf "$H"; mkdir -p "$H"
mk() { mkdir -p "$(dirname "$1")"; mkfile "$2" "$1"; }
mk "$H/.gradle/caches/modules-2/files.bin" 60m          # shared dependency cache (ask-first)
mk "$H/.gradle/caches/7.0/transforms/t.bin" 40m          # Gradle version NO project uses (unused)
mk "$H/.gradle/caches/8.5/transforms/t.bin" 30m          # Gradle version the app project uses (kept)
mk "$H/.pub-cache/hosted/pkgs.bin" 40m
mk "$H/Library/Developer/Xcode/DerivedData/Runner-abc/x.bin" 50m
mk "$H/Library/Developer/Xcode/Archives/2026/app.xcarchive" 30m
mk "$H/Library/Android/sdk/ndk/25.1.8937393/n.bin" 45m
mk "$H/.android/avd/Pixel_Fake.avd/userdata.img" 55m
mk "$H/Library/Caches/com.example.app/c.bin" 20m
mk "$H/Downloads/report.pdf" 25m
# project 1: Flutter app, gradle 8.5, ignored build/.dart_tool/android/.gradle
A="$H/work/app"; mkdir -p "$A/android/gradle/wrapper" "$A/lib"
echo "name: app" > "$A/pubspec.yaml"; echo "distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip" > "$A/android/gradle/wrapper/gradle-wrapper.properties"
printf 'build/\n.dart_tool/\nandroid/.gradle/\n' > "$A/.gitignore"; echo "void main(){}" > "$A/lib/main.dart"
mk "$A/build/out.bin" 40m; mk "$A/.dart_tool/d.bin" 15m; mk "$A/android/.gradle/g.bin" 10m
( cd "$A" && git init -q )
# project 2: node app. node_modules ignored (safe); `build` NOT ignored (trap: must be refused)
W="$H/work/web"; mkdir -p "$W"; echo '{}' > "$W/package.json"; printf 'node_modules/\n' > "$W/.gitignore"
mk "$W/node_modules/m.bin" 35m; mk "$W/build/b.bin" 12m
( cd "$W" && git init -q )
# project 3: a repo on the never-touch list
B="$H/work/protected_repo"; mkdir -p "$B"; echo "module x" > "$B/go.mod"; printf 'build/\n' > "$B/.gitignore"; mk "$B/build/y.bin" 20m
( cd "$B" && git init -q )
mkdir -p "$H/.config/host-hygiene"; echo protected_repo > "$H/.config/host-hygiene/protected"
echo "dev-like home ready: $H  ($(find "$H" -type f | wc -l | tr -d ' ') files)"
