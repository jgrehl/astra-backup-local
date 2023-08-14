![Docker pulls](https://img.shields.io/docker/pulls/jgrehl/astra-backup-local)
![GitHub actions](https://github.com/jgrehl/docker-astra-backup-local/actions/workflows/ci.yml/badge.svg?branch=main)

# docker-astra-backup-local

Backup Astra to the local filesystem with periodic rotating backups, based on [prodrigestivill/postgres-backup-local](https://hub.docker.com/r/prodrigestivill/postgres-backup-local/).

Supports the following Docker architectures: `linux/amd64`, `linux/arm64`, `linux/arm/v8`.

Please consider reading detailed the [How the backups folder works?](#how-the-backups-folder-works).

## Usage

Docker:

```sh
docker run -e ASTRA_DB_ID=id -e ASTRA_DB_REGION=eu-central-1 -e ASTRA_DB_SECURE_BUNDLE_FILE=scb_path -e ASTRA_DB_KEYSPACE=keyspace -e ASTRA_DB_PASSWORD=password  jgrehl/astra-backup-local
```

### How the backups folder works?

First a new backup is created in the `last` folder with the full time.

Once this backup finish succefully then, it is hard linked (instead of coping to avoid use more space) to the rest of the folders (daily, weekly and monthly). This step replaces the old backups for that category storing always only the latest for each category (so the monthly backup for a month is always storing the latest for that month and not the first).

So the backup folder are structured as follows:

* `BACKUP_DIR/last/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYMMDD-HHmmss.tgz`: all the backups are stored separatly in this folder.
* `BACKUP_DIR/daily/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYMMDD.tgz`: always store (hard link) the **latest** backup of that day.
* `BACKUP_DIR/weekly/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYww.tgz`: always store (hard link) the **latest** backup of that week (the last day of the week will be Sunday as it uses ISO week numbers).
* `BACKUP_DIR/monthly/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYMM.tgz`: always store (hard link) the **latest** backup of that month (normally the ~31st).

And the following symlinks are also updated after each successfull backup for simlicity:

```
BACKUP_DIR/last/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-latest.tgz -> BACKUP_DIR/last/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYMMDD-HHmmss.tgz
BACKUP_DIR/daily/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-latest.tgz -> BACKUP_DIR/daily/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYMMDD.tgz
BACKUP_DIR/weekly/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-latest.tgz -> BACKUP_DIR/weekly/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYww.tgz
BACKUP_DIR/monthly/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-latest.tgz -> BACKUP_DIR/monthly/ASTRA_DB_ID-ASTRA_DB_KEYSPACE-YYYYMM.tgz
```

For **cleaning** the script removes the files for each category only if the new backup has been successfull.
To do so it is using the following independent variables:

* BACKUP_KEEP_MINS: will remove files from the `last` folder that are older than its value in minutes after a new successfull backup without affecting the rest of the backups (because they are hard links).
* BACKUP_KEEP_DAYS: will remove files from the `daily` folder that are older than its value in days after a new successfull backup.
* BACKUP_KEEP_WEEKS: will remove files from the `weekly` folder that are older than its value in weeks after a new successfull backup (remember that it starts counting from the end of each week not the beggining).
* BACKUP_KEEP_MONTHS: will remove files from the `monthly` folder that are older than its value in months (of 31 days) after a new successfull backup (remember that it starts counting from the end of each month not the beggining).

### Hooks

The folder `hooks` inside the container can contain hooks/scripts to be run in differrent cases getting the exact situation as a first argument (`error`, `pre-backup` or `post-backup`).

Just create an script in that folder with execution permission so that [run-parts](https://manpages.debian.org/stable/debianutils/run-parts.8.en.html) can execute it on each state change.

Please, as an example take a look in the script already present there that implements the `WEBHOOK_URL` functionality.

### Manual Backups

By default this container makes daily backups, but you can start a manual backup by running `/backup.sh`.

This script as example creates one backup as the running user and saves it the working folder.

```sh
docker run --rm -v "$PWD:/backups" -u "$(id -u):$(id -g)" -e ASTRA_DB_ID=id -e ASTRA_DB_REGION=eu-central-1 -e ASTRA_DB_SECURE_BUNDLE_FILE=scb_path -e ASTRA_DB_KEYSPACE=keyspace -e ASTRA_DB_PASSWORD=password  jgrehl/astra-backup-local /backup.sh
```

### Automatic Periodic Backups

You can change the `SCHEDULE` environment variable in `-e SCHEDULE="@daily"` to alter the default frequency. Default is `daily`.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

Folders `daily`, `weekly` and `monthly` are created and populated using hard links to save disk space.

## Restore examples

Some examples to restore/apply the backups.

### Restore using the same container

To restore using the same backup container, replace `$BACKUPFILE`, `$CONTAINER`, `$USERNAME` and `$DBNAME` from the following command:

```sh
docker exec --tty --interactive $CONTAINER /bin/sh -c "zcat $BACKUPFILE | psql --username=$USERNAME --dbname=$DBNAME -W"
```

### Restore using a new container

Replace `$BACKUPFILE`, `$VERSION`, `$HOSTNAME`, `$PORT`, `$USERNAME` and `$DBNAME` from the following command:

```sh
docker run --rm --tty --interactive -v $BACKUPFILE:/tmp/backupfile.sql.gz postgres:$VERSION /bin/sh -c "zcat /tmp/backupfile.sql.gz | psql --host=$HOSTNAME --port=$PORT --username=$USERNAME --dbname=$DBNAME -W"
```
