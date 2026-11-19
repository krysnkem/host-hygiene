# Flutter / Dart developer

## Entries

### pub-cache
- what: Dart package download cache shared by every Dart/Flutter project
- catalog-id: pub-cache
- paths: ~/.pub-cache
- size: 4.2 G (measured here)
- class: ask-first
- removal: flutter pub cache clean
- regen: next `pub get` re-downloads packages; needs network, offline projects break until then
- growth: grows with every new package version any project resolves; old versions are not pruned. Suggested budget 5 G (suggested)
- source: measured on this host 2026-11-17 (STATUS.md largest-items list)

### fvm-sdk
- what: Flutter SDK versions installed by FVM, one directory per version
- catalog-id: fvm-sdk
- paths: ~/fvm/versions/*
- size: about 1 G per version (unverified); 1.6 G total (measured here, via mole report in STATUS.md)
- class: ask-first
- removal: fvm remove <version>
- regen: re-download about 1 G if a project pins that version; apply refuses versions pinned by .fvmrc or the fvm default
- growth: one new SDK per Flutter upgrade or per project pin; never auto-pruned. Suggested budget: keep only pinned versions (suggested)
- source: measured on this host 2026-11-17 (total); per-version size (unverified)

### flutter-project-build
- what: per-project `build/` output (APK/AAB/iOS/intermediates) of a Flutter app
- catalog-id: none
- paths: <project>/build
- size: app-one 4.2 G, app-two 2.7 G, app-three 2.1 G (measured here)
- class: safe-regenerable
- removal: flutter clean (or rm-verified after git confirms the dir is ignored)
- regen: next build of that project is a full rebuild, minutes; no network beyond cached packages
- growth: grows per build mode and per ABI; the biggest per-project consumers on this host. Suggested budget 2 G per project (suggested)
- source: measured on this host 2026-11-17 (engine detects these in code, scan: projects)

### dart-tool
- what: per-project `.dart_tool/` (package config, analyzer and build_runner caches)
- catalog-id: none
- paths: <project>/.dart_tool
- size: (unverified)
- class: safe-regenerable
- removal: rm-verified after git confirms it is ignored (flutter clean also removes it)
- regen: `flutter pub get` recreates it; build_runner outputs need a regenerate run
- growth: grows with build_runner caches and analyzer state; per-project
- source: measured on this host 2026-11-17 (found by mole purge dry-run, STATUS.md); size (unverified)

### flutter-sdk-cache
- what: the Flutter SDK's own `bin/cache` (engine artifacts per platform)
- catalog-id: none
- paths: <flutter sdk>/bin/cache
- size: (unverified)
- class: ask-first
- removal: flutter precache --help lists what can be re-fetched; otherwise none
- regen: engine artifacts re-download on the next run; needs network
- growth: grows when `flutter precache` adds platforms or the SDK upgrades
- source: (unverified)

## Developer habits
- Keeps several Flutter apps open at once, each with its own `build/`; builds debug and release for Android and iOS (measured here: three apps hold 9 G of build output).
- Pins different Flutter SDKs per project through FVM and rarely removes old ones (1.6 G here).
- Runs emulators and simulators continuously; see android-native.md and ios-native.md.
- Adds and upgrades packages often, so pub-cache accumulates versions.

## Signals
- `pubspec.yaml` containing `flutter:`; `.dart_tool/`; `.metadata`; `lib/main.dart`
- `~/.pub-cache`, `~/fvm`, `.fvmrc`, `.fvm/fvm_config.json`
- commands on PATH: `flutter`, `dart`, `fvm`
- profile toolchain ids from `host-hygiene profile`: dart, fvm

## Not covered / open questions
- Per-version FVM sizes and Flutter SDK `bin/cache` size not measured.
- `.dart_tool` size not measured separately.
- Pub hosted-hashes and git-dependency caches under ~/.pub-cache not split out.
- No researched (online) sizes yet; everything here is host-measured or unverified.
