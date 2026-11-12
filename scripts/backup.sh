#!/bin/sh
set -eu
umask 077

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Set BACKUP_DIR to use a different directory on the production server.
backup_directory=${BACKUP_DIR:-"$PWD/backups"}
mkdir -p "$backup_directory"
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
printf 'Backup saved: %s\n' "$backup_file"
