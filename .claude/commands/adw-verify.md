---
description: ADW step 5 - run the repo's REAL checks and record what actually happened
argument-hint: <run_id>
---

Single job: run every gate in the repo's gate list against the build and record the
real results. You do NOT change product code, and you do NOT describe a result you did
not observe.

## Resolve the run file
- run_id in $ARGUMENTS, else the most recently modified `.claude/adw/runs/*.json`.
- Read it and `.claude/adw/state.schema.json`.

## Load these context files first
- .claude/context/commands.md (the `## Gates` blocks are the list you run)
- .claude/context/gotchas.md

## Run every gate through the gate script. Never capture results by hand.

    bash scripts/adw-gate.sh --into <run_id> --name <name> --expect '<expect>' -- <command>

Copy `name`, `expect` and `command` from the gate's block in commands.md exactly. The
script runs the command, captures the exit code on the same line, checks the output for
proof of work, and appends the result to `verify.checks` itself. You never type a result.

Why this is mandatory: `some-check | tail -20; echo $?` reports the exit code of `tail`,
which is 0 no matter what the check did. And a test tool that crashes on startup can
still exit 0 with no tests run. The gate script catches both: a non-zero exit is `fail`,
and exit 0 without the expected marker is `suspect`. **Treat `suspect` as a failure.**

If you doubt the script itself: `bash scripts/adw-gate.sh --self-test`.

## Steps
1. Stamp the start: `bash scripts/adw-stamp.sh <run_id> verify start`
2. Set the attempt BEFORE running gates: 1 on the first pass, previous value plus one when
   you come back after a fix. `node scripts/adw-run.mjs set <run_id> verify.attempt 1`
   and, the first time, `node scripts/adw-run.mjs set <run_id> verify.max_attempts 3`.
   Re-attempts APPEND new checks. Never delete earlier ones: they are the record.
3. Run every gate whose `run_when` applies to `build.files_changed`. Skipping a gate is only
   allowed when its condition clearly does not apply; say which and why in the note.
4. Classify every check from this attempt that did not pass (see below). Set it with
   `node scripts/adw-run.mjs set <run_id> verify.checks.<index>.failure_class '"code"'`
   and `failure_evidence` the same way (index = position in the `verify.checks` array).
5. Last, check the run file itself:
   `bash scripts/adw-gate.sh --into <run_id> --name run-file --expect 'adw-run check: OK' -- node scripts/adw-run.mjs check <run_id>`
6. Close: `bash scripts/adw-stamp.sh <run_id> verify end` (or `end blocked`), then
   `node scripts/adw-run.mjs note <run_id> "<one line>"`.

**"Verify passed" means: every check tagged with the current `verify.attempt` has
verdict `pass`.** The review stage and `adw-run.mjs check` both use this definition.

## Classify every failure
For each check that did not pass, set `failure_class` and quote the output line that
justifies it in `failure_evidence`:
- **`code`**: a real defect (a failing test, a type error, a build error). A failure in a
  file you never touched is still `code`. It predates you, but it is real. Go back to build.
- **`environment`**: the machine, network or toolchain failed (out of memory, missing
  binary, registry timeout, a service not running). The change cannot fix it.
- **`unclassified`**: you cannot tell yet. It stays a failure until evidence decides it.

**`environment` NEVER means "skip this gate and continue."** It does not mean pass and it
does not mean go to review. Fix the environment and rerun the same gate. If you cannot fix
it, the run is blocked and a human needs to know. The classification decides what gets
fixed. It never decides whether the gate counts.

## Record every refusal
Whenever this stage declines to proceed, append with
`node scripts/adw-run.mjs append <run_id> refusals -`:
`{ "stage": "verify", "reason", "at" (from `date -u +%Y-%m-%dT%H:%M:%SZ`), "unaided", "recovered", "evidence" }`.
Never remove a refusal when a later attempt succeeds. A refusal the loop later recovered
from is still evidence that it said no on its own.

## Timestamps
Only `scripts/adw-stamp.sh` writes times. Never type one yourself.

## Next command
- On PASS: `/adw-review <run_id>`
- On FAIL with `code`: `/adw-build <run_id>` to fix, then verify again with the next
  attempt number. After `max_attempts`, end with `blocked`,
  `terminal_reason: "blocked_max_attempts"`, and stop.
- On FAIL with `environment` you cannot fix: end with `blocked`,
  `terminal_reason: "blocked_environment"`, tell the human exactly what failed.
- On `unclassified`: stop and gather evidence. Do not continue to review.
