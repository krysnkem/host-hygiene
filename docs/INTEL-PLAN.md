# Plan: the full interface on Intel and Apple Silicon (1.0.1)

Status: phases A to D built and tested (the Intel binary under Rosetta passes every suite); phase E done (1.0.1 released by hand); phase F built: `.github/workflows/release.yml`, with a deploy key for the tap (secret `TAP_DEPLOY_KEY`), dry run pending. Author: Claude. For: Christian.

## 1. Why

The interface (`tui/hh_tui`) is a compiled program, and the one shipped in 1.0.0 was built on Apple Silicon, so an Intel Mac cannot run it. Intel users get the plain shell menu (no Home, no Memory or CPU screens, no forms, one look). Worse, a notification click runs `hh focus`, which exits with an error when the interface is missing.

Dart 3.9 cannot cross-compile to macOS (`Unsupported target platform macos_x64`; only Linux targets are accepted), so each architecture has to be built by a Dart that runs as that architecture.

## 2. Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Ship **two binaries**, `hh_tui-arm64` and `hh_tui-x86_64`, not one combined binary | Dart's output is a Mach-O with an appended snapshot; merging two with `lipo` is untested and could break silently |
| 2 | `hh` picks the binary by `uname -m` | Works on native Intel, native Apple Silicon, and a Terminal running under Rosetta |
| 3 | Build the Intel binary first with **Rosetta** locally, then add **GitHub Actions** for native builds of both | Rosetta unblocks 1.0.1 now; Actions makes every future release automatic and gives real Intel testing |
| 4 | Raise the folder size cap from 9,500 KB to 18,000 KB | A second 8 MB binary; the cap exists to catch accidental bloat, not to forbid this |
| 5 | The shell menu stays as the last-resort fallback | A machine where neither binary runs still works |

## 3. Phases

Each phase ends green on the existing suites before the next starts.

### A. Make a missing or unrunnable interface degrade gracefully (no build needed)

- `hh focus [perf [mem|cpu]]` with no usable interface: print the same information as text (`hh perf` report, or the disk plan summary) and say why, instead of exiting 2.
- `focus.command`, `focus-perf.command`, `focus-cpu.command` therefore never open a terminal that only shows an error.
- A launcher helper `tui_bin()` in `host-hygiene.sh`: prefers `tui/hh_tui-$(uname -m)` (mapping `arm64` and `x86_64`), then legacy `tui/hh_tui`, then none. Used by every call site (`hh`, `focus`, `look`, `menu.sh` look chooser).
- A runnability check: the chosen file must be executable and answer `--version` within 2 seconds, else treat as missing (catches the wrong-architecture case).
- Add `--version` to `tui/bin/hh_tui.dart` (prints the version and `uname -m`, exits). Today `hh_tui --help` starts the interface and never exits.
- Tests (`check-apps.sh` or a new `check-arch.sh`): a fake `tui/` folder with (a) only the wrong-architecture binary, (b) none, (c) the right one; assert the chosen path, and that `focus` prints text and exits 0 in (a) and (b).

### B. Build and test the Intel binary under Rosetta

1. Download the x64 Dart SDK (same version as the arm64 one, 3.9.2) into a scratch folder.
2. `arch -x86_64 <x64-dart> pub get && arch -x86_64 <x64-dart> compile exe bin/hh_tui.dart -o hh_tui-x86_64`.
3. `file` must say `x86_64`.
4. Run the suites with that binary under Rosetta: `unit`, `check-home`, `check-look`, `check-chooser`, `check-profile` (they take the binary path from `tui/`; add an `HH_TUI_BIN` override so a test can point at either file).
5. Record the result honestly: Rosetta runs Intel instructions on Apple hardware, so it proves the build and the behaviour, but not real Intel timing or quirks.

### C. Packaging

- `tools/make-release.sh`: include both binaries (and no legacy `hh_tui`), still excluding personal files; fail if either is missing or has the wrong `file` architecture.
- `install.sh`: print which binary this machine uses (it does not delete the other: the Homebrew formula drops the unused one, and a checkout keeps both). Remove the "Apple Silicon only" notes.
- Homebrew formula: `libexec.install` everything, then delete the binary that does not match `Hardware::CPU` (replaces the current `rm unless arm?`). `test do` also runs `hh_tui --version` through the wrapper.
- Budget: `check-budget.sh` cap to 18,000 KB; add a note in `POLICY.md` section 6.

### D. Words

- README, `docs/`, `SKILL.md`, the landing page (`brand/landing.html`, republish the artifact) and the LinkedIn post: drop "Apple Silicon only / Intel gets a plain menu"; say "Apple Silicon and Intel".
- `CHANGELOG.md`: 1.0.1 entry (Intel interface, alarm clicks no longer error without it, `hh_tui --version`).
- `VERSION` to 1.0.1.

### E. Release 1.0.1 (by hand, from Rosetta + native builds)

1. Full regression, both binaries.
2. `tools/make-release.sh`, tag `v1.0.1`, GitHub release with tarball and checksum.
3. Update the tap formula (`url`, `sha256`), `brew audit --strict`, install, `brew test`, uninstall, untap, as before.
4. Needs your explicit go-ahead: pushing, tagging, creating the release.

### F. GitHub Actions (automatic native builds)

File: `.github/workflows/release.yml`. Trigger: a pushed tag `v*`, plus `workflow_dispatch` for dry runs.

```
jobs:
  build:            # matrix: one job per architecture, each on a native runner
    runs-on: macos-latest (Apple Silicon)   |   an Intel macOS runner
    steps: checkout; setup-dart (same pinned version as VERSION notes);
           dart pub get; dart analyze; dart run tests/home_model.dart;
           dart compile exe bin/hh_tui.dart -o hh_tui-<arch>;
           ./hh_tui-<arch> --version;           # smoke test on the real chip
           run the shell suites that need no extras: check-apps, check-schedule, check-budget;
           upload-artifact hh_tui-<arch>
  terminal-tests:   # optional, same matrix: pip install pyte, run check-home and check-look
  release:          # needs: [build]; permissions: contents: write
    download both artifacts into tui/; tools/make-release.sh;
    gh release create "$GITHUB_REF_NAME" tarball + sha256;
    update the tap: clone homebrew-tap with a token, rewrite url/version/sha256 in
    Formula/host-hygiene.rb, commit, push.
```

Notes and cautions:

- **Intel runner label.** GitHub has been retiring its older Intel macOS runners; the remaining Intel image at the time of writing is `macos-15-intel`. Check the current label in GitHub's runner list before writing the file, and re-check yearly.
- **Secrets.** The tap push needs a fine-grained personal access token limited to the `homebrew-tap` repo (contents: write), stored as the repository secret `TAP_TOKEN`. Nothing else needs a secret (`GITHUB_TOKEN` covers the release).
- **Supply chain.** Pin each third-party action to a full commit SHA, not a tag.
- **Guard.** The release job runs only for tags pushed by you; a failed build job blocks it. The tap update step is separate so a tap failure does not delete the release.
- **Dry run first.** Run once with `workflow_dispatch` on a branch (build and test only, no release) before the first real tag.
- **First real tag with Actions:** `v1.0.2` (or the next version); 1.0.1 is built by hand in phase E.
- This workflow does what phase E does by hand, so after it works, phase E becomes "push a tag".

## 4. Risks

| Risk | Handling |
|---|---|
| The Intel binary built under Rosetta behaves differently on real Intel | Phase F's native Intel runner runs the same smoke and shell suites; ask any Intel user to try 1.0.1 and report |
| Downloaded binaries carry the macOS quarantine flag and are blocked by Gatekeeper | Homebrew and `curl` downloads are not quarantined; for browser downloads, document `xattr -d com.apple.quarantine` in the README; notarising needs an Apple Developer account and is out of scope |
| Terminal under Rosetta on Apple Silicon reports `x86_64` | The launcher then picks the Intel binary, which runs under Rosetta; fine, just slower |
| The repo and tarball grow by about 8 MB | Cap raised (decision 4); binaries are not committed to git, only attached to releases |
| Runner image or Dart version drift breaks the build | Pin the Dart version; dry-run before each major change |

## 5. Order and checkpoints

1. Phase A, then run the suites. Safe on its own; worth shipping even if the rest slips.
2. Phase B, report what Rosetta showed.
3. Phases C and D, then full regression.
4. **Stop for your approval**, then phase E.
5. Phase F as a separate piece of work after 1.0.1 is out.

## 6. What needs you

- Approval before any push, tag or release (phase E, and the first Actions run).
- Creating the `TAP_TOKEN` secret yourself in the repo settings (I will not handle the token).
- A real Intel Mac, if you can borrow one, for a final check. Optional.
