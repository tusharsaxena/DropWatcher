#!/bin/bash
# usage: checkpoint.sh <M> "<label>"
set -e
cd /mnt/d/Profile/Users/Tushar/Documents/GIT/DropWatcher
B=/home/tushar/.claude/dev-copilot/bin/ka0s-bounded; P=docs/superpowers/plans/2026-10-10-drop-watcher-v1
[ -z "$(git status --porcelain)" ] || { echo DIRTY; git status --short; exit 1; }
T=$($B lua tests/run.lua 2>&1 | grep -E 'passed.*failed' | tail -1); L=$($B luacheck . 2>&1 | tail -1 | sed 's/\x1b\[[0-9;]*m//g')
echo "$T | $L"; echo "$T" | grep -q ' 0 failed' || { echo GATE-RED; exit 1; }
echo "$L" | grep -q '0 warnings / 0 errors' || { echo LINT-RED; exit 1; }
git notes --ref=ka0s-review show HEAD >/dev/null 2>&1 || echo "WARN: no review note on HEAD"
printf '%s\t%s\tDropWatcher %s: %s; %s\n' "$(date +%F)" "$2" "$(git rev-parse --short HEAD)" "$T" "$L" >> $P/checkpoints.tsv
git add $P/checkpoints.tsv && git commit -q -m "$(printf "Checkpoint $1: %s\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01Hhzer7JyMRjWR6cFaLB7KV" "$2")"
rm $P/checkpoints.tsv && git checkout -- $P/checkpoints.tsv
git notes --ref=ka0s-review copy HEAD~1 HEAD 2>/dev/null || true
git push -q origin feat/2026-10-10-drop-watcher-v1 2>&1 | grep -v '^remote: *$' || true
git push -q -f origin refs/notes/ka0s-review 2>&1 | grep -v '^remote: *$' || true
bash $P/resume-state.sh | tail -9
