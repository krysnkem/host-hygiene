# Rust developer

## Entries

### cargo-registry
- what: downloaded crate archives and extracted sources shared by all projects
- catalog-id: cargo-registry
- paths: ~/.cargo/registry (cache, src, index)
- size: 463 M (measured here, 474224 KB)
- class: ask-first
- removal: rm-verified (the catalog's removal); `cargo cache -a` needs the third-party cargo-cache tool
- regen: next build re-downloads crates and the index; needs network
- growth: grows with every crate version any project resolves; never pruned (cargo's own gc is recent, unverified). Suggested budget 2 G (suggested)
- source: measured on this host 2026-11-17; reported online, https://doc.rust-lang.org/cargo/guide/cargo-home.html fetched 2026-11-17 (registry index/cache/src; any part may be deleted and cargo restores it; points to third-party cargo-cache; no built-in gc described there)

### cargo-git
- what: git checkouts of git dependencies
- catalog-id: cargo-git
- paths: ~/.cargo/git (db, checkouts)
- size: not present on this host (absent); (unverified) elsewhere
- class: ask-first
- removal: rm-verified
- regen: re-cloned on next build; needs network and the remote must still exist (a deleted repo cannot be rebuilt)
- growth: one clone per git dependency revision. Suggested budget 1 G (suggested)
- source: reported online, https://doc.rust-lang.org/cargo/guide/cargo-home.html fetched 2026-11-17 (git/db bare clones, git/checkouts); absence measured on this host 2026-11-17; K3 note: catalog class is ask-first (like cargo-registry): git dependencies need the network to re-clone; the KB seed said safe-regenerable

### cargo-bin
- what: tools installed with `cargo install` and rustup proxy binaries
- catalog-id: none
- paths: ~/.cargo/bin
- size: 23 M (measured here)
- class: never
- removal: none (use `cargo uninstall <crate>` for a single tool; rustup proxies must stay)
- regen: installed tools need recompiling; rustup proxies deleted break cargo and rustc
- growth: one binary per tool. Suggested: review manually (suggested)
- source: measured on this host 2026-11-17

### rustup-toolchains
- what: installed Rust toolchains (rustc, std, cargo, components)
- catalog-id: rustup-toolchains
- paths: ~/.rustup/toolchains/*
- size: 523 M total in ~/.rustup, one toolchain stable-aarch64-apple-darwin (measured here); extra targets add more (unverified)
- class: ask-first
- removal: rustup toolchain uninstall <name>
- regen: rustup toolchain install re-downloads; needs network. Projects with rust-toolchain.toml need theirs
- growth: nightly and per-date toolchains accumulate. Suggested: keep stable plus pinned (suggested)
- source: measured on this host 2026-11-17; https://rust-lang.github.io/rustup/

### rust-target
- what: per-project target/ build output (debug, release, incremental)
- catalog-id: none
- paths: <project>/target; or $CARGO_TARGET_DIR when set
- size: none found under ~/magic at depth 3 on this host; routinely 1-20 G per project (unverified)
- class: safe-regenerable
- removal: cargo clean (cargo clean -p <crate> for one package)
- regen: full rebuild, minutes to tens of minutes; no network beyond cached crates
- growth: grows each build, debug plus release plus incremental; the biggest Rust consumer. Suggested budget 5 G per project (suggested)
- source: reported online, https://doc.rust-lang.org/cargo/commands/cargo-clean.html fetched 2026-11-17 (removes the target dir; -p cleans one package; --release, --profile, --dry-run; target dir overridable by CARGO_TARGET_DIR); size (unverified)

### sccache
- what: shared compiler cache if sccache is configured as RUSTC_WRAPPER
- catalog-id: none
- paths: ~/Library/Caches/Mozilla.sccache (macOS default); ~/.cache/sccache (Linux)
- size: not present on this host; default cap 10 GB (reported online, https://github.com/mozilla/sccache/blob/main/docs/Local.md)
- class: safe-regenerable
- removal: sccache --stop-server then rm-verified of the directory
- regen: next builds miss the cache and compile in full
- growth: bounded by SCCACHE_CACHE_SIZE (default 10 GB, reported online). Suggested budget 10 G (suggested)
- source: reported online, https://github.com/mozilla/sccache/blob/main/docs/Local.md fetched 2026-11-17 (macOS ~/Library/Caches/Mozilla.sccache, default size 10 GB, SCCACHE_DIR and SCCACHE_CACHE_SIZE) and https://github.com/mozilla/sccache (--stop-server); absence measured on this host 2026-11-17

## Developer habits
Many target/ dirs across projects, nightly toolchains, `cargo install` of CLI tools.

## Signals
Cargo.toml, Cargo.lock, rust-toolchain.toml, ~/.cargo, ~/.rustup, `cargo` on PATH.

## Not covered / open questions
Cargo's built-in cache garbage collection and its version are unverified (the cargo-home and cargo-clean pages fetched on 2026-11-17 mention none). The rustup pages fetched (rust-lang.github.io/rustup basics, overview, concepts) did not state `rustup toolchain uninstall` or the ~/.rustup/toolchains path, so the rustup-toolchains command and path stay as written, unconfirmed online (path is measured here). cargo-cache is third-party and not installed here.
