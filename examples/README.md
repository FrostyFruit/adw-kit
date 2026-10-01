# Examples: one real practice ticket

Everything in this folder was produced by the kit itself, on a small practice repo
(signup validation and pricing for a pretend SaaS). Nothing here was written by hand.

The ticket: **"add an annual version of the growth plan, billed yearly."** It is a one-line
change, but it touches `src/billing.js`, which the repo's own notes say must not change
without the founder's sign-off. It shows the parts of the loop that matter most:

- **`context/`**: the seven files `/adw-bootstrap` wrote after reading the practice repo,
  plus what earlier tickets added. Look at `commands.md` (the gates, including one that
  existed only as a sentence in the repo's docs) and `fragile.md` (the protected pricing
  file, and the history of a fix that was reverted in production).
- **`run-file.json`**: the whole run in one file. Worth reading in this order:
  - `plan.questions_for_human` and `plan.human_decisions`: the loop stopped and asked
    for sign-off before touching the pricing file, and recorded the answer.
  - `challenge.rounds`: round 1 (a fresh agent) raised one major. Nothing in the plan
    said "billed yearly", so a caller could charge the yearly price every month, a 12x
    overcharge. That became a new question for the human. Round 2 (the same agent)
    checked the fix and approved.
  - `verify.checks`: every result captured by the gate script, never typed.
  - `review`: the fresh reviewer's verdict, word for word, with evidence for each
    criterion and the things it noticed that nobody asked for.
  - `history`: every stage, timed by the clock. The two `plan / waiting` entries are
    the loop stopping to ask the human; the wait is not counted as work.
- **`handover.md`**: what the next person (or the next run) needs to know.
