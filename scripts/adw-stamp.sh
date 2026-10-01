#!/usr/bin/env bash
# adw-stamp.sh: the clock writes the timestamp, never the AI.
#
# WHY THIS EXISTS
# ---------------
# Stage timestamps used to be typed into the run file by the agent. In one
# session it fabricated five of them, each internally consistent, so no
# checker could see it. The cause was mechanical: the agent wrote ended_at
# BEFORE it read the clock. This helper reads the clock and writes the file in
# one step, so the value never passes through the agent's hands.
#
# USAGE
#   bash scripts/adw-stamp.sh <run_id|path> <stage> start
#   bash scripts/adw-stamp.sh <run_id|path> <stage> end [passed|waiting|blocked]
#
#   passed  = the stage did its job (its verdict, if any, lives in the run file)
#   waiting = the stage stopped to ask the human; it restarts with `start` after
#   blocked = the run cannot continue (also sets the run's status to blocked)
#
#   start  records the observed instant under stamps.<stage> in the run file,
#          and sets the run's `stage` to <stage> (so `stage` always means "the
#          stage in progress, or the last one that ran").
#   end    consumes that pending stamp and APPENDS a completed history entry.
#          Ending with `blocked` also sets the run's status to "blocked".
#          The entry looks like this:
#          { stage, status (default "passed"), started_at, ended_at,
#            duration_seconds, note: "" }
#          The agent then fills `note` in place. Prose is the agent's job.
#          The clock is not.
#
#   `end` REFUSES (exit 1) without an observed `start`. An end with no start
#   is exactly the fabrication this helper exists to prevent.
#
# EXIT 0 stamped, EXIT 1 misuse (missing file, end without start, bad args)
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "usage: adw-stamp.sh <run_id|path> <stage> start|end [status]" >&2
  exit 1
fi

RUN_ARG="$1"; STAGE_ARG="$2"; MODE_ARG="$3"; STATUS_ARG="${4:-passed}"

if [ -f "$RUN_ARG" ]; then
  RUN_FILE="$RUN_ARG"
else
  RUN_FILE=".claude/adw/runs/${RUN_ARG}.json"
fi
if [ ! -f "$RUN_FILE" ]; then
  echo "adw-stamp: run file not found: $RUN_FILE (create the run first; this helper never creates one)" >&2
  exit 1
fi

case "$MODE_ARG" in
  start|end) ;;
  *) echo "adw-stamp: mode must be start|end, got '$MODE_ARG'" >&2; exit 1 ;;
esac
case "$STATUS_ARG" in
  passed|waiting|blocked|failed) ;;
  *) echo "adw-stamp: status must be passed|waiting|blocked, got '$STATUS_ARG'" >&2; exit 1 ;;
esac

RUN_FILE="$RUN_FILE" STAGE="$STAGE_ARG" MODE="$MODE_ARG" ST="$STATUS_ARG" node -e '
const fs = require("fs");
const file = process.env.RUN_FILE, stage = process.env.STAGE;
const mode = process.env.MODE, status = process.env.ST;
const now = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

let d;
try { d = JSON.parse(fs.readFileSync(file, "utf8")); }
catch (e) { console.error(`adw-stamp: unparseable run file: ${e.message}`); process.exit(1); }

if (mode === "start") {
  d.stamps = d.stamps || {};
  if (d.stamps[stage]) {
    console.error(
      `adw-stamp: WARNING, pending start for \x27${stage}\x27 at ${d.stamps[stage].started_at} ` +
      `is being OVERWRITTEN (stage restarted?). The earlier instant is lost; say so in the note.`
    );
  }
  d.stamps[stage] = { started_at: now };
  d.stage = stage;
} else {
  const pending = d.stamps && d.stamps[stage];
  if (!pending) {
    console.error(
      `adw-stamp: REFUSED, no pending start for \x27${stage}\x27. ` +
      `An end without an observed start is the fabrication this helper exists to prevent. Run start first.`
    );
    process.exit(1);
  }
  const dur = Math.round((Date.parse(now) - Date.parse(pending.started_at)) / 1000);
  if (dur < 0) console.error(`adw-stamp: WARNING, negative duration (${dur}s); writing observed truth anyway.`);
  d.history = d.history || [];
  d.history.push({
    stage,
    status,
    started_at: pending.started_at,
    ended_at: now,
    duration_seconds: dur,
    note: "",
  });
  delete d.stamps[stage];
  if (Object.keys(d.stamps).length === 0) delete d.stamps;
  if (status === "blocked") d.status = "blocked";
}

const tmp = `${file}.tmp.${process.pid}`;
fs.writeFileSync(tmp, JSON.stringify(d, null, 2) + "\n");
fs.renameSync(tmp, file);

if (mode === "start") {
  console.log(`adw-stamp: start ${stage} @ ${now}`);
} else {
  const h = d.history[d.history.length - 1];
  console.log(`adw-stamp: end ${stage} @ ${now} (started ${h.started_at}, ${h.duration_seconds}s, status ${h.status}); history entry appended, fill note in place`);
}
'
