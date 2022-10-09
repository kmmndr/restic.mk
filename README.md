# Restic.mk

[Restic](https://restic.net/) is a wonderful backup tool, but it has no
configuration file. [restic.mk](https://github.com/kmmndr/restic.mk) aims to
automate backup and restore tasks in the simplest way.

## Requirements

The following tools are required:
- coreutils
- jq
- make

## Installation

```
# installation
env PREFIX=~/.local make install

# uninstallation
env PREFIX=~/.local make uninstall
```

## Configuration

Simple configuration example

```
$ restic.mk config-example
{
  "volumes": [
    {
      "name": "home_user",
      "path": "/home/user",
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
      "backup_cmd": "docker exec -it -e PGPASSWORD=$DB_PASSWORD postgres pg_dump --clean -h 127.0.0.1 -U $DB_USER $DB_DATABASE",
      "restore_cmd": "docker exec -i -e PGPASSWORD=$DB_PASSWORD postgres psql -U $DB_USER -h localhost -d $DB_DATABASE"
    }
  ]
}

# Add a default configuration file as an example
$ restic.mk config-example > $HOME/.restic.json
```

## Usage

```
$ restic.mk
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
```
