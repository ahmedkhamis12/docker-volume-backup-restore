#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Check argument
if [ -z "$1" ]; then
  echo "❌ Usage: ./restore.sh <volume_name>"
  exit 1
fi

VOLUME_NAME="$1"
ZIP_PREFIX="${VOLUME_NAME}_"

# Create local backup dir
mkdir -p "$LOCAL_BACKUP_DIR"

echo "🔍 Finding latest backup for volume: $VOLUME_NAME on remote server..."
LATEST_ZIP=$(ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST" "ls -t $REMOTE_BACKUP_PATH/${ZIP_PREFIX}*.zip 2>/dev/null | head -n 1")

if [ -z "$LATEST_ZIP" ]; then
  echo "❌ No backup zip found for $VOLUME_NAME on remote server."
  exit 1
fi
# Get the name of the latest backup zip file
ZIP_FILENAME=$(basename "$LATEST_ZIP")
LOCAL_ZIP_PATH="$LOCAL_BACKUP_DIR/$ZIP_FILENAME"

# Download the zip file from the remote server to the local machine
echo "⬇️ Downloading: $ZIP_FILENAME from remote server..."
scp -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST:$LATEST_ZIP" "$LOCAL_ZIP_PATH"

# Find the container using this Docker volume
echo "🔍 Finding container using volume: $VOLUME_NAME"
CONTAINER_ID=$(docker ps -q --filter volume="$VOLUME_NAME")

if [ -n "$CONTAINER_ID" ]; then
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' "$CONTAINER_ID" | sed 's/^\/\(.*\)/\1/')
  echo "🛑 Stopping container: $CONTAINER_NAME"
  docker stop "$CONTAINER_NAME"
else
  echo "⚠️ No running container using volume $VOLUME_NAME. Proceeding to restore data only."
fi

# Use a helper container (BusyBox) to restore backup into the volume
echo "🧹 Restoring into volume $VOLUME_NAME using helper container..."

docker run --rm \
  -v "$VOLUME_NAME":/data \
  -v "$LOCAL_BACKUP_DIR":/backup \
  busybox sh -c "
    rm -rf /data/* && \
    unzip /backup/$(basename "$LOCAL_ZIP_PATH") -d /data
  "

# If the container was stopped, start it again
if [ -n "$CONTAINER_NAME" ]; then
  echo "🚀 Starting container: $CONTAINER_NAME"
  docker start "$CONTAINER_NAME"

fi

# Done!
echo "✅ Restore complete."
