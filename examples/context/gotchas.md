# Gotchas

### Hardcoded user-facing strings
Symptom: a message shown to users lives outside `src/messages.js`.
Cause: convenience; the rule is only written in CLAUDE.md.
Fix: put the string in `MESSAGES` and reference `MESSAGES.<key>`.

### Copy check is prose-only
Symptom: a long message ships, `npm test` is green.
Cause: `scripts/check-copy.mjs` (80-char max per message) is not in npm scripts or CI;
CLAUDE.md just says to run it before merging.
Fix: run the `copy-length` gate (commands.md) on every change.

### Signup error order matters
Symptom: callers / tests see errors in the wrong order.
Cause: `validateSignup` must push email errors before password errors (comment in
`src/signup.js`, commit 13ac449 "fix: signup error order again").
Fix: keep email checks above password checks; assert full arrays with `deepEqual`.

### Trimming the email broke valid signups
Symptom: valid emails rejected in production.
Cause: commit 82e81ce added `.trim()` to the email check; reverted in a9887b8
("broke valid emails in prod"). The exact mechanism is not recorded.
Fix: do not change email normalisation without a test reproducing the prod case.

### billing.js changes what customers pay
Symptom: a refactor or "small" edit changes a price.
Cause: `src/billing.js` holds the live price table.
Fix: do not edit without the founder's sign-off (CLAUDE.md). Protected in fragile.md.

### Plan keys carry no billing interval
Symptom: a yearly plan (e.g. `growth_annual: 990`) gets charged or shown as monthly.
Cause: `PRICES` in `src/billing.js` is a flat key -> amount map. `priceFor` returns a bare
number; the interval lives only in the key name, and the callers that charge are outside
this repo (run 20261001-061108-annual-growth-plan, challenge round 1 major).
Fix: when adding a non-monthly plan, ask the human who makes callers charge it on the
right cycle, record it as an accepted risk, and file the caller-side follow-up at handover.

### priceFor matches prototype keys
Symptom: `priceFor('toString')` returns a function instead of throwing `unknown plan`.
Cause: `src/billing.js` checks `plan in PRICES`, which walks the prototype chain.
Fix: keep negative billing tests to non-prototype names; the real fix (own-property
check) is an open follow-up that needs founder sign-off (protected file).
