---
description: Scan this repo and write the context files every ADW stage reads first
---

You are setting up the AI Developer Workflow (ADW) for THIS repository.
Your job is discovery and writing context files. You are not implementing features.

The stage prompts (`adw-scout` through `adw-handover`) are the same for every repo.
What makes the loop fit THIS codebase is the context files you write here. Get them
right and every future run starts from what this repo has already learned.

## Phase 1: Discover (read only, no writes yet)

Run these and record what you actually find. Do not assume.

1. **Repo shape**
   - `git ls-files | head -200`
   - identify: framework, language, package manager, monorepo or single package

2. **What the repo already knows**
   - find and read: CLAUDE.md, AGENTS.md, README*, ARCHITECTURE*, HANDOVER*,
     docs/**, .cursor/**, and .claude/** EXCEPT the ADW kit itself
     (`.claude/commands/adw-*.md`, `.claude/adw/`). The kit's rules are not this repo's gotchas.
   - extract every stated gotcha, constraint, convention and "do not do X"

3. **Commands that actually exist**
   - read package.json scripts (or the equivalent manifest for the stack) and any CI config
   - record the REAL command strings for: install, dev, build, lint, typecheck,
     test, database migrate, deploy
   - if a category has no command, record it as NONE rather than inventing one

4. **Checks written only in prose.** Do this before you trust the list above.
   A manifest scan finds the checks someone wired into a manifest. It does NOT find
   the check a repo's most important rule lives in.
   - search the docs you read in step 2 for check-shaped language: "must pass",
     "always run", "before merging", "--check", "never commit without", "required", "blocking"
   - record every command named in prose as a CANDIDATE GATE, even if no manifest
     or CI file mentions it
   - mark each gate's source: `manifest`, `ci`, or **`prose-only`**

   **Prose-only checks are the ones that get lost.** Real case: one repo's most
   important check was a drift guard that protected a file feeding about 19 other
   surfaces. It appeared in no manifest, no CI file and no config. It existed as
   one sentence in CLAUDE.md. A scanner found the unit tests, missed the drift
   guard, and reported a confident, plausible, incomplete list. That is exactly
   the failure this whole workflow exists to prevent: output that reports success
   without having done the whole job.

   A repo with no CI is not a repo with no checks. It is a repo where these checks
   are the only automated verification it will ever get, which raises the stakes.

5. **Entry points and boundaries**
   - app routes and API handlers
   - database schema and migration location
   - external services and where their clients live
   - environment variable NAMES only (never read or print values)
   - where tests live and how they are named

6. **Failure history**
   - `git log --oneline -80`
   - look for reverts, hotfixes, and the same file fixed again and again.
     Those are the fragile areas. Record them with the commits as evidence.

7. **Prove every gate.** A gate you have not run is a guess.
   Run each candidate gate once on the current tree through the gate script:

       bash scripts/adw-gate.sh --name <name> --expect '<regex>' -- <command>

   - Choose `expect` from the REAL output you just saw: a line that only appears when
     the tool actually did its work (for example `^# pass [1-9]`, `Tests: +[1-9][0-9]* passed`).
     **The marker must be impossible to print when zero work was done.** `# pass [0-9]+`
     also matches `# pass 0`, which is a green result with no tests behind it. Do not guess the format from memory: the same tool prints different
     output in a terminal and into a file.
   - Every gate must come back `pass` on the current tree. If it comes back `suspect`,
     fix the regex from the real output and run it again. If it comes back `fail`, the
     tree is already red: record it as a known-red gate and tell the human in Phase 2.
     Never write down a gate you have not seen pass or knowingly fail.
   - Leave `expect` empty only for tools that print nothing on success (for example
     `tsc --noEmit`).

## Phase 2: Report, then STOP

Show the human:
- stack and structure
- every gate: name, exact command, expect regex, source, and the verdict you observed
- gotchas found, grouped by theme
- fragile areas, with the commits that show it
- anything you could NOT determine
- any place where two sources disagree (flag it, do not pick a winner)

Then STOP and ask the human to confirm or correct before Phase 3.

## Phase 3: Write the context files

If a file already exists in `.claude/context/`, do not overwrite it. Show what you
would add and ask. These files grow over time through `/adw-handover`, and that
growth is the most valuable thing in them.

Every path and command you write must come from Phase 1, not general knowledge.
Keep each file under 200 lines. No secrets, only variable names.

- **`stack.md`**: languages, frameworks, versions, package manager.
- **`commands.md`**: the verified command table, exact strings. It MUST end with a
  `## Gates` section in exactly this format: one fenced code block per gate, so nothing
  gets escaped:

  ````
  ## Gates

  ```
  name: test
  command: npm test
  expect: ^# pass [1-9]
  run_when: always
  source: manifest
  observed: pass
  ```
  ````

  `run_when` is `always` or a plain condition such as "if files under db/ changed".
  `expect` is a raw extended regex exactly as `grep -E` receives it.
- **`architecture.md`**: module boundaries, data flow, entry points.
- **`conventions.md`**: naming, file placement, patterns used here.
- **`gotchas.md`**: one entry per gotcha, in this shape:
  `### <short name>` then `Symptom:` / `Cause:` / `Fix:` lines.
- **`fragile.md`**: areas with revert or hotfix history, handle with care. It MUST
  include a `## Protected: do not change without a human` section listing paths
  the build stage must refuse to touch (from existing docs, or ask the human).
  Write "none yet" if there are none.
- **`map.md`**: index of what lives where, and which context file covers which concern.

Also create, if missing: `.claude/adw/runs/.gitkeep`, `docs/adw/handovers/.gitkeep` and
`docs/adw/evals/.gitkeep`.

## Phase 4: Offer a CLAUDE.md section (do not apply it)

Show the human this snippet and ask whether to add it to CLAUDE.md:

```
## How work gets done
Non-trivial changes go through the ADW loop: /adw-scout "<ticket>" then follow
each stage's "next command". The bar is no false greens: a false block costs
minutes, a false green ships a bug with a tick beside it.
Context every stage reads: .claude/context/. Run records: .claude/adw/runs/ (committed).
```

## Constraints
- Never invent a file path. Verify it exists first.
- Never invent a command. If it is not in a manifest, CI file or doc, mark it NONE.
- If discovery contradicts an existing doc, flag the contradiction.

## Finish
Tell the human two things:
1. Commit the new context files now:
   `git add .claude/context .claude/adw/runs/.gitkeep docs/adw && git commit -m "chore: add ADW context files"`
   Every run compares against a clean starting point, so uncommitted setup files would
   show up as part of the first ticket.
2. The first command to run: `/adw-scout "<a small real ticket>"`.
