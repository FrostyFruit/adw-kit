# Architecture

Small library, three modules, no server, no database, no external services, no env vars.

- `src/signup.js`: `validateSignup({ email, password })` returns an array of error
  strings (empty = valid). Pulls every message from `src/messages.js`.
- `src/messages.js`: `MESSAGES`, the single home of every user-facing string.
- `src/billing.js`: `PRICES` map (plan key -> price, no billing interval; `growth_annual`
  is a yearly amount) and `priceFor(plan)`, which throws
  `unknown plan: <plan>` for a key not in `PRICES`. PROTECTED (see fragile.md).

Data flow: caller -> `validateSignup` -> `MESSAGES`; caller -> `priceFor` -> `PRICES`.
There are no entry points (routes, handlers, CLIs) in this repo; callers are external.

Tests: `test/<module>.test.js`, one per source module.
Scripts: `scripts/check-copy.mjs` imports `MESSAGES` and enforces the 80-char limit.
