#!/bin/sh
set -eu
umask 077

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Server defaults; override these paths for local testing if needed.
backup_directory=${BACKUP_DIR:-/var/backups/cookiesuite}
mkdir -p "$backup_directory"

# Both manual and scheduled runs append output and errors to this log.
log_file=${BACKUP_LOG:-/var/log/cookiesuite-backup.log}
touch "$log_file"
chmod 600 "$log_file"
exec >> "$log_file" 2>&1

# Hold the lock until this process exits; all callers share the backup directory.
exec 9>"$backup_directory/.backup.lock"
if ! flock -n 9; then
    printf '[%s] Backup skipped: another backup is running\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    exit 1
fi

printf '[%s] Backup started\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
temporary_file=$(mktemp "$backup_directory/cookiesuite-$timestamp-XXXXXX")
trap 'rm -f "$temporary_file"' EXIT
trap 'exit 1' HUP INT TERM

# pg_dump runs inside the database container; output is saved on the host.
docker compose exec -T db sh -c \
    'exec pg_dump --no-password -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
    > "$temporary_file"

# Check that the output is a readable archive before publishing the filename.
# A full restore test is still required to verify recovery.
docker compose exec -T db pg_restore --list < "$temporary_file" > /dev/null

backup_file="$temporary_file.dump"
mv "$temporary_file" "$backup_file"
printf '[%s] Backup saved: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$backup_file"
