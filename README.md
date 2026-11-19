# host-hygiene (`hh`)

Find what eats disk, CPU and memory on your Mac, and clear it only when you say so.

Built for developers, whose machines fill up with build folders, SDKs, emulators and package caches, but it also covers the usual non-developer space hogs. macOS only.

- **Storage.** Scans, ranks and explains each item (the exact command, how much it frees, what it costs to get back), then removes only what you tick. Every item is classed `safe-regenerable`, `ask-first` or `never`. Dry run is the default.
- **Memory and CPU.** Ranks running apps by impact (a browser's 30 helper processes are one row) and tells you how to free resources. **It never closes, kills or signals anything**; you do that yourself.
- **Alarms.** A launchd job (no resident process) warns you when disk, memory or CPU crosses a line you set, with quiet hours and snooze. A notification click opens the right screen.
- **Guard.** `hh guard` is a fast free-space and load check other tools can call before a build.

## Install

```sh
git clone https://github.com/krysnkem/host-hygiene.git && cd host-hygiene
./install.sh            # adds ~/.local/bin/hh   (--claude also links it as a Claude Code skill)
hh                      # opens Home
```

The interface (`tui/hh_tui`) is not stored in git. Either download the release archive from the [Releases page](https://github.com/krysnkem/host-hygiene/releases), which includes it for Apple Silicon, or build it with `tui/build.sh` (needs a Dart SDK). Without it `hh` falls back to a plain shell menu.

Remove it with `./uninstall.sh` (`--purge` also deletes `~/.config/host-hygiene`).

## Use

`hh` opens **Home**: Storage, Memory, CPU, Alarms, Settings, each with one status line. `s m c a g` jump, `Enter` opens, `Esc` goes back, `v` cycles looks, `L` chooses one, `q` quits.

| Command | What |
|---|---|
| `hh` | the interactive interface |
| `hh scan`, `hh plan` | read-only: what is using space, and what clearing it would do |
| `hh apply --target PATH --run` | remove one approved item (dry run without `--run`) |
| `hh perf` | running apps ranked by impact, with directions |
| `hh schedule on\|off\|status` | disk, memory and CPU alarms |
| `hh snooze disk\|memory\|cpu 1h\|4h\|24h\|tomorrow\|off` | keep one alarm quiet |
| `hh check --test` | send a sample alert |
| `hh config show\|get\|set` | thresholds, look, name, quiet hours, ignored apps |
| `hh guard` | free-space gate for scripts (exit 0 ok) |
| `hh --version` | the version |

Everything the interface can change is also a `hh config set` or `hh schedule` call, so scripts and the interface never disagree. The full reference is in [SKILL.md](SKILL.md); the rules the tool keeps are in [POLICY.md](POLICY.md); the Home design is in [docs/HOME-DESIGN.md](docs/HOME-DESIGN.md).

## Safety

- `apply` acts only on explicit `--target` paths and re-checks each one: absolute, no `..`, no symlink, not `$HOME`, not a tracked file, nothing on your never-touch list.
- Never-touch list: one folder name per line in `~/.config/host-hygiene/protected` (or `HH_PROTECT=a,b`). Anything at or under such a folder is refused.
- Alarms read the machine and notify; they never clean anything. The test suite fails if any script or the interface contains a kill, a signal, an app quit, or a clipboard call.
- Config and state live in `~/.config/host-hygiene/` and are data only, never executed.

## Licence

MIT. See [LICENSE](LICENSE).

## Tests

```sh
tests/check-apps.sh && tests/check-schedule.sh && tests/check-budget.sh   # no extra tools
HH_PYTHON=<python with pyte> tests/check-home.sh   # also check-look, check-profile, check-chooser (terminal-driven)
cd tui && dart run tests/home_model.dart && dart analyze
```

All suites use fake home folders and a stub notifier: nothing real is deleted and no real notification is sent.
