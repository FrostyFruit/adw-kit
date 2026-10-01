# Commands

Every command below was found in package.json, CLAUDE.md or README.md. NONE means no
command exists for that category; do not invent one.

| Category  | Command                        | Source                         |
|-----------|--------------------------------|--------------------------------|
| install   | NONE (no dependencies)         | package.json has no deps       |
| dev       | NONE                           |                                |
| build     | NONE                           |                                |
| lint      | NONE                           |                                |
| typecheck | NONE                           |                                |
| test      | `npm test` (= `node --test`)   | package.json, README.md        |
| copy check| `node scripts/check-copy.mjs`  | CLAUDE.md (prose only)         |
| migrate   | NONE                           |                                |
| deploy    | NONE                           |                                |

`node --test` picks up `test/*.test.js` automatically. Output is TAP; the summary
lines (`# tests N`, `# pass N`, `# fail N`) are printed at the end.

`scripts/check-copy.mjs` is NOT wired into npm scripts or CI. CLAUDE.md says to run it
before merging. It is a gate here so it cannot be forgotten.

## Gates

```
name: test
command: npm test
expect: ^# pass [1-9]
run_when: always
source: manifest
observed: pass
```

```
name: copy-length
command: node scripts/check-copy.mjs
expect: ^check-copy: [1-9][0-9]* strings OK$
run_when: always
source: prose-only
observed: pass
```
