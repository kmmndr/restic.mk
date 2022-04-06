#!/usr/bin/env -S make -f

RESTIC_CONF?=$$HOME/.restic.json
HOST?=$(shell hostname -f)

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

  backup-volume -e volume=...
    Backup specified volume

  backup-volumes
    Backup each volumes

  backup-virtual-volume -e volume=...
    Backup specified virtual volume

  backup-virtual-volumes
    Backup each virtual volumes

  find-last-snapshot -e volume=...
    Find last snapshot id for a given volume name
    May be combined to restore last volume
    (restic.mk -e volume=... find-last-snapshot restore-volume)

  restore-volume -e volume=... snapshot=...
    Restore specified volume's snapshot

  restore-virtual-volume -e volume=... snapshot=...
    Restore specified virtual volume's snapshot
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
	@docker_volumes_path=$${DOCKER_VOLUMES_PATH:-/var/lib/docker/volumes/}; \
		echo "Docker volumes path: $$docker_volumes_path"; \
		for volume in $$(find $$docker_volumes_path -maxdepth 1 -mindepth 1 -type d -exec basename {} \;); do \
			echo "*** Backup volume docker-$$volume ***"; \
			restic backup --tag docker-$$volume --host "${HOST}" "$$docker_volumes_path/$$volume"; \
		done

.PHONY: ensure-volume-presence
ensure-volume-presence:
	@test -n "${volume}" || (echo 'volume parameter is missing'; exit 1)

.PHONY: ensure-snapshot-presence
ensure-snapshot-presence:
	@test -n "${snapshot}" || (echo 'snapshot parameter is missing'; exit 1)

VOLUME_CMDS = path_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".volumes[] | select(.name == \"$$1\") | .path"; \
}; \
backup_volume() { \
	echo "*** Backup volume $$1 ***"; \
	restic backup --tag $$1 --host "${HOST}" "$$(path_cmd $$1)"; \
}
.PHONY: backup-volume
backup-volume: ensure-volume-presence
	@$(VOLUME_CMDS); backup_volume ${volume}

.PHONY: backup-volumes
backup-volumes:
	@$(VOLUME_CMDS); $(call for_each_volume, backup_volume $$volume)

.PHONY: find-last-snapshot
find-last-snapshot: ensure-volume-presence
	@echo "*** Finding last snapshot for volume '${volume}' ***"
	@$(eval snapshot=$(shell restic snapshots --tag ${volume} --host ${HOST} --latest 1 --json | jq -r .[].id))
	@echo "Last snapshot: ${snapshot}"

.PHONY: restore-volume
restore-volume: ensure-volume-presence ensure-snapshot-presence
	@echo "*** Restore volume '${volume}' from snapshot '${snapshot}' ***"
	restic restore --target / "${snapshot}"

VIRTUAL_BACKUP_CMDS = virtual_backup_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".virtual_volumes[] | select(.name == \"$$1\") | .backup_cmd"; \
}; \
backup_virtual_volume() { \
	echo "*** Backup virtual volume $$1 ***"; \
	$$(virtual_backup_cmd $$1) | restic backup --tag "$$1" --host "${HOST}" --stdin; \
}
.PHONY: backup-virtual-volume
backup-virtual-volume: ensure-volume-presence
	@$(VIRTUAL_BACKUP_CMDS); backup_virtual_volume ${volume}

.PHONY: backup-virtual-volumes
backup-virtual-volumes:
	@$(VIRTUAL_BACKUP_CMDS); $(call for_each_virtual_volume, backup_virtual_volume $$volume)

VIRTUAL_RESTORE_CMD = virtual_restore_cmd() { \
	cat ${RESTIC_CONF} | jq -r ".virtual_volumes[] | select(.name == \"$$1\") | .restore_cmd"; \
}
.PHONY: restore-virtual-volume
restore-virtual-volume: ensure-volume-presence ensure-snapshot-presence
	@set -eu; echo "*** Restore virtual volume '${volume}' from snapshot '${snapshot}'"
	@$(VIRTUAL_RESTORE_CMD); restic dump "${snapshot}" /stdin | $$(virtual_restore_cmd ${volume}) \
