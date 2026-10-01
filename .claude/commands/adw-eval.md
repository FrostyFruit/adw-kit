---
description: Measure the loop itself, then PROPOSE (never silently apply) up to 3 improvements
---

Single job: measure how the loop is performing across all runs, find the problems that
keep recurring, and propose at most THREE changes to the workflow. You do NOT edit the
ADW commands in the same session that runs the eval.

## Why this exists
The loop improves the product. Nothing measures the loop unless you do. And the person
(or agent) running the loop cannot easily see its own blind spots, so this is the
scheduled look.

## Steps
1. Run the instrument: `node scripts/adw-eval.mjs`. It reads structured fields only.
   Never derive a statistic from prose notes.
2. Compare with the previous report in `docs/adw/evals/` (newest file). First eval is
   the baseline.
3. Interpret, in this order:
   - **Is the fresh reviewer still earning its cost?** Look at multi-round reviews and
     unscoped findings per run. A reviewer that stops finding things is either a better
     build stage or a reviewer that stopped looking. Work out which before celebrating.
   - **Which kinds of problem recur?** Classes, not one-offs: claims that did not match
     the change, missing tests that were claimed, the same gotcha hit twice. Classes drive
     proposals.
   - **Where does the time go?** Median minutes per stage, and the slowest runs.
   - **Is the loop refusing?** A loop that never says no is either well-fed or not looking.
4. Write `docs/adw/evals/EVAL_<YYYY-MM-DD>.md`: the numbers, the change since last time,
   and at most 3 proposals. Each proposal names the problem class, how many times it
   happened, the exact file or instruction it would change, and the **throwaway run**
   that will test it.
5. Hand the proposals to the human.

## The two rules
- **This command never edits `.claude/commands/adw-*.md`.** The session that measures
  must not be the session that rewrites the instructions.
- **No instruction change counts until a throwaway run has exercised it.** A throwaway
  run is a small practice ticket in a scratch branch or scratch repo that deliberately
  triggers the thing the change is meant to catch. If the change does not fire there,
  it will not fire for real.
