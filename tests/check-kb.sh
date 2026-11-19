#!/bin/bash
# Checks kb/*.md entry blocks against the template and catalog.tsv. bash 3.2.
# FAIL (exit 1): entry lacks class / removal / source / size label / valid catalog-id.
# WARN only: catalog row with no KB entry.
HERE="$(cd "$(dirname "$0")" && pwd)"
KB="$HERE/../kb"; CAT="$HERE/../catalog/catalog.tsv"
fail=0; n=0
ids="$(grep -vE '^[[:space:]]*(#|$)' "$CAT" | cut -d'|' -f1)"
used=""
err() { echo "FAIL $1: $2"; fail=$((fail+1)); }

check_entry() {  # file id block
  local f="$1" id="$2" b="$3" v c
  n=$((n+1))
  v="$(printf '%s\n' "$b" | sed -n 's/^- class: *//p' | head -1)"
  case "$v" in safe-regenerable|ask-first|never) ;; *) err "$f:$id" "missing or invalid class '$v'" ;; esac
  printf '%s\n' "$b" | grep -qE '^- removal: *[^ ]' || err "$f:$id" "missing removal line (use 'none' if never removed)"
  printf '%s\n' "$b" | grep -qE '^- source: *[^ ]' || err "$f:$id" "missing source"
  v="$(printf '%s\n' "$b" | sed -n 's/^- size: *//p' | head -1)"
  case "$v" in *"measured here"*|*"reported online, http"*|*"(unverified)"*) ;; *) err "$f:$id" "size lacks label (measured here | reported online, URL | (unverified))" ;; esac
  c="$(printf '%s\n' "$b" | sed -n 's/^- catalog-id: *//p' | head -1)"
  if [ -z "$c" ]; then err "$f:$id" "missing catalog-id"
  elif [ "$c" != none ]; then
    printf '%s\n' "$ids" | grep -qx "$c" || err "$f:$id" "catalog-id '$c' not in catalog.tsv"
    [ "$c" = "$id" ] || err "$f:$id" "heading id must equal catalog-id '$c'"
    used="$used $c "
  fi
}

for f in "$KB"/*.md; do
  base="$(basename "$f")"
  case "$base" in README.md|INDEX.md|_TEMPLATE.md) continue ;; esac
  id=""; block=""
  while IFS= read -r line; do
    case "$line" in
      "### "*) [ -n "$id" ] && check_entry "$base" "$id" "$block"; id="${line#\#\#\# }"; block="" ;;
      "## "*) [ -n "$id" ] && check_entry "$base" "$id" "$block"; id=""; block="" ;;
      *) [ -n "$id" ] && block="$block
$line" ;;
    esac
  done < "$f"
  [ -n "$id" ] && check_entry "$base" "$id" "$block"
done

warn=0
for i in $ids; do
  case "$used" in *" $i "*) ;; *) echo "WARN catalog row '$i' has no KB entry"; warn=$((warn+1)) ;; esac
done
echo "kb entries: $n, failures: $fail, warnings: $warn"
[ "$fail" -eq 0 ]
