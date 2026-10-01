---
description: ADW step 3 - a fresh agent attacks the plan before any code is written
argument-hint: <run_id>
---

Single job: get the plan attacked by an agent that did not write it, and record the
verdict. You do NOT change product code.

A problem found here costs minutes. The same problem found after shipping costs a bug
that already has a green tick beside it.

## Why a fresh agent
You wrote this plan. Asking you to break it asks the mind that just argued for it. So the
attack comes from a fresh subagent that sees the plan and the codebase, and none of the
reasoning behind it.

(No subagents in your tool? Open a brand-new session and paste the prompt below.)

## At most two rounds
- **Round 1** is a full attack by a fresh challenger.
- If it says `revise`, the plan is fixed, and **round 2** is a delta check by the SAME
  challenger (resumed, context intact): were its findings fixed, and did the fix break
  anything? A new fresh challenger every round never converges: each one finds something new.
- If round 2 still says `revise`, STOP and show the human the open findings. The human
  decides: proceed to build anyway, narrow the ticket, or abandon it. Record their answer
  in `plan.human_decisions`.

## Resolve the run file
- run_id in $ARGUMENTS, else the most recently modified `.claude/adw/runs/*.json`.
- Read it and `.claude/adw/state.schema.json`. Count existing `challenge.rounds` to know
  which round this is.

## Steps
1. Stamp the start: `bash scripts/adw-stamp.sh <run_id> challenge start`
2. **Round 1:** dispatch one subagent with this prompt, filling in `<repo_path>` (the
   absolute path of this repo, from `pwd`) and `<run_id>`:

   > Working directory: `<repo_path>`. `cd` there first. Do not read or change anything
   > outside it, and do not modify any file inside it: you are read-only.
   >
   > You are a devil's advocate. Someone wrote a plan for a code change. Your job is to
   > find how it fails for real users.
   >
   > 1. Read `.claude/adw/runs/<run_id>.json`: `ticket`, `scout` and `plan` only.
   > 2. Read `.claude/context/fragile.md`, `.claude/context/gotchas.md` and
   >    `.claude/context/conventions.md`, then open the files in `plan.files_to_touch`.
   > 3. Look for, where relevant to this change: edge cases the criteria miss (empty or
   >    missing input, wrong types, duplicates, the second time it runs, retries, two users
   >    at once), files missing from `files_to_touch`, criteria that cannot be checked,
   >    scope creep, every gotcha this plan walks into, and any path under `## Protected`
   >    in fragile.md that the human has not approved in `plan.human_decisions`.
   > 4. **Scale the attack to the ticket.** A three-line fix needs its edge cases and
   >    gotchas checked, not a test-methodology audit. Use these severities strictly:
   >    - `blocker`: would ship a bug users hit, lose or corrupt data, touch a protected
   >      path without approval, or make the ticket impossible as written.
   >    - `major`: a realistic input or situation the plan gets wrong, or a criterion that
   >      cannot be checked.
   >    - `minor`: everything else, including wording, test style and improbable inputs.
   > 5. Return ONE JSON object and nothing else:
   >    `{ "verdict": "approve|revise|reject", "findings": [ { "severity": "blocker|major|minor", "finding": "...", "suggested_fix": "..." } ] }`
   >    approve = no blockers or majors. revise = at least one the plan can absorb.
   >    reject = the ticket is unsound as scoped.

   **Round 2** (after a revise and a plan fix): resume the SAME challenger and send:

   > The plan was revised for your findings. Re-read `plan` in the run file. For each
   > blocker and major you raised: is it fixed? Did the revision introduce a new blocker
   > or major? Do not re-audit things you already accepted. Return the same JSON shape.

3. Record the round (append, never overwrite: earlier rounds are the record):

       node scripts/adw-run.mjs append <run_id> challenge.rounds - <<'JSON'
       { "round": 1, "mode": "full", "challenged_by": "subagent", "verdict": "...", "findings": [ ... ] }
       JSON

   Use `"mode": "delta"` for round 2, and `"challenged_by": "self"` if you had to do it in
   your own context (weaker, and the run must say so). Then mirror the verdict:
   `node scripts/adw-run.mjs set <run_id> challenge.verdict '"approve"'`.
   If the challenger added prose around the JSON, record the JSON and summarise the prose
   in the note. If it returned no usable JSON, record the round as `revise` with the parse
   failure as a finding. Never substitute your own verdict.
4. Close: `bash scripts/adw-stamp.sh <run_id> challenge end` (the stage did its job;
   the verdict lives in `challenge`). Use `end waiting` when stopping for the human after
   round 2, and `end blocked` on reject. Then `node scripts/adw-run.mjs note <run_id> "<one line>"`.

## Record a reject as a refusal
On `reject`, append to `refusals` with `node scripts/adw-run.mjs append <run_id> refusals -`:
`{ "stage": "challenge", "reason", "at" (from `date -u +%Y-%m-%dT%H:%M:%SZ`), "unaided": true, "evidence" }`.
A `revise` is NOT a refusal. It is normal iteration.

## Timestamps
Only `scripts/adw-stamp.sh` writes times. Never type one yourself.

## Next command
- approve: `/adw-build <run_id>` (build reads the findings of every round, minors included)
- revise after round 1: `/adw-plan <run_id>` to address the findings, then back here for round 2
- revise after round 2: stop and ask the human (see "At most two rounds")
- reject: stop and report to the human.
