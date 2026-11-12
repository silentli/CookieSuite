**CookieSuite — Database Backup**

**Architecture**

```text
Host Cron (root) → backup.sh → pg_dump inside db container → backup file on host
```

- Format: compressed PostgreSQL archive (`pg_dump -Fc`).
- Storage: host directory, outside the database volume.
- Application and database remain running.

**Files / Paths**

- `scripts/backup.sh`
- `/etc/cron.d/cookiesuite-backup`
- `/var/backups/cookiesuite/`
- `/var/log/cookiesuite-backup.log`

**Manual Backup**

Run as root from the repository root, with the database running:

```sh
sh scripts/backup.sh
```

Output: `/var/backups/cookiesuite/cookiesuite-<UTC timestamp>-<random suffix>.dump`.
Output and errors are appended to `/var/log/cookiesuite-backup.log`.

The script writes a temporary file, checks the archive directory, then renames it to `.dump`. Failed backups are removed.
New files use permissions `600`.

**Scheduled Backup (Cron)**

Example: daily at 03:00, using the server's timezone. Use the actual repository's absolute path in the Cron command.

```sh
nano /etc/cron.d/cookiesuite-backup
```

```cron
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

0 3 * * * root /bin/sh /root/CookieSuite/scripts/backup.sh
```

Keep a final newline. The file must be root-owned with permissions `644`. The Cron service must be running.
The script uses `flock` internally with `/var/backups/cookiesuite/.backup.lock`, protecting both manual and scheduled runs. Remove the outer `flock` from the previous Cron command.

**Check Results**

```sh
tail -n 50 /var/log/cookiesuite-backup.log
ls -lt /var/backups/cookiesuite/
```

Confirm that a new backup appears after the scheduled time.

**Notes / Potential Improvements**

**Permissions:** Consider a dedicated backup user with limited privileges instead of root, without unrestricted Docker access.

**Backup storage:** Consider cloud or external storage. Automate retention and cleanup using object storage lifecycle rules or local scripts.
- **Recovery:** Test restoration into a separate database. Archive checks alone do not prove recovery works.
- **Configuration:** Back up `.env` separately. Database role definitions are not included in this single-database dump.
- **Automation:** Automate directory and Cron setup without overwriting existing settings; add failure notifications.
