---
description: ADW step 7 - write the handover and teach the codebase what this run learned
argument-hint: <run_id>
---

Single job: write the handover, feed what this run learned back into the context files,
and close the run. **This is the step that makes the loop compound.** Every lesson written
here is read by every future run before it touches anything.

## Resolve the run file
- run_id in $ARGUMENTS, else the most recently modified `.claude/adw/runs/*.json`.
- Read it. Confirm `review.verdict` is "approve". **Never hand over an unapproved run.**

## Load these context files first
- .claude/context/map.md
- .claude/context/gotchas.md
- .claude/context/fragile.md

## Steps
1. Stamp the start: `bash scripts/adw-stamp.sh <run_id> handover start`
2. Write `docs/adw/handovers/<run_id>.md`: the ticket, the human's decisions, what changed
   (`build.files_changed`), verify results, the review verdict, **every unscoped finding,
   every accepted risk from `plan.risky_assumptions`, and every open question**, and anything the next person should know.
   Short and specific.
3. Harvest lessons. For every surprise in this run (a challenge finding, a failed gate, a
   reviewer catch, a wrong assumption), ask: **would a future run make the same mistake?**
   If yes, add it to the right context file:
   - `gotchas.md`: `### <name>` then `Symptom:` / `Cause:` / `Fix:`
   - `fragile.md`: an area that proved easy to break
   - `commands.md`: a check that should become a gate (prove it with adw-gate.sh first)
   Do not duplicate an existing entry. Sharpen it instead.
4. **A lesson travels with its code.** The lessons from this run go in the SAME commit as
   the code they describe (step 7). If this work is on a branch that might never merge,
   label each lesson "applies once <branch> merges". A lesson pointing at code that never
   shipped is worse than no lesson: future runs will follow it.
5. Write the `handover` object with `node scripts/adw-run.mjs set <run_id> handover -`:
   doc_path, new_gotchas, context_files_updated, follow_up_tickets.
6. Close the run:
   - `node scripts/adw-run.mjs set <run_id> terminal_reason '"completed"'`
   - `bash scripts/adw-stamp.sh <run_id> handover end`, then `node scripts/adw-run.mjs note <run_id> "<one line>"`
   - `node scripts/adw-run.mjs set <run_id> stage '"done"'` and
     `node scripts/adw-run.mjs set <run_id> status '"passed"'`
   - `node scripts/adw-run.mjs check <run_id>` must print OK.
7. Tell the human what to commit, as ONE commit: the product changes, the run file
   (`.claude/adw/runs/<run_id>.json`), the handover doc and any context file you changed.
   Run files are committed on purpose: they are the history `/adw-eval` measures. Show the
   human the unscoped findings and follow-ups before they commit, and show them the
   lesson diff (`git diff -- .claude/context`): no reviewer has seen those lessons, and every
   future run will read them, so the human approves them. Suggest a message in the repo's
   usual style, for example `<fix|feat|chore>: <ticket summary> (ADW <run_id>)`.

## Pass / fail
- PASS: the handover doc exists, the run is closed as done, and the check prints OK.
- FAIL: review had not approved. End the stage with `blocked`, note why, STOP.

## Timestamps
Only `scripts/adw-stamp.sh` writes times. Never type one yourself.

## Next command
- On PASS: the run is complete. Next ticket: `/adw-scout "<ticket>"`.
  Every 10 runs or so: `/adw-eval`.
- On FAIL: return to the stage that failed.
