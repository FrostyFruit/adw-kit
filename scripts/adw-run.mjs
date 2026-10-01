#!/usr/bin/env node
// adw-run: write to a run file safely, and check that it tells the truth.
//
// WHY THIS EXISTS
// Hand-editing JSON through the shell breaks on quoting, and a run file that
// nobody checks drifts from what actually happened. This script does both jobs
// so the agent never has to improvise either.
//
// USAGE
//   node scripts/adw-run.mjs set <run> <path> -          value = JSON read from stdin
//   node scripts/adw-run.mjs set <run> <path> '<json>'   value = JSON argument
//   node scripts/adw-run.mjs append <run> <path> -       push stdin JSON onto an array
//   node scripts/adw-run.mjs note <run> "<text>"         set the note on the latest history entry
//   node scripts/adw-run.mjs check <run>                 exit 0 = consistent, 1 = problems
//
//   <run>  is a run_id (looked up in .claude/adw/runs/) or a path to the file.
//   <path> is dotted, e.g. plan, review.verdict, verify.attempt, refusals.
//
// Stdin with a quoted heredoc avoids every shell quoting problem:
//   node scripts/adw-run.mjs set <run_id> plan - <<'JSON'
//   { "acceptance_criteria": ["..."], "files_to_touch": ["src/a.js"] }
//   JSON

import { existsSync, readFileSync, renameSync, writeFileSync } from 'node:fs'
import { execSync } from 'node:child_process'

const [cmd, runArg, dotted, valueArg] = process.argv.slice(2)

function die(msg) {
  console.error(`adw-run: ${msg}`)
  process.exit(1)
}

function resolve(arg) {
  if (!arg) die('missing <run>')
  if (existsSync(arg)) return arg
  const p = `.claude/adw/runs/${arg}.json`
  if (existsSync(p)) return p
  die(`run file not found: ${arg} (looked in .claude/adw/runs/)`)
}

function load(file) {
  try {
    return JSON.parse(readFileSync(file, 'utf8'))
  } catch (e) {
    die(`unparseable run file ${file}: ${e.message}`)
  }
}

function save(file, doc) {
  const tmp = `${file}.tmp.${process.pid}`
  writeFileSync(tmp, JSON.stringify(doc, null, 2) + '\n')
  renameSync(tmp, file)
}

function readValue(arg) {
  const raw = arg === '-' ? readFileSync(0, 'utf8') : arg
  if (raw === undefined) die('missing value (pass JSON, or - to read stdin)')
  try {
    return JSON.parse(raw)
  } catch (e) {
    die(`value is not valid JSON: ${e.message}`)
  }
}

function walk(doc, path, create) {
  const keys = path.split('.')
  let node = doc
  for (const k of keys.slice(0, -1)) {
    if (node[k] === undefined) {
      if (!create) return [undefined, undefined]
      node[k] = {}
    }
    node = node[k]
  }
  return [node, keys.at(-1)]
}

if (cmd === 'set' || cmd === 'append') {
  if (!dotted) die(`usage: adw-run.mjs ${cmd} <run> <path> <json|->`)
  const file = resolve(runArg)
  const doc = load(file)
  const value = readValue(valueArg)
  const [parent, key] = walk(doc, dotted, true)
  if (cmd === 'set') {
    // Never let a rewrite of the plan drop what the human decided. Those answers
    // are the only record of a sign-off, and a re-plan that forgets them is how a
    // protected-file approval silently disappears.
    if (dotted === 'plan' && parent.plan && value && typeof value === 'object') {
      for (const k of ['questions_for_human', 'human_decisions']) {
        if (Array.isArray(parent.plan[k]) && parent.plan[k].length && value[k] === undefined) {
          value[k] = parent.plan[k]
          console.error(`adw-run: kept existing plan.${k} (${parent.plan[k].length}); the new plan did not include it`)
        }
      }
      const before = parent.plan.human_decisions?.length ?? 0
      if ((value.human_decisions?.length ?? 0) < before) die(`refused: this would remove recorded human decisions (${before} -> ${value.human_decisions.length}). Append instead.`)
    }
    parent[key] = value
  } else {
    if (parent[key] === undefined) parent[key] = []
    if (!Array.isArray(parent[key])) die(`${dotted} is not an array`)
    parent[key].push(value)
  }
  save(file, doc)
  console.log(`adw-run: ${cmd} ${dotted} in ${file}`)
} else if (cmd === 'note') {
  const file = resolve(runArg)
  const doc = load(file)
  const text = dotted === '-' ? readFileSync(0, 'utf8').trim() : dotted
  if (!text) die('usage: adw-run.mjs note <run> "<text>" (or - to read stdin)')
  const last = (doc.history ?? []).at(-1)
  if (!last) die('no history entry yet: close the stage with adw-stamp.sh first')
  last.note = text
  save(file, doc)
  console.log(`adw-run: note set on the latest history entry (${last.stage})`)
} else if (cmd === 'check') {
  const file = resolve(runArg)
  const d = load(file)
  const problems = []
  const bad = (m) => problems.push(m)

  const STAGES = ['scout', 'plan', 'challenge', 'build', 'verify', 'review', 'handover', 'done']
  const STATUSES = ['in_progress', 'passed', 'failed', 'blocked']
  const TERMINAL = ['completed', 'blocked_environment', 'blocked_max_attempts', 'blocked_protected_area',
    'blocked_needs_human_decision', 'rejected_unsound', 'abandoned']

  for (const k of ['run_id', 'ticket', 'base_ref', 'stage', 'status', 'history']) {
    if (d[k] === undefined) bad(`missing required field: ${k}`)
  }
  if (d.ticket && (!d.ticket.id || !d.ticket.type || !d.ticket.summary)) bad('ticket needs id, type and summary')
  if (d.ticket?.type && !['feature', 'bug', 'chore', 'hotfix', 'refactor'].includes(d.ticket.type)) bad(`ticket.type invalid: ${d.ticket.type}`)
  if (d.stage && !STAGES.includes(d.stage)) bad(`stage invalid: ${d.stage}`)
  if (d.status && !STATUSES.includes(d.status)) bad(`status invalid: ${d.status}`)
  if (d.base_ref && !/^[0-9a-f]{7,40}$/.test(d.base_ref)) bad(`base_ref is not a commit SHA: ${d.base_ref}`)

  // History: written by adw-stamp.sh, so every entry must be complete and in order.
  let prevEnd = null
  for (const [i, h] of (d.history ?? []).entries()) {
    if (!h.stage || !h.status || !h.started_at || !h.ended_at) bad(`history[${i}] incomplete (stamp with scripts/adw-stamp.sh)`)
    if (h.started_at && h.ended_at && h.ended_at < h.started_at) bad(`history[${i}] ends before it starts`)
    if (prevEnd && h.started_at && h.started_at < prevEnd) bad(`history[${i}] starts before the previous stage ended`)
    prevEnd = h.ended_at ?? prevEnd
  }

  const finished = d.stage === 'done' || d.status === 'blocked'
  if (finished && !TERMINAL.includes(d.terminal_reason)) bad('finished run needs a valid terminal_reason')
  if (finished && d.stamps && Object.keys(d.stamps).length) bad(`finished run has a stage that started and never ended: ${Object.keys(d.stamps).join(', ')}`)

  // Claims about files must be true while the run is live.
  if (!finished) {
    for (const f of d.build?.files_changed ?? []) {
      if (existsSync(f)) continue
      let deleted = false
      try { deleted = execSync(`git ls-files --deleted -- "${f}"`, { encoding: 'utf8' }).trim() !== '' } catch {}
      if (!deleted) bad(`build.files_changed claims a file that does not exist: ${f}`)
    }
  }

  // Plan questions must be answered before the run moves past plan.
  const pastPlan = STAGES.indexOf(d.stage) > STAGES.indexOf('plan')
  const questions = d.plan?.questions_for_human ?? []
  const answers = d.plan?.human_decisions ?? []
  if (pastPlan && questions.length > answers.length) bad(`${questions.length - answers.length} question(s) for the human are unanswered, but the run moved past plan`)

  // Verify: every check has an observed exit code and a verdict.
  for (const [i, c] of (d.verify?.checks ?? []).entries()) {
    if (!Number.isInteger(c.exit_code)) bad(`verify.checks[${i}] has no observed integer exit_code`)
    if (!['pass', 'fail', 'suspect'].includes(c.verdict)) bad(`verify.checks[${i}] verdict must be pass|fail|suspect (use adw-gate.sh --into)`)
    if (c.verdict && c.verdict !== 'pass' && !c.failure_class) bad(`verify.checks[${i}] (${c.name}) did not pass and has no failure_class`)
  }

  // Review: never an approval of nothing, never over a failed verify.
  if (d.review) {
    if (d.review.verdict === 'approve' && !(d.review.diff_lines > 0)) bad('review approved with diff_lines 0 or missing: a verdict about nothing')
    if (d.review.verdict === 'approve') {
      const attempt = d.verify?.attempt ?? 1
      const latest = (d.verify?.checks ?? []).filter((c) => (c.attempt ?? 1) === attempt)
      if (!latest.length) bad('review approved but verify recorded no checks')
      if (latest.some((c) => c.verdict !== 'pass')) bad('review approved over a verify check that did not pass')
    }
  }

  if (problems.length) {
    console.error(`adw-run check: ${problems.length} problem(s) in ${file}`)
    for (const p of problems) console.error(`  - ${p}`)
    process.exit(1)
  }
  console.log(`adw-run check: OK (${file})`)
} else {
  console.error('usage: adw-run.mjs set|append <run> <path> <json|->  |  note <run> <text>  |  check <run>')
  process.exit(2)
}
