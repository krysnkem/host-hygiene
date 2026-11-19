# hh home: every feature, interactively

Status: built, steps 1 to 6 of section 9. Not built: `z` on the Storage screen (the disk snooze exists as `hh snooze disk`), Dashboard and Space map Home tiles (they use the table), `:mem` and `:cpu` Console commands. Mockups are 80 columns.

## 1. Goal and rules

Everything `hh` can do is reachable from inside the TUI, for the three
resources it watches (Storage, Memory, CPU) and for the things around them
(Alarms, Settings). Each resource gets the same loop: **scan, view, act**.

Rules this design must not break:

1. **hh never closes, kills or signals anything.** Memory and CPU "actions" are
   advice plus bookkeeping. `tests/check-apps.sh` stays and is extended to
   every new file. No Activity Monitor launch, no clipboard.
2. **One implementation, five looks.** A look draws; it does not decide. The
   home, the resource screens and the forms are shared components fed by state,
   so a feature added once appears in every look (the `Look` seam stays).
3. **TUI and CLI are equivalent.** A setting saved in the TUI writes the same
   config key `hh config set` writes. Nothing lives only in the TUI.
4. **No resident process, no extra load.** Scanning happens on a key press or
   from the launchd check, never in the background while the TUI idles.
5. Files stay under 200 lines; screens are extracted widgets, not `_buildX()`.

## 2. Gap map (what the TUI reaches today)

| Capability | CLI | TUI today | After |
|---|---|---|---|
| Scan, plan, apply cleanup | yes | yes | Storage screen |
| Focus on the storage gap | `hh focus` | notification only | Storage screen, `f` |
| Apps by impact | `hh perf` | `m` | Memory and CPU screens |
| Memory scan and advice | `hh check`, `hh perf` | none | Memory screen |
| CPU scan and advice | `hh check`, `hh perf` | none | CPU screen |
| Limits | `config set` | first run only | Settings |
| Schedule on/off, interval | `hh schedule` | none | Alarms |
| Alarm thresholds, quiet hours, notify | `config set` | none | Alarms |
| Test notification | `hh check --test` | none | Alarms, `t` |
| Look | `config set ui`, `hh look` | `v`, `L` | Settings (and keys stay) |
| Name, role | onboarding | none | Settings |
| Ignored apps | none | none | new: Settings list |
| Snooze an alarm | none | none | new: any resource screen, `z` |

## 3. Navigation

One new stage, `Stage.home`, becomes the first screen after onboarding, scan
question and first scan (replacing the direct jump to Pick). Existing screens
become areas reached from it:

```
onboarding -> look -> scan? -> HOME --s--> Storage (pick -> confirm -> work -> done)
                                   |--m--> Memory
                                   |--c--> CPU
                                   |--a--> Alarms
                                   `--g--> Settings
```

`Esc` returns to Home from any area; `q` quits from Home. Existing shortcuts
keep working: `v` cycles looks, `L` chooses, `?` help. `m` today opens the
apps view; it becomes Memory. `hh perf` opens Memory (Tab flips to CPU).

Deep links (so a notification click lands where it should):

| Entry | Opens |
|---|---|
| `hh` | Home |
| `hh focus` | Storage, focus ticking on |
| `hh focus perf mem` / `cpu` | Memory / CPU (the alarm names which) |
| `hh perf` | Memory |

`Stage.home` plus an `Area` field in `AppState`; `HH_FOCUS` carries
`1`, `perf-mem`, `perf-cpu` (plain `perf` keeps meaning memory).

## 4. Home

Three resource rows and two utility rows. Each resource row is one line of
status taken from the last scan, with the threshold it is judged against, a
level word (ok, low, critical), and the key that opens it. The same
`HomeRow` list feeds every look.

Console (the k9s-like look):

```
 hh console  free 11.6G  load 8.2  mem 31% free  alarms on, every 30 min
 ❯ s Storage   11.6 GiB free   below the 15 GiB floor        LOW
   m Memory    31% free        above the 15% line            ok
   c CPU       load 8.2        above max 8.0                 HIGH
   a Alarms    on, every 30 min, quiet 22-07
   g Settings  look console, name Sam, 2 apps ignored
 r rescan · enter open · s m c a g jump · v look · q quit
```

Cockpit (panels):

```
 ● host-hygiene                      scanned 2 min ago · r rescan
 ╭─ Storage ──────────╮ ╭─ Memory ───────────╮ ╭─ CPU ──────────────╮
 │ 11.6 GiB free     │ │ 31% free           │ │ load 8.2 (8 cores) │
 │ floor 15 · LOW    │ │ line 15 · ok       │ │ max 8.0 · HIGH     │
 │ 5 safe items 150M │ │ top: Docker 4.1G   │ │ top: qemu 170%     │
 │ [s] open          │ │ [m] open           │ │ [c] open           │
 ╰───────────────────╯ ╰────────────────────╯ ╰────────────────────╯
 ╭─ Alarms: on, every 30 min ─╮ ╭─ Settings ──────────────────────────╮
 │ [a] schedule, thresholds   │ │ [g] look, limits, name, ignored apps │
 ╰────────────────────────────╯ ╰──────────────────────────────────────╯
```

Guided (one question per screen, Hy speaks):

```
  Hy: Two things need attention. Your disk is under its 15 GiB floor,
      and the machine is busy. What would you like to look at?

    ❯ Storage: 11.6 GiB free, 5 safe items to clear
      CPU: load 8.2, qemu is using 170%
      Memory: fine
      Alarms and settings
```

Dashboard: three tiles with a sparkline each (history already collected for
the look). Space map: three bars sized by how far each is from its line.
Plain: a numbered list (`1 Storage ... 5 Settings`), the same rows as Console.

## 5. Resource screens

One shared `ResourceView(resource)`: a header with the gap to the line, a ranked
list, and a directions panel for the selected row.

Memory (CPU is identical but sorted and measured by CPU share):

```
 Memory  31% free, your line is 15%: ok       scanned just now
   #  APP               PROCS    MEM    CPU   ADVICE
 ❯ 1  Docker Desktop       9   4.1G   12%   can quit: frees ~4.1G
   2  Google Chrome       31   2.6G    8%   can quit: frees ~2.6G
   3  Xcode                6   2.2G    3%   keep if you are building
   4  claude               3   0.6G    9%   (this tool's host)
   system: WindowServer 0.9G · kernel_task · mds (not ours to close)
 Selected: Docker Desktop (will free ~4.1G)       ticked 1: ~4.1G
 How: save work, then Cmd-Q, or right-click its Dock icon and choose Quit.
 If it is frozen: Option-Cmd-Esc, select it, Force Quit.
 space tick · i ignore · z snooze · y summary · r rescan · esc back
```

Scan: `r` takes a fresh reading (free memory %, 5-minute load) and re-ranks.
View: collapsed per app, system items listed but never ticked. Act: below.

### Act menu (the whole list, none of it touches a process)

| Key | Action | Writes |
|---|---|---|
| space | Tick an app you plan to close; the tally shows what that would free | nothing |
| i | Ignore this app: never advised or named in alarms again | `ignored_apps` |
| z | Snooze this resource's alarm: 1 h, 4 h, 24 h, until tomorrow | state file |
| y | Show a plain-text summary of the ticked apps to copy by hand | nothing |
| ? | Directions for the selected row (kind decides the text, below) | nothing |

Directions by kind: normal app (Cmd-Q, or Dock icon Quit, save first);
frozen app (Option-Cmd-Esc, Force Quit); command-line tool or emulator (stop
it where you started it, for example Ctrl-C, or quit Docker Desktop); system
item (existing hint, never a quit instruction).

Storage keeps its current pick, confirm and work flow (that one the user does
approve and hh executes, with the existing guard and dry-run default), plus `f`
for focus ticking, `z` snooze, `r` rescan.

## 6. Alarms and Settings (shared form kit)

A form is a list of rows `label  value  (default or last used)`. Enter edits
the row (toggle, number, choice or text), Esc cancels the edit, and a save
writes the config key immediately and shows `saved`. Validation is the CLI's
validation (same ranges, same messages), called through the engine, so the two
cannot disagree.

```
 Alarms
 ❯ Checks          on                      (hh schedule on/off)
   Check every     30 min      default 30, last 30
   Disk floor      15 GiB      warns below; critical at 5 GiB
   Memory line     15 % free   warns below; critical at half
   CPU load        8.0         warns above; critical at 2x
   Notify          on
   Quiet hours     22-07       silences warnings only
   t  send a test notification now
```

Settings: look (opens the chooser), name, role, limits shortcut, and the
ignored-apps list where each row can be restored with Enter.

## 7. Where it goes in the code

| Piece | File (new unless noted) | Notes |
|---|---|---|
| `Stage.home`, `Area`, `homeRows` | state.dart (edit), home_model.dart | rows from last scan |
| Home drawing | home_view.dart plus one tiny adapter per look | shared; looks only frame it |
| Resource screen | resource_view.dart, resource_rows.dart | replaces apps_view.dart |
| Directions text | advice_text.dart | pure functions, unit-tested |
| Form kit | form_view.dart, form_rows.dart | alarms and settings share it |
| Engine reads | engine.dart (edit) | `perf()`, `field`/`setField` exist |
| Ignore and snooze | schedule.sh, apps.sh (edit), state file | check honors both |
| Deep links | control.dart, host-hygiene.sh (edit) | `focus perf mem|cpu` |

New config key: `ignored_apps` (comma-separated, free text, data only).
New state key: `snooze_<resource>` (epoch). `hh check` skips a snoozed
resource and `apps.sh` skips ignored apps in advice and in the alarm text.

## 8. Tests

- `check-apps.sh`: extend the no-close grep to every new file; add: no
  `open -a "Activity Monitor"`, no `pbcopy`, no clipboard calls.
- Pty tests (look-drive): Home appears after first scan in all five looks and
  at 24x80, 12x60, 10x70; each key opens its area and Esc returns.
- Form tests: each key writes exactly the config line `config set` writes;
  invalid input is rejected with the CLI's message.
- `check-schedule.sh`: snooze and ignore honored; ignored apps absent from the
  notification text.
- Deep links: `hh focus perf mem|cpu` lands on the right screen.

## 9. Build order

1. Shared model and engine reads (no UI): `homeRows`, `perf()`, advice text.
2. Resource screen for Memory and CPU in the Console look first, then others.
3. Home and `Stage.home`, Storage re-entered from it.
4. Form kit, Alarms, Settings.
5. Ignore and snooze, with the schedule.sh changes.
6. Deep links, docs (POLICY, SKILL, STATUS), full suite run.

Each step ends green on the existing suites before the next starts.

## 10. Decisions (accepted: the recommended option in each)

1. **Ignored apps persist** across runs (recommended) versus session only.
2. **Home is the first screen** after onboarding (recommended) versus a key
   from the existing screens.
3. `m` changes meaning (apps view to Memory). Accept (recommended) or keep
   `m` for apps and use another key for Memory.
4. Dashboard and Space map get Home tiles in step 3, or ship Console,
   Cockpit and Guided first and follow with the other two.
