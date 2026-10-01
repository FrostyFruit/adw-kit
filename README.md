# ADW: a coding loop your codebase learns from

A free kit of Claude Code commands that turns "ask the AI to build it" into a small,
disciplined team: a scout, a planner, a devil's advocate, a builder, an inspector, an
outside reviewer and a note-taker. Every ticket goes through the same seven steps, and
every ticket leaves the codebase a little smarter for the next one.

I use this loop to build our AI SDR. These are the same commands, with our
product-specific parts removed.

---

## The problem it solves

AI coding feels magic on day one and gets worse as the codebase grows. The AI does not
remember last week's mistake. It marks its own homework. It tells you tests pass when it
never ran them. And every new session starts from zero.

Better prompts do not fix that. A better loop does.

## The loop

```
              /adw-bootstrap  (once: learns YOUR repo)
                     |
                     v
   scout -> plan -> challenge -> build -> verify -> review -> handover
     ^                  |                    |          |          |
     |               revise               fix it     revise       |
     |                                                             |
     +------------- lessons written back into the codebase <-------+
```

| Step | Who it is | Its one job | What it catches |
|---|---|---|---|
| `/adw-scout` | the scout | find the real files and known traps this ticket touches | "I assumed it lived somewhere else" |
| `/adw-plan` | the planner | write checkable acceptance criteria, and stop to ask you any product question | vague goals, the AI guessing what you meant |
| `/adw-challenge` | the devil's advocate | a FRESH agent attacks the plan before any code exists (two rounds at most, then you decide) | missed edge cases, touching fragile areas |
| `/adw-build` | the builder | implement exactly the plan, and nothing else | (the only step that writes code) |
| `/adw-verify` | the inspector | run your repo's real checks and record the real results | "tests pass" when they did not run |
| `/adw-review` | the outside reviewer | a FRESH agent that never saw the plan judges the change | the builder grading its own homework |
| `/adw-handover` | the note-taker | write what was learned back into the context files | making the same mistake twice |

Plus `/adw-eval`, which measures the loop itself every 10 or so runs and proposes (never
silently applies) up to three improvements.

Each ticket gets one JSON file in `.claude/adw/runs/` that carries the whole run: the
plan, the challenge findings, every check result, the reviewer's verdict word for word,
and timestamps written by the clock rather than by the AI.

## Why it is built around YOUR codebase

The seven step prompts are the same for everyone. What makes the loop fit your repo is
`/adw-bootstrap`. It reads your code, your docs and your git history, then writes seven
short context files every step reads first:

- `stack.md`: what you are built on
- `commands.md`: your real commands, and the **gates** verify runs every time
- `architecture.md`: how the pieces fit
- `conventions.md`: how things are done here
- `gotchas.md`: symptom, cause, fix, for every trap found so far
- `fragile.md`: the areas that keep breaking, and the paths the AI must not touch without you
- `map.md`: what lives where

Then every ticket's handover adds to them. The process is universal. The knowledge is yours,
and it compounds.

## Set up in 10 minutes

You need: [Claude Code](https://claude.com/claude-code), git, and Node 18 or newer (for the small scripts).

1. Copy the kit into your repo:
   ```sh
   cp -r adw-kit/.claude/commands/adw-*.md  your-repo/.claude/commands/
   mkdir -p your-repo/.claude/adw/runs && touch your-repo/.claude/adw/runs/.gitkeep
   cp adw-kit/.claude/adw/state.schema.json  your-repo/.claude/adw/
   mkdir -p your-repo/scripts
   cp adw-kit/scripts/adw-*  your-repo/scripts/
   chmod +x your-repo/scripts/adw-*.sh
   ```
2. In Claude Code, inside your repo: `/adw-bootstrap`
3. Read its report. **Correct anything it got wrong.** This is the most valuable ten
   minutes you will spend: you know things about your codebase that are not written down.
4. Commit what it wrote (`.claude/context/` and `docs/adw/`). Each run compares against
   a clean starting point.
5. Run your first ticket, something small and real:
   `/adw-scout "the signup form accepts an empty email"`

Each step tells you the next command to run. You stay the decision maker: the loop stops
and asks you whenever a product decision comes up (wording customers see, whether
something is required, prices), whenever a step blocks or rejects the ticket, and before
it touches anything you marked as protected.

## The rules that make it work

- **No false greens.** A false block costs you minutes. A false green ships a bug with a
  tick next to it, and nobody looks again. Every rule below serves this one.
- **Never let the AI grade its own homework.** The reviewer is a fresh agent that gets the
  criteria, the builder's claims and the changes, and nothing else. Its verdict is recorded
  word for word. The devil's advocate is a fresh agent too.
- **The AI does not make product decisions.** When the plan hits one, it stops and asks you,
  and your answer is recorded word for word.
- **The builder's notes are claims, not facts.** Where a note and the actual change
  disagree, the change wins. If it says a test exists, the reviewer finds the test.
- **Never approve what you did not see.** The reviewer reports how many lines it read.
  An approval of zero lines is rejected.
- **A machine captures results, the AI never infers them.** `scripts/adw-gate.sh` runs each
  check and records the real exit code. A check that "passes" without proof it did its
  work is marked `suspect`, and suspect counts as a failure.
- **The clock writes the time.** `scripts/adw-stamp.sh` stamps each step. An agent once
  invented five timestamps in one session, all plausible, none real.
- **A lesson travels with its code.** A lesson about code that never merged will send
  every future run looking for something that does not exist.
- **The loop proposes, you decide.** `/adw-eval` suggests changes. Nothing changes until a
  small practice run has proved the change actually works.

## Tested before it shipped

Before publishing, I ran this kit on a throwaway repo with three traps planted in it: a
check that existed only as one sentence in the docs, a pricing file marked "do not touch",
and a fix that had been reverted in production. Bootstrap found all three.

Then four practice tickets, each run by a fresh agent that logged every place the
instructions made it guess. Each log fed the next version:

- Run 1 found real bugs. The worst: the reviewer prompt had no working directory, so it
  could have reviewed the wrong repo.
- Run 2 caught me over-correcting. I had made the devil's advocate a fresh agent with no
  round limit, and it went five rounds on a three-line fix. Now it is two rounds, then you decide.
- Run 3 touched the protected pricing file. The loop stopped and asked before any code
  was written.
- Run 4 ran the final version from scratch. It stopped for sign-off at the plan, and its
  devil's advocate caught a 12x overcharge risk before any code existed. It found one
  last real bug: a second planning pass could erase your recorded sign-off. The helper
  script now refuses to. That run is in `examples/`.

## What it looked like for us

Six weeks building our AI SDR (one team, one codebase, so treat it as a data point, not a
benchmark):

- 61 tickets went through full review. 60 of them were judged by a fresh reviewer.
- 29 of 61 needed more than one review round. Nearly half bounced the first time, which
  is exactly why the reviewer is there.
- 103 serious problems were caught at the challenge step, before any code was written.
- 226 times, the reviewer flagged something the change did that nobody asked for.
- Median ticket: 39 minutes from scout to handover.

## FAQ

**Is this slow?** Our median ticket was 39 minutes end to end. The time you save is the
bug you do not ship and the afternoon you do not spend finding it.

**Do I use it for everything?** No. A typo or a copy change does not need seven steps.
Use it for anything that touches data, money, messages to customers, or code that has
broken before.

**Do I need to be an engineer?** You need to read a plan and say "that is not what I
meant." The loop is designed so the important decisions come back to you as plain
questions, with a suggested answer.

**Does it work outside Claude Code?** The commands are plain markdown prompts, so you can
adapt them. They are written for Claude Code slash commands and subagents.

**What should I commit?** At the end of each ticket, one commit: the code, its run file,
its handover doc and any lessons added to the context files. Lessons travel with their code,
and the run files are the history `/adw-eval` measures.

## What is in the kit

```
.claude/commands/      9 commands: bootstrap, scout, plan, challenge, build,
                       verify, review, handover, eval
.claude/adw/           state.schema.json (the shape of a run file), runs/
scripts/adw-stamp.sh   the clock writes timestamps
scripts/adw-gate.sh    captures real check results (try: --self-test)
scripts/adw-run.mjs    writes to a run file safely, and checks it tells the truth
scripts/adw-eval.mjs   measures the loop across all runs
examples/              a real practice ticket: its run file, handover, and the
                       context files bootstrap wrote
```

## License

MIT. Use it, change it, ship with it. If it helps, tell me what you built.
