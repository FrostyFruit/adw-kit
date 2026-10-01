#!/usr/bin/env node
// adw-eval: the loop's own measurement instrument.
//
// Reads every run file in .claude/adw/runs/ and computes per-run and aggregate
// stats from STRUCTURED fields only: stage durations, challenge findings,
// review verdicts, diff sizes, criteria, verify attempts, refusals, terminal
// reasons. Prose notes are NOT parsed. A stat derived from narrative is an
// anecdote wearing a number.
//
// This script MEASURES; the /adw-eval command interprets. An instruction
// change that comes out of an eval does not count until a throwaway run has
// exercised it. The report says so every time it runs.
//
// Usage: node scripts/adw-eval.mjs [runs-dir]

import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const DIR = process.argv[2] ?? '.claude/adw/runs'

if (!existsSync(DIR)) {
  console.error(`adw-eval: no runs directory at ${DIR}`)
  process.exit(1)
}

const runs = []
for (const f of readdirSync(DIR).filter((f) => f.endsWith('.json')).sort()) {
  try {
    const doc = JSON.parse(readFileSync(join(DIR, f), 'utf8'))
    if (!doc.run_id) {
      console.error(`skipped (no run_id, not a run file): ${f}`)
      continue
    }
    runs.push(doc)
  } catch {
    console.error(`skipped (unparseable): ${f}`)
  }
}

if (runs.length === 0) {
  console.log('No runs yet. Start one with /adw-scout "<ticket>".')
  process.exit(0)
}

function stageDurations(run) {
  const out = {}
  for (const h of run.history ?? []) {
    if (typeof h.duration_seconds === 'number') {
      out[h.stage] = (out[h.stage] ?? 0) + h.duration_seconds
    }
  }
  return out
}

const rows = runs.map((r) => {
  const durations = stageDurations(r)
  const total = Object.values(durations).reduce((a, b) => a + b, 0)
  const rounds = r.challenge?.rounds ?? (r.challenge?.findings ? [r.challenge] : [])
  const findings = rounds.flatMap((x) => x.findings ?? [])
  const criteria = r.review?.criteria_results ?? []
  const unmet = criteria.filter((c) => c.met === false).length
  return {
    run: r.run_id,
    terminal: r.terminal_reason ?? r.status,
    total_min: Math.round(total / 60),
    build_min: Math.round((durations.build ?? 0) / 60),
    review_min: Math.round((durations.review ?? 0) / 60),
    ch_rounds: rounds.length,
    ch_findings: findings.length,
    ch_majors: findings.filter((f) => ['blocker', 'major'].includes(f.severity)).length,
    review_verdict: r.review?.verdict ?? '-',
    review_rounds: (r.history ?? []).filter((h) => h.stage === 'review').length,
    diff_lines: r.review?.diff_lines ?? null,
    criteria: criteria.length ? `${criteria.length - unmet}/${criteria.length}` : '-',
    unscoped: (r.review?.unscoped_findings ?? []).length,
    verify_attempts: r.verify?.attempt ?? null,
    reviewed_by: r.review?.reviewed_by ?? '-',
    refusals: (r.refusals ?? []).length,
    human_stops: (r.history ?? []).filter((h) => h.status === 'waiting').length,
  }
})

console.log('\n=== ADW runs (structured fields only) ===')
console.table(rows)

const reviewed = rows.filter((r) => r.review_verdict !== '-')
const agg = {
  runs_total: rows.length,
  runs_reviewed: reviewed.length,
  reviewed_by_fresh_agent: reviewed.filter((r) => r.reviewed_by === 'subagent').length,
  first_pass_approves: reviewed.filter((r) => r.review_rounds <= 1 && r.review_verdict === 'approve').length,
  multi_round_reviews: reviewed.filter((r) => r.review_rounds > 1).length,
  median_total_min: median(rows.map((r) => r.total_min).filter((n) => n > 0)),
  median_diff_lines: median(reviewed.map((r) => r.diff_lines).filter(Boolean)),
  challenge_majors: rows.reduce((a, r) => a + r.ch_majors, 0),
  unscoped_findings: rows.reduce((a, r) => a + r.unscoped, 0),
  verify_second_attempts: rows.filter((r) => (r.verify_attempts ?? 1) > 1).length,
  refusals_recorded: rows.reduce((a, r) => a + r.refusals, 0),
  human_stops: rows.reduce((a, r) => a + r.human_stops, 0),
}
console.log('\n=== Aggregate ===')
console.table([agg])

function median(ns) {
  if (!ns.length) return null
  const s = [...ns].sort((a, b) => a - b)
  const n = s.length
  return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
}

console.log(`\nInterpretation lives in /adw-eval. Reminder, printed every time:
AN INSTRUCTION CHANGE PROPOSED BY AN EVAL DOES NOT COUNT UNTIL A THROWAWAY RUN
HAS EXERCISED IT.`)
