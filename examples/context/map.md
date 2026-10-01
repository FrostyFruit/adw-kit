# Map

## What lives where
- `src/signup.js`: signup validation (`validateSignup`)
- `src/messages.js`: every user-facing string (`MESSAGES`)
- `src/billing.js`: plan prices (`PRICES`, `priceFor`), PROTECTED
- `test/signup.test.js`, `test/billing.test.js`: node:test suites
- `scripts/check-copy.mjs`: 80-char limit on every `MESSAGES` value
- `scripts/adw-*.{sh,mjs}`: ADW helpers (gate, stamp, run file, eval)
- `CLAUDE.md`: rules for AI assistants (source of the protected path and copy rule)
- `README.md`: one-line description, Node 18+, `npm test`

## Which context file covers which concern
- stack.md: language, runtime, test runner
- commands.md: command table and the `## Gates` the verify stage runs
- architecture.md: modules and data flow
- conventions.md: style, file placement, test and commit conventions
- gotchas.md: known traps (Symptom / Cause / Fix)
- fragile.md: revert/hotfix history and the `## Protected` list
