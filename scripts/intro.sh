#!/usr/bin/env bash
# host-hygiene first-run hello: looks around the machine and says what it found, in plain words.
# Runs automatically before the first threshold questions; replay with `host-hygiene.sh hello`.
# Wording lives in the phrase pools below (one is picked at random each time). Add lines freely.
set -u
HH="$(cd "$(dirname "$0")" && pwd -P)/host-hygiene.sh"
. "$(dirname "$0")/ui.sh"
pause() { [ -t 1 ] && sleep "${1:-0.5}"; }
pick() { local n=$#; shift 0; local i=$((RANDOM % n)); eval "printf '%s' \"\${$((i+1))}\""; }   # pick "a" "b" "c"
pl() { [ "$1" = 1 ] && printf "%s %s" "$1" "$2" || printf "%s %s" "$1" "$3"; }
say() { printf '  '; typeline "$1"; pause 0.35; }
sub() { local t="$1"; shift; while [ $# -gt 1 ]; do t="${t//\{$1\}/$2}"; shift 2; done; printf '%s' "$t"; }
join() { awk -v a="$*" 'BEGIN{n=split(a,x,"|"); for(i=1;i<=n;i++){ if(i>1) printf (i==n?" and ":", "); printf "%s",x[i] } }'; }
# developer-type names: kn pl|sg|mass ID -> "Go services" | "a Go service" | "Go". Only ever called for a type the engine detected.
kn() { local f; case "$2" in
  flutter) f="Flutter apps|a Flutter app|Flutter";;  android) f="Android apps|an Android app|Android";;
  ios) f="iOS and Swift projects|an iOS or Swift project|Swift";;  rn) f="React Native apps|a React Native app|React Native";;
  kmp) f="Kotlin Multiplatform projects|a Kotlin Multiplatform project|Kotlin Multiplatform";;
  maui) f="MAUI and Xamarin apps|a MAUI or Xamarin app|MAUI";;  node) f="Node and TypeScript projects|a Node project|Node";;
  frontend) f="frontend monorepos|a frontend monorepo|frontend monorepo work";;  python) f="Python projects|a Python project|Python";;
  go) f="Go services|a Go service|Go";;  rust) f="Rust projects|a Rust project|Rust";;  jvm) f="Java and Kotlin projects|a Java or Kotlin project|JVM";;
  ruby) f="Ruby projects|a Ruby project|Ruby";;  rails) f="Rails apps|a Rails app|Rails";;  php) f="PHP projects|a PHP project|PHP";;
  dotnet) f=".NET projects|a .NET project|.NET";;  *) f="$2 projects|a $2 project|$2";; esac
  case "$1" in pl) echo "${f%%|*}";; sg) f="${f#*|}"; echo "${f%%|*}";; *) echo "${f##*|}";; esac; }
# "a|b|c" of ids -> "A, B and C" (mass names); more than 3 ends "and a few more"
knlist() { local o="" n=0 i; for i in $(echo "$1" | tr '|' ' '); do n=$((n+1)); [ $n -le 3 ] && o="${o:+$o|}$(kn mass "$i")"; done
  [ $n -gt 3 ] && o="$(echo "$o" | cut -d'|' -f1,2)|a few more"; join "$o"; }

# ---- opening lines -------------------------------------------------------------------------------
[ "$TTY" = 1 ] && clear; echo; logo; echo
say "$(pick "Hi, I'm host-hygiene. Give me a moment to look around your machine." \
             "Hey there. Let me have a quick look at what lives on this machine." \
             "Hello! Before anything else, I'll take a peek at how your machine is set up." \
             "Hi. Just getting my bearings here, I'll be quick.")"
spin "Looking around your machine" "$HH" profile --tsv; DATA="$(cat "$SPIN_OUT")"; rm -f "$SPIN_OUT"
TC="$(printf '%s\n' "$DATA" | awk -F'\t' '$1=="tc"{print $2}')"
PROFILE="$(printf '%s\n' "$DATA" | awk -F'\t' '$1=="meta"{print $3}')"
has() { printf '%s\n' "$TC" | grep -qx "$1"; }

# developer types from the engine's "kind" rows: id, active projects, all projects, toolchain y/n. Active ones first; if none are active, all of them.
KROWS="$(printf '%s\n' "$DATA" | awk -F'\t' '$1=="kind"')"
KINDS="$(printf '%s\n' "$KROWS" | awk -F'\t' '$3>0{print $3, $2}' | sort -k1,1nr -k2,2)"; QUIET=0
[ -z "$KINDS" ] && { KINDS="$(printf '%s\n' "$KROWS" | awk -F'\t' '$4>0{print $4, $2}' | sort -k1,1nr -k2,2)"; QUIET=1; }
TOOLK="$(printf '%s\n' "$KROWS" | awk -F'\t' '$5=="y"{print $2}' | tr '\n' '|' | sed 's/|$//')"
NP="$(printf '%s\n' "$DATA" | awk -F'\t' '$1=="proj"&&$2==1' | wc -l | tr -d ' ')"
NA="$(printf '%s\n' "$DATA" | awk -F'\t' '$1=="proj"' | wc -l | tr -d ' ')"
P1="$(printf '%s\n' "$KINDS" | sed -n 1p | awk '{print $2}')"; C1="$(printf '%s\n' "$KINDS" | sed -n 1p | awk '{print $1}')"
# majors: types with at least a third of the leader's count, at most two; everything else is a sprinkle
MAJ=""; SPR=""; NM=0
while read -r c id; do [ -z "$id" ] && continue
  if [ $((c * 3)) -ge "$C1" ] && [ $NM -lt 2 ]; then NM=$((NM+1)); MAJ="${MAJ:+$MAJ|}$id"; else SPR="${SPR:+$SPR|}$id"; fi; done <<EOK
$KINDS
EOK
NAMED="$MAJ|$SPR"
echo

if [ "$PROFILE" = non-developer ] || { [ -z "$P1" ] && [ -z "$(printf '%s\n' "$TC" | grep -E '^(android|gradle|dart|fvm|xcode|docker|node|rust)$')" ]; }; then
  say "$(pick "Looks like an everyday machine to me. I don't see any developer tools." \
               "I don't see a developer setup here, so this looks like a regular day-to-day computer." \
               "No coding toolchains that I can spot, so I'll treat this as an everyday machine.")"
  say "$(pick "That keeps things simple: I'll focus on caches, old downloads, the Trash and anything slowing you down." \
               "I'll stick to the usual suspects: app caches, logs, mail attachments and the Trash.")"
else
  A="${MAJ%%|*}"; B="${MAJ#*|}"; [ "$B" = "$MAJ" ] && B=""
  if [ -z "$P1" ]; then
    if [ -n "$TOOLK" ]; then NAMED="$TOOLK"
      say "$(sub "$(pick "I don't see any projects yet, but the tools here point to {l}." \
                        "No projects that I can find, though your toolbox hints at {l}.")" l "$(knlist "$TOOLK")")"
    else say "$(pick "I can see a developer setup here, judging by the tools." "This looks like a developer machine, going by the tools I can see.")"; fi
  elif [ -z "$SPR" ] && [ -z "$B" ]; then   # a single type
    if [ "$QUIET" = 1 ]; then
      if [ "$C1" = 1 ]; then say "$(sub "$(pick "I found {s}, though it has been quiet for the last three months." "There's {s} here, nothing touched lately.")" s "$(kn sg "$A")")"
      else say "$(sub "$(pick "I found {p}, though none were touched in the last three months." "There are {p} here, all quiet lately.")" p "$(kn pl "$A")")"; fi
    elif [ "$C1" = 1 ]; then say "$(sub "$(pick "I can see {s} that you've been working on lately." "Looks like you've got {s} on the go." "So you build things like {s}, and you've touched it lately.")" s "$(kn sg "$A")")"
    else say "$(sub "$(pick "Looks like {p} are your thing. I count {n} you've touched lately." \
                            "So you build {p}. {n} of them have seen activity lately." \
                            "I can see you work on {p}, with {n} of them active in the last three months.")" p "$(kn pl "$A")" n "$C1")"; fi
  elif [ -z "$B" ]; then   # a main type with sprinkles
    say "$(sub "$(pick "I see mostly {a}, with some {b} sprinkled in." \
                      "Looks like you mostly work on {a}, with a little {b} on the side." \
                      "{a} are the star here, with a bit of {b} around them." \
                      "You're mostly into {a}, and there's some {b} too.")" a "$(kn pl "$A")" b "$(knlist "$SPR")")"
  elif [ -z "$SPR" ]; then   # two types side by side
    say "$(sub "$(pick "I see a real mix here: {a} and {b} side by side." \
                      "Looks like you work on both {a} and {b}, nice." \
                      "You split your time between {a} and {b}, from what I can see.")" a "$(kn pl "$A")" b "$(kn pl "$B")")"
  else   # three or more
    say "$(sub "$(pick "You're a real all-rounder: mostly {a} and {b}, with a bit of {c}." \
                      "I see mostly {a} and {b}, plus a bit of {c}." \
                      "It's a proper mix here: mostly {a} and {b}, with some {c} around the edges.")" a "$(kn pl "$A")" b "$(kn pl "$B")" c "$(knlist "$SPR")")"
  fi
  [ "$NA" -gt "$NP" ] && say "$(sub "$(pick "Altogether I found {t} projects, {n} of them touched in the last three months." \
                                              "There are {t} projects in total; about {n} look alive, the rest have been quiet for a while." )" t "$NA" n "$NP")"
  # other tools it can find
  TOOLS=""; add() { TOOLS="${TOOLS:+$TOOLS|}$1"; }
  nm() { case "|$NAMED|" in *"|$1|"*) return 0;; esac; return 1; }
  has android && add "the Android SDK"; has xcode && add "Xcode"; has gradle && add "Gradle"; has docker && add "Docker"
  has fvm && add "FVM"; has rust && ! nm rust && add "Rust"; has node && ! nm node && ! nm rn && ! nm frontend && add "Node.js"; has brew && add "Homebrew"
  has go && ! nm go && add "Go"; has ruby && ! nm ruby && ! nm rails && add "a Ruby version manager"; has php && ! nm php && add "Composer"
  has dotnet && ! nm dotnet && ! nm maui && add ".NET"; has kmp && ! nm kmp && add "Kotlin/Native"
  [ -n "$TOOLS" ] && say "$(sub "$(pick "Around that, I also found {t}." \
                                       "Your toolbox also has {t}." \
                                       "Besides that I can see {t} installed." \
                                       "I also spotted {t}.")" t "$(join "$TOOLS")")"
  NAVD="$(ls -d "$HOME"/.android/avd/*.avd 2>/dev/null | wc -l | tr -d ' ')"; NSIM="$(ls "$HOME/Library/Developer/CoreSimulator/Devices" 2>/dev/null | wc -l | tr -d ' ')"
  EXTRA=""; [ "$NAVD" -gt 0 ] && EXTRA="$(pl "$NAVD" "Android emulator" "Android emulators")"; [ "$NSIM" -gt 0 ] && EXTRA="${EXTRA:+$EXTRA and }$(pl "$NSIM" "iOS simulator" "iOS simulators")"
  [ -n "$EXTRA" ] && say "$(sub "$(pick "You also have {x} on disk. Those tend to be the big ones." \
                                         "I see {x}. Those are usually the heaviest items on a developer machine." \
                                         "Worth knowing: {x} on disk, usually the heaviest things around.")" x "$EXTRA")"
fi

# ---- how the machine is doing right now ---------------------------------------------------------
FREE="$(df -Pk "$HOME" | awk 'NR==2{printf "%.0f", $4/1048576}')"; LOAD="$(uptime | sed -E 's/.*averages?: ([0-9.]+).*/\1/')"
say "$(sub "$(pick "Right now you have {f} GiB free and the machine is running at load {l}." \
                   "For the record: {f} GiB free, load {l} at the moment." \
                   "Current state: {f} GiB of free space, load {l}.")" f "$FREE" l "$LOAD")"
echo
say "$(pick "Next, let's set the limits I should watch for you. The defaults are suggestions based on this machine." \
             "Now a few quick questions, so I know when your machine is struggling. Press Enter to accept my suggestions." \
             "Last thing before we start: tell me when I should start worrying about space and load. Suggestions are ready.")"
echo
