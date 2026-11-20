# Changelog

## 1.0.1

- The full interface now runs on Intel Macs as well as Apple Silicon: the release archive carries a binary for each chip and `hh` picks the right one. (`hh_tui --version` names the chip.)
- If no usable interface is found, `hh focus` (what an alarm click runs) prints the text view instead of an error.
- A removal that fails no longer stops the rest of the batch: the interface keeps going and lists what failed, with a plain-words hint. A folder that an app's background helper keeps writing into ("Directory not empty") is retried once. `hh apply --keep-going` does the same on the command line.
- Home stays one key away after an alarm click (`hh focus`), and the finished screen says how to get back to it.
- The WhatsApp media entry says to quit WhatsApp first.
- `hh schedule off` only unloads a job whose file it owns.
- Tests: new `check-arch.sh` and `check-apply.sh`; several terminal tests wait for the content they check instead of a fixed pause.

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

Limits: macOS only. (1.0.0 shipped the interface for Apple Silicon only; Intel Macs got the plain shell menu.)
