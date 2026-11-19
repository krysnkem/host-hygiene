# Ruby, PHP and .NET developer

CocoaPods (~/.cocoapods, ~/Library/Caches/CocoaPods) is documented in ios-native.md and is not repeated here.

## Entries

### rbenv-versions
- what: Ruby interpreters built by rbenv, with their installed gems
- catalog-id: rbenv-versions
- paths: ~/.rbenv/versions/*
- size: 273 M for one version 3.2.0 (measured here, 280036 KB)
- class: ask-first
- removal: rbenv uninstall -f <version> (catalog; -f documented by `rbenv uninstall --help` on this host 2026-11-17; apply refuses a pinned version)
- regen: reinstall compiles Ruby, minutes; gems installed into that version are lost and need `bundle install`
- growth: one dir per Ruby version, plus gems installed globally. Suggested: keep versions in .ruby-version files (suggested)
- source: measured on this host 2026-11-17; https://github.com/rbenv/rbenv

### rvm-rubies
- what: Ruby interpreters and gemsets managed by RVM
- catalog-id: none
- paths: ~/.rvm/rubies/*, ~/.rvm/gems/*
- size: not present on this host; (unverified)
- class: ask-first
- removal: rvm remove <version>; rvm gemset delete <name>
- regen: reinstall compiles Ruby; gemsets rebuilt by `bundle install` if a Gemfile exists
- growth: one dir per version and gemset. Suggested: keep pinned versions (suggested)
- source: https://rvm.io/gemsets/deleting fetched 2026-11-17 confirms `rvm gemset delete` (prompts, --force skips) only; `rvm remove`, ~/.rvm/rubies and ~/.rvm/gems are (unverified)

### bundler-gems
- what: gems installed by Bundler, global and per-project (vendor/bundle, .bundle config)
- catalog-id: none
- paths: ~/.bundle; <project>/vendor/bundle; gems in <ruby>/lib/ruby/gems/*/gems; ~/.cache/gem
- size: ~/.bundle 24 M and ~/.cache/gem 22 M (measured here); gems inside the rbenv Ruby are counted in rbenv-versions
- class: safe-regenerable
- removal: bundle clean --force (removes gems not in the Gemfile.lock); gem cleanup for old versions; rm-verified of a git-ignored vendor/bundle
- regen: `bundle install` re-downloads and recompiles native gems; needs network; requires Gemfile.lock to match versions
- growth: old gem versions accumulate. Suggested budget 1 G (suggested)
- source: measured on this host 2026-11-17; https://bundler.io/man/bundle-clean.1.html

### composer-cache
- what: Composer download and VCS cache
- catalog-id: composer-cache
- paths: ~/.composer/cache or ~/.cache/composer (Linux, XDG); see `composer config cache-dir -g`
- size: not present on this host; (unverified)
- class: safe-regenerable
- removal: composer clear-cache
- regen: next install re-downloads; needs network
- growth: one archive per package version. Suggested budget 1 G (suggested)
- source: reported online, https://getcomposer.org/doc/03-cli.md fetched 2026-11-17 (clear-cache / clearcache / cc; cache-dir is $COMPOSER_HOME/cache on macOS with COMPOSER_HOME ~/.composer, $XDG_CACHE_HOME/composer on Linux; --gc runs garbage collection only); absence measured on this host 2026-11-17

### php-vendor
- what: per-project vendor/ of Composer dependencies
- catalog-id: none
- paths: <project>/vendor
- size: (unverified)
- class: ask-first
- removal: rm-verified only if vendor/ is git-ignored; never when committed
- regen: `composer install` recreates it from composer.lock; needs network or composer cache; patched vendor files are lost
- growth: tracks project dependencies. Suggested: none (suggested)
- source: https://getcomposer.org/doc/01-basic-usage.md (not re-fetched; vendor semantics unverified online)

### nuget-packages
- what: NuGet global-packages folder and HTTP/temp caches
- catalog-id: nuget-packages
- paths: ~/.nuget/packages; http-cache ~/.local/share/NuGet/v3-cache and plugins-cache ~/.local/share/NuGet/plugins-cache (macOS/Linux); temp $TMPDIR/NuGetScratch on macOS (/tmp/NuGetScratch<user> on Linux)
- size: not present on this host; commonly 1-5 G (unverified)
- class: safe-regenerable
- removal: dotnet nuget locals all --clear (or one of http-cache, global-packages, temp, plugins-cache instead of all)
- regen: `dotnet restore` re-downloads; needs network
- growth: one folder per package version. Suggested budget 3 G (suggested)
- source: reported online, https://learn.microsoft.com/en-us/nuget/consume-packages/managing-the-global-packages-and-cache-folders fetched 2026-11-17 (paths, overrides NUGET_PACKAGES / NUGET_HTTP_CACHE_PATH / NUGET_SCRATCH, clear commands; the page gives no sizes)

### dotnet-bin-obj
- what: per-project bin/ and obj/ build output
- catalog-id: none
- paths: <project>/bin, <project>/obj
- size: (unverified)
- class: safe-regenerable
- removal: dotnet clean (or rm-verified of bin and obj when git-ignored)
- regen: next `dotnet build` recompiles; obj/project.assets.json is rebuilt by restore
- growth: per configuration and target framework. Suggested budget 500 M per project (suggested)
- source: reported online, https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-clean fetched 2026-11-17 (cleans both obj and bin outputs of the previous build); sizes (unverified)

### dotnet-sdks
- what: installed .NET SDKs, runtimes and workload packs
- catalog-id: none
- paths: /usr/local/share/dotnet/sdk/*, /usr/local/share/dotnet/shared/*; ~/.dotnet for install-script installs
- size: not present on this host; about 300-400 M per SDK (unverified)
- class: ask-first
- removal: Microsoft's dotnet-core-uninstall tool; for ~/.dotnet rm-verified
- regen: reinstall from the Microsoft installer; projects with global.json need that exact SDK
- growth: each update adds an SDK side by side. Suggested: keep latest plus global.json pins (suggested)
- source: reported online, https://learn.microsoft.com/en-us/dotnet/core/install/remove-runtime-sdk-versions fetched 2026-11-17 (macOS /usr/local/share/dotnet/sdk/<ver>, shared/, host/fxr; ~/.dotnet for scripted installs; .NET Uninstall Tool; sizes not stated)

### msbuild-caches
- what: MSBuild and Roslyn server temp and build-server state
- catalog-id: none
- paths: $TMPDIR/.net, $TMPDIR/NuGetScratch, $TMPDIR/VBCSCompiler (unverified)
- size: small (unverified)
- class: safe-regenerable
- removal: dotnet build-server shutdown, then rm-verified
- regen: recreated on next build
- growth: small, bounded. Suggested: ignore (suggested)
- source: (unverified)

## Developer habits
Gems compiled per Ruby version, Rails apps with vendor/bundle, Laravel/Symfony vendor dirs, many .NET solutions each with bin/obj.

## Signals
Gemfile, Gemfile.lock, .ruby-version, composer.json, composer.lock, *.csproj, *.sln, global.json, ~/.rbenv, ~/.nuget.

## Not covered / open questions
Only rbenv and bundler data were measurable here. NuGet and dotnet install-root paths are now sourced. Still unconfirmed: bundler docs (bundler.io bundle-clean pages returned empty, so `bundle clean --force` is from memory), RVM paths and `rvm remove`, the ~/.cache/gem path, the MSBuild/Roslyn temp dirs, and `dotnet build-server shutdown`. The Composer macOS cache location can differ if COMPOSER_HOME or XDG vars are set. Homebrew-installed ruby/php are covered by homebrew-cache in the catalog.
