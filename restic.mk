#!/usr/bin/env -S make -f

DOCKER_VOLUMES_PATH=/var/lib/docker/volumes/
DOCKER_VOLUMES=$(shell find ${DOCKER_VOLUMES_PATH} -type d -maxdepth 1 -mindepth 1 -exec basename {} \;)
RESTIC_CONF?=$$HOME/restic.json
HOST?=$(shell hostname -f)

for_each_docker_volume=for volume in ${DOCKER_VOLUMES}; do $(1); done
for_each_volume=for volume in $$(cat ${RESTIC_CONF} | jq -r '.volumes[].name' | xargs); do $(1); done
for_each_virtual_volume=for volume in $$(cat ${RESTIC_CONF} | jq -r '.virtual_volumes[].name' | xargs); do $(1); done

define usage =
Options:
  init
    Initialize restic repository

  config-example
    Print config example (restic.mk config-example > ${RESTIC_CONF})

  snapshots
    List available snapshots

  list-volumes
    List volumes
  list-virtual-volumes
    List virtual volumes

  backup-docker-volumes
    Backup docker volumes
  backup-virtual-volumes
    Backup virtual volumes

  restore-volume -e volume=... snapshot=...
    Restore specified snapshot to volume
  restore-virtual-volume -e volume=... snapshot=...
    Restore specified snapshot to virtual volume
endef

define default_config =
{
  "volumes": [
    {
      "name": "example",
      "path": "/important/data"
    }
  ],
  "virtual_volumes": [
    {
      "name": "database_example",
      "backup_cmd": "mysqldump --user=user --password=password database",
      "restore_cmd": "mysql --user=user --password=password database"
    }
  ]
}
endef
export default_config

.PHONY: help
help:; @ $(info $(usage)) :

.PHONY: config-example
config-example:
	@echo $$default_config | jq

.PHONY: init
init:
	restic snapshots -q >/dev/null 2>&1 || restic init

.PHONY: snapshots
snapshots:
	restic snapshots --host "${HOST}"

.PHONY: list-volumes
list-volumes:
	@echo "** Volumes **"
	@$(call for_each_volume, \
		echo "- $$volume" \
	)

.PHONY: list-virtual-volumes
list-virtual-volumes:
	@echo "** Virtual volumes **"
	@$(call for_each_virtual_volume, \
		echo "- $$volume" \
	)

.PHONY: backup-docker-volumes
backup-docker-volumes:
	@$(call for_each_docker_volume, \
		echo "*** Backup docker volume $$volume ***"; \
		restic backup --tag $$volume --host "${HOST}" "${DOCKER_VOLUMES_PATH}/$$volume" \
	)

PATH_CMD = path_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".volumes[] | select(.name == \"$$1\") | .path"; \
}
.PHONY: backup-volumes
backup-volumes:
	@$(PATH_CMD); $(call for_each_volume, \
		echo "*** Backup volume $$volume ***"; \
		restic backup --tag $$volume --host "${HOST}" "$$(path_cmd $$volume)" \
	)

.PHONY: restore-volume
restore-volume:
	@test -n "${volume}" -a -n "${snapshot}"
	@echo "*** Restore volume '${volume}' from snapshot '${snapshot}' ***"
	restic restore --target / "${snapshot}"

BACKUP_CMD = backup_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".virtual_volumes[] | select(.name == \"$$1\") | .backup_cmd"; \
}
.PHONY: backup-virtual-volumes
backup-virtual-volumes:
	@echo "** Backup virtual volumes **"
	@$(BACKUP_CMD); $(call for_each_virtual_volume, \
		$$(backup_cmd $$volume) | restic backup --tag "$$volume" --host "${HOST}" --stdin \
	)

RESTORE_CMD = restore_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".virtual_volumes[] | select(.name == \"$$1\") | .restore_cmd"; \
}
.PHONY: restore-virtual-volume
restore-virtual-volume:
	@test -n "${volume}" -a -n "${snapshot}"
	@set -eu; echo "*** Restore virtual volume '${volume}' from snapshot '${snapshot}'"
	@$(RESTORE_CMD); restic dump "${snapshot}" /stdin | $$(restore_cmd ${volume}) \
