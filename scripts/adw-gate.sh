#!/usr/bin/env bash
#
# adw-gate.sh: run one check and report what actually happened.
#
# WHY THIS EXISTS
# ---------------
# Every false green we found came from an agent *reasoning about* a result
# instead of a machine *capturing* one:
#
#   - `cmd | tail -20; echo $?`   reports tail's exit code. Always 0.
#   - `${PIPESTATUS[0]}`          is bash-only; empty under zsh, reads as "no error".
#   - "405 passed" in the output  is an exit code INFERRED from text.
#   - a test reporter that crashes on load and still exits 0.
#   - a lint run whose output ends on warnings while the gate is red.
#
# This script removes the judgement. It runs the command, captures $? on the
# same line, checks the output for a marker you supply, and prints JSON. The
# agent never sees an exit code it could have invented.
#
# USAGE
#   scripts/adw-gate.sh --name test --expect 'pass [0-9]+' -- npm test
#   scripts/adw-gate.sh --name typecheck -- npx tsc --noEmit
#   scripts/adw-gate.sh --into <run_id|path> --name test --expect '...' -- npm test
#   scripts/adw-gate.sh --self-test
#
#   --into appends the result to verify.checks in the run file, tagged with the
#   current verify.attempt, so nobody retypes a number.
#
# VERDICTS
#   pass     exit 0, and any --expect marker was found
#   fail     non-zero exit
#   suspect  exit 0 but --expect was given and its marker is ABSENT
#
# `suspect` is the point: exit 0 is necessary, not sufficient. A check that
# exits clean without the marker proving it did its work is the false-green
# shape, and is reported as such rather than rounded down to "pass".
#
# PASS --expect FOR ANY TOOL THAT REPORTS ITS WORK. Silence alone is NOT
# treated as suspicious: `tsc --noEmit` is silent on success, and a rule that
# cries wolf on every clean run is a rule that gets ignored.

# Deliberately no `set -e`: a non-zero exit is data to record, not a reason to
# abort before recording it.
set -uo pipefail

NAME=""
EXPECT=""
INTO=""
SELF_TEST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)      NAME="${2:-}"; shift 2 ;;
    --into)      INTO="${2:-}"; shift 2 ;;
    --expect)    EXPECT="${2:-}"; shift 2 ;;
    --self-test) SELF_TEST=1; shift ;;
    --)          shift; break ;;
    *)           break ;;
  esac
done

# Runs a gate, writes JSON to stdout, returns the gate's own exit code.
run_gate() {
  local name="$1"; shift
  local expect="$1"; shift
  local log
  # Trailing X's only: macOS mktemp does NOT substitute a template with a
  # suffix after the X's, and silently returns the literal name.
  log="$(mktemp "${TMPDIR:-/tmp}/adw-gate-${name}-XXXXXX")"

  # THE LINE THAT MATTERS: assignment on the same line as the command, no pipe.
  "$@" > "$log" 2>&1; local exit_code=$?

  local bytes; bytes=$(wc -c < "$log" | tr -d ' ')
  local tail_text; tail_text="$(tail -20 "$log")"

  local marker_ok=1
  if [[ -n "$expect" ]]; then
    marker_ok=0
    grep -qE "$expect" "$log" && marker_ok=1
  fi

  local verdict reason=""
  if [[ "$exit_code" -ne 0 ]]; then
    verdict="fail"
  elif [[ "$marker_ok" -eq 0 ]]; then
    verdict="suspect"
    reason="exited 0 but the expected marker '${expect}' is absent; the command may not have done its work"
  else
    verdict="pass"
  fi

  local non_empty="false"; [[ "$bytes" -gt 0 ]] && non_empty="true"

  node -e '
    const [name, command, exitCode, logPath, bytes, tail, nonEmpty, markerOk, expect, verdict, reason] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({
      name,
      command,
      exit_code: Number(exitCode),
      verdict,
      log_path: logPath,
      output_bytes: Number(bytes),
      output_tail: tail,
      sanity: {
        non_empty: nonEmpty === "true",
        expected_marker: expect === "" ? null : expect,
        expected_marker_found: expect === "" ? null : markerOk === "1",
        reason: reason === "" ? null : reason,
      },
    }, null, 2) + "\n");
  ' "$name" "$*" "$exit_code" "$log" "$bytes" "$tail_text" \
    "$non_empty" "$marker_ok" "$expect" "$verdict" "$reason"

  return "$exit_code"
}

# Reads one field out of a JSON file.
json_field() {
  node -e '
    const fs = require("fs");
    const doc = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    process.stdout.write(String(doc[process.argv[2]]));
  ' "$1" "$2"
}

self_test() {
  # Prove the instrument with known-bad inputs. A check shown only good inputs
  # has not been tested.
  local fails=0 tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/adw-gate-selftest-XXXXXX")"

  expect_case() { # expect_case <label> <want_verdict> <want_exit> <expect_regex> <cmd...>
    local label="$1" want_v="$2" want_e="$3" expect="$4"; shift 4
    local out="$tmp/$(echo "$label" | tr -c 'a-zA-Z0-9' '_').json"
    run_gate "selftest" "$expect" "$@" > "$out" 2>/dev/null
    local got_v got_e
    got_v="$(json_field "$out" verdict)"
    got_e="$(json_field "$out" exit_code)"
    if [[ "$got_v" == "$want_v" && "$got_e" == "$want_e" ]]; then
      printf "  OK    %-52s verdict=%-8s exit=%s\n" "$label" "$got_v" "$got_e"
    else
      printf "  FAIL  %-52s got %s/%s want %s/%s\n" "$label" "$got_v" "$got_e" "$want_v" "$want_e"
      fails=1
    fi
  }

  echo "adw-gate self-test: proving the instrument with known-bad inputs"

  expect_case "clean command with output"                    pass    0 "" bash -c 'echo hello'
  expect_case "FAILING command (exit 7) not rounded to pass" fail    7 "" bash -c 'echo boom; exit 7'
  expect_case "silent success is PASS (tsc is quiet)"        pass    0 "" bash -c 'exit 0'
  expect_case "exit 0 missing its marker is SUSPECT"         suspect 0 'Test Files' bash -c 'echo nothing useful'
  expect_case "exit 0 with its marker present is pass"       pass    0 'Test Files' bash -c 'echo "Test Files  3 passed"'
  expect_case "marker present but non-zero exit is FAIL"     fail    1 'Test Files' bash -c 'echo "Test Files  1 failed"; exit 1'

  # The trap this script removes, DEMONSTRATED rather than asserted.
  local broken fixed
  set +o pipefail
  ( exit 7 ) | tail -1 >/dev/null; broken=$?
  set -o pipefail
  ( exit 7 ) | tail -1 >/dev/null; fixed=$?
  if [[ "$broken" -eq 0 && "$fixed" -eq 7 ]]; then
    printf "  OK    %-52s no-pipefail=%s (the bug) pipefail=%s (truth)\n" \
           "piped \$? swallows a real failure" "$broken" "$fixed"
  else
    printf "  FAIL  %-52s got %s/%s want 0/7\n" "piped-exit demonstration" "$broken" "$fixed"
    fails=1
  fi

  rm -rf "$tmp"
  if [[ "$fails" -eq 0 ]]; then echo "SELF-TEST PASSED"; return 0; fi
  echo "SELF-TEST FAILED"; return 1
}

if [[ "$SELF_TEST" -eq 1 ]]; then
  self_test
  exit $?
fi

if [[ -z "$NAME" || $# -eq 0 ]]; then
  echo "usage: adw-gate.sh [--into <run>] --name <gate> [--expect <regex>] -- <command...>" >&2
  echo "       adw-gate.sh --self-test" >&2
  exit 2
fi

if [[ -z "$INTO" ]]; then
  run_gate "$NAME" "$EXPECT" "$@"
  exit $?
fi

# --into: resolve the run file BEFORE running the gate, so a typo fails fast.
RUN_FILE="$INTO"
[[ -f "$RUN_FILE" ]] || RUN_FILE=".claude/adw/runs/${INTO}.json"
if [[ ! -f "$RUN_FILE" ]]; then
  echo "adw-gate: run file not found: $INTO" >&2
  exit 3
fi

OUT="$(mktemp "${TMPDIR:-/tmp}/adw-gate-out-XXXXXX")"
run_gate "$NAME" "$EXPECT" "$@" > "$OUT"; GATE_EXIT=$?
cat "$OUT"

node -e '
  const fs = require("fs");
  const [runFile, outFile] = process.argv.slice(1);
  const d = JSON.parse(fs.readFileSync(runFile, "utf8"));
  const r = JSON.parse(fs.readFileSync(outFile, "utf8"));
  d.verify = d.verify || {};
  d.verify.checks = d.verify.checks || [];
  d.verify.checks.push({
    name: r.name, command: r.command, exit_code: r.exit_code, verdict: r.verdict,
    attempt: d.verify.attempt || 1,
    // A pass needs only its proof line; a failure keeps 20 lines of evidence.
    output_tail: r.verdict === "pass" ? r.output_tail.split("\n").slice(-5).join("\n") : r.output_tail,
  });
  const tmp = runFile + ".tmp." + process.pid;
  fs.writeFileSync(tmp, JSON.stringify(d, null, 2) + "\n");
  fs.renameSync(tmp, runFile);
  console.error("adw-gate: recorded " + r.name + " (" + r.verdict + ", exit " + r.exit_code + ") in " + runFile);
' "$RUN_FILE" "$OUT" || { echo "adw-gate: FAILED to record the result in $RUN_FILE" >&2; rm -f "$OUT"; exit 3; }

rm -f "$OUT"
exit "$GATE_EXIT"
