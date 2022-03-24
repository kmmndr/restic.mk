#!/bin/sh

BASE_TEST_DIR=$(mktemp -d)

export PATH=.:$PATH
export RESTIC_REPOSITORY=$BASE_TEST_DIR/repo
export RESTIC_PASSWORD=secret
export SOURCE_DIR=$BASE_TEST_DIR/source
mkdir -p $SOURCE_DIR
export RESTIC_CONF=$BASE_TEST_DIR/restic.json
cat > $RESTIC_CONF <<EOF
{
  "volumes": [
    {
      "name": "source",
      "path": "$SOURCE_DIR"
    }
  ]
}
EOF

echo "BASE_TEST_DIR: $BASE_TEST_DIR"
echo "RESTIC_REPOSITORY: $RESTIC_REPOSITORY"
echo "RESTIC_PASSWORD: $RESTIC_PASSWORD"
echo "RESTIC_CONF:"; cat $RESTIC_CONF
echo "SOURCE_DIR: $SOURCE_DIR"

restic.mk init

date > $SOURCE_DIR/file

restic.mk backup-volumes

env PS1='restic.mk> ' /bin/sh
