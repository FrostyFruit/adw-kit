---
description: ADW step 4 - implement exactly the approved plan and record what changed
argument-hint: <run_id>
---

Single job: implement the approved plan, then record what changed and anything that
differs from the plan. This is the ONLY stage that changes product code.

## Resolve the run file
- run_id in $ARGUMENTS, else the most recently modified `.claude/adw/runs/*.json`.
- Read it and `.claude/adw/state.schema.json`.
- Confirm `challenge.verdict` is "approve". If not, STOP.

## Load these context files first
- .claude/context/conventions.md
- .claude/context/architecture.md
- .claude/context/gotchas.md
- .claude/context/fragile.md

## Steps
1. Stamp the start: `bash scripts/adw-stamp.sh <run_id> build start`
2. Read the findings of every entry in `challenge.rounds`, **including the minors**. An approve means "no blockers",
   not "nothing to handle". For each finding: handle it, say in `notes_for_reviewer` that
   the revised plan already absorbed it, or record why not in `deviations_from_plan`.
3. Implement `plan.acceptance_criteria` and honour `plan.human_decisions`, touching only
   `plan.files_to_touch`. If you must add a file the plan did not list, add it and record
   it as a deviation.
4. If the work requires a path in fragile.md's `## Protected` section that the human has
   not approved in `plan.human_decisions`, STOP and ask. Do not proceed on your own judgement.
5. Write tests for the criteria that can be tested, following the repo's conventions.
   Include the edge cases the challenge raised.
6. Do NOT commit. The reviewer reads the change as it stands against `base_ref`.
7. Write the `build` object with `node scripts/adw-run.mjs set <run_id> build -`:
   - `files_changed`: every file you created, edited or deleted
   - `deviations_from_plan`: anything you did differently, and why
   - `notes_for_reviewer`: what you believe you did. Be precise. The reviewer will
     treat every note as a claim to check against the actual changes, so a note that
     says "added tests for X" must point at a test that exists.
8. Check: `node scripts/adw-run.mjs check <run_id>` (it fails if `files_changed` names a
   file that does not exist), then close: `bash scripts/adw-stamp.sh <run_id> build end`,
   then `node scripts/adw-run.mjs note <run_id> "<one line>"`.

## Pass / fail
- PASS: every acceptance criterion implemented and `files_changed` recorded truthfully.
- FAIL: blocked by a protected path, a missing decision, or an impossible criterion.

## Write state even on failure
On FAIL: end the stage with `blocked`, set `terminal_reason`, record the partial
`files_changed` and the blocker, STOP.

## Timestamps
Only `scripts/adw-stamp.sh` writes times. Never type one yourself.

## Next command
- On PASS: `/adw-verify <run_id>`
- On FAIL: stop and surface the blocker to the human.
