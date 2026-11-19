# Node / TypeScript developer

Host facts (measured on this host 2026-11-17): node, npm via Homebrew (/opt/homebrew/bin), pnpm at ~/Library/pnpm, bun at ~/.bun, deno via Homebrew; no yarn, nvm, fnm or volta installed.

## Entries

### npm-cache
- what: npm's content-addressed download cache (`_cacache`), shared by every npm project
- catalog-id: npm-cache
- paths: ~/.npm/_cacache
- size: absent here (measured here); typically hundreds of MB to several GB (unverified)
- class: safe-regenerable
- removal: npm cache clean --force
- regen: packages re-download on the next install; offline installs fail until then. Docs call the cache self-healing and say clean is rarely needed: https://docs.npmjs.com/cli/commands/npm-cache
- growth: grows with every package version fetched; npm never evicts by age. Suggested budget 2 G (suggested)
- source: reported online, https://docs.npmjs.com/cli/v11/commands/npm-cache (fetched 2026-11-17: default cache ~/.npm on POSIX, data in `_cacache`); path checked on this host 2026-11-17

### npm-npx-cache
- what: packages that `npx` downloaded to run once, kept under ~/.npm/_npx (one hash dir per package set)
- catalog-id: npm-npx-cache
- paths: ~/.npm/_npx
- size: 511 M (measured here)
- class: safe-regenerable
- removal: `npm cache npx rm` (catalog tool command; the removal is not stated to also run under `npm cache clean --force`)
- regen: the next `npx <pkg>` re-downloads and re-installs it; needs network
- growth: one dir per distinct npx invocation set, never pruned; it is the whole of ~/.npm here. Suggested budget 500 M (suggested)
- source: measured on this host 2026-11-17; reported online, https://docs.npmjs.com/cli/v11/commands/npm-cache (fetched 2026-11-17: `npm cache npx ls|rm` subcommands exist; the page never mentions the _npx dir name, which is confirmed only by the host and a third-party tool description)

### npm-logs
- what: npm debug logs from failed or verbose runs
- catalog-id: none
- paths: ~/.npm/_logs
- size: 44 K (measured here)
- class: safe-regenerable
- removal: rm-verified
- regen: nothing; only old logs lost (npm itself keeps a limited number, logs-max default 10: https://docs.npmjs.com/cli/using-npm/config)
- growth: bounded by npm's own rotation
- source: measured on this host 2026-11-17

### node-modules
- what: per-project `node_modules/` dependency tree
- catalog-id: none
- paths: <project>/node_modules
- size: flashlight-flutter-extension has one (measured here, size not taken); typically 200 M to 1 G per web project (unverified)
- class: safe-regenerable
- removal: rm-verified after git confirms the dir is ignored; then reinstall with the project's package manager
- regen: `npm ci` / `pnpm install` / `yarn install` / `bun install` rebuilds it from the lockfile; fast from a warm cache, needs network when cold. Native addons recompile (node-gyp). Only safe-regenerable when a lockfile is committed; without one, versions may drift, so treat as ask-first
- growth: one per project and per workspace package; the largest per-project consumer for web work. Suggested: purge for projects idle over 60 days (suggested)
- source: measured on this host 2026-11-17 (existence); sizes (unverified)

### pnpm-store
- what: pnpm's global content-addressable store that node_modules hard-links into
- catalog-id: pnpm-store
- paths: ~/Library/pnpm/store on macOS when neither PNPM_HOME nor XDG_DATA_HOME is set ($PNPM_HOME/store or $XDG_DATA_HOME/pnpm/store otherwise); run `pnpm store path` for the exact versioned dir
- size: ~/Library/pnpm total 610 M (measured here, includes pnpm's own files)
- class: ask-first
- removal: pnpm store prune (removes packages no project uses, also the metadata cache and the macOS directory-clone cache; docs: https://pnpm.io/cli/store)
- regen: pruned packages re-download when a project needs them. Hard links mean deleting the store whole does not shrink projects that still link to it, and a full wipe is not needed. Do not run during an install
- growth: grows with each new package version any project installs; prune is the only eviction. Suggested budget 3 G (suggested)
- source: reported online, https://pnpm.io/cli/store and https://pnpm.io/settings/store (fetched 2026-11-17); total measured on this host 2026-11-17

### yarn-cache
- what: yarn download cache (classic global cache; berry global cache when enableGlobalCache)
- catalog-id: none
- paths: classic: run `yarn cache dir` for the exact path (~/Library/Caches/Yarn on macOS is unverified); berry: globalFolder ~/.yarn/berry, global cache on by default (enableGlobalCache true); per-project .yarn/cache if the global cache is disabled or zero-install
- size: not installed here (measured here); typical size (unverified)
- class: safe-regenerable
- removal: yarn cache clean (classic); yarn cache clean --all (berry)
- regen: re-download on next install. Exception: a project using Yarn zero-install commits .yarn/cache to git, so that directory is source, never delete it
- growth: like npm, never evicted by age (unverified)
- source: reported online, https://yarnpkg.com/configuration/yarnrc (berry defaults) and https://classic.yarnpkg.com/en/docs/cli/cache (`yarn cache dir`, `yarn cache clean`), fetched 2026-11-17; classic macOS path and berry `clean --all` flag (unverified)

### bun-cache
- what: bun's global package cache
- catalog-id: bun-cache
- paths: ~/.bun/install/cache (override BUN_INSTALL_CACHE_DIR)
- size: 62 M (measured here); ~/.bun total 123 M including the binary
- class: safe-regenerable
- removal: bun pm cache rm (clears everything, including <cache>/links/ of the global store, so projects using globalStore need `bun install` again; `--dry-run` previews); `bun pm cache prune` removes only packages older than 30 days (`--max-age <days>`)
- regen: re-download on next `bun install`
- growth: grows per package version, no eviction. Suggested budget 1 G (suggested)
- source: reported online, https://bun.sh/docs/install/cache and https://bun.sh/docs/pm/cli/pm (fetched 2026-11-17); size measured on this host 2026-11-17

### node-version-managers
- what: Node versions installed by nvm, fnm or volta
- catalog-id: none
- paths: $NVM_DIR/versions/node/* (NVM_DIR default ~/.nvm; downloads cached in $NVM_DIR/.cache); fnm: ~/Library/Application Support/fnm on macOS when XDG_DATA_HOME is unset (README also mentions ~/.fnm), version subdir layout unverified; volta: ~/.volta (VOLTA_HOME), tools/image/node layout unverified
- size: about 100 to 200 M per version (unverified); none installed here (measured here)
- class: ask-first
- removal: nvm uninstall <version>; fnm uninstall <version> (alias fnm uni; passing an alias removes its target version); volta: `volta uninstall` is documented only for global packages, so no confirmed per-Node-version command (unverified), use rm-verified on the version dir after asking
- regen: re-download that version (~50 M archive, unverified); projects with .nvmrc or engines pinning it break until reinstalled. Never remove the default/current version
- growth: one per Node upgrade or project pin; never auto-pruned
- source: reported online, https://github.com/nvm-sh/nvm#readme , https://github.com/Schniz/fnm/blob/master/docs/commands.md , https://docs.volta.sh/advanced/installers and https://docs.volta.sh/reference/uninstall (fetched 2026-11-17); sizes and volta/fnm layout (unverified); absence measured on this host 2026-11-17

### corepack-cache
- what: package-manager binaries (pnpm, yarn) that corepack downloaded
- catalog-id: corepack-cache
- paths: ~/.cache/node/corepack (COREPACK_HOME overrides)
- size: absent here (measured here); typically tens of MB (unverified)
- class: safe-regenerable
- removal: `corepack cache clean` (documented), or rm-verified
- regen: corepack re-downloads the pinned manager on next use (packageManager field); needs network
- growth: one entry per pinned manager version
- source: reported online, https://github.com/nodejs/corepack#readme (fetched 2026-11-17: COREPACK_HOME default $HOME/.cache/node/corepack on non-Windows; `corepack cache clean` clears it; nodejs.org/api/corepack.html redirects there)

### node-gyp-headers
- what: Node headers downloaded by node-gyp for compiling native addons
- catalog-id: node-gyp-headers
- paths: ~/Library/Caches/node-gyp/<node-version>
- size: 62 M (measured here)
- class: safe-regenerable
- removal: rm-verified
- regen: node-gyp re-downloads headers for that Node version on the next native build; needs network
- growth: one dir per Node version ever built against. Suggested: keep only current (suggested)
- source: measured on this host 2026-11-17; behaviour https://github.com/nodejs/node-gyp#readme

### playwright-browsers
- what: Chromium, Firefox, WebKit and ffmpeg builds that Playwright downloads
- catalog-id: playwright-browsers
- paths: ~/Library/Caches/ms-playwright (PLAYWRIGHT_BROWSERS_PATH overrides)
- size: 1.1 G (measured here)
- class: ask-first
- removal: rm-verified (catalog; `npx playwright uninstall --all` is the documented tool command but npx can download Playwright first, so the catalog does not use it)
- regen: `npx playwright install` re-downloads, hundreds of MB, needs network; tests and the Playwright MCP fail until then. Each Playwright version wants specific revisions, so old dirs pile up
- growth: a new revision set per Playwright upgrade; old ones stay. Suggested budget 1.5 G (suggested)
- source: reported online, https://playwright.dev/docs/browsers (fetched 2026-11-17: macOS ~/Library/Caches/ms-playwright; `npx playwright uninstall` for current install, `--all` for all installations); size measured on this host 2026-11-17

### puppeteer-browsers
- what: Chrome / chrome-headless-shell / Firefox that Puppeteer downloads
- catalog-id: puppeteer-browsers
- paths: ~/.cache/puppeteer (since Puppeteer v19; override via `cacheDirectory` in .puppeteerrc or the browsers CLI --path; PUPPETEER_CACHE_DIR not confirmed by the docs read)
- size: 539 M (measured here)
- class: ask-first
- removal: rm-verified (catalog; `npx @puppeteer/browsers clear` is documented but npx can download code first, so the catalog does not use it)
- regen: next puppeteer install or launch re-downloads; needs network
- growth: one build per Puppeteer upgrade. Suggested budget 1 G (suggested)
- source: reported online, https://pptr.dev/browsers-api and https://pptr.dev/guides/configuration (fetched 2026-11-17); size measured on this host 2026-11-17

### cypress-binary-cache
- what: the Cypress test-runner binary, one dir per version
- catalog-id: cypress-binary-cache
- paths: ~/Library/Caches/Cypress (confirm with `npx cypress cache path`; CYPRESS_CACHE_FOLDER overrides)
- size: absent here (measured here); several hundred MB per version (unverified)
- class: ask-first
- removal: rm-verified (catalog; `npx cypress cache clear` is documented but npx can download code first, so the catalog does not use it)
- regen: `npx cypress install` re-downloads; needs network
- growth: one binary per Cypress version; old versions stay. Docs: https://docs.cypress.io/app/references/troubleshooting
- source: reported online, https://docs.cypress.io/app/references/advanced-installation (fetched 2026-11-17: macOS ~/Library/Caches/Cypress, cache path/list/prune/clear commands)

### electron-download-cache
- what: Electron release zips fetched by @electron/get
- catalog-id: electron-download-cache
- paths: ~/Library/Caches/electron
- size: absent here (measured here); about 100 M per version (unverified)
- class: safe-regenerable
- removal: rm-verified
- regen: re-download on next electron install or electron-builder run; needs network
- growth: one zip per Electron version per platform/arch
- source: reported online, https://github.com/electron/get (fetched 2026-11-17: macOS ~/Library/Caches/electron/)

### typescript-typings-cache
- what: TypeScript's automatic type-acquisition cache used by editors
- catalog-id: none
- paths: ~/Library/Caches/typescript
- size: 11.6 M (measured here)
- class: safe-regenerable
- removal: rm-verified
- regen: the language server re-fetches @types packages when an editor opens a JS/TS project
- growth: small, grows with projects opened
- source: measured on this host 2026-11-17; purpose (unverified)

### js-build-cache-dirs
- what: per-project framework and tool caches: .next, .nuxt, .svelte-kit, .turbo, .nx, .parcel-cache, .vite, .angular, .cache, .eslintcache, jest cache, *.tsbuildinfo
- catalog-id: none
- paths: <project>/.next, .nuxt, .svelte-kit, .turbo, .nx, .parcel-cache, node_modules/.vite, .angular, node_modules/.cache, .eslintcache, **/*.tsbuildinfo; jest cache in the OS temp dir (jest_*)
- size: (unverified)
- class: safe-regenerable
- removal: rm-verified after git confirms each is ignored. Turbo and Nx also have `nx reset`; tsc rebuilds tsbuildinfo
- regen: next build or dev start is a cold build, seconds to minutes; remote caches (Turbo, Nx Cloud) may refill it. Check .gitignore first: a committed tsbuildinfo or .nx file is source
- growth: grows with builds; .next/cache and .turbo are the usual large ones. Suggested budget 1 G per project (suggested)
- source: https://nextjs.org/docs/app/guides/ci-build-caching ; https://nx.dev/reference/core-api/nx/documents/reset ; sizes (unverified)

### js-dist-output
- what: per-project build output: dist/, build/, out/, .output
- catalog-id: none
- paths: <project>/dist, build, out, .output
- size: (unverified)
- class: ask-first
- removal: the project's clean script, else rm-verified after git confirms the dir is ignored
- regen: `npm run build`; ask-first because some repos commit dist (libraries, GitHub Pages) or hold hand-written files in build/
- growth: one copy per build target
- source: (unverified)

## Developer habits
- Many small projects each with a full node_modules, plus npx one-offs that pile up in ~/.npm/_npx (511 M here, the entire ~/.npm).
- Several package managers on one machine (npm, pnpm, bun here), each with its own cache.
- Browser-automation tools (Playwright, Puppeteer, MCP browser servers) each download their own browser, 1.1 G and 539 M here.
- Upgrading Node, Playwright or Electron leaves old versions behind.

## Signals
- package.json, package-lock.json, pnpm-lock.yaml, yarn.lock, bun.lock(b), .nvmrc, .node-version, .tool-versions
- `command -v node npm pnpm yarn bun deno`; ~/.npm, ~/Library/pnpm, ~/.bun, ~/.nvm, ~/.fnm, ~/.volta
- tsconfig.json, next.config.*, vite.config.*, turbo.json, nx.json

## Not covered / open questions
- Sizes for yarn, nvm/fnm/volta, corepack, Cypress, Electron are unverified because they are absent here and no source states one.
- Whether `npm cache clean --force` also clears _npx: npm docs do not say; they do document `npm cache npx rm`. Not tested here (nothing deleted).
- Yarn classic macOS path (use `yarn cache dir`), berry `yarn cache clean --all`, fnm/volta on-disk version layout, and a per-version volta removal command were not confirmed by any official page.
- PUPPETEER_CACHE_DIR env var not confirmed in the docs read (config file `cacheDirectory` is).
- Jest cache location per OS and pnpm's versioned store dir were not checked on this host.
- Global installs (`npm ls -g`, ~/.bun/install/global) not assessed; no entry added because no source was fetched for their location (checked 2026-11-17: only the npm cache page, not the folders docs).
- Turborepo local cache is `.turbo/cache` per project (https://turborepo.dev/docs/crafting-your-repository/caching, fetched 2026-11-17); that page describes no global cache dir and no clean command, so the js-build-cache-dirs entry is unchanged.
