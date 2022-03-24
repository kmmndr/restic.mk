# Restic.mk

[Restic](https://restic.net/) is a wonderful backup tool. But it has no
configuration file. This project aim to simply automate backup tasks.

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
    Print config example (restic.mk config-example > $HOME/.restic.json)

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

  find-last-snapshot -e volume=...
    Find last snapshot id for a given volume name
    May be combined to restore last volume
    (restic.mk -e volume=... find-last-snapshot restore-volume)

  restore-volume -e volume=... snapshot=...
    Restore specified snapshot to volume
  restore-virtual-volume -e volume=... snapshot=...
    Restore specified snapshot to virtual volume
```
