# Restic.mk

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
cat >> $HOME/restic.json <<EOF
{
  "virtual": [
    {
      "name": "mariadb",
      "backup_cmd": "docker exec db_1 mysqldump --all-databases -uroot -p$$MYSQL_ROOT_PASSWORD",
      "restore_cmd": "docker exec -i db_1 mysql --user=root --password=$$MYSQL_ROOT_PASSWORD"
    }
  ]
}
EOF
```

## Usage

```
$ restic.mk
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
```
