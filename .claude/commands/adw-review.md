---
description: ADW step 6 - a FRESH agent that did not write the change judges it against the criteria
argument-hint: <run_id>
---

Single job: get the change judged against `plan.acceptance_criteria` **by a reviewer that
did not write it**, and record its verdict word for word. You do NOT change product code.

## You do not perform this review yourself

Every earlier stage happened in your context. You wrote the plan, argued for it and made
the build decisions. Asking you "is this criterion met?" asks the mind that already
convinced itself it was. **An agent cannot reliably catch a mistake it made itself.**

So dispatch a fresh subagent. It gets the acceptance criteria, the builder's claims, the
check results and the actual changes. It does NOT get the plan reasoning, the challenge
debate, or this conversation.

(No subagents in your tool? Open a brand-new session, paste the reviewer prompt below,
and bring back its JSON. That still counts as a fresh reviewer.)

## Resolve the run file
- run_id in $ARGUMENTS, else the most recently modified `.claude/adw/runs/*.json`.
- Read it. Confirm verify passed: every check tagged with the current `verify.attempt`
  has verdict `pass`. **Never review over a failed verify.**

## Steps

1. Stamp the start: `bash scripts/adw-stamp.sh <run_id> review start`

2. **Dispatch one subagent** (general purpose is fine) with this prompt, filling in
   `<repo_path>` (the absolute path of this repo, from `pwd`) and `<run_id>`:

   > Working directory: `<repo_path>`. `cd` there first. Do not read or change anything
   > outside it, and do not modify any file inside it: you are read-only.
   >
   > You are reviewing a change you did not write and know nothing about. You have no
   > context beyond this message and what you read from disk.
   >
   > 1. From `.claude/adw/runs/<run_id>.json` read ONLY these fields: `base_ref`,
   >    `plan.acceptance_criteria`, `plan.human_decisions`, `build.notes_for_reviewer`,
   >    `verify.checks`. Ignore everything else in that file.
   > 2. Read the actual changes yourself. **Do not accept anyone's summary of them.**
   >    - `git diff <base_ref> -- . ':(exclude).claude/adw'` shows every change to tracked
   >      files since the run started, committed or not, minus the run's own bookkeeping.
   >    - `git status --short --untracked-files=all -- . ':(exclude).claude/adw'` lists new
   >      files, which do NOT appear in `git diff`. Read every one in full.
   > 3. Report `diff_lines`: the number of changed lines you actually read (diff lines
   >    plus new-file lines). **If it is 0, return verdict "revise" with the reason
   >    "empty diff". Never approve a change you did not see.**
   > 4. For each acceptance criterion return `met: true|false` with **evidence**: a
   >    `file:line`, a quoted hunk, or a `verify.checks` entry. **A criterion with no
   >    evidence you can cite is `met: false`.** "It looks right" is not evidence.
   > 5. `build.notes_for_reviewer` are **claims under test**, not facts. Where a note and
   >    the actual change disagree, the change wins. Say so explicitly. If a note claims
   >    a test exists, find the test.
   > 6. Look for behaviour the change introduces that **no criterion asked for**. That is
   >    an unscoped finding even when every criterion passes.
   > 7. Return ONE JSON object and nothing else:
   >    `{ "verdict": "approve|revise|reject", "diff_lines": <int>, "criteria_results": [ { "criterion", "met", "evidence" } ], "unscoped_findings": [ "..." ] }`
   >
   > You must not ask for more context. If the fields above and the changes do not show
   > it, the answer is `met: false`.

3. **Write the subagent's JSON into `review` exactly as returned**
   (`node scripts/adw-run.mjs set <run_id> review -`). Extra keys it adds are kept. Do not
   edit it, soften it, or argue with a `met: false` you disagree with. If you can rewrite
   the verdict, the independence is decoration.

4. Then set `review.reviewed_by` to `"subagent"` (or `"self"` if you had to review in
   your own context, which is a weaker result the run must admit) and
   `review.final_round` (`"full"`, or `"delta"` on a delta round). The number of rounds
   is counted from history, so there is nothing else to count.

5. Close: `bash scripts/adw-stamp.sh <run_id> review end` (the stage did its job; the
   verdict lives in `review`), or `end blocked` on reject. Then `node scripts/adw-run.mjs note <run_id> "<one line>"`.
   Every review round gets its own start/end stamps.

6. Run `node scripts/adw-run.mjs check <run_id>`. It rejects an approve with
   `diff_lines` 0 and an approve over a failed verify.

## Verdicts
- **approve**: every criterion met, verify passed. Show the human every unscoped finding.
- **revise**: a criterion unmet but fixable. Back to build, then the delta round below.
- **reject**: the approach does not satisfy the ticket. Stop and tell the human.

If the reviewer adds prose around the JSON, record the JSON and summarise the prose in the
note. If it returns no usable JSON, record `verdict: "revise"` with the parse failure as
the reason. **Never substitute your own judgement for a reviewer that did not report.**

## The revise path: a delta round by the SAME reviewer

After build fixes the flagged items and verify passes again, resume the SAME reviewer
(context intact) rather than paying a new one to reread everything. Send it:

   > The build has fixed the items you flagged. Re-run the same `git diff` and
   > `git status` commands yourself and compare with what you reviewed. Never accept the
   > builder's summary of the fix. For EACH `met: false` and EACH finding you raised,
   > verify the fix on disk, and run any test the fix claims. Anything changed beyond the
   > flagged items is a new unscoped finding. Return the same JSON plus
   > `"review_mode": "delta"`. If the fix changes the approach instead of fixing the
   > flagged items, refuse and say a full round is needed.

A delta round is valid only if: the same reviewer's context is intact, the fix addressed
the flagged items rather than changing approach, and it is the first delta round. At most
one delta round per review. Otherwise dispatch a new fresh reviewer for a full round.

## Timestamps
Only `scripts/adw-stamp.sh` writes times. Never type one yourself.

## Next command
- approve: `/adw-handover <run_id>`
- revise: `/adw-build <run_id>`, then `/adw-verify <run_id>`, then back here for the delta round.
- reject: stop and report to the human.
