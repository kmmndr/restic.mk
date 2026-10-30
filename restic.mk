#!/usr/bin/env -S make -f

RESTIC_CONF?=$$HOME/.restic.json
RESTIC_ENV_FILE?=$$HOME/.restic.env
HOST?=$(shell hostname -f)
VERSION=0.4.0

define usage =
restic.mk (version ${VERSION})

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

Environment variables:
  RESTIC_CONF
    Path to the JSON config file (default: ~/.restic.json)

  RESTIC_ENV_FILE
    Path to the KEY=value env file (default: ~/.restic.env);
    sourced only if the file exists
    Example to use a rest-server:
      RESTIC_REPOSITORY=rest:https://backup.example.com:8000/host1
      RESTIC_PASSWORD_FILE=/etc/restic/password
      RESTIC_REST_USERNAME=backup-user
      RESTIC_REST_PASSWORD=...
endef

define config_example =
{
  "volumes": [
    {
      "name": "home_${USER}",
      "path": "${HOME}",
      "backup_flags": "--verbose",
      "restore_flags": "--quiet"
    }
  ],
  "virtual_volumes": [
    {
      "name": "database_example",
      "backup_cmd": "mysqldump --user=user --password=password database",
      "restore_cmd": "mysql --user=user --password=password database"
    },
    {
      "name": "dockerized_database_example",
      "backup_cmd": "docker exec -it -e PGPASSWORD=$$DB_PASSWORD postgres pg_dump --clean -h 127.0.0.1 -U $$DB_USER $$DB_DATABASE",
      "restore_cmd": "docker exec -i -e PGPASSWORD=$$DB_PASSWORD postgres psql -U $$DB_USER -h localhost -d $$DB_DATABASE"
    }
  ]
}
endef

define config
	$(shell cat ${RESTIC_CONF} | jq -r "$(1)")
endef

define with_env
if [ -n "${RESTIC_ENV_FILE}" ] && [ -r "${RESTIC_ENV_FILE}" ]; then echo "*** Loading environment from ${RESTIC_ENV_FILE} ***" >&2; set -a; . "${RESTIC_ENV_FILE}" || exit 1; set +a; fi;
endef

define volume_config
	$(call config,.volumes[] | select(.name == \"$(1)\")$(2))
endef

define virtual_volume
	$(call config,.virtual_volumes[] | select(.name == \"$(1)\")$(2))
endef

define backup_volume
	echo "*** Backup volume $(1) ***"
	$(call with_env) restic backup $(call volume_config,$(1),|.backup_flags // empty) --tag $(1) --host "${HOST}" $(call volume_config,$(1),|.path);
endef

define backup_virtual_volume
	echo "*** Backup virtual_volume $(1) ***"
	$(call with_env) $(call virtual_volume,$(1),.backup_cmd) | restic backup $(call virtual_volume,$(1),.backup_flags // empty) --tag $(1) --host "${HOST}" --stdin
endef

define restore_volume
	echo "*** Restore volume '$(1)' from snapshot '$(2)' ***"
	$(call with_env) restic restore $(call volume_config,$(1),.restore_flags // empty) --target / "$(2)"
endef

define restore_virtual_volume
	echo "*** Restore virtual volume '$(1)' from snapshot '$(2)' ***"
	$(call with_env) restic dump $(call virtual_volume,$(1),.restore_flags // empty) $(2) /stdin | $(call virtual_volume,$(1),.restore_cmd)
endef

define volumes_names
	$(call config,.volumes[].name)
endef

define virtual_volumes_names
	$(call config,.virtual_volumes[].name)
endef

.PHONY: help
help:; @ $(info $(usage)) :

.PHONY: config-example
config-example:; @ $(info ${config_example}) :

.PHONY: init
init:
	@$(call with_env) restic snapshots -q >/dev/null 2>&1 || $(call with_env) restic init

.PHONY: snapshots
snapshots:
	@$(call with_env) restic snapshots --host "${HOST}"

.PHONY: list-volumes
list-volumes:
	@echo "** Volumes **"
	@$(foreach volume,$(call volumes_names),echo "- $(volume)";)

.PHONY: list-virtual-volumes
list-virtual-volumes:
	@echo "** Virtual volumes **"
	@$(foreach volume,$(call virtual_volumes_names),echo "- $(volume)";)

.PHONY: ensure-volume-presence
ensure-volume-presence:
	@test -n "${volume}" || (echo 'volume parameter is missing'; exit 1)

.PHONY: ensure-snapshot-presence
ensure-snapshot-presence:
	@test -n "${snapshot}" || (echo 'snapshot parameter is missing'; exit 1)

.PHONY: backup-volume
backup-volume: ensure-volume-presence
	@$(call backup_volume,${volume})

.PHONY: backup-volumes
backup-volumes:
	@$(foreach volume,$(call volumes_names),$(call backup_volume,$(volume)))

.PHONY: find-last-snapshot
find-last-snapshot: ensure-volume-presence
	@echo "*** Finding last snapshot for volume '${volume}' ***"
	@$(eval snapshot=$(shell $(call with_env) restic snapshots --tag ${volume} --host ${HOST} --latest 1 --json | jq -r .[].id))
	@echo "Last snapshot: ${snapshot}"

.PHONY: restore-volume
restore-volume: ensure-volume-presence ensure-snapshot-presence
	$(call restore_volume,${volume},${snapshot})

.PHONY: backup-virtual-volume
backup-virtual-volume: ensure-volume-presence
	$(call backup_virtual_volume,${volume})

.PHONY: backup-virtual-volumes
backup-virtual-volumes:
	$(foreach volume,$(call virtual_volumes_names),$(call backup_virtual_volume,$(volume)))

.PHONY: restore-virtual-volume
restore-virtual-volume: ensure-volume-presence ensure-snapshot-presence
	$(call restore_virtual_volume,${volume},${snapshot})
