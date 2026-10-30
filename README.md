# Restic.mk

[Restic](https://restic.net/) is a wonderful backup tool, but it has no
configuration file. [restic.mk](https://github.com/kmmndr/restic.mk) aims to
automate backup and restore tasks in the simplest way.

## Requirements

The following tools are required:
- restic
- coreutils (for the `env -S` shebang)
- jq
- GNU Make

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

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `RESTIC_CONF` | `~/.restic.json` | Path to the JSON configuration file |
| `HOST` | `hostname -f` | Hostname passed to restic (`--host`) |
| `RESTIC_ENV_FILE` | `~/.restic.env` | `KEY=value` file sourced and exported before each `restic` call |
| `RESTIC_FLAGS` | none | Extra options passed to every `restic` call (e.g. `--insecure-tls`) |

`restic` reads its own settings from the environment (`RESTIC_REPOSITORY`,
`RESTIC_PASSWORD_FILE`, `RESTIC_REST_USERNAME`, `RESTIC_REST_PASSWORD`, ...).
restic.mk passes its environment through to `restic`, so exporting them works
out of the box:

```sh
export RESTIC_REPOSITORY="rest:https://backup.example.com:8000/host1"
export RESTIC_PASSWORD_FILE="/etc/restic/password"
export RESTIC_REST_USERNAME="backup-user"
export RESTIC_REST_PASSWORD="mot-de-passe-http"

restic.mk backup-volumes
```

Alternatively, keep them in `~/.restic.env` (the default) or in any file
pointed to by `RESTIC_ENV_FILE` (e.g. `/etc/restic/restic.env`, `chmod 600`) —
nothing needs to be exported:

```
RESTIC_REPOSITORY=rest:https://backup.example.com:8000/host1
RESTIC_PASSWORD_FILE=/etc/restic/password
RESTIC_REST_USERNAME=backup-user
RESTIC_REST_PASSWORD=mot-de-passe-http
```

```sh
restic.mk RESTIC_ENV_FILE=/etc/restic/restic.env backup-volumes

# or from cron:
17 3 * * * root RESTIC_ENV_FILE=/etc/restic/restic.env restic.mk backup-volumes
```

Custom restic options — e.g. `--insecure-tls` for a rest-server with a
self-signed certificate (restic has no official env var for this flag) — can
be passed to every `restic` call via `RESTIC_FLAGS`, set from the environment,
the command line, or the env file:

```sh
restic.mk RESTIC_FLAGS=--insecure-tls backup-volumes
# or in ~/.restic.env:
# RESTIC_FLAGS=--insecure-tls
```

The env file has no fixed content: any `KEY=value` lines are exported before
each `restic` call and are also visible to the `backup_cmd`/`restore_cmd` of
virtual volumes. The file is optional: if it does not exist (the default
`~/.restic.env` or a custom `RESTIC_ENV_FILE`), no environment variables are
loaded and restic.mk runs without them.

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

  RESTIC_FLAGS
    Extra options passed to every restic call, e.g. --insecure-tls for a
    rest-server with a self-signed certificate. Set via the environment,
    the command line, or the env file:
      restic.mk RESTIC_FLAGS=--insecure-tls backup-volumes
```

## Tests

```
make check
```

runs the test suite in `tests/` (local backend and `RESTIC_ENV_FILE` scenarios).
It needs `restic`, `jq` and GNU Make, works in temporary directories only and
requires no network access. Run a subset with e.g.
`make check TESTS="tests/test-local.sh"`. The output is TAP, so it can also be
fed to `prove tests/test-*.sh`.
