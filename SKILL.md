---
name: host-hygiene
description: Find what eats disk, CPU and memory on this Mac (developer caches, SDKs, emulators, per-project build dirs, plus a smaller non-developer set), classify each as safe-regenerable, ask-first or never, plan the cleanup with cost notes, and apply it only with explicit approval (dry-run by default). Also a fast guard gate other tools call before a build. Use when the disk is nearly full or the machine is slow.
---

# host-hygiene

A global bash tool (macOS only; other systems exit 3) with a Dart terminal UI. It discovers the machine and the kind of work done on it, ranks what uses space, explains each item (exact command, expected freed, cost), and removes only what the user approves. The engine is `scripts/host-hygiene.sh`; data lives in `catalog/catalog.tsv`. Status and measurements: `STATUS.md`. Rules and budgets: `POLICY.md`. Evidence per developer type: `kb/`.

## Run it

Global command: `hh` (wrapper at `~/.local/bin/hh`, `exec`s the script). `S=~/.claude/skills/host-hygiene/scripts/host-hygiene.sh` is the same thing.

`hh` with no arguments in a terminal opens the guided journey (Look, Pick, Confirm, Work, Done, mascot Hy) if `tui/hh_tui` is built (`tui/build.sh`, needs a Dart SDK), else the shell menu (`scripts/menu.sh`). `HH_CLASSIC=1` forces the shell menu.

### TUI keys
Arrows move, space ticks, `s` all safe, `f` all ask-first, `a` all, `n` none, PgUp/PgDn one window, Home/End, mouse wheel and click-to-tick, Enter continues (Confirm defaults to No), `q` quits. Under 24 rows: compact mode. Under 30x6: "Terminal too small". It never deletes by itself; it calls `apply --run --yes` only after Confirm.
**Home (the first screen).** `hh` opens a menu of Storage, Memory, CPU, Alarms and Settings with one status line each, drawn by every look. `s m c a g` jump; Esc returns from any area; after a clear, Enter or Esc returns with fresh readings. Memory and CPU rank running apps and give directions; `space` ticks, `i` ignores an app for good (config `ignored_apps`, restored in Settings), `z` snoozes that alarm. Alarms and Settings are forms that write the same keys as `hh config set` and `hh schedule`. Design: `docs/HOME-DESIGN.md`.

**Looks (UI Phase 2).** Six ways to draw the same journey: `guided` (default, mascot Hy), `plain` (fallback list), `cockpit` (two panes), `dashboard` (live gauges; polls `uptime`/`df` every 10 s only while shown, paused in Work), `spacemap` (blocks sized by item size), `console` (sortable table with a `:` command line: `:safe :ask :all :none :sort size|class|path :filter text :look <id> :go :quit :help`; also keys z c p sort, `/` filter). Choose with `host-hygiene.sh config set ui <id>` (allowed ids are `UI_LOOKS` in `scripts/host-hygiene.sh`, the one list) or `HH_LOOK=<id>` (beats the file). A look smaller than its minimum (cockpit 60x16, dashboard 60x14, spacemap 40x10, console 50x10, guided 30x6) draws the plain list with a one-line hint.
Switching live: `v` cycles guided, cockpit, dashboard, spacemap, console (plain is never a stop), skips looks that do not fit this terminal, keeps cursor, ticks and stage, and does NOT save; `V` switches and saves the new look as the default (`config set ui`). In the console look `v` is typed text while the `:` or `/` prompt is open: use `:look <id>`. Spacemap only: `Tab` or `e` toggles collapsed/expanded. The key-hint line ends with `v look: <Name>` when there is room. A terminal resize repaints at once (SIGWINCH).
**Look chooser (UI Phases 3-5).** `hh look` opens a list of the five designs (guided, cockpit, dashboard, spacemap, console; plain is the automatic fallback and is not offered) with a small ASCII picture of the highlighted one (shown from 24 rows; shorter terminals get the list alone, scrolled to fit). Arrows move, Enter saves through `config set ui <id>` and then opens the TUI in that look, Esc or `q` cancels (nothing written). When a browser can be opened, "Open in the browser" is the first choice. `hh look --web` goes straight to the browser page: `hh_tui --pick-look [--web]` binds 127.0.0.1 on a random port, opens `http://127.0.0.1:PORT/<token>/` (macOS `open` in a GUI session and not over SSH; Linux `$BROWSER`/`xdg-open` with DISPLAY or WAYLAND_DISPLAY), shows all five designs as mockups with sample data (nothing is scanned) and the mascot Hy, and exits on the first Save. The terminal shows "Waiting for your choice in the browser... (Esc to choose here instead)"; no browser, a failed launch, no page request within 60 s, or Esc/Ctrl-C fall back to the terminal list with the reason. Inside the TUI the `L` key (also `l`) opens the same chooser at any stage except Limits and Work and the TUI switches live (no restart); the key line always ends with a look-switch hint: `v look: <Name> . L choose`, shortened to `v look: <Name>`, `v look . L choose` or `v look` (and the key list itself shortened) as the terminal gets narrower. First run: after the limits question (or at start when `ui=` is not in the config file and `HH_LOOK` is unset) Hy asks "Choose how I should look: in the browser, or here?" with browser / here / keep the default; the answer is remembered by the presence of `ui=` (keep writes `ui=guided`), Esc means "ask me next time". Never asked with `HH_NO_PROMPT=1`, and never without a terminal. The classic shell menu has "Change look" (calls the chooser when `tui/hh_tui` exists, else says it needs the TUI); `hh look` without the binary says so plainly. Exit codes of `hh_tui --pick-look`: 0 saved, 10 no change, 2 no terminal.
Web chooser security: loopback only (127.0.0.1, random port, no daemon, one process, exits on save/cancel/timeout, port closed); a random 192-bit token is required in the URL path of every request (403 otherwise) and again in the save body; Host must be exactly `127.0.0.1:<port>` and an Origin, if sent, must be `http://127.0.0.1:<port>` (403: DNS rebinding and cross-site requests); only GET and POST (405); one static page embedded in the binary, no file is ever read from disk, no external request, no font, no CDN (CSP `default-src 'none'`); `POST /<token>/save` takes only `application/json` of at most 1 KB with exactly `{"look","token"}` and the id must be one of the five (400/413); it writes only the config file through `config set ui`, replies OK, then the server exits at once. Idle limit 5 minutes after the page was opened.
Env: `HH_LOOK=<id>` look for this run; `HH_ASCII=1` force ASCII glyphs (otherwise UTF-8 is detected from LC_ALL/LC_CTYPE/LANG); `HH_CLASSIC=1` shell menu; `HH_MIN_MB=N` smallest row shown (default 50); `HH_SCRIPT=path` engine script the TUI calls; `HH_BROWSER_CMD=path` (test hook) executable that is called with the page URL instead of the detected browser, wins over the SSH/GUI checks, and a failing one falls back to the terminal chooser; `HH_WEB_TIMEOUTS=FIRST,IDLE` seconds (default `60,300`, test hook) for the page to be requested and for idle time after that; `HH_NO_PROMPT=1` also suppresses the first-run look question.

## Commands (all read-only except `apply --run`)

| Command | What |
|---|---|
| `profile [--profile developer\|non-developer] [--tsv]` | toolchains, projects, developer type(s), host numbers. `--tsv` is machine output |
| `scan [--profile P] [--tsv] [--min-mb N] [--root DIR ...]` | ranked findings (size, class, owner, mtime, command, cost), load, top processes, perf advice. About 1-3 min on a real home; log load |
| `perf` | running apps ranked by impact (processes collapsed into apps) with advice on what you could close. Never closes anything. In the TUI: the `m` key |
| `check [--dry\|--test]` | one read of disk, memory and CPU against the alarm levels; notifies at most once per level, then a cooldown |
| `schedule on [--every MIN]\|off\|status` | `on` asks how often (shows the default or the last choice) and installs a launchd agent that runs `check`; `off` removes it |
| `focus [perf [mem\|cpu]]` | opens on Pick with enough safe items ticked to get back above the disk floor; `perf` opens the Memory screen, `perf cpu` the CPU screen. What a notification click runs (disk, memory, CPU each land on their own screen) |
| `snooze disk\|memory\|cpu 1h\|4h\|24h\|tomorrow\|off` | keeps one alarm quiet for a while (state file only; critical too) |
| `plan [--profile P] [--min-mb N] [--tsv]` | scan plus exact command, freed estimate, cost 1 (rebuild) / 2 (re-download) / 3 (data loss), best freed/cost first; `--tsv` has 10 columns (column 8 `supported` y/n) |
| `apply --target PATH [...] [--run] [--yes] [--ask-first-ok] [--log F]` | dry-run unless `--run`. See safety below |
| `guard [--min-free-gb N] [--hard-gb N] [--max-load N] [--quiet\|--kv]` | instant df + uptime gate. Exit 0 ok, 1 below soft floor (disk or load), 2 hard stop (disk below hard). `--kv` prints load= free_gb= status= and the limits |
| `config [show\|init\|set KEY VALUE]` | thresholds file `~/.config/host-hygiene/config` (HH_CONFIG overrides the path) |
| `look [--web]` | choose the look: terminal list, or `--web` for the browser page (needs `tui/hh_tui`; exit 2 with a plain message when it is missing or there is no terminal) |
| `perf [report\|advice]` | CPU/memory consumers and known offenders (Spotlight, WindowServer, mediaanalysisd, chat apps, qemu), AVD RAM advice. Kills nothing |
| `menu` | shell guided menu (needs a tty, else exit 2) |
| `hello` | replay the first-run intro (phrase pools in `scripts/intro.sh`) |

Other exit codes: 2 usage/refused invocation (bad option, `--run` without tty or `--yes`, unwritable log), 1 an apply item errored, 3 unsupported OS.

**Thresholds**: flag > env (`HH_MIN_FREE_GB HH_HARD_GB HH_MAX_LOAD`) > config file > built-in 15 / 5 / 8. The first interactive run asks (suggestions from this host); never prompts when piped, `--quiet`, `--kv`, `--run`, `--tsv` or `HH_NO_PROMPT=1`. `flutter-uat/scripts/bootstrap.sh` reads `guard --kv`.

**Profile** is auto-detected: two or more developer toolchains, or one project with a manifest (or `*.tf`, `*.ipynb`, `*.uproject`, `project.godot`, Unity ProjectVersion) = developer. java/python/brew/go/ruby/php/dotnet/kmp tools are shown but not counted. `--profile non-developer` runs only catalog rows marked `any`.

## Classes
`safe-regenerable` (git-ignored project dirs, tool-owned caches, removable after apply re-verifies); `ask-first` (shared or costly: AVDs, ~/.gradle, ~/.pub-cache, Docker, SDK packages, model caches, per-project Unity/Unreal/Godot dirs); `never` (Downloads, Documents, keychains, browser profiles, `protected_repo`; never proposed, apply refuses). Anything unproven is ask-first. Rows marked `report-only` (ollama, lmstudio, kaggle, vagrant, messages attachments, large unused apps, old Downloads) are shown with a by-hand command and always REFUSED by apply.

## apply safety
Acts only on explicit `--target` paths and re-verifies each: refuses relative paths, `..`, symlinks, `$HOME`, anything on your never-touch list (`~/.config/host-hygiene/protected`, one folder name per line, or `HH_PROTECT`), class `never`, report-only, project dirs git does not ignore, anything not in the catalog or known regenerable names. `ask-first` is SKIPPED without `--ask-first-ok`. `--run` needs a y/N per item (exact `y`) or `--yes`. Stops on the first error or refusal, skips dirs with open files (lsof), refuses to delete if it cannot write `apply-log.txt`. Freed = du before minus after per target. Tool-owned removals ask the tool which dir it would clear and refuse on mismatch; editor/daemon guards refuse while IDE, Gradle daemon, Unity/Godot/Unreal or terraform run.
Supported tool commands: docker system prune, npm/pnpm/bun/corepack/deno/pip/uv/go/composer/nuget/pod cache commands, brew cleanup, flutter pub cache clean, simctl delete unavailable, avdmanager delete avd, fvm remove, rustup toolchain uninstall, sdkmanager --uninstall, pyenv/rbenv uninstall; plus rm of verified paths. A missing tool makes the row supported=n.

## Developer kinds (profile `kind` rows)
flutter, android, ios, rn, kmp, maui, node, frontend, python, go, rust, jvm, ruby, rails, php, dotnet (16). Overlaps are folded (node under rn/frontend, jvm under android/kmp, dotnet under maui, ruby under rails).

## KB and tests
`kb/` is documentation of evidence per developer type (160 entries); the engine never reads it, the catalog wins on disagreement. Format `kb/_TEMPLATE.md`, overview `kb/INDEX.md`, rules `kb/README.md`. Every size needs a label (measured here / reported online + URL / unverified).

**Add a catalog row from a KB entry (K3/K3b procedure):** pick an entry with a safe removal and a verifiable source; set `catalog-id: <id>` in the entry; add `id|needs|path|class|removal|cost` to `catalog/catalog.tsv` above the generic app-caches/dot-cache rows (first path wins); use `rm` with guards or the tool's own command (tool rows need a `dc_prepare` check naming the dir it clears, in `scripts/devcatalog.sh` or `devcatalog2.sh`); default to ask-first when the KB source is secondary; use `report-only: <by-hand command>` when no safe command is verified; add the id to the expectations in `tests/check-catalog-groups.sh` (fake home, stub tools); run all three checks.

Tests (bash 3.2, fake homes under a scratch dir, `env -i`, stripped PATH, never the real home):
- `tests/check-kb.sh`: KB entries vs template and catalog. Expect 0 failures (18 warnings: catalog rows without a KB entry).
- `tests/check-catalog-groups.sh`: catalog rows per developer group, apply refusals and approved runs on fakes. 276 passed.
- `tests/check-profile.sh [SCRATCH]`: kinds and sentences for 16 types and mixes. 331 checks without pyte; 523 when a python with `pyte` is on PATH or `HH_PYTHON` (adds the TUI Look screen via `tests/look-driver.py`).
- `tests/check-look.sh [SCRATCH]` (HH_PYTHON with pyte, tui built): all six looks, config round trip, HH_LOOK, fallback, pty matrix per look and size, live resize, CJK, ASCII, switch keys, `V`, `:look`, Dashboard poll timer (PATH shim). Set `HH_MATRIX=0` to run only the quick config part. Drivers: `tests/look-drive.py`, `tests/look-seam.py`. Parser tests: `(cd tui && dart run tests/console_parse.dart)`.
- `tests/check-chooser.sh [SCRATCH]` (HH_PYTHON with pyte, tui built, curl, lsof; about 10 minutes): the terminal chooser at 24x80, 12x60 and 10x70 (every id saves and the TUI opens in it), the web server against curl (403/404/405/400/413, Host and Origin, valid save, port closed, one process, loopback only, CPU), timeouts, the browser-detection matrix (open present or missing, SSH, failing hook), first run, the `L` key and the classic menu entry.
- `tests/make-dev-home.sh DIR`: builds a fake developer home; run the tool with `env -i HOME=DIR PATH=/usr/bin:/bin:/usr/sbin:/sbin`.
- TUI: `(cd tui && dart analyze)`; rebuild with `tui/build.sh`.

Never delete anything from a scan by hand without the cost note and the user's approval; shared caches are always asked about.
