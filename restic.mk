#!/usr/bin/env -S make -f

DOCKER_VOLUMES_PATH=/var/lib/docker/volumes/
DOCKER_VOLUMES=$(shell find ${DOCKER_VOLUMES_PATH} -type d -maxdepth 1 -mindepth 1 -exec basename {} \;)
RESTIC_CONF?=$$HOME/restic.json

for_each_docker_volume=for volume in ${DOCKER_VOLUMES}; do $(1); done
for_each_virtual_volume=for volume in $$(cat ${RESTIC_CONF} | jq -r '.virtual[].name' | xargs); do $(1); done

CMDS = backup_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".virtual[] | select(.name == \"$$1\") | .backup_cmd"; \
}; \
restore_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".virtual[] | select(.name == \"$$1\") | .restore_cmd"; \
}

define usage =
Options:
  init
    Initialize restic repository

  snapshots
    List available snapshots

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

.PHONY: help
help:; @ $(info $(usage)) :

.PHONY: init
init:
	restic snapshots -q >/dev/null 2>&1 || restic init

.PHONY: snapshots
snapshots:
	restic snapshots --host "$$HOST"

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
		restic backup --tag $$volume --host "$$HOST" "${DOCKER_VOLUMES_PATH}/$$volume" \
	)

.PHONY: restore-volume
restore-volume:
	@test -n "${volume}" -a -n "${snapshot}"
	@echo "*** Restore volume ${volume} from snapshot ${snapshot} ***"
	restic restore --target / "${snapshot}"

.PHONY: backup-virtual-volumes
backup-virtual-volumes:
	@echo "** Backup virtual volumes **"
	@$(CMDS); $(call for_each_virtual_volume, \
		$$(backup_cmd $$volume) | restic backup --tag "$$volume" --host "$$HOST" --stdin \
	)

.PHONY: restore-virtual-volume
restore-virtual-volume:
	@test -n "${volume}" -a -n "${snapshot}"
	@set -eu; echo "*** Restore virtual volume ${volume} from snapshot ${snapshot}"
	@$(CMDS); restic dump "${snapshot}" /stdin | $$(restore_cmd ${volume}) \
