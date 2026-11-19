# JVM developer (Java, Kotlin, Scala)

Gradle caches (~/.gradle/caches/modules-2, daemon, wrapper dists) and the Android SDK are documented in android-native.md and the catalog rows gradle-modules and gradle-daemon: not repeated here.

## Entries

### maven-repo
- what: local Maven repository of every dependency and plugin any Maven build resolved
- catalog-id: maven-repo
- paths: ~/.m2/repository (wrapper dists in ~/.m2/wrapper)
- size: 107 M (measured here, 109608 KB); GBs on long-time Java users (unverified)
- class: ask-first
- removal: rm-verified (the catalog's removal); mvn dependency:purge-local-repository re-resolves a project's deps
- regen: dependencies re-downloaded on next build; locally `mvn install`ed artifacts of your own projects are NOT downloadable and are lost
- growth: grows per dependency/plugin version; SNAPSHOTs accumulate. Suggested budget 2 G (suggested)
- source: measured on this host 2026-11-17; reported online, https://maven.apache.org/plugins/maven-dependency-plugin/purge-local-repository-mojo.html and https://maven.apache.org/guides/introduction/introduction-to-repositories.html fetched 2026-11-17 (purge deletes project deps and re-resolves by default, reResolve=true; the repository also holds your unreleased built artifacts; deleting it all is safe but forces re-download)

### sbt-ivy-coursier
- what: sbt, Ivy and Coursier dependency caches for Scala builds
- catalog-id: none
- paths: ~/.ivy2, ~/.sbt, ~/Library/Caches/Coursier (macOS), ~/.cache/coursier (Linux)
- size: not present on this host; commonly 1-5 G (unverified)
- class: ask-first
- removal: rm-verified of the cache dirs (no tool command known); sbt `cleanCache` is per project (unverified)
- regen: re-download on next sbt/cs run; needs network
- growth: grows with Scala versions and library versions. Suggested budget 3 G (suggested)
- source: reported online, https://get-coursier.io/docs/cache fetched 2026-11-17 (macOS ~/Library/Caches/Coursier/v1, Linux ~/.cache/coursier/v1, older ~/.coursier/cache/v1; the page gives no clear command); absence measured on this host 2026-11-17

### jvm-installed-jdks
- what: JDKs installed on the machine
- catalog-id: none
- paths: /Library/Java/JavaVirtualMachines/*; ~/Library/Java/JavaVirtualMachines/*
- size: corretto-1.8.0_422 198 M, jbr-21.0.4 275 M, both under ~/Library/Java (measured here); /Library/Java/JavaVirtualMachines is empty
- class: ask-first
- removal: rm-verified of the .jdk dir (user-level) or the vendor's uninstaller (system-level); IDE-managed JDKs: remove from the IDE
- regen: re-download 200-300 M; a project or IDE configured for that JDK stops building until re-pointed
- growth: one per installed version. Suggested: keep versions your projects use (suggested)
- source: measured on this host 2026-11-17

### sdkman-candidates
- what: SDKMAN-managed JDKs, Gradle, Maven, Kotlin, Scala, etc.
- catalog-id: none
- paths: ~/.sdkman/candidates/*, ~/.sdkman/archives
- size: not present on this host; JDK about 300 M each (unverified)
- class: ask-first
- removal: sdk uninstall <candidate> <version>; sdk flush archives (and tmp) for download leftovers
- regen: sdk install re-downloads; needs network
- growth: one dir per version; downloaded zips stay in archives until flushed. Suggested: sdk flush after installs (suggested)
- source: reported online, https://sdkman.io/usage fetched 2026-11-17 (`sdk uninstall <candidate> <version>` confirmed; `sdk flush` exists and tmp must not be deleted by hand); `sdk flush archives`, ~/.sdkman/archives and the candidates path are (unverified), not stated there

### intellij-caches
- what: IntelliJ IDEA/JetBrains IDE caches, indexes and logs
- catalog-id: intellij-caches
- paths: ~/Library/Caches/JetBrains/* (catalog row: one per IDE version; IDE must be closed, apply refuses while one runs)
- size: not present on this host; commonly 1-5 G per IDE version (unverified)
- class: ask-first
- removal: IDE menu File > Invalidate Caches, or rm-verified of ~/Library/Caches/JetBrains/<IDE><ver> with the IDE closed
- regen: IDE re-indexes every project on next open, minutes; old IDE-version dirs are orphans once the IDE is upgraded
- growth: one dir per IDE version; orphans accumulate across upgrades. Suggested: delete dirs of uninstalled versions (suggested)
- source: reported online, https://www.jetbrains.com/help/idea/directories-used-by-the-ide-to-store-settings-caches-plugins-and-logs.html fetched 2026-11-17 (macOS caches ~/Library/Caches/JetBrains/<product><version>, logs ~/Library/Logs/JetBrains/..., config ~/Library/Application Support/JetBrains/...); absence measured on this host 2026-11-17

### jvm-project-build
- what: per-project build output: Maven target/, Gradle build/ and .gradle/, sbt target/ and project/target
- catalog-id: none
- paths: <project>/target, <project>/build, <project>/.gradle
- size: (unverified)
- class: safe-regenerable
- removal: mvn clean; ./gradlew clean; sbt clean (or rm-verified when the dir is git-ignored)
- regen: next build recompiles; needs cached dependencies or network
- growth: per build. Suggested budget 1 G per project (suggested)
- source: (unverified)

## Developer habits
Multiple JDKs for different projects, IDE upgrades leaving orphan caches, Maven plus Gradle side by side.

## Signals
pom.xml, build.gradle(.kts), build.sbt, ~/.m2, ~/.sdkman, ~/Library/Java/JavaVirtualMachines, `java`/`mvn` on PATH.

## Not covered / open questions
Android Studio caches and AVDs are in android-native.md. JetBrains Toolbox-installed IDE size and Gradle wrapper dists in ~/.gradle/wrapper are not covered here. Not confirmed online: sbt/Ivy paths and `sbt cleanCache`, the ~/.m2/wrapper path, JDK sizes beyond the measured two, per-project build-dir sizes, `sdk flush archives`.
