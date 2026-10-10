export const meta = {
  name: 'dw-milestone',
  description: 'Drop Watcher: implement one milestone (items in order), independent review, fix confirmed findings',
  phases: [
    { title: 'Implement', detail: 'one agent per item, sequential, commits DW-NN' },
    { title: 'Review', detail: 'independent reviewers against spec + standard' },
    { title: 'Fix', detail: 'apply confirmed findings, gate, commit' },
  ],
}

const A = args
const REPO = '/mnt/d/Profile/Users/Tushar/Documents/GIT/DropWatcher'
const COMMON = `
You are building the WoW Retail addon "Ka0s Drop Watcher" in ${REPO} on branch feat/2026-10-10-drop-watcher-v1 (already checked out; verify with git branch --show-current and never switch branches).
Read first: ${REPO}/docs/superpowers/specs/2026-10-10-drop-watcher-v1-design.md (the spec) and ${REPO}/docs/superpowers/plans/2026-10-10-drop-watcher-v1.md (the plan, its "Rules of the run"). Once ${REPO}/CLAUDE.md exists, it governs too (standards compliance, green gate).
The Ka0s WoW Addon Standard: read it from the local checkout /mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards (NEW_ADDON.md, standards/NEW_ADDON_CONTEXT.md, standards/STANDARDS.md and the section files under standards/standards/); its master matches origin. Read sections on demand by following the index. NEVER copy the context pack into the addon. LibKa0s source + API docs: /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s (tag v1.71.0; docs/api/<Major>/). Good reference addons: ../LootHistory (window, tabs, parser, Compat), ../WhatGroup (small window addon), ../AuraMaster (options pages), ../MultiMeters (Compat.ChatSender).
Green gate before EVERY commit, run from ${REPO}: lua tests/run.lua (all pass) and luacheck . (0 warnings / 0 errors); no authored .lua over 1500 lines. Use US English everywhere in addon files (the kit's test_prose gate).
Commit each item separately with subject "<ID>: <summary>" and a body ending with exactly these two trailer lines:
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Hhzer7JyMRjWR6cFaLB7KV
Do NOT push, merge, tag or bump versions. Do not modify tests/_kit/ or libs/ (vendored). Extend tests/wow_mock.lua for new WoW APIs. Write tests first for pure logic. Keep functions small (aim CCN <= 10; hard limit 15).
Run heavy commands through the bounded runner: /home/tushar/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua and /home/tushar/.claude/dev-copilot/bin/ka0s-bounded luacheck . (a hook blocks unbounded luacheck).
Line endings: the repo pins CRLF in the working tree (.gitattributes) and the kit's test_eol checks it. Files you create with the Write tool are LF; after committing, re-normalize each new/edited file with: rm <file> && git checkout -- <file> (working tree only), and re-run the gate. Never use git add --renormalize on unrelated files.
Keep docs in step with code as you go (the standard requires it): when you add a module, message, event, setting, slash verb or Compat shim, update docs/ARCHITECTURE.md (module map / event subscriptions / documented deviations), the matching Tier 1/2 doc, docs/smoke-tests.md checks (owed, never marked passed), and regenerate docs/test-cases.md the way the scaffold did.
${A.extra || ''}
`

const ITEM_SCHEMA = { type: 'object', properties: {
  id: { type: 'string' }, committed: { type: 'boolean' }, commits: { type: 'array', items: { type: 'string' } },
  gate: { type: 'string', description: 'test totals + luacheck result from the final gate run' },
  notes: { type: 'string', description: 'decisions taken, deviations, anything the orchestrator must know' },
}, required: ['id', 'committed', 'gate', 'notes'] }

const REVIEW_SCHEMA = { type: 'object', properties: {
  summary: { type: 'string' },
  findings: { type: 'array', items: { type: 'object', properties: {
    severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
    item: { type: 'string' }, file: { type: 'string' }, line: { type: 'number' },
    issue: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'item', 'file', 'issue', 'fix'] } },
}, required: ['summary', 'findings'] }

phase('Implement')
const results = []
for (const it of A.items) {
  const r = await agent(`${COMMON}
YOUR ITEM: ${it.id} — ${it.title}
${it.notes || ''}
Earlier items in this milestone already landed: ${results.map(x => x && x.id).filter(Boolean).join(', ') || 'none'}. Check git log first; if ${it.id} already has a commit, verify it and finish anything missing rather than redoing it.
Implement the item fully per the spec sections it names, with tests, run the gate, and commit. Return the structured result.`,
    { label: `impl:${it.id}`, phase: 'Implement', schema: ITEM_SCHEMA })
  results.push(r)
  if (!r || !r.committed) { log(`${it.id} did not commit — stopping milestone for orchestrator review`); return { results, stopped: it.id } }
}

phase('Review')
const lenses = A.reviewLenses || [
  'spec conformance: does the code do exactly what the spec sections for these items say, including edge cases and the never-throw rule',
  'Ka0s standard compliance: layout, TOC, setup-file pattern, LibKa0s consumption (no hand-rolled subsystems), events via SafeRegisterEvent, secret-value safety, combat/taint, saved variables, US English, docs the standard requires for what was added',
  'correctness and WoW API usage: real Retail 12.x API names/signatures/return shapes, nil handling, timers, event payloads, performance in combat',
]
const reviews = await parallel(lenses.map((lens, i) => () => agent(`${COMMON}
You are an independent REVIEWER (read-only: do not edit or commit). Review the commits for milestone ${A.milestone} (items ${A.items.map(x => x.id).join(', ')}): use git log/diff on the branch since ${A.base}.
Lens: ${lens}.
Run the gate yourself to confirm it is green. Report only real, specific problems with file and line; no style nits. Severity: critical/high = wrong behavior, crash, taint, standard MUST violated; medium = likely bug or SHOULD violated; low = minor.`,
  { label: `review:${i + 1}`, phase: 'Review', schema: REVIEW_SCHEMA })))

const findings = reviews.filter(Boolean).flatMap(r => r.findings).filter(f => f.severity !== 'low')
const lows = reviews.filter(Boolean).flatMap(r => r.findings).filter(f => f.severity === 'low')
log(`${findings.length} medium+ findings, ${lows.length} low`)

phase('Fix')
let fix = null
if (findings.length) {
  fix = await agent(`${COMMON}
Independent reviewers reported these findings on milestone ${A.milestone}. For EACH: verify it against the code first; if real, fix it (with a test where sensible); if not real, say why. Commit fixes grouped by item with subject "<ITEM>: fix review — <summary>". Gate green before each commit.
Findings JSON:
${JSON.stringify(findings, null, 1)}
Return a summary listing each finding as fixed / rejected (with reason).`, { label: 'fix', phase: 'Fix', schema: { type: 'object', properties: {
    summary: { type: 'string' }, fixed: { type: 'number' }, rejected: { type: 'number' }, gate: { type: 'string' } }, required: ['summary', 'fixed', 'rejected', 'gate'] } })
}

const note = await agent(`In ${REPO}, add a git note on HEAD under ref ka0s-review summarizing the independent review of milestone ${A.milestone}: reviewers' summaries, finding counts, what was fixed/rejected. Use: git notes --ref=ka0s-review add -f -m "<text>" HEAD. Do not change any files or commits. Return the note text.
Reviewer summaries: ${JSON.stringify(reviews.filter(Boolean).map(r => r.summary))}
Fix result: ${JSON.stringify(fix)}
Low findings (not fixed, for the record): ${JSON.stringify(lows.map(l => l.file + ': ' + l.issue))}`, { label: 'note', phase: 'Fix', effort: 'low' })

return { results, reviews: reviews.filter(Boolean).map(r => ({ summary: r.summary, n: r.findings.length })), fix, lows: lows.length, note }
