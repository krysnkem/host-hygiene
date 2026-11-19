#!/bin/bash
# K4: developer-type detection (profile --tsv "kind" rows) and the sentences that name the types. bash 3.2.
# Usage: check-profile.sh [SCRATCH_DIR]   (TUI part needs pyte: set HH_PYTHON to a python that has it, else it is skipped)
# Fake homes only, env -i with a stripped PATH. For every type and for 3 mixes: the kinds profile --tsv reports,
# the shell-menu opening line (intro.sh) and the TUI Look screen at 24x80 and 10x70 must name those types and no other.
HERE="$(cd "$(dirname "$0")" && pwd)"; HH="$HERE/../scripts/host-hygiene.sh"; INTRO="$HERE/../scripts/intro.sh"
S="${1:-$(mktemp -d /tmp/hh-k4.XXXXXX)}"; mkdir -p "$S"; S="$(cd "$S" && pwd -P)"
PY="${HH_PYTHON:-python3}"; "$PY" -c 'import pyte' 2>/dev/null && TUI=1 || TUI=0
PASS=0; FAILN=0; SAFE=/usr/bin:/bin:/usr/sbin:/sbin
ok() { PASS=$((PASS+1)); echo "PASS $1"; }
bad() { FAILN=$((FAILN+1)); echo "FAIL $1"; }
hh() { local H="$1"; shift; env -i HOME="$H" PATH="$SAFE" HH_NO_PROMPT=1 HH_APPS_DIR=/nonexistent "$@"; }

# kind names as the voices say them (plural | mass); presence is checked with the plural or the mass name
pl_of() { case "$1" in flutter) echo "Flutter apps";; android) echo "Android apps";; ios) echo "iOS and Swift projects";; rn) echo "React Native apps";;
  kmp) echo "Kotlin Multiplatform projects";; maui) echo "MAUI and Xamarin apps";; node) echo "Node and TypeScript projects";; frontend) echo "frontend monorepos";;
  python) echo "Python projects";; go) echo "Go services";; rust) echo "Rust projects";; jvm) echo "Java and Kotlin projects";; ruby) echo "Ruby projects";;
  rails) echo "Rails apps";; php) echo "PHP projects";; dotnet) echo ".NET projects";; esac; }
mass_of() { case "$1" in flutter) echo Flutter;; android) echo Android;; ios) echo Swift;; rn) echo "React Native";; kmp) echo "Kotlin Multiplatform";; maui) echo MAUI;;
  node) echo Node;; frontend) echo "frontend monorepo work";; python) echo Python;; go) echo Go;; rust) echo Rust;; jvm) echo JVM;; ruby) echo Ruby;;
  rails) echo Rails;; php) echo PHP;; dotnet) echo .NET;; esac; }
ALL="flutter android ios rn kmp maui node frontend python go rust jvm ruby rails php dotnet"

# mkproj HOME TYPE N : a git project of that type (the git dir makes it a project, fresh index = active)
mkproj() { local p="$1/work/$2$3"; mkdir -p "$p"
  case "$2" in
    flutter) printf 'name: a\nflutter:\n  uses-material-design: true\n' > "$p/pubspec.yaml"; mkdir -p "$p/ios" "$p/android"; echo x > "$p/android/build.gradle" ;;
    android) mkdir -p "$p/app/src/main"; echo '<manifest/>' > "$p/app/src/main/AndroidManifest.xml"; echo "plugins { id 'com.android.application' }" > "$p/build.gradle"; echo x > "$p/gradlew" ;;
    ios) mkdir -p "$p/App.xcodeproj"; echo x > "$p/Podfile" ;;
    rn) echo '{"dependencies":{"react-native":"0.74"}}' > "$p/package.json"; mkdir -p "$p/ios/App.xcodeproj" "$p/android"; echo x > "$p/android/build.gradle" ;;
    kmp) echo 'plugins { kotlin("multiplatform") }' > "$p/build.gradle.kts"; mkdir -p "$p/shared" "$p/iosApp" ;;
    maui) echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFrameworks>net8.0-android;net8.0-ios</TargetFrameworks><UseMaui>true</UseMaui></PropertyGroup></Project>' > "$p/App.csproj"; echo x > "$p/MauiProgram.cs" ;;
    node) echo '{"name":"a","dependencies":{"express":"4"}}' > "$p/package.json"; echo '{}' > "$p/tsconfig.json" ;;
    frontend) echo '{"name":"mono","private":true}' > "$p/package.json"; echo 'packages: ["apps/*"]' > "$p/pnpm-workspace.yaml" ;;
    python) echo '[project]' > "$p/pyproject.toml" ;;
    go) echo 'module x' > "$p/go.mod" ;;
    rust) printf '[package]\nname="x"\n' > "$p/Cargo.toml" ;;
    jvm) echo '<project/>' > "$p/pom.xml" ;;
    ruby) echo "source 'https://rubygems.org'" > "$p/Gemfile" ;;
    rails) printf "source 'https://rubygems.org'\ngem 'rails', '~> 7.1'\n" > "$p/Gemfile" ;;
    php) echo '{}' > "$p/composer.json" ;;
    dotnet) echo '<Project Sdk="Microsoft.NET.Sdk"/>' > "$p/Api.csproj" ;;
  esac; ( cd "$p" && git init -q ); }
# mkhome NAME "type:n type:n ..."
mkhome() { local H="$S/$1"; rm -rf "$H"; mkdir -p "$H"; local t n i; for t in $2; do n="${t#*:}"; t="${t%%:*}"; i=1; while [ $i -le "$n" ]; do mkproj "$H" "$t" "$i"; i=$((i+1)); done; done; }

# kinds_of HOME -> sorted ids with at least one project (kind rows, all-projects column > 0)
kinds_of() { hh "$1" "$HH" profile --tsv | awk -F'\t' '$1=="kind" && $4>0{print $2}' | sort | tr '\n' ' ' | sed 's/ $//'; }
# the opening sentence from the shell menu (colour codes stripped)
intro_line() { hh "$1" "$INTRO" 2>&1 | sed $'s/\x1b\\[[0-9;]*m//g' | grep -E '^  [A-Z]' | sed -n 2p | sed 's/^ *//'; }   # 2nd spoken line: after the greeting
named() { local t="$1" text="$2"; printf '%s' "$text" | grep -Fwq "$(pl_of "$t")" || printf '%s' "$text" | grep -Fwq "$(mass_of "$t")"; }
check_text() { # label text "expected types" : names every expected type, no other
  local label="$1" text="$2" want=" $3 " t; [ -z "$text" ] && { bad "$label: no sentence"; return; }
  for t in $ALL; do
    case "$want" in *" $t "*) named "$t" "$text" && ok "$label names $t" || bad "$label should name $t: [$text]" ;;
      *) named "$t" "$text" && bad "$label names absent $t: [$text]" || ok "$label omits $t" ;; esac
  done; }

echo "== kinds and sentences, one home per type"
for t in $ALL; do
  mkhome "one-$t" "$t:2"; want="$t"
  case "$t" in flutter) want="flutter";; android) want="android jvm";; kmp) want="jvm kmp";; esac   # raw kind rows: android and kmp live in gradle, so jvm is also a raw kind (folded in speech)
  got="$(kinds_of "$S/one-$t")"; exp="$(printf '%s\n' $t | sort | tr '\n' ' ' | sed 's/ $//')"
  case "$t" in android) exp="android jvm";; kmp) exp="jvm kmp";; ios) exp="ios";; esac
  # the profile folds overlaps in the kind rows themselves: node under rn/frontend, jvm under android/kmp, dotnet under maui, ruby under rails
  case "$t" in android) exp="android";; kmp) exp="kmp";; esac
  [ "$got" = "$exp" ] && ok "profile $t -> [$got]" || bad "profile $t: expected [$exp] got [$got]"
  L="$(intro_line "$S/one-$t")"; echo "SAY one-$t: $L"; check_text "intro one-$t" "$L" "$t"
done

echo "== three mixes"
mkhome mix-back "go:3 python:2 rust:1"; mkhome mix-mobile "flutter:4 android:1 ios:1"; mkhome mix-web "dotnet:2 php:2 rails:1 node:1"
for m in "mix-back:go python rust" "mix-mobile:flutter android ios" "mix-web:dotnet php rails node"; do
  n="${m%%:*}"; w="${m#*:}"; exp="$(printf '%s\n' $w | sort | tr '\n' ' ' | sed 's/ $//')"; got="$(kinds_of "$S/$n")"
  [ "$got" = "$exp" ] && ok "profile $n -> [$got]" || bad "profile $n: expected [$exp] got [$got]"
  L="$(intro_line "$S/$n")"; echo "SAY $n: $L"; check_text "intro $n" "$L" "$w"
done

echo "== tools only (no projects): types come from installed toolchains, nothing invented"
H="$S/tools-only"; rm -rf "$H"; mkdir -p "$H/.gradle" "$H/.cargo" "$H/go"
tk="$(hh "$H" "$HH" profile --tsv | awk -F'\t' '$1=="kind" && $5=="y"{print $2}' | sort | tr '\n' ' ')"
case " $tk " in *" go "*) ok "tools-only: go from ~/go";; *) bad "tools-only: go missing [$tk]";; esac
case " $tk " in *" rust "*) ok "tools-only: rust from ~/.cargo";; *) bad "tools-only: rust missing [$tk]";; esac
case " $tk " in *" python "*|*" ruby "*|*" php "*|*" dotnet "*|*" flutter "*|*" android "*) bad "tools-only: invented a type [$tk]";; *) ok "tools-only: no invented type";; esac
L="$(intro_line "$H")"; echo "SAY tools-only: $L"
printf '%s' "$L" | grep -Fwq Go && printf '%s' "$L" | grep -Fwq Rust && ok "tools-only sentence names Go and Rust" || bad "tools-only sentence: [$L]"

echo "== non-developer home says no types"
H="$S/plain"; rm -rf "$H"; mkdir -p "$H/Documents"; [ -z "$(kinds_of "$H")" ] && ok "plain: no kinds" || bad "plain: kinds [$(kinds_of "$H")]"

echo "== profile --tsv stays backward compatible: meta/tc/proj rows keep their columns, kind rows only appended"
H="$S/one-go"; out="$(hh "$H" "$HH" profile --tsv)"
[ "$(printf '%s\n' "$out" | head -1 | cut -f1,2)" = "$(printf 'meta\tprofile')" ] && ok "first row is meta profile" || bad "first row"
printf '%s\n' "$out" | awk -F'\t' '$1=="proj" && NF!=4{e=1} $1=="tc" && NF!=3{e=1} END{exit e}' && ok "proj has 4 columns, tc 3" || bad "column counts changed"
printf '%s\n' "$out" | awk -F'\t' '$1=="kind"{k=1} k && $1!="kind"{e=1} END{exit e}' && ok "kind rows come last" || bad "kind rows not appended"

echo "== projects hidden from the user's view: speed (informational)"
H="$S/mix-back"; s0=$(date +%s); hh "$H" "$HH" profile --tsv >/dev/null; echo "profile on a small fake home: $(( $(date +%s) - s0 ))s, uptime: $(uptime | sed 's/.*averages*: //')"

if [ "$TUI" = 1 ]; then
  echo "== TUI Look screen at 24x80 and 10x70"
  for n in one-go one-rails one-maui mix-back mix-mobile mix-web; do
    want="$n"; case "$n" in one-*) want="${n#one-}";; mix-back) want="go python rust";; mix-mobile) want="flutter android ios";; mix-web) want="dotnet php rails node";; esac
    for sz in "24 80" "10 70"; do
      T="$("$PY" "$HERE/look-driver.py" "$S/$n" $sz 2>&1)"
      # drop the greeting and the tools/state sentences so only the type sentence is judged (Xcode on the real /Applications may be named as a tool)
      L="$(printf '%s' "$T" | sed -E 's/Around that, I also found [^.]*\.//; s/Your toolbox also has [^.]*\.//; s/Besides that I can see [^.]*\.//; s/I also spotted [^.]*\.//; s/^.*(machine|set up|lives on this machine)\. //')"
      echo "SAY tui $n ${sz// /x}: $(printf '%s' "$L" | sed -E 's/For the record.*//; s/Right now.*//; s/Current state.*//')"
      L="$(printf '%s' "$L" | sed -E 's/(For the record|Right now|Current state).*//')"
      check_text "tui $n ${sz// /x}" "$L" "$want"
    done
  done
else echo "SKIP TUI part: no pyte (set HH_PYTHON)"; fi
echo; echo "check-profile: $PASS passed, $FAILN failed"; [ "$FAILN" = 0 ]
