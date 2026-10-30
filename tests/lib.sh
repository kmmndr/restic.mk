#!/bin/sh
# Minimal TAP helpers for restic.mk tests: ok / fails / finish.
# Source this file from a test script:
#
#   ok $? "description"     — passes when the exit code is 0
#   fails $? "description"  — passes when the exit code is non-zero
#   finish                  — prints the TAP plan, exits non-zero on failure
#
# If TEST_LOG points to the output file of the last command, a failing `ok`
# dumps its tail as TAP comments.

pass=0
fail=0
tno=0

ok() {
  tno=$((tno + 1))
  if [ "$1" -eq 0 ]; then
    pass=$((pass + 1)); echo "ok $tno - $2"
  else
    fail=$((fail + 1)); echo "not ok $tno - $2"
    if [ -n "${TEST_LOG:-}" ] && [ -f "$TEST_LOG" ]; then
      echo "# --- output of last command ---"
      tail -n 25 "$TEST_LOG" | sed 's/^/# /'
    fi
  fi
}

fails() {
  tno=$((tno + 1))
  if [ "$1" -ne 0 ]; then
    pass=$((pass + 1)); echo "ok $tno - $2"
  else
    fail=$((fail + 1)); echo "not ok $tno - $2"
  fi
}

finish() {
  echo "1..$tno"
  echo "# pass=$pass fail=$fail"
  [ "$fail" -eq 0 ]
}
