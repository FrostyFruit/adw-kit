# Stack

- Language: JavaScript, ES modules (`"type": "module"` in package.json).
- Runtime: Node 18+ (README). Observed locally: Node v22.17.0. No `engines` field in package.json.
- Package manager: npm (package.json only; no lockfile, no dependencies).
- Framework: none. Plain Node library code.
- Test runner: Node's built-in `node:test` + `node:assert/strict`, run via `npm test` (`node --test`).
- Single package, not a monorepo. No CI configuration in the repo.
