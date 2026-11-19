# Kotlin Multiplatform and .NET MAUI / Xamarin developer

## Entries

### kotlin-native-konan
- what: Kotlin/Native compiler distributions, LLVM dependencies and prebuilt libraries downloaded for KMP iOS/native targets
- catalog-id: kotlin-native-konan
- paths: ~/.konan (catalog row covers ~/.konan/dependencies only)
- size: not present on this host (measured here); several GB is commonly reported for multi-target setups (unverified)
- class: ask-first
- removal: rm-verified of `~/.konan/dependencies` or a single `kotlin-native-prebuilt-*` dir; no vendor command
- regen: re-downloaded on the next Kotlin/Native build; needs network, can take many minutes
- growth: one compiler dist per Kotlin version plus shared dependencies; old versions are not pruned
- source: reported online, https://slack-chats.kotlinlang.org/t/9708433/what-is-konan-data-dir-incl-an-example-file-path-in-konan-pr (community, fetched 2026-11-17 via search; not official kotlinlang docs); confirms ~/.konan default and KONAN_DATA_DIR override; sizes (unverified)

### kotlin-daemon-and-profile
- what: Kotlin compile daemon logs and Gradle Kotlin build-profile reports
- catalog-id: none
- paths: ~/.gradle/kotlin-profile, $TMPDIR/kotlin-daemon.*.log
- size: 2.1 MB for ~/.gradle/kotlin-profile (measured here)
- class: safe-regenerable
- removal: rm-verified after `./gradlew --stop`
- regen: logs and profiles are written again on next build
- growth: small
- source: measured on this host 2026-11-17

### kmp-project-build
- what: per-project Gradle build output of a KMP module (shared, androidMain, iosMain, framework outputs)
- catalog-id: none
- paths: <project>/build, <project>/*/build, <project>/.gradle, <project>/.kotlin
- size: (unverified)
- class: safe-regenerable
- removal: `./gradlew clean` or rm-verified of ignored dirs
- regen: full Kotlin compile for every target, plus the iOS framework link; slow
- growth: per target and per build type; `.kotlin` holds sessions and error logs
- source: reported online, https://docs.gradle.org/current/userguide/directory_layout.html (fetched 2026-11-17); confirms project `.gradle`; `.kotlin` dir and `./gradlew clean` NOT confirmed; sizes (unverified)

### kmp-xcode-framework
- what: XCFramework and derived data produced when an iOS app embeds a KMP shared module
- catalog-id: none
- paths: <project>/shared/build/XCFrameworks, ~/Library/Developer/Xcode/DerivedData/*
- size: (unverified)
- class: safe-regenerable
- removal: `./gradlew clean`; DerivedData follows the xcode-derived entry
- regen: re-link of the Kotlin framework on next iOS build
- growth: per target (arm64, simulator, x64) and per build type
- source: (unverified)

### nuget-packages
- what: NuGet global packages folder used by .NET MAUI/Xamarin and any .NET project
- catalog-id: nuget-packages
- paths: ~/.nuget/packages
- size: not present on this host (measured here)
- class: safe-regenerable
- removal: `dotnet nuget locals all --clear`
- regen: packages restored from nuget.org on next `dotnet restore`; needs network, offline builds break meanwhile
- growth: one folder per package version ever restored; never pruned
- source: reported online, https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-locals (fetched 2026-11-17); confirms `dotnet nuget locals all --clear` and `global-packages`; the ~/.nuget/packages path is not stated on the page (use `dotnet nuget locals global-packages -l`); sizes (unverified)

### dotnet-workloads-and-packs
- what: .NET SDK workloads (maui, ios, android) and their packs, plus installed SDK/runtime versions
- catalog-id: none
- paths: /usr/local/share/dotnet/packs, /usr/local/share/dotnet/sdk, ~/.dotnet
- size: (unverified); not present under ~/.dotnet on this host (measured here)
- class: ask-first
- removal: `dotnet workload uninstall <id>`; `dotnet workload clean` only drops leftovers of uninstalled workloads (`--all` removes everything, ask first); SDKs by their own uninstall tool (needs admin)
- regen: `dotnet workload install maui` re-downloads, often several GB; needs network
- growth: one pack set per workload version; old versions linger after updates
- source: reported online, https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-workload-clean (fetched 2026-11-17); `workload clean` removes components left by uninstalled workloads, `--all` removes ALL workload components of all SDK versions; pack paths NOT confirmed; sizes (unverified)

### maui-project-build
- what: per-project `bin/` and `obj/` of a MAUI or Xamarin solution
- catalog-id: none
- paths: <project>/bin, <project>/obj
- size: (unverified)
- class: safe-regenerable
- removal: `dotnet clean` or rm-verified of ignored `bin`/`obj`
- regen: full rebuild of every target platform; `obj` also holds restore assets, so run `dotnet restore`
- growth: per target framework and configuration; MAUI multi-targeting multiplies it
- source: reported online, https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-clean (fetched 2026-11-17); confirms `dotnet clean` cleans both obj and bin; sizes (unverified)

### xamarin-legacy-state
- what: legacy Xamarin SDK state (Visual Studio for Mac, Xamarin.iOS/Android installs, mono) in the home directory
- catalog-id: none
- paths: ~/Library/Developer/Xamarin, ~/.local/share/Xamarin, ~/Library/Caches/Xamarin
- size: not present on this host (measured here)
- class: ask-first
- removal: report-only; Xamarin support ended 2024 and uninstall is by the installer, so decide per case
- regen: cannot be recreated once the toolchain is removed
- growth: static for an unmaintained toolchain
- source: (unverified)

## Developer habits
- KMP developers run Gradle (shared with Android-native) plus Xcode for the iOS half, so they carry both caches and `~/.konan` on top.
- MAUI developers multi-target Android, iOS and Mac Catalyst, so one solution builds several times and restores NuGet packages repeatedly.
- Both keep multiple SDK or compiler versions side by side and rarely remove old ones.

## Signals
- KMP: `build.gradle.kts` with `kotlin("multiplatform")`, `shared/` module, `iosApp/`, `~/.konan`
- MAUI/Xamarin: `*.csproj` with `net*-maui` or `Xamarin.*`, `*.sln`, `MauiProgram.cs`
- commands: `dotnet`, `gradlew`, `xcodebuild`, `cinterop`, `konanc`
- profile toolchain ids: android, gradle, xcode, dotnet (dotnet is not an engine id yet)

## Not covered / open questions
- No KMP or MAUI project exists on this host, so every per-project size is unmeasured.
- .NET paths on macOS (workload packs location differs by install method) not verified; no web fetch done.
- Compose Multiplatform Desktop/Web outputs and Wasm toolchains not covered.
- 2026-11-17 web pass: kotlinlang.org docs did not mention ~/.konan; only community sources confirm it. Xcode framework paths, Xamarin legacy paths and end-of-support date remain (unverified).
