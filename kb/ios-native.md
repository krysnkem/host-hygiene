# iOS native developer (also the iOS half of Flutter)

## Entries

### xcode-derived
- what: Xcode build products and indexes per project
- catalog-id: xcode-derived
- paths: ~/Library/Developer/Xcode/DerivedData/*
- size: (unverified); not above the 300 MB scan threshold on the last scan (measured here)
- class: safe-regenerable
- removal: rm-verified
- regen: next iOS build of that project is slower once
- growth: one directory per project and per path; stale ones accumulate
- source: measured on this host 2026-11-17 (absence above threshold); size (unverified)

### xcode-archives
- what: archived release builds with their dSYMs
- catalog-id: xcode-archives
- paths: ~/Library/Developer/Xcode/Archives
- size: (unverified); no row appeared at 300 MB (measured here, absent or smaller, not checked individually)
- class: ask-first
- removal: rm-verified
- regen: not regenerable; lose crash symbolication for shipped builds
- growth: one per release archive
- source: measured on this host 2026-11-17 (absence above threshold)

### xcode-devicesupport
- what: per-iOS-version device symbol files created when a device connects
- catalog-id: xcode-devicesupport
- paths: ~/Library/Developer/Xcode/iOS DeviceSupport/*
- size: (unverified); about 1-3 GB each is commonly reported (unverified)
- class: ask-first
- removal: rm-verified
- regen: re-created (slowly) next time that device version connects
- growth: one per device OS version ever connected
- source: (unverified); absent above threshold on this host 2026-11-17

### xcode-sim-devices
- what: iOS Simulator devices and their data containers
- catalog-id: xcode-sim-devices
- paths: ~/Library/Developer/CoreSimulator/Devices
- size: 14.1 G (measured here); 15.1 G by mole (measured here)
- class: ask-first
- removal: xcrun simctl delete unavailable (the safe first step)
- regen: simulator data lost for removed devices; 0 unavailable devices here, so the safe step frees 0 (measured here)
- growth: one device per runtime/model created and per app install. Suggested budget: delete devices by hand, per-device sizes not yet measured (suggested)
- source: measured on this host 2026-11-17

### xcode-sim-caches
- what: simulator dyld caches
- catalog-id: xcode-sim-caches
- paths: ~/Library/Developer/CoreSimulator/Caches
- size: (unverified)
- class: safe-regenerable
- removal: rm-verified
- regen: simulators rebuild dyld caches on next boot
- growth: grows per runtime booted
- source: (unverified)

### coresimulator-logs
- what: logs written by the simulator service
- catalog-id: none
- paths: ~/Library/Logs/CoreSimulator
- size: 382 MB (measured here)
- class: safe-regenerable
- removal: rm-verified (skipped while a simulator holds files open)
- regen: none; old logs lost
- growth: grows while simulators run
- source: measured on this host 2026-11-17 (apply skipped it because files were open)

### ios-pods
- what: per-project CocoaPods `Pods/` checkout
- catalog-id: none
- paths: <project>/ios/Pods, <project>/Pods
- size: (unverified)
- class: safe-regenerable
- removal: rm-verified after git confirms ignored; then `pod install`
- regen: `pod install` re-fetches; needs network
- growth: per project and dependency set
- source: measured on this host 2026-11-17 (mole purge found Pods); `pod install` creating ./Pods reported online, https://guides.cocoapods.org/terminal/commands.html (fetched 2026-11-17); size (unverified)

### cocoapods-cache
- what: CocoaPods download cache and local spec repo clone
- catalog-id: cocoapods-cache
- paths: ~/Library/Caches/CocoaPods, ~/.cocoapods
- size: 334 MB cache plus 50 MB specs (measured here)
- class: safe-regenerable
- removal: `pod cache clean --all`
- regen: next `pod install` re-downloads pods; needs network
- growth: one entry per pod version ever installed; never pruned. Suggested budget 1 G (suggested)
- source: measured on this host 2026-11-17

### swiftpm-cache
- what: Swift Package Manager repository and artifact caches
- catalog-id: none
- paths: ~/Library/Caches/org.swift.swiftpm, ~/Library/org.swift.swiftpm
- size: under 1 MB (measured here)
- class: safe-regenerable
- removal: `swift package purge-cache` (per-project checkouts live under .build or DerivedData)
- regen: packages re-cloned on next resolve; needs network
- growth: grows with package dependencies resolved
- source: measured on this host 2026-11-17

## Developer habits
- Creates many simulator devices across Xcode/runtime updates and never prunes them (14 G here).
- Archives every release build; archives hold dSYMs needed later.
- Opens many projects so DerivedData fills with stale builds.

## Signals
- `~/Library/Developer/Xcode`, `~/Library/Developer/CoreSimulator`
- `*.xcodeproj`, `*.xcworkspace`, `Podfile`, `Package.swift`, `ios/Runner.xcodeproj`
- commands: `xcodebuild`, `xcrun simctl`, `pod`
- profile toolchain id: xcode

## Not covered / open questions
- Swift Package Manager caches (~/Library/Caches/org.swift.swiftpm) and CocoaPods cache (~/Library/Caches/CocoaPods) not looked at.
- Per-device simulator sizes and simulator runtime images (outside CoreSimulator/Devices) not measured.
- DerivedData, Archives and DeviceSupport sizes below 300 MB not itemised.
- No online research yet.
- 2026-11-17 web pass: DerivedData, Archives, iOS DeviceSupport, simulator caches and SwiftPM have no Apple-doc source (the Apple page fetched was empty); only third-party blogs seen, so they stay (unverified).
- CocoaPods docs do not say whether Pods/ or Podfile.lock should be committed; check git ignore per project.
