


#!/bin/bash

# --- Load environment variables ---
set -a
source .env
set +a

# --- Input volume name ---
VOLUME_NAME="$1"
BACKUP_DIR="./backups"
LOG_DIR="./logs"
DATE=$(date +%F_%H-%M-%S)
HUMAN_DATE=$(date "+%F %H:%M:%S")
BACKUP_FILE="${VOLUME_NAME}_${DATE}.zip"
LOG_FILE="${LOG_DIR}/${VOLUME_NAME}_last_backup.log"

# --- Validate volume name ---
if [ -z "$VOLUME_NAME" ]; then
  echo "❌ Usage: $0 <volume-name>"
  exit 1
fi

# --- Create folders if not exist ---
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# --- Get real volume mountpoint ---
MOUNTPOINT=$(docker volume inspect "$VOLUME_NAME" --format '{{ .Mountpoint }}')

# --- Find containers using the volume ---
CONTAINERS=()
for cont in $(docker ps -q); do
  if docker inspect "$cont" | grep -q "$VOLUME_NAME"; then
    CONTAINERS+=("$cont")
  fi
done

# --- Stop containers using the volume ---
for c in "${CONTAINERS[@]}"; do
  docker stop "$c" >/dev/null
done

# --- Run the backup using Alpine with zip ---
docker run --rm \
  -v "$VOLUME_NAME":/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine sh -c "apk add zip >/dev/null && cd /data && zip -r /backup/$BACKUP_FILE . >/dev/null"

# --- Start containers again ---
for c in "${CONTAINERS[@]}"; do
  docker start "$c" >/dev/null
done

# --- Save backup metadata ---
echo "Backup Date: $HUMAN_DATE" > "$LOG_FILE"
echo "Backup File: $BACKUP_FILE" >> "$LOG_FILE"

# --- Prepare remote backup folder ---
echo "🛠️ Preparing backup directory on remote SSH server..."
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" \
  "mkdir -p $REMOTE_BACKUP_PATH && chmod 755 $REMOTE_BACKUP_PATH"

# --- Upload to remote server using SCP ---
echo "📤 Uploading to SSH server..."
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
  "$BACKUP_DIR/$BACKUP_FILE" \
  "$REMOTE_USER@$REMOTE_HOST:$REMOTE_BACKUP_PATH"

# --- Compute local SHA256 ---
LOCAL_HASH=$(sha256sum "$BACKUP_DIR/$BACKUP_FILE" | awk '{ print $1 }')

# --- Compute remote SHA256 ---
REMOTE_HASH=$(ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST" "sha256sum '$REMOTE_BACKUP_PATH/$BACKUP_FILE' | awk '{print \$1}'")

# --- Compare hashes ---
if [ "$LOCAL_HASH" == "$REMOTE_HASH" ]; then
  echo "✅ Backup compared and fully uploaded successfully: $BACKUP_FILE"
  echo "🧹 Cleaning up local backup..."
  rm -f "$BACKUP_DIR/$BACKUP_FILE"
else
  echo "❌ Hash mismatch! Backup may be corrupted during upload."
  echo "Local:  $LOCAL_HASH"
  echo "Remote: $REMOTE_HASH"
fi

# --- Final Result ---
if [ $? -eq 0 ]; then
  echo "✅ Backup completed: $BACKUP_FILE"
else
  echo "⚠️ Backup created but upload failed!"
fi
