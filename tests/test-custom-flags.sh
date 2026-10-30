#!/bin/sh
# Custom restic options via RESTIC_FLAGS, e.g. --insecure-tls for a
# rest-server with a self-signed certificate. RESTIC_FLAGS may be set via
# the environment, the command line, or the env file.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/tests/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/data"
echo "flags data" > "$TMP/data/file.txt"
: > "$HOME/.restic.env"

cat > "$HOME/.restic.json" <<EOF
{ "volumes": [ { "name": "data", "path": "$TMP/data" } ] }
EOF

# Run restic.mk in a minimal environment; extra variables go in EXTRA_ENV as
# space-separated KEY=VALUE pairs. Output is captured in $TEST_LOG.
EXTRA_ENV=
run() {
  TEST_LOG="$TMP/last.log"
  env -i PATH="$PATH" HOME="$HOME" HOST=testhost $EXTRA_ENV \
    make -f "$ROOT/restic.mk" "$@" >"$TEST_LOG" 2>&1
}

echo "== RESTIC_FLAGS via environment =="
EXTRA_ENV="RESTIC_REPOSITORY=$TMP/repo RESTIC_PASSWORD=secret RESTIC_FLAGS=--insecure-tls"

run init
ok $? "init accepts RESTIC_FLAGS=--insecure-tls"

run backup-volumes
ok $? "backup-volumes forwards RESTIC_FLAGS to restic"

echo "== unknown flags are forwarded (and fail) =="
EXTRA_ENV="RESTIC_REPOSITORY=$TMP/repo RESTIC_PASSWORD=secret RESTIC_FLAGS=--no-such-flag"

run snapshots
fails $? "unknown RESTIC_FLAGS reaches restic and fails the command"
grep -q "unknown flag" "$TEST_LOG"
ok $? "restic reports the unknown flag"

echo "== RESTIC_FLAGS via the default env file =="
echo "RESTIC_FLAGS=--no-such-flag" > "$HOME/.restic.env"
EXTRA_ENV="RESTIC_REPOSITORY=$TMP/repo RESTIC_PASSWORD=secret"

run snapshots
fails $? "RESTIC_FLAGS from ~/.restic.env is forwarded too"

finish
