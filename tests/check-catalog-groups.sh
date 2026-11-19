#!/bin/bash
# K3: fake-home checks for the developer-cache catalog rows. bash 3.2. Usage: check-catalog-groups.sh [SCRATCH_DIR]
# Everything is fake: HOMEs under SCRATCH, tools are stubs, env -i with a stripped PATH. Never touches the real home.
# Per group (node, python, rust+go, jvm, mobile, ruby-php-dotnet) + the make-dev-home.sh home:
#   - plan --tsv shows EXACTLY the expected id:class rows, 10 columns, sizes within 5% of du
#   - with stubs off PATH the tool rows say supported=n, with stubs y
#   - apply dry-run says WOULD; without --ask-first-ok ask-first rows are SKIPPED; the approved run frees du-measured bytes
# plus refusals: path outside the catalog, symlink, pinned version, tool pointing at another dir, open files, a project dir.
HERE="$(cd "$(dirname "$0")" && pwd)"; HH="$HERE/../scripts/host-hygiene.sh"
S="${1:-$(mktemp -d /tmp/hh-k3.XXXXXX)}"; mkdir -p "$S"; S="$(cd "$S" && pwd -P)"
PASS=0; FAILN=0
ok() { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAILN=$((FAILN+1)); echo "FAIL $1"; }
chk() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: expected [$3] got [$2]"; fi; }
SAFE=/usr/bin:/bin:/usr/sbin:/sbin
STUBS="$S/stubs"; mkdir -p "$STUBS"
cat > "$STUBS/tool" <<'EOF'
#!/bin/bash
# generic stub for pip3 uv go composer dotnet pnpm bun npm deno corepack pod pyenv rbenv. Honest to the commands it knows, else exit 9.
n="$(basename "$0")"; a="$*"; H="$HOME"; echo "$n $a" >> "${STUB_LOG:-/dev/null}"
empty() { [ -d "$1" ] && find "$1" -mindepth 1 -delete; }
case "$n $a" in
  "pip3 cache dir") echo "${PIP_CACHE_DIR:-$H/Library/Caches/pip}" ;;
  "pip3 cache purge") empty "${PIP_CACHE_DIR:-$H/Library/Caches/pip}" ;;
  "uv cache dir") echo "$H/.cache/uv" ;;  "uv cache clean") empty "$H/.cache/uv" ;;
  "go env GOMODCACHE") echo "$H/go/pkg/mod" ;;  "go env GOCACHE") echo "$H/Library/Caches/go-build" ;;
  "go clean -modcache") rm -rf "$H/go/pkg/mod" ;;  "go clean -cache") empty "$H/Library/Caches/go-build" ;;
  "composer config cache-dir -g") echo "$H/.composer/cache" ;;  "composer clear-cache") empty "$H/.composer/cache" ;;
  "dotnet nuget locals global-packages --list") [ -n "$DOTNET_NOLOGO" ] || printf '\nWelcome to .NET 8.0!\r\nSDK Version: 8.0.412\r\n'   # real first-run banner (measured): colons that are not the answer
    echo "global-packages: $H/.nuget/packages/" ;;
  "dotnet nuget locals global-packages --clear") empty "$H/.nuget/packages" ;;
  "pnpm store path") echo "$H/Library/pnpm/store/v3" ;;  "pnpm store prune") empty "$H/Library/pnpm/store/v3" ;;
  "bun pm cache"|"bun pm cache rm") [ -f package.json ] || { echo 'error: No package.json was found for directory "'"$PWD"'"' >&2; exit 1; }   # real bun (measured)
    if [ "$a" = "pm cache" ]; then printf '%s' "$H/.bun/install/cache"; else empty "$H/.bun/install/cache"; fi ;;
  "npm cache clean --force") empty "$H/.npm/_cacache" ;;
  "npm config get cache") echo "$H/.npm" ;;  "npm cache npx rm") rm -rf "$H/.npm/_npx" ;;
  "deno info") if [ -n "$NO_COLOR" ]; then echo "DENO_DIR location: $H/Library/Caches/deno"; else printf '\033[0m\033[1mDENO_DIR location:\033[0m %s\n' "$H/Library/Caches/deno"; fi ;;   # real deno colours even into a pipe (measured)  "deno clean") empty "$H/Library/Caches/deno" ;;
  "deno clean") empty "$H/Library/Caches/deno" ;;
  "corepack cache clean") empty "$H/.cache/node/corepack" ;;
  "pod cache clean --all") empty "$H/Library/Caches/CocoaPods" ;;
  "pyenv uninstall -f "*) rm -rf "$H/.pyenv/versions/${a#uninstall -f }" ;;
  "rbenv uninstall -f "*) rm -rf "$H/.rbenv/versions/${a#uninstall -f }" ;;
  *) echo "stub: unexpected: $n $a" >&2; exit 9 ;;
esac
EOF
chmod +x "$STUBS/tool"
for t in pip3 uv go composer dotnet pnpm bun npm deno corepack pod pyenv rbenv; do ln -sf tool "$STUBS/$t"; done

mkf() { mkdir -p "$(dirname "$1")"; mkfile "$2" "$1"; }
proj() { # HOME NAME manifest-file [pin-file pin-value]   a git project, so the profile is developer
  local p="$1/work/$2"; mkdir -p "$p"; echo x > "$p/$3"; [ -n "${4:-}" ] && echo "$5" > "$p/$4"; ( cd "$p" && git init -q ); }
: > "$S/ps.empty"
run() { local H="$1" p="$2"; shift 2; env -i HOME="$H" PATH="$p" ${TFD:+"TF_PLUGIN_CACHE_DIR=$TFD"} HH_DC_PS_FILE="${PSF:-$S/ps.empty}" HH_NO_PROMPT=1 HH_APPS_DIR=/nonexistent "$HH" "$@" 2>&1; }

# group NAME  "expected id:class ..."   (the HOME must already be built in $S/NAME)
verify_plan() {
  local name="$1" H="$S/$1" want="$2" out got cols bads=0 id sz path du lo hi
  out="$(run "$H" "$STUBS:$SAFE" plan --tsv --min-mb 1)"
  got="$(printf '%s\n' "$out" | awk -F'\t' '!/^#/ && NF{print $5":"$3}' | sort | tr '\n' ' ')"
  want="$(printf '%s\n' $want | sort | tr '\n' ' ')"
  chk "$name: exact rows and classes" "$got" "$want"
  cols="$(printf '%s\n' "$out" | awk -F'\t' '!/^#/ && NF{print NF}' | sort -u | tr '\n' ' ')"
  chk "$name: plan --tsv has 10 columns" "$cols" "10 "
  # sizes within 5% of du (rows are the scan's own du, so this also guards against a different path being measured)
  printf '%s\n' "$out" | awk -F'\t' '!/^#/ && NF{print $5"\t"$2"\t"$6}' | while IFS="$(printf '\t')" read -r id sz path; do
    du="$(du -sk "$path" | cut -f1)"; lo=$((du*95/100)); hi=$((du*105/100+8))
    [ "$sz" -ge "$lo" ] && [ "$sz" -le "$hi" ] || echo "SIZE-MISMATCH $id $sz vs du $du"
  done > "$S/$name.sizes"
  chk "$name: sizes within 5% of du" "$(cat "$S/$name.sizes")" ""
  # supported column: tool rows need their tool; with no stubs on PATH they must say n
  local tool_rows_y tool_rows_n
  tool_rows_y="$(printf '%s\n' "$out" | awk -F'\t' '!/^#/ && $7 !~ /^rm -rf/ && $8=="y"' | wc -l | tr -d ' ')"
  out="$(run "$H" "$SAFE" plan --tsv --min-mb 1)"
  tool_rows_n="$(printf '%s\n' "$out" | awk -F'\t' '!/^#/ && $5 ~ /^(uv-cache|go-|composer-|nuget-|pnpm-|bun-|npm-npx|deno-|corepack-|cocoapods-|pyenv-|rbenv-)/ && $8=="y"' | wc -l | tr -d ' ')"
  chk "$name: tool rows supported=n when their tool is absent" "$tool_rows_n" "0"
  [ "$tool_rows_y" -ge 0 ] && ok "$name: supported=y with stubs counted ($tool_rows_y)"
}

# ---------------- build the homes ----------------
H="$S/node"; rm -rf "$H"; proj "$H" web package.json
mkf "$H/.npm/_npx/a/x" 6m; mkf "$H/.npm/_cacache/c" 5m; mkf "$H/Library/pnpm/store/v3/f" 8m; mkf "$H/.bun/install/cache/p" 5m
mkf "$H/.cache/node/corepack/c" 3m; mkf "$H/Library/Caches/node-gyp/18/h" 4m; mkf "$H/Library/Caches/ms-playwright/chromium-1/b" 12m
mkf "$H/.cache/puppeteer/chrome/b" 9m; mkf "$H/Library/Caches/Cypress/13/b" 7m; mkf "$H/Library/Caches/electron/e" 6m; mkf "$H/Library/Caches/deno/d" 5m
NODE_WANT="npm-npx-cache:safe-regenerable npm-cache:safe-regenerable pnpm-store:ask-first bun-cache:safe-regenerable corepack-cache:safe-regenerable node-gyp-headers:safe-regenerable playwright-browsers:ask-first puppeteer-browsers:ask-first cypress-binary-cache:ask-first electron-download-cache:safe-regenerable deno-cache:safe-regenerable"
H="$S/python"; rm -rf "$H"; proj "$H" api requirements.txt .python-version 3.12.1
mkf "$H/Library/Caches/pip/w" 7m; mkf "$H/.cache/uv/u" 6m; mkf "$H/.pyenv/versions/3.11.4/b" 10m; mkf "$H/.pyenv/versions/3.12.1/b" 9m
PY_WANT="pip-cache:safe-regenerable uv-cache:safe-regenerable pyenv-versions:ask-first pyenv-versions:ask-first"
H="$S/rustgo"; rm -rf "$H"; proj "$H" svc Cargo.toml; echo "module x" > "$H/work/svc/go.mod"
mkf "$H/.cargo/registry/r" 8m; mkf "$H/.cargo/git/g" 5m; mkf "$H/go/pkg/mod/m" 9m; mkf "$H/Library/Caches/go-build/b" 6m
RG_WANT="cargo-registry:ask-first cargo-git:ask-first go-mod-cache:safe-regenerable go-build-cache:safe-regenerable"
H="$S/jvm"; rm -rf "$H"; proj "$H" app build.gradle; mkdir -p "$H/work/app/gradle/wrapper"
echo 'distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip' > "$H/work/app/gradle/wrapper/gradle-wrapper.properties"
mkf "$H/.gradle/caches/modules-2/m" 6m; mkf "$H/.gradle/caches/transforms-3/t" 5m; mkf "$H/.gradle/caches/7.0/x" 4m; mkf "$H/.gradle/caches/8.5/x" 3m
mkf "$H/.gradle/wrapper/dists/gradle-7.0-bin/h/z" 4m; mkf "$H/.m2/repository/r" 4m
mkf "$H/Library/Caches/JetBrains/IdeaIC2024.1/c" 8m; mkf "$H/.konan/dependencies/d" 7m; mkf "$H/.konan/kotlin-native-prebuilt-x/keep" 3m
JVM_WANT="gradle-modules:ask-first gradle-transforms:ask-first gradle-unused:ask-first gradle-unused:ask-first maven-repo:ask-first intellij-caches:ask-first kotlin-native-konan:ask-first"
H="$S/mobile"; rm -rf "$H"; proj "$H" app pubspec.yaml
mkf "$H/.pub-cache/p" 5m; mkf "$H/Library/Caches/CocoaPods/c" 6m; mkf "$H/Library/Developer/Xcode/DerivedData/R-abc/x" 5m
mkf "$H/.gradle/caches/transforms-3/t" 4m; mkf "$H/.gradle/caches/modules-2/m" 4m
MOB_WANT="pub-cache:ask-first cocoapods-cache:safe-regenerable xcode-derived:safe-regenerable gradle-transforms:ask-first gradle-modules:ask-first"
H="$S/rpd"; rm -rf "$H"; proj "$H" app Gemfile; echo '{}' > "$H/work/app/composer.json"; echo 3.2.0 > "$H/work/app/.ruby-version"
mkf "$H/.rbenv/versions/3.2.0/r" 7m; mkf "$H/.rbenv/versions/3.1.0/r" 6m; mkf "$H/.composer/cache/c" 5m; mkf "$H/.nuget/packages/p" 4m
RPD_WANT="rbenv-versions:ask-first rbenv-versions:ask-first composer-cache:safe-regenerable nuget-packages:safe-regenerable"
bash "$HERE/make-dev-home.sh" "$S/dev" >/dev/null
DEV_WANT="gradle-modules:ask-first gradle-unused:ask-first gradle-unused:ask-first pub-cache:ask-first xcode-derived:safe-regenerable xcode-archives:ask-first android-ndk:ask-first android-avd:ask-first app-caches:ask-first downloads:never project:build project:.dart_tool project:node_modules project:build project:android/.gradle"
# ---------------- plan checks ----------------
verify_plan node "$NODE_WANT"; verify_plan python "$PY_WANT"; verify_plan rustgo "$RG_WANT"; verify_plan jvm "$JVM_WANT"
verify_plan mobile "$MOB_WANT"; verify_plan rpd "$RPD_WANT"
# the developer home: only the rows it really has (compare against the ids present, no new-catalog ids may appear)
out="$(run "$S/dev" "$SAFE" plan --tsv --min-mb 1)"
newids="$(printf '%s\n' "$out" | awk -F'\t' '!/^#/ && $5 ~ /^(npm-npx|pnpm|bun|corepack|node-gyp|playwright|puppeteer|cypress|electron|deno|pip|uv|pyenv|go-|cargo-git|gradle-transforms|intellij|kotlin|rbenv|composer|nuget|cocoapods)/{print $5}' | tr '\n' ' ')"
chk "dev home: no row of a tool it does not have" "$newids" ""
chk "dev home: plan --tsv 10 columns" "$(printf '%s\n' "$out" | awk -F'\t' '!/^#/ && NF{print NF}' | sort -u | tr '\n' ' ')" "10 "
# ---------------- apply: dry-run, ask-first gate, approved run ----------------
targets() { local H="$1"; shift; local a=""; for id in "$@"; do a="$a --target $(run "$H" "$STUBS:$SAFE" plan --tsv --min-mb 1 | awk -F'\t' -v i="$id" '$5==i{print $6}' | head -1)"; done; printf '%s' "$a"; }
approved() { # NAME ids... : dry-run, gate, then approved run; each target must shrink, freed reported by du
  local name="$1" H="$S/$1" id t o before after n=0; shift
  for id in "$@"; do
    t="$(run "$H" "$STUBS:$SAFE" plan --tsv --min-mb 1 | awk -F'\t' -v i="$id" '$5==i{print $6}' | head -1)"
    [ -n "$t" ] || { bad "$name/$id: no row"; continue; }
    o="$(run "$H" "$STUBS:$SAFE" apply --ask-first-ok --target "$t")"
    case "$o" in *"WOULD"*) ok "$name/$id: dry-run WOULD" ;; *) bad "$name/$id: dry-run: $o" ;; esac
    before="$(du -sk "$t" | cut -f1)"
    cls="$(run "$H" "$STUBS:$SAFE" plan --tsv --min-mb 1 | awk -F'\t' -v i="$id" '$5==i{print $3}' | head -1)"
    if [ "$cls" = ask-first ]; then
      o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --target "$t")"
      case "$o" in *SKIPPED*ask-first*) ok "$name/$id: ask-first skipped without --ask-first-ok" ;; *) bad "$name/$id: gate: $o" ;; esac
      [ "$(du -sk "$t" 2>/dev/null | cut -f1)" = "$before" ] && ok "$name/$id: untouched after the skip" || bad "$name/$id: changed without approval"
    fi
    o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$t")"
    after="$(du -sk "$t" 2>/dev/null | cut -f1)"; after="${after:-0}"
    case "$o" in *" done "*"freed "*"measured by du"*) ok "$name/$id: done, freed reported" ;; *) bad "$name/$id: run: $o" ;; esac
    [ "$after" -lt "$before" ] && ok "$name/$id: shrank ($before KB -> $after KB)" || bad "$name/$id: did not shrink"
  done
}
approved node npm-npx-cache npm-cache pnpm-store bun-cache corepack-cache node-gyp-headers playwright-browsers cypress-binary-cache electron-download-cache deno-cache
approved rustgo cargo-git go-mod-cache go-build-cache
approved jvm gradle-transforms intellij-caches kotlin-native-konan
approved mobile cocoapods-cache gradle-transforms
approved rpd composer-cache nuget-packages
chk "jvm: konan sibling dir not under the row is untouched" "$([ -e "$S/jvm/.konan/kotlin-native-prebuilt-x/keep" ] && echo kept)" kept
chk "jvm: the project's files untouched" "$([ -e "$S/jvm/work/app/build.gradle" ] && echo kept)" kept
# ---------------- refusals ----------------
H="$S/python"
t="$H/.pyenv/versions/3.12.1"
o="$(run "$H" "$STUBS:$SAFE" apply --target "$t" --ask-first-ok)"; case "$o" in *REFUSED*pinned*) ok "pyenv: pinned version REFUSED" ;; *) bad "pyenv pinned: $o" ;; esac
o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$t")"; [ -d "$t" ] && ok "pyenv: pinned version intact after --run" || bad "pyenv pinned removed"
approved python pip-cache uv-cache
t="$H/.pyenv/versions/3.11.4"; o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$t")"
case "$o" in *" done "*) [ ! -e "$t" ] && ok "pyenv: unpinned version removed via pyenv, gone" || bad "pyenv: still there" ;; *) bad "pyenv unpinned: $o" ;; esac
H="$S/rpd"; t="$H/.rbenv/versions/3.2.0"; o="$(run "$H" "$STUBS:$SAFE" apply --target "$t" --ask-first-ok)"; case "$o" in *REFUSED*pinned*) ok "rbenv: pinned version REFUSED" ;; *) bad "rbenv pinned: $o" ;; esac
t="$H/.rbenv/versions/3.1.0"; o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$t")"
case "$o" in *" done "*) [ ! -e "$t" ] && ok "rbenv: unpinned version removed" || bad "rbenv: still there" ;; *) bad "rbenv unpinned: $o" ;; esac
# outside the catalog, parent dirs of a row, relative path, symlink
H="$S/node"
for t in "$H/work/web/package.json" "$H/.pyenv" "$H/.npm" "$H/Library/pnpm" "$H/Library"; do
  o="$(run "$H" "$STUBS:$SAFE" apply --target "$t")"; case "$o" in *REFUSED*) ok "outside catalog REFUSED: ${t#$H}" ;; *WOULD*) bad "outside catalog accepted: $t" ;; *) ok "outside catalog not accepted: ${t#$H}" ;; esac
done
o="$(run "$H" "$STUBS:$SAFE" apply --target "relative/path")"; case "$o" in *"not absolute"*) ok "relative path REFUSED" ;; *) bad "relative: $o" ;; esac
mkdir -p "$S/elsewhere/real"; echo x > "$S/elsewhere/real/f"; mkdir -p "$H/.cache"; ln -sfn "$S/elsewhere/real" "$H/.cache/puppeteer-link"
rm -rf "$H/.cache/puppeteer"; ln -s "$S/elsewhere/real" "$H/.cache/puppeteer"
o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$H/.cache/puppeteer")"
case "$o" in *REFUSED*symlink*) ok "symlinked cache dir REFUSED" ;; *) bad "symlink: $o" ;; esac; [ -e "$S/elsewhere/real/f" ] && ok "symlink target untouched" || bad "symlink target removed"
# the tool would clear another directory (env override) -> refused, nothing cleared
H="$S/python"; mkf "$H/Library/Caches/pip/w2" 3m; mkdir -p "$S/other-pip"; echo x > "$S/other-pip/f"
o="$(env -i HOME="$H" PATH="$STUBS:$SAFE" PIP_CACHE_DIR="$S/other-pip" HH_NO_PROMPT=1 "$HH" apply --run --yes --log "$S/apply.log" --target "$H/Library/Caches/pip" 2>&1)"
case "$o" in *REFUSED*"would clear"*) ok "tool pointing at another dir REFUSED" ;; *) bad "env override: $o" ;; esac
[ -e "$S/other-pip/f" ] && [ -e "$H/Library/Caches/pip/w2" ] && ok "neither directory touched" || bad "something was cleared"
# tool missing -> refused (not a crash)
o="$(run "$H" "$SAFE" apply --run --yes --log "$S/apply.log" --target "$H/.cache/uv")"; case "$o" in *REFUSED*"uv not found"*) ok "missing tool REFUSED" ;; *) bad "missing tool: $o" ;; esac
# open files: a process holding a file in an rm-verified cache -> SKIPPED, dir intact
H="$S/node"; rm -f "$H/.cache/puppeteer"; mkf "$H/.cache/puppeteer/chrome/open.bin" 2m
( exec 3< "$H/.cache/puppeteer/chrome/open.bin"; sleep 30 ) & TP=$!; sleep 1
o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$H/.cache/puppeteer")"; pkill -P $TP 2>/dev/null; kill $TP 2>/dev/null; wait $TP 2>/dev/null
case "$o" in *"SKIPPED"*"files open"*) ok "open files SKIPPED" ;; *) bad "open files: $o" ;; esac; [ -e "$H/.cache/puppeteer/chrome/open.bin" ] && ok "open-file dir intact" || bad "open-file dir removed"
# running-process guards (ps fixtures): a Gradle daemon blocks transforms, an IDE blocks JetBrains caches, a process inside the dir blocks any rm row
mkf "$S/jvm/.gradle/caches/transforms-3/t" 2m; mkf "$S/jvm/Library/Caches/JetBrains/IdeaIC2024.1/c" 2m
echo "/usr/bin/java -cp x org.gradle.launcher.daemon.bootstrap.GradleDaemon 8.5" > "$S/ps.gradle"
echo "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea" > "$S/ps.idea"
echo "$S/jvm/.konan/dependencies/bin/clang -c x.c" > "$S/ps.inside"; mkf "$S/jvm/.konan/dependencies/d2" 2m
o="$(PSF="$S/ps.gradle" run "$S/jvm" "$STUBS:$SAFE" apply --ask-first-ok --target "$S/jvm/.gradle/caches/transforms-3")"; case "$o" in *REFUSED*"Gradle daemon"*) ok "running Gradle daemon blocks transforms" ;; *) bad "gradle guard: $o" ;; esac
o="$(PSF="$S/ps.idea" run "$S/jvm" "$STUBS:$SAFE" apply --ask-first-ok --target "$S/jvm/Library/Caches/JetBrains/IdeaIC2024.1")"; case "$o" in *REFUSED*"IDE is running"*) ok "running IDE blocks JetBrains caches" ;; *) bad "ide guard: $o" ;; esac
# overlap: the GENERIC app-caches / dot-cache rows reach the same directories, so they need the same guards
o="$(PSF="$S/ps.idea" run "$S/jvm" "$STUBS:$SAFE" apply --ask-first-ok --target "$S/jvm/Library/Caches/JetBrains")"; case "$o" in *REFUSED*"IDE is running"*) ok "running IDE blocks the generic JetBrains parent (app-caches row)" ;; *) bad "ide guard via app-caches: $o" ;; esac
o="$(PSF="$S/ps.idea" run "$S/jvm" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$S/jvm/Library/Caches/JetBrains")"; [ -e "$S/jvm/Library/Caches/JetBrains/IdeaIC2024.1/c" ] && ok "JetBrains parent intact after refused --run" || bad "JetBrains parent removed while IDE running"
mkf "$S/jvm/.cache/node/corepack/c" 2m; echo "$S/jvm/.cache/node/corepack/bin/node x.js" > "$S/ps.inside2"
o="$(PSF="$S/ps.inside2" run "$S/jvm" "$STUBS:$SAFE" apply --ask-first-ok --target "$S/jvm/.cache/node")"; case "$o" in *REFUSED*"running process"*) ok "process inside a child blocks the generic dot-cache parent" ;; *) bad "dot-cache parent guard: $o" ;; esac
o="$(PSF="$S/ps.empty" run "$S/jvm" "$STUBS:$SAFE" apply --ask-first-ok --target "$S/jvm/Library/Caches/JetBrains")"; case "$o" in *WOULD*) ok "generic JetBrains parent allowed when no IDE runs" ;; *) bad "parent without IDE: $o" ;; esac
o="$(PSF="$S/ps.inside" run "$S/jvm" "$STUBS:$SAFE" apply --ask-first-ok --target "$S/jvm/.konan/dependencies")"; case "$o" in *REFUSED*"running process"*) ok "process running inside the dir blocks the rm" ;; *) bad "inside guard: $o" ;; esac
# non-developer home: caches of developer tools may exist but no developer row is listed (needs != any rows are skipped)
H="$S/nondev"; rm -rf "$H"; mkdir -p "$H"; mkf "$H/Library/Caches/pip/w" 6m; mkf "$H/.npm/_npx/x" 6m; mkf "$H/Documents/d" 5m; mkf "$H/Library/Caches/com.some.App/c" 6m
o="$(run "$H" "$STUBS:$SAFE" plan --tsv --min-mb 1)"; chk "non-developer home: only generic rows" "$(printf '%s\n' "$o" | awk -F'\t' '!/^#/&&NF{print $5}' | sort | tr '\n' ' ')" "app-caches app-caches "
# a project dir that git does not ignore is still refused (existing rule unchanged)
H="$S/dev"; mkdir -p "$H/work/web/build"; o="$(run "$H" "$STUBS:$SAFE" apply --target "$H/work/web/build")"; case "$o" in *REFUSED*"NOT git-ignored"*) ok "non-ignored project dir REFUSED" ;; *) bad "project dir: $o" ;; esac
# ================= K3b: data/ml, devops, game =================
# data/ml
H="$S/ml"; rm -rf "$H"; proj "$H" nb requirements.txt
mkf "$H/.cache/huggingface/hub/models--a--b/blobs/w" 12m; mkf "$H/.cache/huggingface/xet/s" 6m; mkf "$H/.cache/huggingface/token" 1m
mkf "$H/.cache/torch/hub/checkpoints/m.pth" 5m; mkf "$H/.cache/wandb/a" 4m; mkf "$H/.ollama/models/blobs/b" 8m; mkf "$H/.lmstudio/models/p/m" 7m
mkf "$H/.cache/kagglehub/d" 5m; mkf "$H/work/nb/.ipynb_checkpoints/a-checkpoint.ipynb" 3m; mkf "$H/work/nb/a.ipynb" 1m
mkf "$H/work/nb/mlruns/0/r" 3m; mkf "$H/work/nb/.dvc/cache/c" 3m; mkf "$H/work/nb/wandb/run-1/f" 3m
ML_WANT="hf-hub-cache:ask-first hf-xet-cache:safe-regenerable torch-hub-cache:ask-first wandb-cache:safe-regenerable ollama-models:ask-first lmstudio-models:ask-first kaggle-cache:ask-first jupyter-checkpoints:ask-first"
verify_plan ml "$ML_WANT"
# devops (TF_PLUGIN_CACHE_DIR set for the plan)
H="$S/devops"; rm -rf "$H"; proj "$H" iac main.tf; echo ".terraform/" > "$H/work/iac/.gitignore"; mkf "$H/work/iac/.terraform/providers/p" 5m; echo s > "$H/work/iac/terraform.tfstate"
proj "$H" iac2 main.tf; mkf "$H/work/iac2/.terraform/providers/p" 5m   # NOT git-ignored: no row
mkf "$H/.kube/cache/discovery/d" 4m; echo cfg > "$H/.kube/config"; mkf "$H/Library/Caches/helm/repository/r" 4m
mkf "$H/.vagrant.d/boxes/ubuntu-VAGRANTSLASH-focal64/0/b" 9m; mkf "$H/VirtualBox VMs/vm1/disk.vdi" 6m
mkf "$H/.terraform.d/plugin-cache/registry.terraform.io/hashicorp/aws/5.0.0/darwin_arm64/p" 6m
DO_WANT="kube-cache:safe-regenerable helm-cache:safe-regenerable vagrant-boxes:ask-first terraform-plugin-cache:safe-regenerable terraform-project-dirs:safe-regenerable"
TFD="$H/.terraform.d/plugin-cache" verify_plan devops "$DO_WANT"
o="$(run "$H" "$SAFE" plan --tsv --min-mb 1)"; chk "devops: without TF_PLUGIN_CACHE_DIR no terraform-plugin-cache row" "$(printf '%s\n' "$o" | awk -F'\t' '$5=="terraform-plugin-cache"' | wc -l | tr -d ' ')" "0"
# game
H="$S/game"; rm -rf "$H"; mkdir -p "$H"
mkdir -p "$H/work/ugame/ProjectSettings" "$H/work/ugame/Assets"; echo "m_EditorVersion: 2022.3.1f1" > "$H/work/ugame/ProjectSettings/ProjectVersion.txt"; ( cd "$H/work/ugame" && git init -q )
mkf "$H/work/ugame/Library/x" 8m; mkf "$H/work/ugame/Temp/t" 4m; mkf "$H/work/ugame/Logs/l" 3m; mkf "$H/work/ugame/obj/o" 3m; mkf "$H/work/ugame/Assets/keep.asset" 3m
mkdir -p "$H/work/gd"; echo "config_version=5" > "$H/work/gd/project.godot"; mkf "$H/work/gd/.godot/c" 6m
mkdir -p "$H/work/ue"; echo '{}' > "$H/work/ue/G.uproject"; mkf "$H/work/ue/Intermediate/i" 7m; mkf "$H/work/ue/Binaries/b" 5m; mkf "$H/work/ue/Saved/s" 5m; mkf "$H/work/ue/Content/c" 5m
mkf "$H/Library/Caches/Unity/upm/p" 6m; mkf "$H/Library/Caches/Godot/c" 5m; mkf "$H/Library/Unity/Asset Store-5.x/a" 5m; mkf "$H/Library/Application Support/Godot/templates/t" 5m
mkdir -p "$H/work/plain/Library"; mkf "$H/work/plain/Library/x" 3m; ( cd "$H/work/plain" && git init -q )   # a Library dir with no Unity marker
GM_WANT="unity-upm-global-cache:safe-regenerable godot-cache-dir:safe-regenerable unity-library:ask-first unity-temp:ask-first godot-project-cache:ask-first unreal-intermediate:ask-first"
verify_plan game "$GM_WANT"
# classes, notes and supported column of the report-only rows (plan --tsv col 8 = supported, col 9 = note, col 7 = by-hand text)
H="$S/ml"; o="$(run "$H" "$STUBS:$SAFE" plan --tsv --min-mb 1)"
for id in ollama-models lmstudio-models kaggle-cache; do
  r="$(printf '%s\n' "$o" | awk -F'\t' -v i="$id" '$5==i')"
  chk "ml/$id: report-only, supported=n, explicit note" "$(printf '%s' "$r" | awk -F'\t' '{print ($7 ~ /^report-only: / && $8=="n" && $9 ~ /^REPORT-ONLY/) ? "ok" : "no:" $7 ":" $8}')" ok
done
chk "ml/hf-hub-cache: ask-first with a cost note naming every cached model" "$(printf '%s\n' "$o" | awk -F'\t' '$5=="hf-hub-cache"{print ($3=="ask-first" && $9 ~ /EVERY cached model/ && $8=="y") ? "ok" : "no"}')" ok
chk "ml: ~/.cache/huggingface/token is not offered" "$(printf '%s\n' "$o" | awk -F'\t' '$6 ~ /huggingface\/token/' | wc -l | tr -d ' ')" "0"
H="$S/devops"; o="$(TFD="$H/.terraform.d/plugin-cache" run "$H" "$SAFE" plan --tsv --min-mb 1)"
r="$(printf '%s\n' "$o" | awk -F'\t' '$5=="vagrant-boxes"')"
chk "devops/vagrant-boxes: report-only, supported=n, explicit note" "$(printf '%s' "$r" | awk -F'\t' '{print ($7 ~ /^report-only: vagrant box/ && $8=="n" && $9 ~ /^REPORT-ONLY/) ? "ok" : "no"}')" ok
chk "devops: the non-ignored .terraform and VirtualBox VMs have no row" "$(printf '%s\n' "$o" | awk -F'\t' '$6 ~ /iac2|VirtualBox/' | wc -l | tr -d ' ')" "0"
# apply: dry-run, ask-first gate, approved run, du-measured freed
approved ml hf-hub-cache hf-xet-cache torch-hub-cache wandb-cache jupyter-checkpoints
chk "ml: the notebook itself and mlruns/.dvc/wandb survive" "$([ -e "$S/ml/work/nb/a.ipynb" ] && [ -e "$S/ml/work/nb/mlruns/0/r" ] && [ -e "$S/ml/work/nb/.dvc/cache/c" ] && [ -e "$S/ml/work/nb/wandb/run-1/f" ] && [ -e "$S/ml/.cache/huggingface/token" ] && echo kept)" kept
TFD="$S/devops/.terraform.d/plugin-cache" approved devops kube-cache helm-cache terraform-plugin-cache terraform-project-dirs
chk "devops: kubeconfig, tfstate and non-ignored .terraform survive" "$([ -e "$S/devops/.kube/config" ] && [ -e "$S/devops/work/iac/terraform.tfstate" ] && [ -e "$S/devops/work/iac2/.terraform/providers/p" ] && echo kept)" kept
approved game unity-upm-global-cache godot-cache-dir unity-library unity-temp godot-project-cache unreal-intermediate
chk "game: Assets, Logs, Binaries, Saved, Content and the other caches survive" "$([ -e "$S/game/work/ugame/Assets/keep.asset" ] && [ -e "$S/game/work/ugame/Logs/l" ] && [ -e "$S/game/work/ue/Binaries/b" ] && [ -e "$S/game/work/ue/Saved/s" ] && [ -e "$S/game/work/ue/Content/c" ] && [ -e "$S/game/Library/Unity/Asset Store-5.x/a" ] && echo kept)" kept
# refusals: report-only rows (dry-run and --run, with --ask-first-ok), data intact
for pair in ml:.ollama/models ml:.lmstudio/models ml:.cache/kagglehub devops:.vagrant.d/boxes; do
  H="$S/${pair%%:*}"; t="$H/${pair#*:}"
  o="$(run "$H" "$STUBS:$SAFE" apply --ask-first-ok --target "$t")"; case "$o" in *REFUSED*"report-only"*) ok "report-only dry-run REFUSED: ${pair#*:}" ;; *) bad "report-only dry-run ${pair#*:}: $o" ;; esac
  o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$t")"; case "$o" in *REFUSED*"report-only"*) ok "report-only --run REFUSED: ${pair#*:}" ;; *) bad "report-only --run ${pair#*:}: $o" ;; esac
  [ -d "$t" ] && ok "report-only dir intact: ${pair#*:}" || bad "report-only dir removed: ${pair#*:}"
done
# refusals: outside the catalog or marker rules
H="$S/game"; mkf "$H/work/ugame/Library/x" 2m; mkf "$H/work/ue/Saved/s" 1m; mkf "$H/work/ue/Binaries/b" 1m
for t in "$H/work/ugame/Logs" "$H/work/ugame/obj" "$H/work/ugame/Assets" "$H/work/ue/Saved" "$H/work/ue/Binaries" "$H/work/ue/Content" "$H/work/plain/Library" "$H/Library/Unity/Asset Store-5.x" "$H/Library/Application Support/Godot/templates"; do
  o="$(run "$H" "$STUBS:$SAFE" apply --ask-first-ok --target "$t")"; case "$o" in *REFUSED*) ok "game REFUSED: ${t#$H/}" ;; *) bad "game accepted: ${t#$H/}: $o" ;; esac
done
mv "$H/work/ugame/Library" "$S/game-lib-real"; ln -s "$S/game-lib-real" "$H/work/ugame/Library"
o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$H/work/ugame/Library")"; case "$o" in *REFUSED*symlink*) ok "symlinked Unity Library REFUSED" ;; *) bad "symlinked Library: $o" ;; esac
[ -e "$S/game-lib-real/x" ] && ok "symlink target untouched" || bad "symlink target removed"
rm "$H/work/ugame/Library"; mv "$S/game-lib-real" "$H/work/ugame/Library"
H="$S/devops"; o="$(run "$H" "$STUBS:$SAFE" apply --target "$H/work/iac2/.terraform")"; case "$o" in *REFUSED*"NOT git-ignored"*) ok "non-ignored .terraform REFUSED" ;; *) bad "non-ignored .terraform: $o" ;; esac
o="$(run "$H" "$STUBS:$SAFE" apply --target "$H/.kube/config")"; case "$o" in *REFUSED*) ok "kubeconfig REFUSED" ;; *) bad "kubeconfig: $o" ;; esac
o="$(run "$H" "$STUBS:$SAFE" apply --target "$H/.kube")"; case "$o" in *REFUSED*) ok "~/.kube parent REFUSED" ;; *) bad "~/.kube parent: $o" ;; esac
o="$(run "$H" "$STUBS:$SAFE" apply --ask-first-ok --target "$H/.terraform.d/plugin-cache")"; case "$o" in *REFUSED*) ok "plugin cache REFUSED when TF_PLUGIN_CACHE_DIR is unset" ;; *) bad "plugin cache without env: $o" ;; esac
mkdir -p "$H/bad-tf-cache"; echo x > "$H/bad-tf-cache/stray-file"
o="$(TFD="$H/bad-tf-cache" run "$H" "$SAFE" apply --target "$H/bad-tf-cache")"; case "$o" in *REFUSED*"provider cache"*) ok "TF_PLUGIN_CACHE_DIR with a non-cache layout REFUSED" ;; *) bad "bad TF layout: $o" ;; esac
chk "devops: bad TF layout gives no plan row" "$(TFD="$H/bad-tf-cache" run "$H" "$SAFE" plan --tsv --min-mb 0 | awk -F'\t' '$5=="terraform-plugin-cache"' | wc -l | tr -d ' ')" "0"
o="$(TFD="$H" run "$H" "$SAFE" apply --target "$H")"; case "$o" in *REFUSED*) ok "TF_PLUGIN_CACHE_DIR=\$HOME REFUSED" ;; *) bad "TF=HOME: $o" ;; esac
# refusals: running-process fixtures
echo "/Applications/Unity/Hub/Editor/2022.3.1f1/Unity.app/Contents/MacOS/Unity -projectpath $S/game/work/ugame" > "$S/ps.unity"
echo "/Applications/Godot.app/Contents/MacOS/Godot --path $S/game/work/gd" > "$S/ps.godot"
echo "/Users/Shared/Epic Games/UE_5.4/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor $S/game/work/ue/G.uproject" > "$S/ps.unreal"
echo "/opt/homebrew/bin/terraform apply" > "$S/ps.tf"
H="$S/game"; mkf "$H/work/ugame/Library/x" 2m; mkf "$H/work/ugame/Temp/t" 1m; mkf "$H/work/gd/.godot/c" 2m; mkf "$H/work/ue/Intermediate/i" 2m; mkf "$H/Library/Caches/Unity/upm/p" 2m; mkf "$H/Library/Caches/Godot/c" 2m
guardchk() { # PSFILE HOME TARGET WORDS
  local o; o="$(PSF="$1" run "$2" "$STUBS:$SAFE" apply --ask-first-ok --target "$3")"
  case "$o" in *REFUSED*"$4"*) ok "guard: ${3#$2/} refused ($4)" ;; *) bad "guard ${3#$2/}: $o" ;; esac
  o="$(PSF="$1" run "$2" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$3")"; [ -d "$3" ] && ok "guard: ${3#$2/} intact after --run" || bad "guard: ${3#$2/} removed while the editor runs"
}
guardchk "$S/ps.unity" "$H" "$H/work/ugame/Library" "Unity Editor"; guardchk "$S/ps.unity" "$H" "$H/work/ugame/Temp" "Unity Editor"
guardchk "$S/ps.unity" "$H" "$H/Library/Caches/Unity/upm" "Unity Editor"; guardchk "$S/ps.godot" "$H" "$H/work/gd/.godot" "Godot editor"
guardchk "$S/ps.godot" "$H" "$H/Library/Caches/Godot" "Godot editor"; guardchk "$S/ps.unreal" "$H" "$H/work/ue/Intermediate" "Unreal Editor"
o="$(PSF="$S/ps.godot" run "$H" "$STUBS:$SAFE" apply --ask-first-ok --target "$H/work/ugame/Library")"; case "$o" in *WOULD*) ok "a Godot editor does not block a Unity project" ;; *) bad "cross-engine block: $o" ;; esac
H="$S/devops"; mkf "$H/work/iac/.terraform/providers/p" 2m; mkf "$H/.terraform.d/plugin-cache/registry.terraform.io/hashicorp/aws/5.0.0/darwin_arm64/p" 2m
o="$(TFD="$H/.terraform.d/plugin-cache" PSF="$S/ps.tf" run "$H" "$STUBS:$SAFE" apply --target "$H/.terraform.d/plugin-cache")"; case "$o" in *REFUSED*"terraform/tofu is running"*) ok "running terraform blocks the plugin cache" ;; *) bad "tf guard: $o" ;; esac
o="$(PSF="$S/ps.tf" run "$H" "$STUBS:$SAFE" apply --target "$H/work/iac/.terraform")"; case "$o" in *REFUSED*"terraform/tofu is running"*) ok "running terraform blocks a project .terraform" ;; *) bad "tf project guard: $o" ;; esac
# the process-inside guard still covers the new rm rows
echo "$S/ml/.cache/torch/hub/checkpoints/srv --serve" > "$S/ps.mlinside"; mkf "$S/ml/.cache/torch/hub/checkpoints/m.pth" 2m
o="$(PSF="$S/ps.mlinside" run "$S/ml" "$STUBS:$SAFE" apply --ask-first-ok --target "$S/ml/.cache/torch/hub")"; case "$o" in *REFUSED*"running process"*) ok "process inside torch hub cache blocks the rm" ;; *) bad "ml inside guard: $o" ;; esac
# open files skip (hf hub)
H="$S/ml"; mkf "$H/.cache/huggingface/hub/models--a--b/blobs/open.bin" 2m
( exec 3< "$H/.cache/huggingface/hub/models--a--b/blobs/open.bin"; sleep 30 ) & TP=$!; sleep 1
o="$(run "$H" "$STUBS:$SAFE" apply --run --yes --ask-first-ok --log "$S/apply.log" --target "$H/.cache/huggingface/hub")"; pkill -P $TP 2>/dev/null; kill $TP 2>/dev/null; wait $TP 2>/dev/null
case "$o" in *"SKIPPED"*"files open"*) ok "hf hub open files SKIPPED" ;; *) bad "hf open files: $o" ;; esac
# docker rows were not touched: the existing docker-data row is the only docker row (no volumes row, no new one)
chk "catalog: docker-data row unchanged and no docker volume/VM row" "$(grep -vE '^\s*(#|$)' "$HERE/../catalog/catalog.tsv" | awk -F'|' '$1 ~ /docker|volume|virtualbox|mlflow|dvc/{print $1":"$4}' | tr '\n' ' ')" "docker-data:ask-first "
echo; echo "passed $PASS, failed $FAILN  (scratch: $S)"; [ "$FAILN" -eq 0 ]
