---
description: ADW step 1 - scout a ticket, create its run file, hand to plan
argument-hint: <ticket description>
---

Single job: turn the ticket in $ARGUMENTS into a new run file and find the real parts of
the codebase it will touch. You do NOT change product code.

## Load these context files first
- .claude/context/map.md
- .claude/context/architecture.md
- .claude/context/fragile.md
- .claude/context/gotchas.md

If `.claude/context/` does not exist, STOP and tell the human to run `/adw-bootstrap` first.

## How to write to the run file
Never hand-edit the JSON. Use the helper, with a quoted heredoc so no quoting can break:

    node scripts/adw-run.mjs set <run_id> <section> - <<'JSON'
    { ... }
    JSON

## Steps
0. Run `git status --short`. If there are uncommitted changes, STOP and ask the human to
   commit or stash them first. The reviewer compares against the commit this run starts
   from, so anything already uncommitted would be judged as part of this ticket.
1. Mint a run_id: `date -u +%Y%m%d-%H%M%S` plus `-` and a short kebab-case slug of the ticket.
2. Read `.claude/adw/state.schema.json`, then create `.claude/adw/runs/<run_id>.json` with:
   - `run_id`
   - `ticket`: { id (the run_id, or a ticket id if given), type (feature, bug, chore, hotfix
     or refactor: pick the closest), summary ($ARGUMENTS), source (optional: where it came from) }
   - `base_ref`: the output of `git rev-parse HEAD` right now
   - `stage`: "scout", `status`: "in_progress", `history`: []
   This is the one write you do by hand, because the file does not exist yet.
3. Stamp the start: `bash scripts/adw-stamp.sh <run_id> scout start`
4. Scout read-only (read, search, `git log`): the real files this ticket touches, the
   relevant docs, every gotcha or fragile area it lands in, and open unknowns. When an
   unknown is really a product decision (what customers see, whether something is
   required, pricing), say so in its text: plan will need the human to answer it.
5. Write the `scout` object: surface_files, relevant_docs, gotchas_hit, unknowns.
6. Check the file: `node scripts/adw-run.mjs check <run_id>`
7. Close the stage: `bash scripts/adw-stamp.sh <run_id> scout end` (or `end blocked`),
   then `node scripts/adw-run.mjs note <run_id> "<one line>"`.

## Pass / fail
- PASS: `adw-run.mjs check` prints OK, `scout.surface_files` is not empty, and every listed
  path actually exists. Check before writing. Never invent a path.
- FAIL: no surface file can be identified, or the ticket is too vague to scope.

## Write state even on failure
On FAIL: end the stage with `blocked`, set `terminal_reason`, say what is missing in the note, STOP.

## Timestamps
Only `scripts/adw-stamp.sh` writes times. Never type a timestamp yourself: an agent once
invented five, all plausible, none real. You cannot improve a loop you cannot time.

## Next command
- On PASS: `/adw-plan <run_id>`
- On FAIL: stop and tell the human which unknowns block scoping.
