#!/bin/bash
# Ka0s Drop Watcher M24 (review + audit remediation): what has actually landed, straight from git.
#
# An item is DONE when a commit whose subject opens with "<ID>: " exists in the
# repo that owns it (items.tsv column 3), on the run branch or the repo's
# default branch. A commit may carry several ids: "DW-10 + DW-11: ...".
# Items that legitimately land with no commit go in exceptions.tsv with a
# command in the reason column that proves the claim.
#
#   ./resume-state.sh          # summary per milestone
#   ./resume-state.sh -v       # also list every remaining item id
#   ./resume-state.sh M3       # one milestone
#
# Exit 0 always. The last line names the next items to hand a fresh run.

BASE=/mnt/d/Profile/Users/Tushar/Documents/GIT
BR=feat/2026-10-14-drop-watcher-review-audit
HERE="$(cd "$(dirname "$0")" && pwd)"
MANIFEST=$HERE/items.tsv
EXC=$HERE/exceptions.tsv
IDRE='^DW-[0-9A-Z]+$'

[ -r "$MANIFEST" ] || { echo "missing $MANIFEST"; exit 0; }

verbose=0; only=""
for a in "$@"; do
  case $a in
    -v) verbose=1 ;;
    M[0-9]*) only=$a ;;
  esac
done

declare -A landed excepted
for r in $(tail -n +2 "$MANIFEST" | cut -f3 | sort -u); do
  [ -d "$BASE/$r/.git" ] || continue
  refs=()
  for ref in $BR master main; do
    git -C "$BASE/$r" rev-parse --verify -q "$ref" >/dev/null 2>&1 && refs+=("$ref")
  done
  [ ${#refs[@]} -gt 0 ] || continue
  while IFS= read -r s; do
    case $s in *:*) ;; *) continue ;; esac
    head=${s%%:*}
    IFS='+' read -ra ids <<< "${head// /}"
    for id in "${ids[@]}"; do
      [[ $id =~ $IDRE ]] && landed["$r/$id"]=1
    done
  done < <(git -C "$BASE/$r" log --format='%s' "${refs[@]}" 2>/dev/null)
done

if [ -r "$EXC" ]; then
  while IFS=$'\t' read -r id reason; do
    [[ $id =~ $IDRE ]] && excepted[$id]=1
  done < "$EXC"
fi

total_done=0; total_all=0; next=""
for m in M24a M24b M24c M24d M24e M24f; do
  [ -n "$only" ] && [ "$only" != "$m" ] && continue
  todo=(); done_n=0
  while IFS=$'\t' read -r id mi repo title rest; do
    [ "$mi" = "$m" ] || continue
    if [ -n "${landed[$repo/$id]}" ] || [ -n "${excepted[$id]}" ]; then done_n=$((done_n+1)); else todo+=("$id"); fi
  done < <(tail -n +2 "$MANIFEST")
  n=$((done_n + ${#todo[@]}))
  [ $n -eq 0 ] && continue
  total_done=$((total_done + done_n)); total_all=$((total_all + n))
  state="not started"; [ $done_n -gt 0 ] && state="in flight"; [ ${#todo[@]} -eq 0 ] && state="COMPLETE"
  printf '%-3s %3d/%-3d  %s\n' "$m" "$done_n" "$n" "$state"
  [ $verbose -eq 1 ] && [ ${#todo[@]} -gt 0 ] && echo "     remaining: ${todo[*]}"
  [ -z "$next" ] && [ ${#todo[@]} -gt 0 ] && next="$m: ${todo[*]}"
done

echo
printf 'TOTAL %d/%d items landed\n' "$total_done" "$total_all"
if [ -n "$next" ]; then echo "RESUME at $next"; else echo "RESUME: all items landed; run the last milestone's checkpoint and ask the owner for the merge go-ahead"; fi
exit 0
