**CookieSuite — Container Setup**

**Architecture**

```text
Host 127.0.0.1:8080 → app:8080 → db:5432 → postgres_data
```

- **Images:** `dunglas/frankenphp:1.13.5-php8.3`, `postgres:17`.
- Storage: named volume → `/var/lib/postgresql/data`.
- Network: application bound to host loopback only; no published database port.

Developers: see Notes / Potential Improvements below for version selection.

**Files**

- `Dockerfile`
- `compose.yaml`
- `scripts/init.sh`
- `.dockerignore`

**Initialization**

Run on the host:

```sh
sh scripts/init.sh
```

The script:

- Creates `.env` from `.env.example` if missing; sets production mode and disables debug.
- Generates and saves a database password and Laravel key if empty.
- Preserves existing credentials; sets `.env` permissions to `600`.

Manually set `APP_URL` and mail settings in `.env`.
Compose supplies `DB_HOST=db` and `DB_PORT=5432` (PostgreSQL default).

**First Run**

From the repository root; Docker, Compose and OpenSSL required:

```sh
sh scripts/init.sh
nano .env  # Set APP_URL and mail settings.
docker compose up -d --wait db
docker compose run --rm app php artisan migrate --force
docker compose up -d app
docker compose ps
```

Local access: [localhost:8080](http://localhost:8080). Server deployment requires a reverse proxy or SSH tunnel for remote access.

**Update**

Back up the database first. Then run:

```sh
docker compose build app
docker compose run --rm app php artisan migrate --force
docker compose up -d app
```

Only the app container is updated. Database migrations may modify or delete data.

Preserve configuration and database data during updates. Avoid `docker compose down -v`, which deletes the database volume.

**Notes / Potential Improvements**

- **Version selection:** Confirm image and runtime versions with the developers. Meeting minimum requirements does not guarantee compatibility. Prefer maintained stable releases and validate the application before deployment.
- **CI image publishing:** Build, test and publish images in CI; pull them during deployment to save time and manual work.
