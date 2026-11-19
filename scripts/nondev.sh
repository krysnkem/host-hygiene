# host-hygiene non-developer detectors. SOURCED by host-hygiene.sh (needs emit, kb, mtime, hr, age, ROWS). Read-only.
# Never modifies anything. Rows use classes ask-first / never and removal "report-only": apply cannot act on them
# (they are not catalog rows, so classify() refuses them). Seams (env) for tests:
#   HH_APPS_DIR (default /Applications:~/Applications, colon list)   HH_APP_LASTUSED_FILE (lines "path|YYYY-MM-DD", else mdls)
#   HH_APP_MIN_MB (200)  HH_APP_DAYS (180)   HH_OLD_DAYS (90) for Downloads
#   HH_LOGIN_ITEMS_FILE (one name per line)   HH_LOGIN_OSASCRIPT=1 (opt-in real source; may show a permission prompt)
#   HH_TMUTIL_FILE (fixture of `tmutil listlocalsnapshots /` output)

nd_epoch() {   # "YYYY-MM-DD[ HH:MM:SS +ZZZZ]" -> epoch, or 0
  local d="${1%% *}"; [ -n "$d" ] && date -j -f '%Y-%m-%d' "$d" +%s 2>/dev/null || echo 0
}
nd_lastused() {   # app path -> epoch of last use, 0 if unknown
  local app="$1" v
  if [ -n "${HH_APP_LASTUSED_FILE:-}" ]; then v="$(awk -F'|' -v p="$app" '$1==p{print $2; exit}' "$HH_APP_LASTUSED_FILE" 2>/dev/null)"
  else v="$(mdls -raw -name kMDItemLastUsedDate "$app" 2>/dev/null)"; fi
  case "$v" in ''|'(null)') echo 0 ;; *) nd_epoch "$v" ;; esac
}

# App size with a short-lived cache: du over /Applications is the single biggest cost of a scan (about 10 s for 75 apps, measured), and an installed
# bundle rarely changes. Key = path + Contents/Info.plist mtime + bundle mtime, valid 24 h, kept in $TMPDIR (the OS clears it; never in $HOME).
# Only real bundles (Contents/Info.plist present) are cached; HH_NO_CACHE=1 turns it off; any doubt means a fresh du.
nd_appkb() {
  local app="$1" cf k now v m
  cf="${ND_CF:=${HH_CACHE_DIR:-${TMPDIR:-/tmp}/host-hygiene-cache-$(id -u)}/app-sizes.tsv}"   # id forked once per run, not per app
  [ "${HH_NO_CACHE:-0}" = 1 ] || [ ! -f "$app/Contents/Info.plist" ] && { kb "$app"; return; }
  m="$(stat -f %m "$app/Contents/Info.plist" "$app" 2>/dev/null | paste -sd'	' -)"; k="$app	$m"; now="${ND_NOW:=$(date +%s)}"
  v="$(awk -F'\t' -v k="$k" -v n="$now" 'index($0, k "\t")==1 { if (n-$4 < 86400) r=$5 } END{ if (r!="") print r }' "$cf" 2>/dev/null)"
  [ -n "$v" ] && { echo "$v"; return; }
  v="$(kb "$app")"
  if [ -n "$v" ] && mkdir -p "$(dirname "$cf")" 2>/dev/null; then printf '%s\t%s\t%s\n' "$k" "$now" "$v" >> "$cf" 2>/dev/null; fi
  echo "$v"
}

nd_lastused_batch() {   # args: app paths -> lus[] (epoch or 0), same order. Seam file or a single mdls; falls back to one call per app if counts disagree
  local a v n=0 out
  lus=()
  if [ -z "${HH_APP_LASTUSED_FILE:-}" ]; then
    out="$(mdls -raw -name kMDItemLastUsedDate "$@" 2>/dev/null | tr '\0' '\n')"
    if [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "$#" ]; then
      while IFS= read -r v; do case "$v" in ''|'(null)') lus[$n]=0 ;; *) lus[$n]="$(nd_epoch "$v")" ;; esac; n=$((n+1)); done <<EOF3
$out
EOF3
      return 0
    fi
  fi
  for a in "$@"; do lus[$n]="$(nd_lastused "$a")"; n=$((n+1)); done
}

nondev_rows() {
  local i bigp bigs lus asz days="${HH_OLD_DAYS:-90}" adays="${HH_APP_DAYS:-180}" amb="${HH_APP_MIN_MB:-200}" now dir app lu mt f
  now="$(date +%s)"
  # old Downloads files: never deleted, listed with sizes
  if [ -d "$HOME/Downloads" ]; then
    # one find + batched stat + one awk (was du, stat and a printf-fork per file: 4897 files cost about 40 s). %b = 512-byte blocks, the number du -k rounds up from.
    find "$HOME/Downloads" -type f -mtime +"$days" -exec stat -f '%b|%m|%N' {} + 2>/dev/null |
      awk -F'|' -v n="older than ${days}d; never deleted by this tool, review by hand" '{ p=substr($0, length($1)+length($2)+3); printf "%d\tnever\tdownloads-old\t%s\t%s\treport-only\t%s\t-\n", int(($1+1)/2), p, $2, n }' >> "$ROWS"
  fi
  # large apps not used recently: report only, uninstall is manual
  for dir in $(printf '%s' "${HH_APPS_DIR:-/Applications:$HOME/Applications}" | tr ':' ' '); do
    [ -d "$dir" ] || continue
    bigp=(); bigs=(); lus=()
    for app in "$dir"/*.app; do
      [ -d "$app" ] || continue
      asz="$(nd_appkb "$app")"   # one du per app (it was two: the threshold test and the emitted row)
      [ "${asz:-0}" -ge $((amb*1024)) ] || continue
      bigp[${#bigp[@]}]="$app"; bigs[${#bigs[@]}]="$asz"
    done
    [ ${#bigp[@]} -gt 0 ] || continue
    nd_lastused_batch "${bigp[@]}"   # one mdls for all large apps of this dir (was one fork each); fills lus[]
    i=0
    while [ $i -lt ${#bigp[@]} ]; do
      app="${bigp[$i]}"; asz="${bigs[$i]}"; lu="${lus[$i]}"; i=$((i+1))
      if [ "$lu" -gt 0 ]; then [ $(( (now-lu)/86400 )) -ge "$adays" ] || continue; mt="$lu"; note="last used $(date -r "$lu" +%F)"
      else mt="$(mtime "$app")"; note="last-used date UNKNOWN (Spotlight has none for this app): NOT verified unused, check before uninstalling"; fi
      emit "$asz" ask-first app-large-unused "$app" "$mt" report-only "$note; uninstall by hand (drag to Trash), apps cannot be rebuilt, re-download or reinstall needed" "-"
    done
  done
}

nondev_report() {
  local f n s t line="$ROWS.s"
  echo "== login items (report only; to remove one use System Settings > General > Login Items; nothing is changed here)"
  if [ -n "${HH_LOGIN_ITEMS_FILE:-}" ]; then cat "$HH_LOGIN_ITEMS_FILE" 2>/dev/null | sed 's/^/  /'
  else
    if [ "${HH_LOGIN_OSASCRIPT:-0}" = 1 ]; then osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n' | sed 's/^ */  /'; fi
    for f in "$HOME"/Library/LaunchAgents/*.plist; do [ -e "$f" ] && echo "  launch agent: $(basename "$f")"; done
  fi | awk 'NF{print; n++} END{if(!n) print "  (none found)"}'
  echo "== downloads older than ${HH_OLD_DAYS:-90} days (class never: this tool never deletes them; largest 10)"
  awk -F'\t' '$3=="downloads-old"' "$line" 2>/dev/null | head -10 | while IFS="$(printf '\t')" read -r s c id path mt rem cost owner; do
    printf '  %7s  %5s  %s\n' "$(hr "$s")" "$(age "$mt")" "${path/#$HOME/~}"; done
  awk -F'\t' '$3=="downloads-old"{n++; t+=$1} END{if(n) printf "  %d file(s), %d KB total\n", n, t; else print "  (none)"}' "$line" 2>/dev/null
  echo "== large apps not used for ${HH_APP_DAYS:-180}+ days, >= ${HH_APP_MIN_MB:-200} MB (ask-first, report only; uninstall by hand; apps whose last use Spotlight does not know are listed too, marked UNKNOWN)"
  awk -F'\t' '$3=="app-large-unused"' "$line" 2>/dev/null | while IFS="$(printf '\t')" read -r s c id path mt rem cost owner; do
    printf '  %7s  %s  (%s)\n' "$(hr "$s")" "${path/#$HOME/~}" "$cost" | cut -c1-200; done
  echo "== Time Machine local snapshots (ask-first; report only here)"
  if [ -n "${HH_TMUTIL_FILE:-}" ]; then t="$(cat "$HH_TMUTIL_FILE" 2>/dev/null)"; else t="$(tmutil listlocalsnapshots / 2>/dev/null)"; fi
  n="$(printf '%s\n' "$t" | grep -c 'com.apple')"
  if [ "$n" -gt 0 ]; then
    printf '%s\n' "$t" | grep 'com.apple' | sed 's/^/  /'
    echo "  to remove ONE after you decide, by hand: tmutil deletelocalsnapshots <date as above>   (supported only with your explicit approval; macOS also thins them itself)"
  else echo "  none"; fi
}
