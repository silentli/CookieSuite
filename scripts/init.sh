#!/bin/sh
set -eu
umask 077

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

new_environment=false
if [ ! -f .env ]; then
    cp .env.example .env
    new_environment=true
fi
chmod 600 .env

# Read values as text; never execute the contents of .env as shell code.
read_value() {
    awk -v key="$1" '
        index($0, key "=") == 1 { value = substr($0, length(key) + 2) }
        END { print value }
    ' .env
}

temporary_file=
trap '[ -z "$temporary_file" ] || rm -f "$temporary_file"' EXIT
trap 'exit 1' HUP INT TERM

write_value() {
    temporary_file=$(mktemp .env.tmp.XXXXXX)
    ENV_UPDATE_KEY="$1" ENV_UPDATE_VALUE="$2" awk '
        BEGIN { key = ENVIRON["ENV_UPDATE_KEY"]; value = ENVIRON["ENV_UPDATE_VALUE"] }
        index($0, key "=") == 1 { print key "=" value; found = 1; next }
        { print }
        END { if (!found) print key "=" value }
    ' .env > "$temporary_file"
    mv "$temporary_file" .env
    temporary_file=
}

if [ "$new_environment" = true ]; then
    write_value APP_ENV production
    write_value APP_DEBUG false
fi

database_password=$(read_value DB_PASSWORD)
case "$database_password" in
    ''|'""'|"''")
        database_password=$(openssl rand -hex 32)
        write_value DB_PASSWORD "$database_password"
        printf '%s\n' 'Generated DB_PASSWORD.'
        ;;
    *) printf '%s\n' 'Kept existing DB_PASSWORD.' ;;
esac

application_key=$(read_value APP_KEY)
case "$application_key" in
    ''|'""'|"''")
        docker compose build app
        application_key=$(docker compose run --rm --no-deps app \
            php artisan key:generate --show --no-ansi)
        if ! printf '%s\n' "$application_key" | grep -Eq '^base64:[A-Za-z0-9+/]{43}=$'; then
            printf '%s\n' 'Failed to generate APP_KEY; .env key was not changed.' >&2
            exit 1
        fi
        write_value APP_KEY "$application_key"
        printf '%s\n' 'Generated APP_KEY.'
        ;;
    *) printf '%s\n' 'Kept existing APP_KEY.' ;;
esac

printf '%s\n' 'Initialization complete. Database and application services were not started.'
