# Conventions

- ES module syntax (`import` / `export`), named exports, no default exports.
- No semicolons, single quotes, 2-space indent (as in every file in src/ and test/).
- User-facing strings: add a key to `MESSAGES` in `src/messages.js` and reference it.
  Never hardcode a user-facing message anywhere else (CLAUDE.md).
- Every user-facing string must be 80 characters or fewer (`scripts/check-copy.mjs`).
- Tests: `test/<module>.test.js`, using `import { test } from 'node:test'` and
  `import assert from 'node:assert/strict'`. Tests assert against `MESSAGES.<key>`, not
  against copied string literals.
- Commit messages: `<type>: <summary>` with types seen in history: `fix`, `chore`,
  `initial`; reverts use git's default `Revert "..."` with a reason in parentheses.
