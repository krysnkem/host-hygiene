#!/usr/bin/env bash
# Sourced by check-look.sh (needs ok/bad/has/hasnt/eq, $D $S $PY $HH). Pty matrix for every look on fake homes in $S only: stages pick/confirm/work/done/quit at 24x80, 30x100 and the look's own minimum, live resize, CJK home, HH_ASCII, the switch keys, V saving, :look, Dashboard polling (PATH shim).
DR="$PY $D/tests/look-drive.py"; HMAKE="$D/tests/make-dev-home.sh"; MH="$S/mh"
mkhome() { bash "$HMAKE" "$MH" >/dev/null; mkdir -p "$MH/.config/host-hygiene"; printf 'min_free_gb=1\nhard_gb=0.5\nmax_load=999\n%s' "${1:-}" > "$MH/.config/host-hygiene/config"; }
blk() { awk -v n="$2" '$0=="=== "n{f=1;next} /^(=== |WAIT |RESIZE_MS|ALIVE)/{f=0} f' "$1"; }
dr() { local o="$1" r="$2" c="$3" st="$4"; shift 4; $DR "$MH" "$r" "$c" "$st" "$@" > "$o" 2>&1; }
MIN_guided=6x30; MIN_cockpit=16x60; MIN_dashboard=14x60; MIN_spacemap=10x40; MIN_console=10x50   # ROWSxCOLS
pm() { case "$1" in spacemap) echo "440M" ;; *) echo "[ ]" ;; esac; }   # what shows once the pick stage is up
dn="Free space|Free:|Cleared"
FIVE="guided cockpit dashboard spacemap console"
sec() { [ -z "${HH_SECTIONS:-}" ] && return 0; case " $HH_SECTIONS " in *" $1 "*) return 0 ;; esac; return 1; }   # HH_SECTIONS="resize poll" runs only those
if sec stage; then
echo "== stage matrix: pick, confirm, work, done, quit (each look x 24x80, 30x100, min)"
WALK='[["wait","$PICK",150],["snap","pick"],["key","s"],["key","ENTER"],["wait","Remove",20],["snap","confirm"],["key","RIGHT"],["key","ENTER"],["snap","work"],["wait","$DN",90],["snap","done"],["key","q"],["sleep",1.5]]'
for L in $FIVE; do for sz in 24x80 30x100 min; do
  [ "$sz" = min ] && { v="MIN_$L"; sz="${!v}"; }
  mkhome; o="$S/w-$L-$sz.txt"; dr "$o" "${sz%x*}" "${sz#*x}" "$(w=${WALK//\$PICK/$(pm $L)}; echo "${w//\$DN/$dn}")" HH_LOOK="$L"; t="$(cat "$o")"; tag="$L $sz"
  has "$tag pick list drawn" "$(blk "$o" pick)" "$(pm $L)"; hasnt "$tag no fallback hint at its own size" "$(blk "$o" pick)" "Too small for"
  has "$tag reached confirm" "$t" "WAIT Remove ok"; has "$tag reached done" "$t" "WAIT $dn ok"; has "$tag quit ends the process" "$t" "ALIVE false"
  [ -e "$MH/Library/Developer/Xcode/DerivedData/Runner-abc" ] && bad "$tag apply ran on the fake home" "DerivedData still there" || ok "$tag apply ran on the fake home"
  [ -e "$MH/.android/avd/Pixel_Fake.avd" ] && ok "$tag ask-first item untouched" || bad "$tag ask-first item untouched" "avd gone"
done; done
fi
if sec resize; then
echo "== live resize repaints within 300 ms (all five looks; was up to 3.5 s)"
for L in $FIVE; do
  mkhome; o="$S/rs-$L.txt"; dr "$o" 30 100 '[["wait","'"$(pm $L)"'",150],["settle",3],["resize",24,80],["snap","small"],["resize",30,100],["snap","big"]]' HH_LOOK="$L"
  ms="$(grep RESIZE_MS "$o" | head -1 | awk '{print $2}')"; [ -n "$ms" ] && [ "$ms" -ge 0 ] && [ "$ms" -le 300 ] && ok "$L resize to 24x80 settled in ${ms} ms" || bad "$L resize settle" "got '$ms' ms"
  ms="$(grep RESIZE_MS "$o" | tail -1 | awk '{print $2}')"; [ -n "$ms" ] && [ "$ms" -ge 0 ] && [ "$ms" -le 300 ] && ok "$L resize back settled in ${ms} ms" || bad "$L resize back" "got '$ms' ms"
  rows="$(blk "$o" small | wc -l | tr -d ' ')"; [ "$rows" -le 24 ] && ok "$L fits 24 rows after shrinking" || bad "$L fits 24 rows" "$rows lines"
done
fi
if sec cjk; then
echo "== CJK home and HH_ASCII"
for L in $FIVE; do
  mkhome; mv "$MH/work" "$MH/家目录"; mkdir -p "$MH/work"; o="$S/cjk-$L.txt"; dr "$o" 30 100 '[["wait","'"$(pm $L)"'",150],["snap","pick"],["key","q"],["sleep",1]]' HH_LOOK="$L"
  has "$L CJK home draws" "$(blk "$o" pick)" "$(pm $L)"; has "$L CJK home quits" "$(cat "$o")" "ALIVE false"
  mkhome; o="$S/asc-$L.txt"; dr "$o" 30 100 '[["wait","'"$(pm $L)"'",150],["snap","pick"],["key","q"],["sleep",1]]' HH_LOOK="$L" HH_ASCII=1 LANG=C LC_ALL=C
  b="$(blk "$o" pick)"; has "$L ASCII pick draws" "$b" "$(pm $L)"; printf '%s' "$b" | grep -q '[^ -~]' && bad "$L HH_ASCII has only ASCII" "non-ASCII glyph drawn" || ok "$L HH_ASCII has only ASCII"
done
fi
if sec switch; then
echo "== switch keys"
mkhome; o="$S/sw.txt"; rm -f "$MH/.config/host-hygiene/ui.chk"
dr "$o" 30 100 '[["wait","[ ]",150],["key","DOWN"],["key","DOWN"],["key","SPACE"],["snap","g"],["key","v"],["snap","cockpit"],["key","v"],["snap","dashboard"],["key","v"],["snap","spacemap"],["key","v"],["snap","console"],["key","v"],["snap","back"],["key","q"],["sleep",1]]'
for pair in "cockpit:Cockpit" "dashboard:Dashboard" "spacemap:Space map" "console:Console"; do n="${pair%%:*}"; w="${pair#*:}"; has "v reaches $n" "$(blk "$o" $n)" "$w"; if [ "$n" = spacemap ]; then has "v to $n keeps the tick" "$(blk "$o" $n)" "35M ticked"; else has "v to $n keeps the tick" "$(blk "$o" $n)" "35M"; fi; done
has "v cycles back to guided" "$(blk "$o" back)" "Hy"; has "v keeps the cursor row (3rd item)" "$(blk "$o" back | grep -F '[x]')" "~/work/web/node_modules"
hasnt "v alone does not save" "$(cat "$MH/.config/host-hygiene/config")" "ui="
has "cockpit hint names the look" "$(blk "$o" cockpit)" "v look: Cockpit"
mkhome; o="$S/sw2.txt"; dr "$o" 30 100 '[["wait","[ ]",150],["key","V"],["sleep",3],["snap","saved"],["key","q"],["sleep",1]]'
has "V saves the next look" "$(cat "$MH/.config/host-hygiene/config")" "ui=cockpit"; has "V says so" "$(blk "$o" saved)" "saved Cockpit as the default"
eq "config get ui after V" "$(env -u HH_LOOK HH_CONFIG="$MH/.config/host-hygiene/config" "$HH" config get ui)" cockpit
mkhome; o="$S/sw3.txt"; dr "$o" 12 55 '[["wait","[ ]",150],["key","v"],["snap","skip"],["key","q"],["sleep",1]]'
has "v skips looks that do not fit 12x55 (-> spacemap)" "$(blk "$o" skip)" "Space"
mkhome; o="$S/sw4.txt"; dr "$o" 12 45 '[["wait","[ ]",150],["key","v"],["snap","none"],["key","q"],["sleep",1]]'
has "v at 12x45 reaches spacemap only (40x10)" "$(blk "$o" none)" "Space"
mkhome; o="$S/sw5.txt"; dr "$o" 7 35 '[["wait","[ ]",150],["key","v"],["snap","tiny"],["key","q"],["sleep",1]]'
has "v at 7x35: nothing fits, stays and says so" "$(blk "$o" tiny)" "no other look fits"
fi
if sec console; then
echo "== console prompt: v is text; :look switches; Space map Tab/e only there"
mkhome; o="$S/con.txt"
dr "$o" 30 100 '[["wait","[ ]",150],["key",":"],["key","v"],["key","v"],["snap","typing"],["key","ESC"],["snap","esc"],["key",":"],["type","look cockpit"],["key","ENTER"],["snap","cmd"],["key","q"],["sleep",1]]' HH_LOOK=console
has "console prompt shows typed v" "$(blk "$o" typing)" ":vv"; hasnt "v typed at the prompt does not switch" "$(blk "$o" typing)" "Cockpit"; has "console still console after Esc" "$(blk "$o" esc)" "sort"
has ":look cockpit switches" "$(blk "$o" cmd)" "Cockpit"; has "v hint on cockpit" "$(blk "$o" cmd)" "v look: Cockpit"
mkhome; o="$S/con2.txt"; dr "$o" 30 100 '[["wait","[ ]",150],["key",":"],["type","look nope"],["key","ENTER"],["snap","bad"],["key","q"],["sleep",1]]' HH_LOOK=console
has ":look nope is an error" "$(blk "$o" bad)" "usage: :look"
mkhome; o="$S/sm.txt"; dr "$o" 30 100 '[["wait","440M",150],["snap","a"],["key","e"],["snap","b"],["key","TAB"],["snap","c"],["key","q"],["sleep",1]]' HH_LOOK=spacemap
has "spacemap starts expanded" "$(blk "$o" a)" "[expanded]"; has "e collapses the map" "$(blk "$o" b)" "[collapsed]"; has "Tab expands it again" "$(blk "$o" c)" "[expanded]"
for L in guided cockpit dashboard console; do mkhome; o="$S/et-$L.txt"; dr "$o" 30 100 '[["wait","'"$(pm $L)"'",150],["settle",2],["snap","a"],["key","e"],["key","TAB"],["snap","b"],["key","q"],["sleep",1]]' HH_LOOK="$L"
  [ "$(blk "$o" a | grep -c '\[x\]')" = "$(blk "$o" b | grep -c '\[x\]')" ] && ok "$L ignores e and Tab" || bad "$L ignores e and Tab" "ticks changed"; hasnt "$L has no map mode" "$(blk "$o" b)" "[collapsed]"; done
fi
if sec poll; then
echo "== Dashboard poll timer: runs only while the look is shown"
SH="$S/shim"; rm -rf "$SH"; mkdir -p "$SH"; for c in uptime df ps; do printf '#!/bin/sh\necho "$(date +%%s) %s $*" >> "$SHIMLOG"\nexec /usr/bin/%s "$@"\n' "$c" "$c" > "$SH/$c"; [ -x "/bin/$c" ] && sed -i '' "s#/usr/bin/$c#/bin/$c#" "$SH/$c"; chmod +x "$SH/$c"; done
mkhome; SHIMLOG="$S/shim.log"; : > "$SHIMLOG"
$DR "$MH" 30 100 '[["wait","[ ]",150],["sleep",2],["snap","m0"],["mark","a0"],["sleep",24],["mark","a1"],["key","v"],["snap","m2"],["mark","b0"],["sleep",24],["mark","b1"],["key","v"],["key","v"],["key","v"],["key","v"],["snap","m4"],["mark","c0"],["sleep",24],["mark","c1"],["key","q"],["sleep",1]]' HH_LOOK=dashboard SHIMLOG="$S/shim.log" PATH="$SH:/usr/bin:/bin:/usr/sbin:/sbin" > "$S/poll.txt" 2>&1
mk() { grep "^MARK $1 " "$S/poll.txt" | awk '{print $3}'; }
cnt() { awk -v a="$(mk $1)" -v b="$(mk $2)" '$2=="uptime" && $1>=a && $1<=b' "$S/shim.log" | wc -l | tr -d ' '; }
na="$(cnt a0 a1)"; nb="$(cnt b0 b1)"; nc="$(cnt c0 c1)"
[ "$na" -ge 2 ] && ok "dashboard polls while shown ($na uptime spawns in 24 s)" || bad "dashboard polls while shown" "$na spawns"
[ "$nb" = 0 ] && ok "no poll spawns after switching away (0 in 24 s)" || bad "poll stops when switched away" "$nb spawns"
[ "$nc" -ge 2 ] && ok "poll restarts on return ($nc spawns in 24 s)" || bad "poll restarts on return" "$nc spawns"
has "dashboard shown first" "$(blk "$S/poll.txt" m0)" "Dashboard"; has "v from dashboard -> spacemap" "$(blk "$S/poll.txt" m2)" "Space"; has "four more v back on dashboard" "$(blk "$S/poll.txt" m4)" "Dashboard"
fi
