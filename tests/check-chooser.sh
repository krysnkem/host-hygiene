#!/usr/bin/env bash
# UI Phases 3-5: the look chooser (terminal list + browser page) and its triggers. Fake homes only; no real browser is ever opened (HH_BROWSER_CMD points at a script that records the URL).
# Usage: HH_PYTHON=<python with pyte> check-chooser.sh [SCRATCH_DIR]     Needs tui/hh_tui built, curl, lsof. bash 3.2.
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"; S="${1:-$(mktemp -d)}"; mkdir -p "$S"; HH="$D/scripts/host-hygiene.sh"; BIN="$D/tui/hh_tui"
PY="${HH_PYTHON:-python3}"; "$PY" -c 'import pyte' 2>/dev/null || { echo "SKIP: need pyte (HH_PYTHON)"; exit 0; }
[ -x "$BIN" ] || { echo "SKIP: tui/hh_tui not built"; exit 0; }
DRV="$D/tests/look-drive.py"; pass=0; fail=0
ok() { pass=$((pass+1)); echo "PASS $1"; }
bad() { fail=$((fail+1)); echo "FAIL $1 :: $2"; }
eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1" "want '$3' got '$2'"; }
has() { printf '%s' "$2" | grep -Fq -- "$3" && ok "$1" || bad "$1" "missing '$3'"; }
hasnt() { printf '%s' "$2" | grep -Fq -- "$3" && bad "$1" "unexpected '$3'" || ok "$1"; }
drive() { "$PY" "$DRV" "$@" 2>&1; }
ui_of() { env -u HH_LOOK HOME="$1" HH_CONFIG="$1/.config/host-hygiene/config" "$HH" config get ui; }
IDS="guided cockpit dashboard spacemap console"
FB="$S/fakebrowser.sh"; printf '#!/bin/sh\necho "$1" >> "${HH_URL_FILE:?}"\n' > "$FB"; chmod +x "$FB"
FAILB="$S/failbrowser.sh"; printf '#!/bin/sh\nexit 1\n' > "$FAILB"; chmod +x "$FAILB"
DEV="$S/devhome"; rm -rf "$DEV"; bash "$D/tests/make-dev-home.sh" "$DEV" >/dev/null
cfg() { mkdir -p "$DEV/.config/host-hygiene"; printf 'min_free_gb=1\nhard_gb=0.5\nmax_load=999\n%s' "${1:-}" > "$DEV/.config/host-hygiene/config"; }
nocfg() { rm -rf "$DEV/.config"; }
mark_of() { case "$1" in guided) echo "✓ Look" ;; cockpit) echo "● host-hygiene" ;; dashboard) echo "Dashboard · Pick" ;; spacemap) echo "ticked" ;; console) echo "hh console" ;; esac; }
none_left() { eq "$1" "$(pgrep -f 'hh_tui --pick-look' | wc -l | tr -d ' ')" 0; }

echo "== static facts"
n="$(sed -n 's/^UI_LOOKS="\(.*\)".*/\1/p' "$HH")"
for L in $IDS; do case " $n " in *" $L "*) ok "UI_LOOKS knows $L" ;; *) bad "UI_LOOKS knows $L" "$n" ;; esac; done
pg="$D/tui/lib/web_page.dart"; sz="$(wc -c < "$pg" | tr -d ' ')"; [ "$sz" -lt 40960 ] && ok "page source $sz B < 40 KB" || bad "page size" "$sz"
for L in $IDS; do has "page offers $L" "$(cat "$pg")" "value=\"$L\""; done
hasnt "page has no plain choice" "$(cat "$pg")" 'value="plain"'
hasnt "page has no external URL, font, image or import" "$(grep -E 'https?://|@import|url\(|src=|<link|@font-face' "$pg")" "http"
has "server binds loopback only" "$(cat "$D/tui/lib/web_pick.dart")" "InternetAddress.loopbackIPv4, 0"
hasnt "server never reads a file" "$(cat "$D/tui/lib/web_pick.dart")" "readAsString"
eq "usage lists hh look" "$("$HH" --help | grep -c 'host-hygiene.sh look')" 1
H0="$S/nobin"; rm -rf "$H0"; mkdir -p "$H0"; cp -R "$D/scripts" "$H0/scripts"
o="$(HOME="$DEV" "$H0/scripts/host-hygiene.sh" look 2>&1)"; has "missing binary: plain message" "$o" "needs the guided front end"; has "missing binary: says how to build" "$o" "tui/build.sh"
o="$(HOME="$DEV" "$HH" look </dev/null 2>&1)"; has "non-tty look refuses" "$o" "needs an interactive terminal"
o="$(HOME="$DEV" "$HH" look --bogus </dev/null 2>&1)"; has "look rejects other args" "$o" "unknown argument"
o="$(env HOME="$DEV" "$BIN" --pick-look </dev/null 2>&1; echo "rc=$?")"; has "hh_tui --pick-look without a tty exits 2" "$o" "rc=2"

echo "== terminal chooser: sizes, preview, every id saves and the TUI opens in it"
# On a failure in the size loop, keep evidence in $S: the screen dump (fail-R-C-L.txt) and a bash -x trace of the script (trace-R-C-L.txt; its "rc=" line is the chooser'"'"'s exit code).
WRAP="$S/wrap-look.sh"; printf '#!/bin/bash\nexec bash -x "%s" "$@" 2> "${HH_TRACE_FILE:?}"\n' "$HH" > "$WRAP"; chmod +x "$WRAP"
for SZ in "24 80" "12 60" "10 70"; do
  set -- $SZ; R="$1"; C="$2"
  nocfg; cfg ""
  o="$(drive "$DEV" $R $C '[["wait","Choose a look",30],["snap","a"],["key","ESC"],["sleep",1],["snap","b"]]' HH_BIN="$HH" HH_ARGS=look SSH_CONNECTION=1)"
  has "$R x $C: list shows Console" "$o" "Console"; has "$R x $C: list shows Guided" "$o" "Guided journey"; has "$R x $C: Esc says no change" "$o" "No change"
  [ "$R" = 24 ] && has "$R x $C: preview of the highlighted look" "$o" "Take me through"
  [ "$R" = 24 ] || hasnt "$R x $C: no preview when short" "$o" "Take me through"
  eq "$R x $C: Esc left the look alone" "$(ui_of "$DEV")" guided
  eq "$R x $C: Esc wrote no ui=" "$(grep -c '^ui=' "$DEV/.config/host-hygiene/config")" 0
  i=0
  for L in $IDS; do
    cfg ""
    downs=""; j=0; while [ $j -lt $i ]; do downs="$downs[\"key\",\"DOWN\"],"; j=$((j+1)); done
    TR="$S/trace-$R-$C-$L.txt"; f0=$fail
    o="$(drive "$DEV" $R $C "[[\"wait\",\"Choose a look\",30],${downs}[\"snap\",\"sel\"],[\"key\",\"ENTER\"],[\"wait\",\"Pick what to clear|ticked|hh console|Dashboard · Pick|● host-hygiene|Too small|free \",150],[\"sleep\",4],[\"settle\",1],[\"snap\",\"tui\"]]" HH_BIN="$WRAP" HH_TRACE_FILE="$TR" HH_DRIVE_RAW="$S/raw-$R-$C-$L.bin" HH_ARGS=look SSH_CONNECTION=1)"
    eq "$R x $C: Enter saves $L" "$(ui_of "$DEV")" "$L"
    t="$(printf '%s' "$o" | sed -n '/=== tui/,$p')"
    hasnt "$R x $C: chooser gone, TUI running ($L)" "$t" "Choose a look"
    if [ "$R" = 24 ]; then has "$R x $C: TUI opens in $L" "$t" "$(mark_of $L)"; fi
    if [ "$fail" -gt "$f0" ]; then printf '%s\n' "$o" > "$S/fail-$R-$C-$L.txt"; echo "     evidence: $S/fail-$R-$C-$L.txt, $TR ($(grep -E '^\+ rc=' "$TR" 2>/dev/null | tr '\n' ' '))"; else rm -f "$TR" "$S/raw-$R-$C-$L.bin"; fi
    i=$((i+1))
  done
done
[ "${CH_STOP:-}" = term ] && { echo "passed $pass, failed $fail"; exit 0; }
cfg ""; o="$(drive "$DEV" 24 80 '[["wait","Choose a look",30],["snap","a"],["key","ESC"],["sleep",1]]' HH_ARGS=--pick-look HH_BROWSER_CMD="$FB" HH_URL_FILE="$S/u0")"
has "browser is the first choice when one exists" "$(printf '%s' "$o" | sed -n '/=== a/,/^ALIVE/p' | sed -n 3p)" "Open in the browser"; has "Esc exits 10 (no change)" "$o" "EXIT 10"
o="$(drive "$DEV" 24 80 '[["wait","Choose a look",30],["snap","a"],["key","ESC"],["sleep",1]]' HH_ARGS=--pick-look SSH_CONNECTION=1)"; hasnt "no browser row over SSH" "$o" "Open in the browser"
o="$(drive "$DEV" 24 80 '[["wait","Choose a look",30],["key","DOWN"],["key","ENTER"],["sleep",2]]' HH_ARGS=--pick-look SSH_CONNECTION=1)"; has "standalone save exits 0" "$o" "EXIT 0"; eq "standalone save wrote cockpit" "$(ui_of "$DEV")" cockpit

echo "== web server: security (real server, curl)"
WH="$S/webhome"; rm -rf "$WH"; mkdir -p "$WH/.config/host-hygiene"; W0() { printf 'min_free_gb=1\nhard_gb=0.5\nmax_load=999\nui=guided\n' > "$WH/.config/host-hygiene/config"; }; W0
webstart() {   # webstart SECONDS [K=V ...]  -> URL PORT TOKEN PID of a running `hh_tui --pick-look --web`
  local dur="$1"; shift; : > "$S/url"; rm -f "$S/drv.out"
  ( "$PY" "$DRV" "$WH" 24 80 "[[\"sleep\",$dur]]" HH_ARGS="--pick-look --web" HH_BROWSER_CMD="$FB" HH_URL_FILE="$S/url" "$@" > "$S/drv.out" 2>&1 & )
  local i=0; while [ $i -lt 150 ] && [ ! -s "$S/url" ]; do sleep 0.1; i=$((i+1)); done
  URL="$(head -1 "$S/url")"; PORT="${URL#http://127.0.0.1:}"; PORT="${PORT%%/*}"; TOKEN="${URL%/}"; TOKEN="${TOKEN##*/}"; PID="$(pgrep -f 'hh_tui --pick-look' | head -1)"
}
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"; }
B() { printf '{"look":"%s","token":"%s"}' "$1" "$TOKEN"; }
post() { code -X POST -H 'Content-Type: application/json' "$@"; }
webstart 70
has "URL is 127.0.0.1" "$URL" "http://127.0.0.1:"; eq "token is 48 hex chars (192 bits)" "$(printf '%s' "$TOKEN" | grep -Ec '^[0-9a-f]{48}$')" 1
eq "exactly one hh_tui process" "$(pgrep -f 'hh_tui --pick-look' | wc -l | tr -d ' ')" 1
eq "no child processes while waiting" "$(pgrep -P "$PID" | wc -l | tr -d ' ')" 0
L="$(lsof -nP -a -p "$PID" -iTCP -sTCP:LISTEN 2>/dev/null | tail -n +2)"; has "listens on 127.0.0.1:$PORT" "$L" "127.0.0.1:$PORT"; hasnt "not on all interfaces (*)" "$L" "*:"; hasnt "not on 0.0.0.0" "$L" "0.0.0.0"; eq "every listening socket of the process is loopback (nocterm also opens its own log socket)" "$(printf '%s\n' "$L" | grep -vc '127.0.0.1:')" 0
cs() { awk -F'[:.]' '{printf "%.2f", $1*60+$2+$3/100}' <<EOF
$1
EOF
}
T0="$(ps -o cputime= -p "$PID" | tr -d ' ')"; sleep 8; T1="$(ps -o cputime= -p "$PID" | tr -d ' ')"
c="$(awk -v a="$(cs "$T0")" -v b="$(cs "$T1")" 'BEGIN{printf "%.2f", (b-a)/8*100}')"; awk -v c="$c" 'BEGIN{exit !(c<1)}' && ok "waiting CPU ${c}% < 1% (cputime delta over 8 s)" || bad "waiting CPU" "$c%"
eq "no token (GET /) -> 403" "$(code "http://127.0.0.1:$PORT/")" 403
eq "no path -> 403" "$(code "http://127.0.0.1:$PORT")" 403
eq "wrong token -> 403" "$(code "http://127.0.0.1:$PORT/0000/")" 403
eq "token prefix only -> 403" "$(code "http://127.0.0.1:$PORT/${TOKEN%?}/")" 403
eq "token as query on / -> 403" "$(code "http://127.0.0.1:$PORT/?t=$TOKEN")" 403
eq "other path, no token -> 403" "$(code "http://127.0.0.1:$PORT/etc/passwd")" 403
eq "other path with token -> 404" "$(code "http://127.0.0.1:$PORT/$TOKEN/etc/passwd")" 404
tv="$(code --path-as-is "http://127.0.0.1:$PORT/$TOKEN/../../etc/passwd")"; case "$tv" in 403|404) ok "traversal with token is refused ($tv, never 200)" ;; *) bad "traversal" "$tv" ;; esac
eq "favicon with token -> 404" "$(code "http://127.0.0.1:$PORT/$TOKEN/favicon.ico")" 404
eq "GET save path -> 404" "$(code "http://127.0.0.1:$PORT/$TOKEN/save")" 404
eq "wrong Host (evil.example) -> 403" "$(code -H "Host: evil.example:$PORT" "$URL")" 403
eq "wrong Host (no port) -> 403" "$(code -H "Host: 127.0.0.1" "$URL")" 403
eq "wrong Host (localhost) -> 403" "$(code -H "Host: localhost:$PORT" "$URL")" 403
eq "cross-Origin GET -> 403" "$(code -H "Origin: http://evil.example" "$URL")" 403
eq "Origin null -> 403" "$(code -H "Origin: null" "$URL")" 403
for M in PUT DELETE PATCH OPTIONS; do eq "$M -> 405" "$(code -X $M "$URL")" 405; done
eq "HEAD -> 405" "$(code -I "$URL")" 405
eq "POST on the page path -> 404" "$(post -d "$(B guided)" "$URL")" 404
eq "POST save without the token path -> 403" "$(post -d "$(B guided)" "http://127.0.0.1:$PORT/save")" 403
eq "GET page -> 200" "$(code "$URL")" 200
pgsrc="$(curl -s --max-time 5 "$URL")"; for L in $IDS; do has "served page offers $L" "$pgsrc" "value=\"$L\""; done; has "served page has the mascot" "$pgsrc" "I am Hy"; has "served page marks the current look" "$pgsrc" "cur='guided'"
hasnt "served page has no external request" "$(printf '%s' "$pgsrc" | grep -Eo '(src|href)="[^"]*"')" "http"
hdr="$(curl -s -D - -o /dev/null --max-time 5 "$URL")"; has "CSP header" "$(printf '%s' "$hdr" | tr A-Z a-z)" "content-security-policy: default-src 'none'"; has "Cache-Control no-store" "$hdr" "no-store"
for bad_id in plain x "../../etc/passwd" "" "guided " "GUIDED" "cockpit;ls" '$(id)' 'a"b'; do eq "bad id '$bad_id' -> 400" "$(post -d "$(B "$bad_id")" "${URL}save")" 400; done
eq "missing look -> 400" "$(post -d "{\"token\":\"$TOKEN\"}" "${URL}save")" 400
eq "extra key -> 400" "$(post -d "{\"look\":\"guided\",\"token\":\"$TOKEN\",\"x\":1}" "${URL}save")" 400
eq "look not a string -> 400" "$(post -d "{\"look\":1,\"token\":\"$TOKEN\"}" "${URL}save")" 400
eq "not JSON -> 400" "$(post -d 'look=cockpit' "${URL}save")" 400
eq "form content type -> 400" "$(code -X POST -H 'Content-Type: application/x-www-form-urlencoded' -d "$(B cockpit)" "${URL}save")" 400
eq "no content type -> 400" "$(code -X POST -H 'Content-Type:' -d "$(B cockpit)" "${URL}save")" 400
eq "wrong token in body -> 403" "$(post -d '{"look":"cockpit","token":"deadbeef"}' "${URL}save")" 403
big="$(printf '{"look":"cockpit","token":"%s","pad":"%s"}' "$TOKEN" "$(head -c 3000 /dev/zero | tr '\0' a)")"
eq "oversize body -> 413" "$(post -d "$big" "${URL}save")" 413
eq "chunked body (no length) -> 413" "$(post -H 'Transfer-Encoding: chunked' -d "$(B cockpit)" "${URL}save")" 413
eq "cross-Origin POST -> 403" "$(post -H "Origin: http://evil.example" -d "$(B cockpit)" "${URL}save")" 403
eq "wrong Host POST -> 403" "$(post -H "Host: evil.example:$PORT" -d "$(B cockpit)" "${URL}save")" 403
eq "config untouched by all rejected requests" "$(ui_of "$WH")" guided
eq "server still up after rejects" "$(code "$URL")" 200
eq "valid save (same Origin) -> 200" "$(post -H "Origin: http://127.0.0.1:$PORT" -d "$(B dashboard)" "${URL}save")" 200
sleep 1.5
eq "config updated by the web save" "$(ui_of "$WH")" dashboard
eq "one ui= line only" "$(grep -c '^ui=' "$WH/.config/host-hygiene/config")" 1
curl -s -o /dev/null --max-time 3 "$URL"; eq "port closed after save (curl exit 7)" "$?" 7
curl -s -o /dev/null --max-time 3 -X POST -H 'Content-Type: application/json' -d "$(B cockpit)" "${URL}save"; eq "second save refused (exit 7)" "$?" 7
none_left "no hh_tui left after the save"
eq "second save did not change config" "$(ui_of "$WH")" dashboard
has "terminal side exited 0 after the save" "$(cat "$S/drv.out")" "EXIT 0"
for L in $IDS; do
  W0; webstart 20
  eq "web save $L -> 200" "$(post -d "$(B $L)" "${URL}save")" 200; sleep 1.2; eq "web save $L stored" "$(ui_of "$WH")" "$L"
done
none_left "no hh_tui left after five saves"

echo "== web server: timeouts and cancel"
W0; webstart 14 HH_WEB_TIMEOUTS=2,30; sleep 3.5; curl -s -o /dev/null --max-time 3 "$URL"; eq "no page request in time: port closed" "$?" 7
webstart 16 HH_WEB_TIMEOUTS=30,2; eq "page requested within time" "$(code "$URL")" 200; sleep 1; eq "still up inside the idle window" "$(code "$URL")" 200; sleep 3.2; curl -s -o /dev/null --max-time 3 "$URL"; eq "idle timeout closes the port" "$?" 7
ps -p "$PID" >/dev/null 2>&1 && ok "process alive after an idle close (back at the list)" || bad "alive after idle" "gone"
sleep 14; none_left "no hh_tui left after the windows"
o="$(drive "$WH" 24 80 '[["wait","Waiting for",30],["sleep",4],["snap","a"],["key","ESC"],["sleep",1]]' HH_ARGS="--pick-look --web" HH_BROWSER_CMD="$FB" HH_URL_FILE="$S/u1" HH_WEB_TIMEOUTS=2,30)"
has "no-request fallback message on screen" "$o" "was not opened within 2 s"; has "no-request fallback shows the list" "$o" "Choose a look"
o="$(drive "$WH" 24 80 '[["wait","Waiting for",30],["snap","w"],["key","ESC"],["sleep",1],["snap","b"],["key","ESC"],["sleep",1]]' HH_ARGS="--pick-look --web" HH_BROWSER_CMD="$FB" HH_URL_FILE="$S/u2")"
has "waiting text" "$o" "Waiting for your choice in the browser... (Esc to choose here instead)"; has "Esc while waiting falls back to the list" "$(printf '%s' "$o" | sed -n '/=== b/,$p')" "Choose a look"; has "then Esc exits 10" "$o" "EXIT 10"
none_left "Esc closed the server"

echo "== browser detection matrix"
FO="$S/fakeopen"; rm -rf "$FO"; mkdir -p "$FO"; printf '#!/bin/sh\necho "$1" >> "${HH_URL_FILE:?}"\n' > "$FO/open"; chmod +x "$FO/open"
NO="$S/noopen"; rm -rf "$NO"; mkdir -p "$NO"; for f in /bin/* /usr/bin/* /usr/sbin/* /sbin/*; do b="${f##*/}"; case "$b" in open|xdg-open) continue ;; esac; [ -e "$NO/$b" ] || ln -s "$f" "$NO/$b"; done
mx() {   # mx NAME EXPECT_TEXT URL_EXPECTED(y|n) K=V...
  local n="$1" want="$2" u="$3"; shift 3; : > "$S/mxurl"
  local o; o="$(drive "$WH" 24 80 '[["wait","Choose a look|Waiting for",40],["sleep",2],["snap","a"],["key","ESC"],["key","ESC"],["sleep",1]]' HH_ARGS="--pick-look --web" HH_URL_FILE="$S/mxurl" HH_WEB_TIMEOUTS=60,60 "$@")"
  has "$n: message" "$o" "$want"
  if [ "$u" = y ]; then [ -s "$S/mxurl" ] && ok "$n: browser launched with a URL" || bad "$n: launch" "no URL recorded"; else [ -s "$S/mxurl" ] && bad "$n: launch" "browser launched" || ok "$n: no browser launched"; fi
  [ "$u" = y ] || has "$n: falls back to the terminal chooser" "$o" "Choose a look"
}
mx "open on PATH (no hook)" "Waiting for your choice" y PATH="$FO:/usr/bin:/bin"
mx "no open on PATH" "no 'open' command" n PATH="$NO"
mx "SSH_CONNECTION set, open present" "SSH session" n PATH="$FO:/usr/bin:/bin" SSH_CONNECTION="1.2.3.4 5 6.7.8.9 22"
mx "SSH_TTY set, open present" "SSH session" n PATH="$FO:/usr/bin:/bin" SSH_TTY=/dev/ttys001
mx "hook command fails" "the browser command failed (exit 1)" n HH_BROWSER_CMD="$FAILB"
mx "hook command missing" "the browser command could not run" n HH_BROWSER_CMD=/nonexistent/browser
mx "hook wins over SSH" "Waiting for your choice" y HH_BROWSER_CMD="$FB" SSH_CONNECTION=1
mx "hook wins over a missing open" "Waiting for your choice" y HH_BROWSER_CMD="$FB" PATH="$NO"
o="$(drive "$WH" 24 80 '[["wait","Choose a look",30],["snap","a"],["key","ESC"],["sleep",1]]' HH_ARGS=--pick-look PATH="$NO")"; hasnt "plain chooser without open: no browser row" "$o" "Open in the browser"
o="$(drive "$WH" 24 80 '[["wait","Choose a look",30],["snap","a"],["key","ESC"],["sleep",1]]' HH_ARGS=--pick-look PATH="$FO:/usr/bin:/bin")"; has "plain chooser with open: browser row" "$o" "Open in the browser"
none_left "matrix left nothing running"

echo "== triggers: first run, L key, classic menu"
fr() { :; }
nocfg; o="$(drive "$DEV" 24 80 '[["wait","What should I call you",120],["snap","hello"],["type","Sam"],["key","ENTER"],["wait","What do you do",15],["snap","role"],["type","mobile dev"],["key","ENTER"],["wait","Choose how I should look",30]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"
has "onboarding: hello first" "$o" "Hello there, I'm Hy"; has "onboarding: asks for a name" "$o" "What should I call you?"; has "onboarding: role question uses the name" "$o" "Nice to meet you, Sam"; has "onboarding: look question follows" "$o" "WAIT Choose how I should look ok"
cf() { env HOME="$DEV" HH_CONFIG="$DEV/.config/host-hygiene/config" "$HH" config get "$1"; }
eq "onboarding: name saved" "$(cf name)" Sam; eq "onboarding: role saved" "$(cf role)" "mobile dev"
nocfg; o="$(drive "$DEV" 24 80 '[["wait","What should I call you",120],["key","ENTER"],["wait","What do you do",15],["key","ENTER"],["wait","Choose how I should look",30]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"
eq "onboarding: empty answers skip and save nothing" "$(cf name)$(cf role)" ""; has "onboarding: skipping still reaches the look question" "$o" "WAIT Choose how I should look ok"
eq "config set name rejects '='" "$(env HOME="$DEV" "$HH" config set name 'a=b' >/dev/null 2>&1; echo $?)" 2
nocfg; o="$(drive "$DEV" 24 80 '[["wait","What should I call you",120],["key","ESC"],["wait","Choose how I should look",30],["snap","q"],["key","DOWN"],["key","ENTER"],["wait","Shall I start scanning",30],["snap","scanask"],["key","ENTER"],["wait","Set the limits",60],["key","ENTER"],["wait","Pick what to clear",60],["snap","after"]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"
has "first run: question comes first, before the scan" "$o" "Choose how I should look: in the browser, or here?"; has "first run: here option" "$o" "Choose here, in the terminal"; has "first run: keep option" "$o" "Keep the default"; hasnt "first run: no browser option over SSH" "$(printf '%s' "$o" | sed -n '/=== q/,/=== after/p')" "Open in the browser"
eq "first run: keep the default saves ui=guided" "$(grep -c '^ui=guided' "$DEV/.config/host-hygiene/config")" 1; has "first run: journey continues to Pick" "$o" "Pick what to clear"; has "first run: confirms the look chosen" "$o" "You chose the Guided journey look"; has "first run: asks before scanning" "$o" "Shall I start scanning this machine now?"
o="$(drive "$DEV" 24 80 '[["wait","Pick what to clear|Choose how I should look",120],["sleep",2],["snap","again"]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"; hasnt "second start: question not asked again" "$(printf '%s' "$o" | grep -v ^WAIT)" "Choose how I should look"; has "second start: straight to Pick" "$o" "Pick what to clear"
nocfg; o="$(drive "$DEV" 24 80 '[["wait","What should I call you",120],["key","ESC"],["wait","Choose how I should look",30],["key","ENTER"],["wait","Choose a look",20],["key","DOWN"],["key","ENTER"],["wait","Shall I start scanning",30],["snap","scanask"],["key","ENTER"],["sleep",8],["wait","● host-hygiene",60]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"
has "first run: here, then pick cockpit: TUI shows cockpit" "$o" "WAIT ● host-hygiene ok"; eq "first run: here saved cockpit" "$(ui_of "$DEV")" cockpit
nocfg; o="$(drive "$DEV" 24 80 '[["wait","What should I call you",120],["key","ESC"],["wait","Choose how I should look",30],["key","ESC"],["wait","Shall I start scanning",30],["snap","scanask"],["key","ENTER"],["wait","Set the limits",60],["key","ENTER"],["wait","Pick what to clear",60]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"
eq "first run: Esc saves nothing" "$(grep -c '^ui=' "$DEV/.config/host-hygiene/config")" 0
o="$(drive "$DEV" 24 80 '[["wait","What should I call you|Pick what to clear",120],["key","ESC"],["wait","Choose how I should look|Pick what to clear",30]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"; has "first run: Esc means asked again next time" "$o" "WAIT Choose how I should look|Pick what to clear ok"
o="$(drive "$DEV" 24 80 '[["wait","What should I call you",120],["key","ESC"],["wait","Choose how I should look",30],["snap","x"]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"; has "first run: question shown again after Esc" "$o" "Choose how I should look: in the browser, or here?"
nocfg; o="$(drive "$DEV" 24 80 '[["wait","Set the limits",120],["key","ENTER"],["wait","Pick what to clear|Choose how",60],["sleep",2],["snap","s"]]' HH_NO_PROMPT=1 SSH_CONNECTION=1)"
hasnt "HH_NO_PROMPT suppresses the question" "$o" "Choose how I should look"; eq "HH_NO_PROMPT: no ui= written" "$(grep -c '^ui=' "$DEV/.config/host-hygiene/config")" 0
cfg "ui=guided"; o="$(drive "$DEV" 24 80 '[["wait","Pick what to clear|Choose how I should look",120],["sleep",2]]' SSH_CONNECTION=1 HH_NO_PROMPT=0)"; hasnt "ui= already set: not asked" "$(printf '%s' "$o" | grep -v ^WAIT)" "Choose how I should look"
nocfg; o="$(drive "$DEV" 24 80 '[["wait","Set the limits",120],["key","ENTER"],["wait","Pick what to clear|Choose how",60],["sleep",2]]' HH_LOOK=cockpit SSH_CONNECTION=1 HH_NO_PROMPT=0)"; hasnt "HH_LOOK set: not asked" "$o" "Choose how I should look"
o="$(env HOME="$DEV" "$HH" </dev/null 2>&1 | head -3)"; hasnt "non-tty start never prompts" "$o" "Choose how"
nocfg; : > "$S/fr.url"
( drive "$DEV" 24 80 '[["wait","What should I call you",120],["key","ESC"],["wait","Choose how I should look",30],["key","ENTER"],["wait","Waiting for",30],["wait","Shall I start scanning",90],["snap","scanask"],["key","ENTER"],["sleep",12],["snap","end"]]' HH_BROWSER_CMD="$FB" HH_URL_FILE="$S/fr.url" HH_NO_PROMPT=0 > "$S/fr.out" 2>&1 & )
i=0; while [ $i -lt 1800 ] && [ ! -s "$S/fr.url" ]; do sleep 0.1; i=$((i+1)); done
URL="$(head -1 "$S/fr.url")"; PORT="${URL#http://127.0.0.1:}"; PORT="${PORT%%/*}"; TOKEN="${URL%/}"; TOKEN="${TOKEN##*/}"
eq "first run: browser answer opens the page, save -> 200" "$(post -d "$(B cockpit)" "${URL}save")" 200
i=0; while [ $i -lt 400 ] && ! grep -q '^ALIVE' "$S/fr.out"; do sleep 0.2; i=$((i+1)); done
eq "first run: browser answer saved cockpit" "$(ui_of "$DEV")" cockpit; has "first run: TUI continued in cockpit after the web save (no restart)" "$(cat "$S/fr.out")" "● host-hygiene"
curl -s -o /dev/null --max-time 3 "$URL"; eq "first run: server gone after save" "$?" 7
cfg "ui=guided"; o="$(drive "$DEV" 24 100 '[["wait","Pick what to clear",120],["sleep",1],["snap","keys"],["key","L"],["wait","Choose a look",20],["key","DOWN"],["key","ENTER"],["sleep",8],["wait","● host-hygiene",30],["snap","c"]]' SSH_CONNECTION=1)"
has "key line hints the L key" "$(printf '%s' "$o" | sed -n '/=== keys/,/=== c/p')" "L choose"; has "L opens the chooser in the TUI" "$o" "WAIT Choose a look ok"; has "TUI switches live to the saved look" "$o" "WAIT ● host-hygiene ok"; eq "L chooser saved cockpit" "$(ui_of "$DEV")" cockpit
cfg "ui=guided"; o="$(drive "$DEV" 24 80 '[["wait","Pick what to clear",120],["send","L"],["wait","Choose a look",20],["key","ESC"],["sleep",1],["snap","e"]]' SSH_CONNECTION=1)"; eq "L then Esc changes nothing" "$(ui_of "$DEV")" guided; has "L then Esc returns to the journey" "$(printf '%s' "$o" | sed -n '/=== e/,$p')" "Pick what to clear"
cfg "ui=guided"; : > "$S/l.url"
( drive "$DEV" 24 80 '[["wait","Pick what to clear",120],["send","L"],["wait","Choose a look",20],["key","ENTER"],["wait","Waiting for",30],["sleep",25],["snap","end"]]' HH_BROWSER_CMD="$FB" HH_URL_FILE="$S/l.url" > "$S/l.out" 2>&1 & )
i=0; while [ $i -lt 1800 ] && [ ! -s "$S/l.url" ]; do sleep 0.1; i=$((i+1)); done
URL="$(head -1 "$S/l.url")"; PORT="${URL#http://127.0.0.1:}"; PORT="${PORT%%/*}"; TOKEN="${URL%/}"; TOKEN="${TOKEN##*/}"
eq "L then browser: save -> 200" "$(post -d "$(B spacemap)" "${URL}save")" 200
i=0; while [ $i -lt 400 ] && ! grep -q '^ALIVE' "$S/l.out"; do sleep 0.2; i=$((i+1)); done
eq "L then browser saved spacemap" "$(ui_of "$DEV")" spacemap; has "L then browser: TUI now draws the Space map" "$(sed -n '/=== end/,$p' "$S/l.out")" "ticked"
HC="$S/menuhome"; rm -rf "$HC"; mkdir -p "$HC/.config/host-hygiene"; cp "$DEV/.config/host-hygiene/config" "$HC/.config/host-hygiene/config"
o="$(drive "$HC" 30 100 '[["wait","What would you like to do",60],["snap","m"],["key","DOWN"],["key","DOWN"],["key","DOWN"],["key","DOWN"],["key","DOWN"],["key","ENTER"],["wait","Choose a look",30],["key","ESC"],["wait","No change",20]]' HH_BIN="$HH" HH_CLASSIC=1 SSH_CONNECTION=1)"
has "classic menu has Change look" "$o" "Change look"; has "classic menu opens the chooser" "$o" "WAIT Choose a look ok"; has "classic menu: Esc says no change" "$o" "WAIT No change ok"
o="$(drive "$HC" 30 100 '[["wait","What would you like to do",60],["key","DOWN"],["key","DOWN"],["key","DOWN"],["key","DOWN"],["key","DOWN"],["key","ENTER"],["wait","needs the guided front end",20]]' HH_BIN="$H0/scripts/host-hygiene.sh" HH_CLASSIC=1)"; has "classic menu without the binary explains" "$o" "WAIT needs the guided front end ok"
none_left "nothing left running"
echo "passed $pass, failed $fail"; [ "$fail" = 0 ]
