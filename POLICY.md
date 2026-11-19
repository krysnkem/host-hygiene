# Host hygiene policy (R8)

For developers and teams who build Flutter/Android/iOS apps on one laptop. Every figure comes from
measurements on the owner's MacBook (macOS 26.6, arm64, 32 GiB RAM, 460 GiB disk, 10 cores) on
2026-11-17 unless marked **(unmeasured)** or **(proposal)**. A proposal is a rule chosen from the
observations, not something that was tested as a rule. Tool: `~/.claude/skills/host-hygiene/`.

## 1. Why this exists: what was measured

| Observation | Number | Source |
|---|---|---|
| Free disk swing within about a day | 16, 4.9, 5.8, then 34 GiB | owner log |
| Free disk during one debug build | down to 640 MiB | owner log |
| One Flutter debug build | about 2.4 GB `build/` plus about 3 GB Gradle cache growth | owner log |
| Free disk fell during a test session | 39 → 19 → 15 → 13 GiB in about 7 min, with Gradle cache growing 19 → 27 GB | this session |
| Host load at its worst | about 35 (earlier), 29 (this session) | owner log, this session |
| Load where the host behaved | below about 8 | owner log |
| Android "isn't responding", UI dumps 6-10x slower | at load about 35 | owner log |
| Cause of the 28 GiB free-space swing | **not found**: 0 local Time Machine snapshots at first, later measured at 7 hourly ones (P8, sizes not measured); a purgeable gap of a few GB exists (`df` 37-39 GiB vs `diskutil` 40.0 GB) | this session |

## 2. Budgets and floors

Thresholds are the user's. The first interactive run of `host-hygiene.sh` asks for them and saves
`~/.config/host-hygiene/config`. Built-in defaults:

| Rule | Default | Basis |
|---|---|---|
| Soft free-disk floor: below it, heavy work is risky | 15 GiB (suggested: 3% of disk, at least 15) | a debug build costs about 5.4 GB (2.4 build + 3 cache) and the disk fell 26 GiB in one session, so 15 GiB leaves room for one build plus a surprise |
| Hard stop: below it, never start a build or boot an emulator | 5 GiB | the 640 MiB low point shows the margin is small |
| Max 1-minute load | 8 (suggested: 0.75 x cores) | host behaved below about 8; timings above it are not trustworthy |
| `build/` review threshold per project | 5 GB **(proposal)** | observed builds: 4.2 G (app-one), 2.7 G (app-two), 2.1 G (app-three, 1.4 G in an earlier reading) |
| Emulator images (AVDs) kept | only the ones a project's `.uat` roles use **(proposal)** | 3 AVDs hold 15.3 GB here; how many are actually used was not checked **(unmeasured)** |

Tools call `host-hygiene.sh guard` before a heavy action. Exit 0 = go, 1 = soft floor or load
tripped (the message names which), 2 = hard stop. `flutter-uat` bootstrap already does (C1 = max
load, C5 = hard stop).

## 3. What may be removed, and by whom

| Class | Meaning | Examples | Rule |
|---|---|---|---|
| `safe-regenerable` | provably rebuilt by the tool, git-ignored or tool-owned | project `build/`, `.dart_tool`, `node_modules`, Xcode DerivedData, npm cache, editor and log caches | removable after the tool re-verifies it |
| `ask-first` | shared, or costly to regenerate | `~/.gradle`, `~/.pub-cache`, AVDs, SDK packages, Docker, unused Gradle versions, Trash, app caches | needs a per-item yes **and** `--ask-first-ok`; read the cost note first |
| `never` | source, user data, anything not provably regenerable | Downloads, Documents, your never-touch folders | never proposed, `apply` refuses |

Non-negotiable:
- Dry-run is the default everywhere; deleting needs `--run` plus a y/N per item (or `--yes` for a caller who already has approval).
- `apply` acts only on explicit `--target` paths and re-verifies each one itself. It refuses relative paths, `..`, symlinks, `$HOME`, project dirs that git does not ignore, and anything not in the catalog.
- It stops on the first error or refusal, skips directories that have open files, and refuses to delete when it cannot write its log.
- Prefer each tool's own command over `rm -rf`. Supported: `docker system prune`, `npm cache clean`, `brew cleanup`, `flutter pub cache clean`, `simctl delete unavailable`, and (scripts/executors.sh, all ask-first) `avdmanager delete avd` (refused while a running emulator uses it), `fvm remove` (refused if a project's .fvmrc / .fvm/fvm_config.json pins it, or it is the fvm default), `rustup toolchain uninstall` (refused for the active default), `sdkmanager --uninstall` (refused for a system image an AVD uses). Later rows (K3/K3b, 36 in catalog.tsv plus ids found in code) add the tool commands for pnpm, bun, corepack, deno, pip, uv, go, composer, nuget, cocoapods, pyenv/rbenv, and rm-verified rows for model, browser and engine caches; each asks the tool which directory it would clear and refuses on a mismatch. Report-only rows (ollama, lmstudio, kaggle, vagrant, messages attachments, large unused apps, old Downloads) are never removed by `apply`. Each re-verifies at apply time and needs its tool present; otherwise it is removed by hand.
- Report the real freed amount (du before minus after), not the directory size.
- Never touch a repo's tracked files, folders on your never-touch list, keychains, browser profiles or documents.
- The scan makes no network calls and sends no telemetry.

## 4. What it found and what was reclaimed (this host)

| Item | Size | Class | Outcome |
|---|---|---|---|
| 3 AVDs | 5.8 + 5.1 + 4.4 GB | ask-first | untouched |
| Google caches | 8.0 GB | ask-first | untouched |
| Gradle `modules-2` / `pub-cache` | 4.5 / 4.2 GB | ask-first | untouched |
| Per-project `build/` (app-one, app-two, app-three) | 4.2 + 2.7 + 1.4 GB | safe-regenerable | removed |
| VS Code extension cache, Xcode ModuleCache | 4.1 + 2.5 GB | safe-regenerable | removed |
| npm cache | 1.3 GB | safe-regenerable | removed through `npm cache clean` |
| Simulator devices | 14.1 GB | ask-first | not reclaimable by the safe command: 0 unavailable simulators |
| Docker | 5.0 GB directory, at most 1.1 GB reclaimable | ask-first | untouched |

Reclaimed by deletion: about 16.8 GB (15.5 + 1.3). Free space moved far less (15.1 → 16.2 GiB) because
other processes were writing at the same time, so **free space alone does not prove a reclaim**; the
tool measures per target.

## 5. Cadence and habits

- Run `guard` before a build or an emulator boot (automatic wherever a tool calls it).
- Run `scan` when disk or speed gets bad; cadence beyond that **(unmeasured)**, no data on how fast a clean host refills.
- After testing in another project under `~/magic`, remove the build output you created there (baseline `du` first, delete only what you made).
- Check load before measuring anything; above the limit, wait or close apps.
- Heavy hitters seen during the slow periods: Spotlight, WindowServer, mediaanalysisd, WhatsApp, Telegram, qemu (one emulator used 94-107% CPU). Whether excluding `~/.gradle`, `~/.android` and `build/` from Spotlight lowers load is **(unmeasured)**.

## 6. Tool performance and limits (measured)

| Command | Time | Load during run |
|---|---|---|
| `profile` | 13 s | about 4.4 |
| `scan` | 57 s | about 5 |
| `guard` | 0.04 s | any |
| Mole `clean --dry-run` | 4 min 27 s | 6 rising to 29: **not trustworthy** |
| Mole `purge --dry-run` | 1 min 24 s | 29: **not trustworthy** |

**Resource budget of this tool (P0, 2026-11-18; the tool must not add to the bottleneck it fights).** Measure with `tests/bench.sh`, enforce with `tests/check-budget.sh` (timing caps skip with `SKIP-load` when the 1-minute load is 8 or more; size caps always apply). `HH_TIMING=1` prints `time <detector> <seconds>` to stderr.

| Command | Before | After | Cap | Load |
|---|---|---|---|---|
| `guard` | 0.06 s | 0.06 s | < 0.2 s | 5.7 |
| `profile --tsv` (fake dev home) | 0.4 s | 0.56 s | < 1 s | 5.7 |
| `plan --tsv` fake dev home, app-size cache warm | 18.7 s | 2.6 s | < 5 s | 5.7 |
| same, first run (cold cache) | 18.7 s | 14.4 s | report only | 5.7 |
| `plan --tsv` real home (about 90 GB, 5000 old downloads, 71 projects) | 188 s (warm) | about 178 s | report only | 7-12 (not trustworthy) |
| TUI idle CPU, Pick screen | 1.7 % | 0.3 % | < 1 % | 7.7 |
| TUI idle RSS | 54 MB | 49 MB | report only | |
| TUI binary size | 7,975,296 B (P0) | 8,320,032 B after the look chooser (was 8,221,536 after P2) | <= 9,023,872 B | |
| Look chooser waiting for the browser (`hh_tui --pick-look --web`) | n/a | CPU 0% (event-driven: one chooser listening socket on 127.0.0.1, plus the loopback log socket the nocterm library opens in every TUI process, and two one-shot timers, no polling, no extra process) | < 1 % | |
| TUI binary / skill folder | 7,975,296 B / 8.4 MB | same | binary growth <= 1 MB (9,023,872 B), folder <= 9.5 MB | |
| TUI binary / skill folder after the four looks (UI Phase 2) | 7,975,296 B / 8.4 MB | 8,221,536 B / 8.8 MB | same caps | |
| TUI idle CPU, Pick screen, per look (UI Phase 2; cputime delta over 10 s, `tests/tui-idle.py`, 10 ms resolution) | n/a | guided 0.2 %, cockpit 0.3 %, dashboard 0.3 %, spacemap 0.3 %, console 0.2 % | < 1 % each | 5.2-7.3 |
| TUI idle RSS per look | 49 MB | 49-55 MB (console 49, spacemap 52, guided 54, dashboard 55, cockpit 55) | report only | |
| Dashboard poll (`uptime; df -k /`, 10 s, perf.sh every 3rd poll) | n/a | spawns only while the look is shown, none in Work or after `v` away (PATH-shim count) | no poll timer outside the look | |

Why `plan` is slow: `du` has to walk every file (WhatsApp media, Library/Caches, Android SDK, AVDs, node_modules are the big ones), and `/Applications` alone costs about 10 s of `du`. That traversal is the work itself; what was removable was repeated work. Fixes: one `du` per app instead of two, a 24 h app-size cache in `$TMPDIR` (never in `$HOME`; `HH_NO_CACHE=1` disables), one batched `mdls` instead of one per app, one `find`+`stat`+`awk` for old Downloads instead of three forks per file (about 40 s for 4,897 files), no second `du` for a path two catalog rows both match, no second whole-`$HOME` `find` for Gradle wrapper versions. Results are identical (rows, classes, sizes). The first plan on a Mac with many apps and a big home is still minutes of disk reads; run it when idle.

- Mole 1.67.0 (GPL-3.0, run as a separate command) gives a useful second opinion on generic caches (6.6 GB) and project artifacts (6.2 GB, marked incomplete), but only prints sizes for the largest items here (Gradle, AVDs, system images, simulators). It missed three `build/` folders worth about 9 GB for an unverified reason **(unmeasured)**. Our catalog stays the source of truth.
- macOS only. Windows and Linux are stubs. The non-developer catalog is small and was tested only on a fake home, not on a real non-developer machine.
- Project discovery covers git repos up to 5 levels under `$HOME`; deeper repos are missed, which also affects the unused-Gradle-version check.

## 7. Open questions

1. What caused the 28 GiB free-space swing? Needs periodic sampling of `df` against `diskutil` **(unmeasured)**.
2. Does Spotlight exclusion lower load? **(unmeasured)** (design and a noisy read-only half-run in STATUS.md "P2 CPU/memory")
3. Why did Mole skip the biggest `build/` folders? **(unmeasured)**
4. How should AVDs be reclaimed without breaking `.uat` roles? Not tested.
5. iOS: Archives and DeviceSupport rows have not been measured on a host that has them.
6. Mail and Messages attachment paths: macOS TCC blocked this process, so sizes and paths are unverified (see section 10).

## 8. Developer types: what fills the disk (K-phases)

Sixteen kinds are detected from manifests (flutter, android, ios, rn, kmp, maui, node, frontend, python, go, rust, jvm, ruby, rails, php, dotnet). The evidence per type is in `kb/` (160 entries, each size labelled). Sizes below are measured only where the row says so; everything else is **(unmeasured)** because the tool is absent from this host (the host is a Flutter/Android/iOS machine with some Node, Rust, Python, Docker).

| Type | Rows the tool offers | Measured here (real home, read-only plan) | Per-type budget |
|---|---|---|---|
| Flutter / Android / iOS | per-project `build/`, `.dart_tool`, Gradle caches and unused versions, `~/.pub-cache`, AVDs, SDK packages, fvm, Xcode DerivedData, simulators | sections 1 and 4 (AVDs 15.3 GB, Gradle 19-27 GB, pub-cache 4.2-4.4 GB) | build review at 5 GB **(proposal)**; AVDs kept = those used **(proposal)** |
| Node / frontend / RN | `node_modules`, npm, npx, pnpm store, bun, corepack, Playwright/Puppeteer/Cypress browsers | pnpm store 551 M (not 610 M: that included pnpm's own binary), playwright 1.08 G, puppeteer 539 M, npx cache 511 M, bun 62 M | **(unmeasured)** |
| Python / data-ml | pip, uv cache, pyenv versions, Hugging Face hub and xet, torch hub, wandb, Jupyter checkpoints; ollama, lmstudio, kaggle report-only | pip 199 M, hf hub 1.6 G (whisper model dominates), hf xet 87 M | **(unmeasured)** |
| Go / Rust / JVM / Ruby / PHP / .NET | go mod and build caches, cargo registry/git, Gradle, rbenv, composer, NuGet | cargo registry 463 M, rbenv 3.2.0 273 M; go, composer, nuget, pyenv absent | **(unmeasured)** |
| DevOps | kube, helm, terraform plugin cache and `.terraform`, docker (one row), vagrant report-only | docker 3.5 G dir (at most about 1.1 G reclaimable earlier), vagrant boxes 587 M | **(unmeasured)** |
| Game (Unity, Unreal, Godot) | `Library`, `Temp`, `Intermediate`, `.godot`, UPM cache, all ask-first per project | none present | **(unmeasured)** |

No per-type budget other than the `build/` and AVD proposals has been measured; do not adopt a number for a type without measuring it on your machines first.

## 9. Lessons and risks seen

- **Free space alone does not prove a reclaim.** Four separate real runs (npm 1.3 G, brew 76.5 M, the 15.5 GB manual set, the test sessions) moved `df` by tens of MB or in the wrong direction because other processes were writing. The tool reports `du` before minus `du` after per target and that is the only figure to trust.
- **The tool's own probes can write.** Querying the real `dotnet` for its NuGet cache path created `~/.dotnet` and `~/.nuget/NuGet/NuGet.Config` on first run (T1). Tool-queried guards therefore run only at apply time, and the dotnet query sets the telemetry and logo opt-outs.
- **Real tools differ from documentation.** `deno info` prints colour into a pipe, `bun pm cache` fails outside a project, `dotnet` prints a first-run banner: each made a row always REFUSED until fixed against the real output (T1). Rows whose tool was never run for real are listed as such in STATUS.md.
- **Wrong paths fail quietly.** The Telegram media path was wrong (`appstore` instead of `stable`) until checked on the real home (P8). Paths are defaults only; XDG/HF_HOME/TORCH_HOME style relocations are not read (except `TF_PLUGIN_CACHE_DIR`).
- **Overlap.** A generic parent row (app caches) could bypass the guard of a specific child (JetBrains); fixed in T1 so a parent applies every child guard.
- **A scan can be slow under load.** A real-home `plan` took 3 to 7 minutes at load 10-20; run it when load is below the limit.

## 10. Honest limits

- Tested on one developer Mac and on fake homes; no real non-developer Mac. The non-developer catalog is small (caches, trash, logs, chat media, large unused apps, login items, snapshots) and its Mail/Messages paths are blocked by TCC here, so unconfirmed; a tool without Full Disk Access shows size 0 or no row (the safe failure).
- Large-app "last used" comes from Spotlight metadata, which was present for 6 of 226 apps here; the rest are listed as UNKNOWN and are never removable by `apply`.
- Never run for real: `docker system prune`, `flutter pub cache clean`, `simctl delete unavailable`, avdmanager/sdkmanager/fvm/rustup, and most K3/K3b tool commands (stubs and fake homes only, by the read-only rule and by user choice for docker).
- `sdkmanager` and `avdmanager` are being superseded by the Android CLI; the supported rows depend on those binaries existing **(verify)**.
- Time Machine local snapshots are reported, never deleted by the tool (`tmutil deletelocalsnapshots` is shown for by-hand use).
- Spotlight exclusion effect on load: **(unmeasured)**; a measurement was attempted twice and aborted for load above 8.

## 11. Apps, alarms and the no-close rule (disk alarm, memory and CPU advice)

- **Never closes, kills or signals anything.** The Memory and CPU screens (`hh perf`, `m` and `c` on Home, `hh focus perf mem|cpu`) and the alarms and the alarms only read and advise. `tests/check-apps.sh` fails if any script or the TUI contains `kill`, `pkill`, `killall`, an osascript quit, `killPid` or `Process.kill` (`kill -0`, a liveness check, is allowed). Advice says "close X (save first)"; the user does it.
- **App based.** `apps.sh` collapses every process under its outermost `.app` (Chrome's helpers are one row) and groups command-line tools by name. Rank = share of RAM + share of all cores. Kinds: app (you can quit it), tool (stop it where you started it), system (macOS itself: indirect advice only, never "close").
- **Figures are approximate.** RSS counts shared memory in every app that maps it, ps `%CPU` is a decayed average, and above load 8 the CPU numbers are not trustworthy (the report says so).
- **Alarms** (`hh schedule on`, a launchd agent running `hh check`; no resident process, about 0.17 s per run): disk warn below `min_free_gb`, critical below `hard_gb`; memory warn below `mem_free_pct` (15) % free, critical at half; CPU warn when the 5-minute load reaches `max_load`, critical at twice. One notification per level crossing, then a 6 h cooldown; quiet hours silence warn, never critical. Disk clicks open `hh focus` (safe items pre-ticked to cover the gap); a memory click opens the Memory screen (`hh focus perf mem`) and a CPU click the CPU screen (`hh focus perf cpu`). `hh snooze` keeps one alarm quiet (critical too) until the time you chose.
- **Config keys added:** `check_every_min` (5-1440, asked by `schedule on`, the last choice is the next default), `notify`, `quiet_hours`, `check_mem`, `check_cpu`, `mem_free_pct`, plus `name` and `role` (onboarding, stored locally only) and `ignored_apps` (comma-separated app names left out of the apps table, the advice and alarm text; data only, never executed). Ignoring and snoozing change only what hh says; neither touches a process.
