# Changelog

## 1.0.0

First public release.

- Finds what eats disk, CPU and memory on a Mac; classifies each item safe-regenerable, ask-first or never; plans the cleanup with cost notes; applies only what you approve (dry run by default).
- Terminal interface with five looks (guided, cockpit, dashboard, space map, console) plus a plain fallback, a look chooser (terminal and browser), and a first-run introduction.
- Home screen: Storage, Memory, CPU, Alarms and Settings in one menu, every area reachable from every look.
- Memory and CPU screens rank running apps and give directions for freeing resources. hh never closes, kills or signals anything; ignore (`i`) and snooze (`z`) change only what it says.
- Alarms for disk, memory and CPU through a launchd job (no resident process); quiet hours, snooze, a test alert, and notification clicks that open the right screen.
- Alarms and Settings forms write the same keys as `hh config set` and `hh schedule`.
- A never-touch list (`~/.config/host-hygiene/protected`, or `HH_PROTECT`).
- Guard gate other tools can call before a build (`hh guard`).

Limits: macOS only. The bundled interface binary is for Apple Silicon; on Intel build `tui/build.sh` (needs a Dart SDK).
