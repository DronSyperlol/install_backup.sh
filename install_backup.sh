#!/bin/bash
set -euo pipefail

SERVICE_USER="backup-service"
SERVICE_HOME="/home/$SERVICE_USER"

if [[ $EUID -ne 0 ]]; then
    echo "run as root"
    exit 1
fi

if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$SERVICE_USER"
    echo "created user: $SERVICE_USER"
fi

read -rp "Project name: " PROJECT_NAME
read -rp "DB names. (Example: DB1 DB2): " DB_NAME
read -rp "DB user: " DB_USER
read -rsp "DB password: " DB_PASS
echo

PROJECT_DIR="$SERVICE_HOME/$PROJECT_NAME"
BACKUP_DIR="$PROJECT_DIR/backups"

mkdir -p "$BACKUP_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"

cat > "$PROJECT_DIR/backup.sh" <<EOF
#!/bin/bash
set -euo pipefail

PROJECT_NAME="$PROJECT_NAME"
read -ra DB_NAMES <<< "$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"

WORKDIR="/home/backup-service/\$PROJECT_NAME"
BACKUP_DIR="\$WORKDIR/backups/"
TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")

REMOVE_BACKUPS_OLDER_DAYS=3

FILEEXT="sql.gz"
FILENAME="\${PROJECT_NAME}_\$TIMESTAMP.\$FILEEXT"

echo "dump database..."
echo "set here dump command"
# docker exec \\
#   -e MYSQL_PWD="\$DB_PASS" \\
#   -i mysql \\
#   mysqldump --single-transaction --quick -u "\$DB_USER" --databases "\${DB_NAMES[@]}" \\
#   | pigz -p2 \\
#   > "\$BACKUP_DIR/\$FILENAME"
echo "dump database...    done"

echo "mark as latest..."
if [[ ! -f "\$BACKUP_DIR/\$FILENAME" ]]; then
    echo "backup command not set: \$BACKUP_DIR/\$FILENAME"
    exit 1
fi
LATEST_NAME="\$BACKUP_DIR/latest"
LATEST_HASH_NAME="\$BACKUP_DIR/latest_hash"
NEW_LATEST_HASH_NAME="\$LATEST_HASH_NAME.new"

echo "\$(md5sum "\$BACKUP_DIR/\$FILENAME" | awk '{ print \$1 }') \$(sha256sum "\$BACKUP_DIR/\$FILENAME" | awk '{ print \$1 }')" > "\$NEW_LATEST_HASH_NAME"

ln -sf "\$FILENAME" "\$LATEST_NAME"
mv "\$NEW_LATEST_HASH_NAME" "\$LATEST_HASH_NAME"

echo "mark as latest...    done"

echo "remove backups older \$REMOVE_BACKUPS_OLDER_DAYS days..."
find "\$BACKUP_DIR" -type f -name "\${PROJECT_NAME}_*.\$FILEEXT" -mtime "+\$REMOVE_BACKUPS_OLDER_DAYS" -delete
echo "remove backups older \$REMOVE_BACKUPS_OLDER_DAYS days...    done"
EOF

chmod 700 "$PROJECT_DIR/backup.sh"
chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/backup.sh"

CRON_LINE="#0 3 * * * $PROJECT_DIR/backup.sh >> $PROJECT_DIR/cron.log 2>&1"

if crontab -u root -l 2>/dev/null | grep -Fq "$PROJECT_DIR/backup.sh"; then
    echo "Cron already exist"
else
    echo "Prepare cron..."
    (crontab -u root -l 2>/dev/null; echo "$CRON_LINE") | crontab -u root -
    echo "Prepare cron...    done. You need activate it manually"
fi

echo
echo "installed:"
echo "$PROJECT_DIR/backup.sh"

echo "####################################"
echo "#              WARNING             #"
echo "#  You will need to configure the  #"
echo "#  database dump command yourself  #"
echo "####################################"
