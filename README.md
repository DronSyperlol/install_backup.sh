# Backup Scripts

A small set of installation scripts for automated database backup management.

## Scripts

### `install_backup.sh`

Installs a database backup script on the target server.

Features:

- Creates compressed database dumps
- Prepares backup storage location
- Designed for automated execution (cron)

Run:

```bash
bash <(curl -s https://raw.githubusercontent.com/DronSyperlol/install_backup.sh/refs/heads/main/install_backup.sh)
````

---

### `install_download_backup.sh`

Installs a script for downloading database backups from a remote server.

Features:

* Connects to the remote backup server
* Downloads backup archives securely over SSH
* Uses key-based authentication
* Suitable for scheduled local synchronization

Run:

```bash
bash <(curl -s https://raw.githubusercontent.com/DronSyperlol/install_backup.sh/refs/heads/main/install_download_backup.sh)
```

---

## Requirements

### `install_backup.sh`

* Linux
* Bash
* SSH access
* Database dump utility (`mysqldump`, `mariadb-dump`, or compatible)

### `install_download_backup.sh`

* Linux
* Bash
* `scp`
* Database dump utility (`mysqldump`, `mariadb-dump`, or compatible)

---

## Authentication

The installer generates a dedicated SSH key pair.

The generated public key must be added to the
`authorized_keys` file of the `backup-service` user on the remote server
to enable secure key-based authentication.

Alternative authentication methods are also supported, including password-based authentication and SSH alias configuration.
