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
  ],
  "virtual_volumes": [
    {
      "name": "fake_example",
      "backup_cmd": "date",
      "restore_cmd": "tee -a $SOURCE_DIR/fake"
    }
  ]
}
EOF
export DOCKER_VOLUMES_PATH=$BASE_TEST_DIR/docker/volumes
mkdir -p $DOCKER_VOLUMES_PATH
for idx in $(seq 1 2); do
  mkdir -p $DOCKER_VOLUMES_PATH/vol$idx/_data/folder
  date > $DOCKER_VOLUMES_PATH/vol$idx/_data/folder/now
done

echo "BASE_TEST_DIR: $BASE_TEST_DIR"
echo "RESTIC_REPOSITORY: $RESTIC_REPOSITORY"
echo "RESTIC_PASSWORD: $RESTIC_PASSWORD"
echo "RESTIC_CONF:"; cat $RESTIC_CONF
echo "SOURCE_DIR: $SOURCE_DIR"

restic.mk init

date > $SOURCE_DIR/file

restic.mk backup-volumes

env PS1='restic.mk> ' /bin/sh
