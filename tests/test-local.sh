#!/bin/sh
# Local backend test: RESTIC_* connection variables come from the exported
# environment (pass-through). RESTIC_ENV_FILE is unset, so the default
# ~/.restic.env is used (empty file: nothing to load).
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/tests/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/data"
echo "hello restic" > "$TMP/data/file.txt"
: > "$HOME/.restic.env"

cat > "$HOME/.restic.json" <<EOF
{
  "volumes": [
    { "name": "data", "path": "$TMP/data" }
  ],
  "virtual_volumes": [
    { "name": "now", "backup_cmd": "date", "restore_cmd": "cat" }
  ]
}
EOF

# Run restic.mk in a minimal environment; extra variables go in EXTRA_ENV as
# space-separated KEY=VALUE pairs. Output is captured in $TEST_LOG.
EXTRA_ENV="RESTIC_REPOSITORY=$TMP/repo RESTIC_PASSWORD=local-secret"
run() {
  TEST_LOG="$TMP/last.log"
  env -i PATH="$PATH" HOME="$HOME" HOST=testhost $EXTRA_ENV \
    make -f "$ROOT/restic.mk" "$@" >"$TEST_LOG" 2>&1
}

run init
ok $? "init: initialize local repository"
grep -q "Loading environment from $HOME/.restic.env" "$TEST_LOG"
ok $? "default ~/.restic.env is loaded when RESTIC_ENV_FILE is unset"

run list-volumes
ok $? "list-volumes shows configured volumes"

run backup-volumes
ok $? "backup-volumes"

run backup-virtual-volumes
ok $? "backup-virtual-volumes"

n=$(RESTIC_REPOSITORY="$TMP/repo" RESTIC_PASSWORD="local-secret" \
    restic snapshots --host testhost --json 2>/dev/null | jq 'length')
[ "$n" -ge 2 ]
ok $? "one snapshot per volume exists (got $n)"

rm -f "$TMP/data/file.txt"
run -e volume=data find-last-snapshot restore-volume
ok $? "find-last-snapshot + restore-volume"
[ -f "$TMP/data/file.txt" ]
ok $? "deleted file is restored"

run backup-volume
fails $? "backup-volume without volume parameter fails"

finish
