#!/bin/bash
set -euo pipefail

SERVICE_USER="backup-service"

read -rp "Project name: " PROJECT_NAME

DEFAULT_WORKDIR="$(pwd)/$PROJECT_NAME"
read -rp "Installation directory [$DEFAULT_WORKDIR]: " WORKDIR
WORKDIR=${WORKDIR:-"$DEFAULT_WORKDIR"}
mkdir -p "$WORKDIR"
BACKUP_DIR="$WORKDIR/backups"
mkdir -p "$BACKUP_DIR"

read -rp "Remote host: " HOST
read -rp "Remote ssh port [22]: " PORT
PORT=${PORT:-22}

read -rp "Auth method (key/password/alias): " AUTH_METHOD
case "$AUTH_METHOD" in
    key)
        DEFAULT_SSH_KEY="$WORKDIR/.ssh/id_ed25519"
        read -rp "SSH key path [$DEFAULT_SSH_KEY]: " SSH_KEY
		SSH_KEY=${SSH_KEY:-"$DEFAULT_SSH_KEY"}
        if [[ ! -f "$SSH_KEY" ]]; then
        	read -rp "File not exist. Do you want to generate a new ssh key? [y/N]: " GENERATE_NEW_SSH
        	if [[ "$GENERATE_NEW_SSH" =~ ^[Yy]$ ]]; then
        		command -v ssh-keygen >/dev/null || {
		            echo "sshpass required"
		            exit 1
		        }
		        DEFAULT_SSH_KEY="$WORKDIR/.ssh/id_ed25519"
				read -rp "Where to save the new key? [$DEFAULT_SSH_KEY]: " SSH_KEY
				SSH_KEY=${SSH_KEY:-"$DEFAULT_SSH_KEY"}
				mkdir -p $(dirname "$SSH_KEY")
		        ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
		        echo "Install the newly generated public SSH key into the authorized_keys file of the backup-service user on the server to enable key-based authentication."
				echo "Public key: $(cat "$SSH_KEY.pub")"
		        read -rp "Press Enter to continue..."
        	fi
        fi
        ;;
    password)
		command -v sshpass >/dev/null || {
            echo "sshpass required"
            exit 1
        }
        read -rp "Using a password is insecure. Do you want to continue? [y/N]: " CONTINUE_WITH_PASSWORD
		if [[ ! "$CONTINUE_WITH_PASSWORD" =~ ^[Yy]$ ]]; then
		    echo "Abort"
		    exit 1
		fi
        read -rsp "SSH password: " SSH_PASS
        echo
        ;;
    alias)
        read -rp "SSH config alias: " SSH_ALIAS
        ;;
    *)
        echo "invalid auth method"
        exit 1
        ;;
esac

SSH_OPTS=""
read -rp "Disable strict host key checking? [y/N]: " DISABLE_STRICT
if [[ "$DISABLE_STRICT" =~ ^[Yy]$ ]]; then
    SSH_OPTS="-o StrictHostKeyChecking=no"
fi

DEFAULT_DOWNLOAD_TARGET="/home/$SERVICE_USER/$PROJECT_NAME/backups/latest"
read -rp "Remote source file [$DEFAULT_DOWNLOAD_TARGET]: " DOWNLOAD_TARGET
DOWNLOAD_TARGET=${DOWNLOAD_TARGET:-"$DEFAULT_DOWNLOAD_TARGET"}

cat > "$WORKDIR/download.sh" <<EOF
#!/bin/bash
set -euo pipefail

DEST_FILENAME="$BACKUP_DIR/${PROJECT_NAME}_\$(date +"%Y%m%d_%H%M%S").sql.gz"

$(
case "$AUTH_METHOD" in
	key)
        echo "scp $SSH_OPTS -i \"$SSH_KEY\" -P \"$PORT\" \"$SERVICE_USER\"@\"$HOST\":\"$DOWNLOAD_TARGET\" \$DEST_FILENAME"
        ;;

    password)
        echo "sshpass -p \"$SSH_PASS\" scp $SSH_OPTS -P \"$PORT\" \"$SERVICE_USER\"@\"$HOST\":\"$DOWNLOAD_TARGET\" \$DEST_FILENAME"
        ;;

    alias)
        echo "scp $SSH_OPTS \"$SSH_ALIAS\":\"$DOWNLOAD_TARGET\" \$DEST_FILENAME"
        ;;
esac
)

[[ -f "\$DEST_FILENAME" ]] || exit 1
pigz -t "\$DEST_FILENAME"

REMOVE_BACKUPS_OLDER_DAYS=3

find "$BACKUP_DIR" \
    -type f \
    -name "${PROJECT_NAME}_*.sql.gz" \
    -mtime "+\$REMOVE_BACKUPS_OLDER_DAYS" \
    -delete
EOF

chmod 700 "$WORKDIR/download.sh"

CRON_LINE_EXECUTE="$WORKDIR/download.sh >> $WORKDIR/cron.log 2>&1"
CRON_LINE="0 4 * * * $CRON_LINE_EXECUTE"

if crontab -u root -l 2>/dev/null | grep -Fq "$CRON_LINE_EXECUTE"; then
    echo "Cron already exist"
else
    echo "Prepare cron..."
    (crontab -u root -l 2>/dev/null; echo "#$CRON_LINE") | crontab -u root -
    echo "Prepare cron...    done. You need activate it manually"
fi

echo
echo "installed:"
echo "$WORKDIR/download.sh"
echo "prepared crontab for root user. Activate it manually."
