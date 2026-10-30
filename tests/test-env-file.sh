#!/bin/sh
# RESTIC_ENV_FILE tests: connection settings (and any custom variable) come
# from a KEY=value file, not from the exported environment. Covers an
# explicit RESTIC_ENV_FILE, the default ~/.restic.env, and absent files
# (silently skipped).
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$ROOT/tests/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

export HOME="$TMP/home"
mkdir -p "$HOME" "$TMP/data"
echo "env file data" > "$TMP/data/file.txt"

# backup_cmd uses $MY_CUSTOM_VAR: it is expanded by the recipe shell, where
# the env file has been sourced by with_env.
cat > "$HOME/.restic.json" <<EOF
{
  "volumes": [
    { "name": "data", "path": "$TMP/data" }
  ],
  "virtual_volumes": [
    {
      "name": "custom",
      "backup_cmd": "printf %s \"\$MY_CUSTOM_VAR\"",
      "restore_cmd": "cat"
    }
  ]
}
EOF

ENV_FILE="$TMP/custom.env"
cat > "$ENV_FILE" <<EOF
RESTIC_REPOSITORY=$TMP/repo
RESTIC_PASSWORD=env-file-secret
MY_CUSTOM_VAR=custom-value-from-env-file
EOF
chmod 600 "$ENV_FILE"

# Run restic.mk in a minimal environment; extra variables go in EXTRA_ENV as
# space-separated KEY=VALUE pairs. Output is captured in $TEST_LOG.
EXTRA_ENV=
run() {
  TEST_LOG="$TMP/last.log"
  env -i PATH="$PATH" HOME="$HOME" HOST=envtest $EXTRA_ENV \
    make -f "$ROOT/restic.mk" "$@" >"$TEST_LOG" 2>&1
}

echo "== explicit RESTIC_ENV_FILE =="
EXTRA_ENV="RESTIC_ENV_FILE=$ENV_FILE"

run init
ok $? "init: repository created with env-file credentials"

run backup-volumes
ok $? "backup-volumes: connection loaded from RESTIC_ENV_FILE"

run -e volume=custom backup-virtual-volume
ok $? "backup-virtual-volume: custom var from env file reaches backup_cmd"

snap=$(RESTIC_REPOSITORY="$TMP/repo" RESTIC_PASSWORD="env-file-secret" \
       restic snapshots --tag custom --host envtest --latest 1 --json 2>/dev/null | jq -r '.[0].id')
content=$(RESTIC_REPOSITORY="$TMP/repo" RESTIC_PASSWORD="env-file-secret" \
          restic dump "$snap" /stdin 2>/dev/null)
[ "$content" = "custom-value-from-env-file" ]
ok $? "virtual volume content equals MY_CUSTOM_VAR from env file"

echo "== absent env file is silently skipped =="
EXTRA_ENV="RESTIC_ENV_FILE=$TMP/missing.env RESTIC_REPOSITORY=$TMP/repo-skip2 RESTIC_PASSWORD=skip-secret"

run init
ok $? "missing explicit RESTIC_ENV_FILE is skipped (command still runs)"
! grep -q "Cannot read" "$TEST_LOG"
ok $? "no error when the env file is absent"

echo "== default ~/.restic.env =="
cat > "$HOME/.restic.env" <<EOF
RESTIC_REPOSITORY=$TMP/repo-default
RESTIC_PASSWORD=default-secret
EOF
chmod 600 "$HOME/.restic.env"
EXTRA_ENV=

run init
ok $? "init: default ~/.restic.env is used when RESTIC_ENV_FILE is unset"

run backup-volumes
ok $? "backup-volumes: connection loaded from default ~/.restic.env"

n=$(RESTIC_REPOSITORY="$TMP/repo-default" RESTIC_PASSWORD="default-secret" \
    restic snapshots --host envtest --json 2>/dev/null | jq 'length')
[ "$n" -ge 1 ]
ok $? "snapshot exists in the default-env repository (got $n)"

echo "== missing default ~/.restic.env is silently skipped =="
HOME2="$TMP/home2"
mkdir -p "$HOME2" "$HOME2/data"
echo "skip data" > "$HOME2/data/file.txt"
cat > "$HOME2/.restic.json" <<EOF
{ "volumes": [ { "name": "data", "path": "$HOME2/data" } ] }
EOF
OLD_HOME="$HOME"
export HOME="$HOME2"
EXTRA_ENV="RESTIC_REPOSITORY=$TMP/repo-skip RESTIC_PASSWORD=skip-secret"

run init backup-volumes
ok $? "missing default ~/.restic.env is skipped (commands still run)"
! grep -q "Cannot read" "$TEST_LOG"
ok $? "no 'Cannot read' error for the absent default file"
export HOME="$OLD_HOME"

echo "== empty default env file + no RESTIC_* vars =="
HOME3="$TMP/home3"
mkdir -p "$HOME3"
: > "$HOME3/.restic.env"
export HOME="$HOME3"
EXTRA_ENV=

run snapshots
fails $? "empty default env file + no RESTIC_* vars: restic fails (no baked-in defaults)"
export HOME="$OLD_HOME"

finish
