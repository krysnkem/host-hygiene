# Go developer

## Entries

### go-mod-cache
- what: downloaded module sources shared by every Go project (GOMODCACHE)
- catalog-id: go-mod-cache
- paths: ~/go/pkg/mod (default $GOPATH/pkg/mod); see `go env GOMODCACHE`
- size: not present on this host (no ~/go, go not installed); often 1-10 G on active developers (unverified)
- class: safe-regenerable
- removal: go clean -modcache
- regen: next build re-downloads modules; needs network or GOFLAGS=-mod=vendor / a GOPROXY. Files are read-only, so plain `rm -rf` needs chmod first
- growth: grows with every module version any project resolves. Suggested budget 5 G (suggested)
- source: reported online, https://go.dev/ref/mod fetched 2026-11-17 (GOPATH/pkg/mod default, `go clean -modcache` works with or without -modcacherw, cache dirs are read-only by default); absence measured on this host 2026-11-17

### go-build-cache
- what: compiled package and test-result cache (GOCACHE)
- catalog-id: go-build-cache
- paths: ~/Library/Caches/go-build (macOS); ~/.cache/go-build (Linux); see `go env GOCACHE`
- size: not present on this host; commonly 1-5 G (unverified)
- class: safe-regenerable
- removal: go clean -cache (go clean -testcache for test results only)
- regen: next build recompiles everything, minutes on large repos; no network
- growth: Go trims entries unused for about five days itself (reported online, https://go.googlesource.com/go/+/master/src/cmd/go/internal/cache/default.go and cache.go source, not the official docs); budget 3 G (suggested)
- source: reported online, https://pkg.go.dev/cmd/go fetched 2026-11-17 (default is a go-build dir in the OS user cache dir, `go clean -cache` and `-testcache` confirmed); ~/Library/Caches/go-build on macOS and the five-day trim come from Go source via https://go.googlesource.com/go/+/master/src/cmd/go/internal/cache/default.go

### go-bin
- what: binaries installed by `go install` (gopls, dlv, air, etc.)
- catalog-id: none
- paths: ~/go/bin
- size: tens to hundreds of M (unverified)
- class: ask-first
- removal: rm-verified per binary (no uninstall command exists)
- regen: `go install <pkg>@version` rebuilds; you must remember which tools you had
- growth: one file per tool, updated in place. Suggested: review manually (suggested)
- source: reported online, https://go.dev/ref/mod fetched 2026-11-17 (go install puts binaries in GOBIN, default $GOPATH/bin, i.e. ~/go/bin); size (unverified)

### go-vendor
- what: per-project vendor/ copy of dependencies created by `go mod vendor`
- catalog-id: none
- paths: <project>/vendor
- size: (unverified)
- class: ask-first
- removal: rm-verified only if vendor/ is git-ignored; if it is committed, never delete
- regen: `go mod vendor` recreates it from go.mod/go.sum and the module cache; a committed vendor/ is source and must stay
- growth: tracks dependency size of the project. Suggested: none (suggested)
- source: reported online, https://go.dev/ref/mod fetched 2026-11-17 (`go mod vendor` creates vendor/ and vendor/modules.txt; used automatically for go 1.14+ modules)

### go-toolchains
- what: Go toolchains auto-downloaded by the `toolchain` directive, stored inside the module cache
- catalog-id: none
- paths: ~/go/pkg/mod/golang.org/toolchain@*
- size: about 250 M per toolchain (unverified)
- class: safe-regenerable
- removal: go clean -modcache (removes them with the cache)
- regen: re-downloaded when a go.mod asks for that version
- growth: one per Go version that go.mod files request. Suggested: clear with the module cache (suggested)
- source: https://go.dev/doc/toolchain fetched 2026-11-17 confirms toolchains are downloaded as golang.org/toolchain modules but does not state the storage path or size; path and size remain (unverified)

## Developer habits
Many small services in separate modules; `go install` of dev tools; vendoring in some repos; Docker builds (see docker-data in the catalog).

## Signals
go.mod, go.sum, go.work, `go` on PATH, ~/go, GOPATH/GOMODCACHE env.

## Not covered / open questions
No Go install on this host, so nothing was measured. The Go docs fetched do not state the toolchain storage path (golang.org/toolchain@* inside the module cache) or its size; the five-day build-cache trim is documented only in Go source. `go env` values may be overridden by the user (GOPATH, GOCACHE); always ask `go env`.
