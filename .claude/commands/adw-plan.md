---
description: ADW step 2 - turn a scouted run into a plan with testable acceptance criteria
argument-hint: <run_id>
---

Single job: write a plan into the run file whose acceptance criteria can be checked by
someone who never saw this conversation. You do NOT change product code, and you do NOT
make product decisions on the human's behalf.

## Resolve the run file
- If $ARGUMENTS is a run_id, use `.claude/adw/runs/$ARGUMENTS.json`.
- Otherwise use the most recently modified file in `.claude/adw/runs/`.
- Read it and `.claude/adw/state.schema.json`.

## Load these context files first
- .claude/context/architecture.md
- .claude/context/conventions.md
- .claude/context/fragile.md

## Steps
1. Stamp the start: `bash scripts/adw-stamp.sh <run_id> plan start`
2. Read the `scout` object, especially `unknowns`.
3. **Separate questions from assumptions.** For each unknown, decide:
   - a technical unknown you can settle by reading code: settle it.
   - a **product decision** (wording customers see, whether a field is required, prices,
     who gets access, anything a customer would notice): do NOT guess. Add it to
     `plan.questions_for_human` as a plain question with your suggested answer.
   - a **protected path**: if `files_to_touch` includes anything under `## Protected` in
     fragile.md, ask for sign-off: "May I edit <path> for this ticket?" If the human says
     no, end the stage with `blocked` and set `terminal_reason: "blocked_protected_area"`.

   **Size the plan to the change.** Use the fewest criteria that fully describe done. For
   a small fix, one criterion proving the fix (a test that fails without it) beats five
   about test methodology.
4. Write the `plan` object with `node scripts/adw-run.mjs set <run_id> plan -` the first
   time. When you come back to plan later, update single fields instead
   (`set <run_id> plan.acceptance_criteria -`) and add questions with
   `append <run_id> plan.questions_for_human -`. Never rewrite `plan.human_decisions`:
   the helper refuses to drop them.
   - `acceptance_criteria`: one per line, each one checkable. "Works well" is not a
     criterion. "Submitting an empty form shows the error and saves nothing" is.
   - `files_to_touch`: real paths from scout, or new files under an existing folder
   - `risky_assumptions`: technical things you are assuming that could be wrong
   - `out_of_scope`: what this ticket will NOT do (always state it)
   - `questions_for_human`: product decisions (may be empty)
5. **If any question in `questions_for_human` has no answer yet: STOP here.** Close the
   stage first with `bash scripts/adw-stamp.sh <run_id> plan end waiting` so the wait is
   not counted as work. Show the human each question with your suggested answer.
   Record ONE answer per question in `plan.human_decisions` as
   `{ question, answer, by }`, in the same order as the questions, appending with
   `append <run_id> plan.human_decisions -`. `by` is who answered (a name or a role), so
   a sign-off says whose it is. Keep `answer` word for word, except when the human says
   "go with your suggestion": then record the suggestion itself, as
   `Accepted suggestion: <your suggested answer>`, so the decision still makes sense if
   the question is edited later. If one reply answers
   several questions, record it against each. If a reply does not actually answer a
   question, ask that question again. Never record a non-answer as an answer. Then restart the stage
   (`bash scripts/adw-stamp.sh <run_id> plan start`), update the criteria to match the
   answers, and continue. Stopping for the human is not a refusal: do not record one.
6. If the challenge stage sent this back, address every blocker and major in the latest
   entry of `challenge.rounds` explicitly, and say how in the note. If a finding turns out
   to be a product decision, add it as a new question and go back to step 5.
7. Check: `node scripts/adw-run.mjs check <run_id>`, then close the stage:
   `bash scripts/adw-stamp.sh <run_id> plan end`, then `node scripts/adw-run.mjs note <run_id> "<one line>"`.

## Pass / fail
- PASS: acceptance_criteria is not empty, every files_to_touch path exists (or is a new
  file under an existing folder), out_of_scope is stated, and every question has an answer.
- FAIL: scout's unknowns block planning, or the criteria cannot be made testable.

## Write state even on failure
On FAIL: end the stage with `blocked`, set `terminal_reason`, name the blocker in the note, STOP.

## Timestamps
Only `scripts/adw-stamp.sh` writes times. Never type one yourself.

## Next command
- On PASS: `/adw-challenge <run_id>`
- On FAIL: stop and tell the human. Usually the fix is a sharper ticket and a new `/adw-scout`.
