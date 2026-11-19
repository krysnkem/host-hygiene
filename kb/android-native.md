# Android native developer (also the Android half of Flutter)

## Entries

### android-avd
- what: Android Virtual Device (emulator disk image, snapshots, installed apps)
- catalog-id: android-avd
- paths: ~/.android/avd/*.avd
- size: 5.8 G, 5.1 G, 4.4 G for three AVDs (measured here)
- class: ask-first
- removal: avdmanager delete avd -n <name> (refused while a running emulator uses it)
- regen: emulator data and installed apps lost; roles in a project's .uat may point at it
- growth: each AVD grows with installed apps and snapshots. Suggested budget: 2 AVDs (suggested)
- source: measured on this host 2026-11-17

### android-sysimg
- what: SDK system images that AVDs boot from
- catalog-id: android-sysimg
- paths: ~/Library/Android/sdk/system-images/*/*
- size: 8.8 G total (measured here, via mole report in STATUS.md); 1-2 G each (per catalog note, unverified)
- class: ask-first
- removal: sdkmanager --uninstall <pkg> (ABI must be filled in by hand; refused for an image an AVD uses)
- regen: re-download 1-2 GB; AVDs using it stop booting
- growth: one per API level and ABI tried
- source: measured on this host 2026-11-17 (total)

### android-ndk
- what: NDK versions, one directory each
- catalog-id: android-ndk
- paths: ~/Library/Android/sdk/ndk/*
- size: (unverified); mole named 3 older versions (measured here)
- class: ask-first
- removal: sdkmanager --uninstall <pkg>
- regen: re-download when a build needs that NDK
- growth: AGP installs the NDK a project asks for; old ones stay
- source: measured on this host 2026-11-17 (existence); removal reported online, https://developer.android.com/tools/sdkmanager (fetched 2026-11-17); size (unverified)

### android-buildtools
- what: SDK build-tools versions
- catalog-id: android-buildtools
- paths: ~/Library/Android/sdk/build-tools/*
- size: (unverified)
- class: ask-first
- removal: sdkmanager --uninstall <pkg>
- regen: re-download when a build needs it
- growth: one per AGP version used
- source: reported online, https://developer.android.com/tools/sdkmanager (fetched 2026-11-17); confirms `sdkmanager --uninstall "build-tools;<ver>"`; sdkmanager is marked deprecated in favour of `android sdk remove`; sizes (unverified)

### android-platforms
- what: SDK platform (android.jar) per API level
- catalog-id: android-platforms
- paths: ~/Library/Android/sdk/platforms/*
- size: (unverified)
- class: ask-first
- removal: sdkmanager --uninstall <pkg>
- regen: re-download when a build targets it
- growth: one per compileSdk used
- source: reported online, https://developer.android.com/tools/sdkmanager (fetched 2026-11-17); confirms `sdkmanager --uninstall "platforms;android-<N>"`; sdkmanager is marked deprecated in favour of `android sdk remove`; sizes (unverified)

### android-cmake
- what: CMake versions installed through the SDK for native builds
- catalog-id: android-cmake
- paths: ~/Library/Android/sdk/cmake/*
- size: (unverified)
- class: ask-first
- removal: sdkmanager --uninstall <pkg>
- regen: re-download when a build needs it
- growth: one per version a project requests
- source: reported online, https://developer.android.com/tools/sdkmanager (fetched 2026-11-17); confirms `cmake;<ver>` package ids and `--uninstall`; sdkmanager is marked deprecated in favour of `android sdk remove`; sizes (unverified)

### gradle-modules
- what: Gradle dependency cache (downloaded artifacts)
- catalog-id: gradle-modules
- paths: ~/.gradle/caches/modules-2
- size: 4.5 G (measured here); ~/.gradle/caches as a whole reached 27 G during one session (measured here)
- class: ask-first
- removal: rm-verified
- regen: every project re-downloads its dependencies on next build; needs network
- growth: grows with every dependency version any project resolves; fast during builds. Suggested budget 10 G (suggested)
- source: measured on this host 2026-11-17

### gradle-daemon
- what: Gradle daemon logs and registry
- catalog-id: gradle-daemon
- paths: ~/.gradle/daemon
- size: (unverified), logs only
- class: safe-regenerable
- removal: rm-verified (run `gradle --stop` first)
- regen: none worth noting
- growth: one log per daemon start
- source: measured on this host 2026-11-17 (catalog note); size (unverified)

### gradle-unused-versions
- what: Gradle distributions and per-version caches that no discovered project's wrapper uses
- catalog-id: none
- paths: ~/.gradle/caches/<ver>, ~/.gradle/wrapper/dists/gradle-<ver>-*
- size: 678 MB for 9.8.1 (measured here)
- class: ask-first
- removal: rm-verified (apply re-checks wrappers at apply time; refuses if none found)
- regen: re-download when a project needs that version
- growth: each wrapper bump leaves the previous version behind
- source: measured on this host 2026-11-17 (engine detects in code, scan: gradle-unused)

### android-project-build
- what: per-project `build/` and `.gradle/` for Android modules
- catalog-id: none
- paths: <project>/build, <project>/.gradle, <project>/android/app/build
- size: (unverified) separately; counted inside flutter-project-build figures
- class: safe-regenerable
- removal: ./gradlew clean, or rm-verified after git confirms ignored
- regen: full rebuild, minutes
- growth: per build variant
- source: measured on this host 2026-11-17 (mole purge found `.gradle`); project `.gradle` confirmed generated by Gradle per https://docs.gradle.org/current/userguide/directory_layout.html (reported online, fetched 2026-11-17); size (unverified)

### gradle-wrapper-dists
- what: Gradle distributions downloaded by each project's gradle wrapper, one dir per version
- catalog-id: none
- paths: ~/.gradle/wrapper/dists/*
- size: 3.4 G across 9 versions (measured here)
- class: ask-first
- removal: rm-verified of a version no project's gradle-wrapper.properties references
- regen: wrapper re-downloads the version on next build of a project that needs it; needs network
- growth: one per Gradle version ever used, `-all` ones larger than `-bin`; never pruned
- source: measured on this host 2026-11-17

### gradle-transforms
- what: Gradle artifact-transform caches under each Gradle version's cache dir
- catalog-id: gradle-transforms
- paths: ~/.gradle/caches/transforms-*, ~/.gradle/caches/<version>
- size: 52 MB for transforms-3 (measured here)
- class: ask-first
- removal: rm-verified after `gradle --stop`
- regen: recomputed from modules-2 on next build
- growth: per Gradle version and per project dependency set
- source: measured on this host 2026-11-17; K3 note: catalog class is ask-first: the only source is a measurement on this host, no Gradle doc read, and a running daemon uses it; apply refuses while a GradleDaemon runs

### gradle-jdks
- what: JDKs auto-provisioned by Gradle toolchains
- catalog-id: none
- paths: ~/.gradle/jdks
- size: (unverified)
- class: ask-first
- removal: rm-verified of a JDK dir no toolchain needs
- regen: Gradle re-downloads on next build that asks for it; needs network
- growth: one per requested JDK version/vendor
- source: reported online, https://docs.gradle.org/current/userguide/toolchains.html (fetched 2026-11-17); confirms auto-provisioned JDKs live in a `jdks` dir in Gradle User Home; automatic re-download after removal is implied, not stated; sizes (unverified)

### android-sdk-emulator
- what: the Android Emulator binaries inside the SDK
- catalog-id: none
- paths: ~/Library/Android/sdk/emulator
- size: 967 MB (measured here)
- class: ask-first
- removal: sdkmanager --uninstall emulator
- regen: sdkmanager --install emulator re-downloads; AVDs stop working until then
- growth: replaced in place on update; roughly constant
- source: measured on this host 2026-11-17

### android-avd-snapshots
- what: quick-boot and saved snapshots inside each AVD dir
- catalog-id: none
- paths: ~/.android/avd/*.avd/snapshots
- size: (unverified); whole ~/.android/avd is 19.2 G (measured here)
- class: ask-first
- removal: delete the snapshot from the emulator's Extended Controls, or rm-verified of the snapshots dir with the emulator stopped; `-no-snapshot-load` skips loading without deleting
- regen: cold boot next time; saved app state in the snapshot is lost
- growth: each saved snapshot is roughly the guest RAM size plus changed disk
- source: measured on this host 2026-11-17 (avd total); deletion via Snapshots pane reported online, https://developer.android.com/studio/run/emulator-snapshots (fetched 2026-11-17); on-disk path, `-no-snapshot-load` and per-snapshot size (unverified)

### android-build-cache
- what: legacy Android Gradle plugin build cache
- catalog-id: none
- paths: ~/.android/build-cache
- size: not present on this host (measured here)
- class: safe-regenerable
- removal: rm-verified
- regen: rebuilt on next build; newer AGP uses the Gradle build cache instead (unverified)
- growth: legacy; absent on current toolchains
- source: (unverified)

## Developer habits
- Keeps multiple AVDs for different roles (Sender/Agent/Terminal style multi-app testing); 15 G across three here.
- Leaves a Gradle daemon and an emulator running for days: a qemu emulator at 94% CPU and 2.5 GB was seen, swap 11 of 12 GB used (measured here).
- Upgrades AGP/Gradle and NDK without removing the old versions.

## Signals
- `~/Library/Android/sdk`, `~/.android/avd`, `~/.gradle`
- `android/` dir with `build.gradle(.kts)` and `gradlew`; `local.properties` with sdk.dir
- commands: `adb`, `avdmanager`, `sdkmanager`, `emulator`, `gradle`
- profile toolchain ids: android, gradle

## Not covered / open questions
- Sizes of build-tools, platforms, cmake, NDK per version not measured.
- ~/.android (adb keys, caches) and ~/.gradle/wrapper/dists size not itemised.
- Kotlin/Java IDE caches (Android Studio under ~/Library/Caches/Google) are a catalog `any` row, not covered here.
- Gradle build-cache location and growth rate under load not isolated: free disk fell 39 to 14.9 GiB in about 7 min while caches grew 19 to 27 GB (cause not isolated).
- 2026-11-17 web pass: ~/.android/build-cache not verified (developer.android.com/build/build-cache returned 404); stays (unverified).
- gradle-daemon: Gradle docs say daemon dir holds registry and logs, logs older than 14 days are auto-removed (https://docs.gradle.org/current/userguide/directory_layout.html); entry class left as is.
- Android docs mark sdkmanager and avdmanager deprecated in favour of the Android CLI (`android sdk`, `android emulator`); the catalog still uses sdkmanager.
