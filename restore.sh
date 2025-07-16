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

ZIP_FILENAME=$(basename "$LATEST_ZIP")
LOCAL_ZIP_PATH="$LOCAL_BACKUP_DIR/$ZIP_FILENAME"

echo "⬇️ Downloading: $ZIP_FILENAME from remote server..."
scp -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST:$LATEST_ZIP" "$LOCAL_ZIP_PATH"

echo "🔍 Finding container using volume: $VOLUME_NAME"
CONTAINER_ID=$(docker ps -q --filter volume="$VOLUME_NAME")

if [ -n "$CONTAINER_ID" ]; then
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' "$CONTAINER_ID" | sed 's/^\/\(.*\)/\1/')
  echo "🛑 Stopping container: $CONTAINER_NAME"
  docker stop "$CONTAINER_NAME"
else
  echo "⚠️ No running container using volume $VOLUME_NAME. Proceeding to restore data only."
fi

# MOUNT_POINT="/var/lib/docker/volumes/${VOLUME_NAME}/_data"

# if [ ! -d "$MOUNT_POINT" ]; then
#   echo "❌ Volume mount point not found: $MOUNT_POINT"
#   exit 1
# fi

# echo "🧹 Clearing volume data at: $MOUNT_POINT"
# rm -rf "${MOUNT_POINT:?}/"*

# echo "🗂️ Restoring from zip to volume..."
# unzip -q "$LOCAL_ZIP_PATH" -d "$MOUNT_POINT"

echo "🧹 Restoring into volume $VOLUME_NAME using helper container..."

docker run --rm \
  -v "$VOLUME_NAME":/data \
  -v "$LOCAL_BACKUP_DIR":/backup \
  busybox sh -c "
    rm -rf /data/* && \
    unzip /backup/$(basename "$LOCAL_ZIP_PATH") -d /data
  "


if [ -n "$CONTAINER_NAME" ]; then
  echo "🚀 Starting container: $CONTAINER_NAME"
  docker start "$CONTAINER_NAME"

fi

echo "✅ Restore complete."

#!/bin/bash

# # Load environment variables
# set -a
# source .env
# set +a

# # Check argument
# if [ -z "$1" ]; then
#   echo "❌ Usage: ./restore.sh <volume_name>"
#   exit 1
# fi

# VOLUME_NAME="$1"
# ZIP_PREFIX="${VOLUME_NAME}_"

# # Create local backup dir
# mkdir -p "$LOCAL_BACKUP_DIR"

# echo "🔍 Finding latest backup for volume: $VOLUME_NAME on EC2..."
# LATEST_ZIP=$(ssh -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP" "ls -t $EC2_BACKUP_PATH/${ZIP_PREFIX}*.zip 2>/dev/null | head -n 1")

# if [ -z "$LATEST_ZIP" ]; then
#   echo "❌ No backup zip found for $VOLUME_NAME on EC2."
#   exit 1
# fi

# ZIP_FILENAME=$(basename "$LATEST_ZIP")
# LOCAL_ZIP_PATH="$LOCAL_BACKUP_DIR/$ZIP_FILENAME"

# echo "⬇️ Downloading: $ZIP_FILENAME from EC2..."
# scp -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP:$LATEST_ZIP" "$LOCAL_ZIP_PATH"

# echo "🔍 Finding container using volume: $VOLUME_NAME"
# CONTAINER_NAME=$(docker ps -q --filter volume="$VOLUME_NAME" | xargs -r docker inspect --format '{{.Name}}' | sed 's/^\/\(.*\)/\1/')

# if [ -z "$CONTAINER_NAME" ]; then
#   echo "⚠️ No running container using volume $VOLUME_NAME. Proceeding to restore data only."
# else
#   echo "🛑 Stopping container: $CONTAINER_NAME"
#   docker stop "$CONTAINER_NAME"
# fi

# MOUNT_POINT="/var/lib/docker/volumes/${VOLUME_NAME}/_data"

# echo "🧹 Clearing volume data at: $MOUNT_POINT"
# rm -rf "${MOUNT_POINT:?}/"*

# echo "🗂️ Restoring from zip to volume..."
# unzip -q "$LOCAL_ZIP_PATH" -d "$MOUNT_POINT"

# if [ -n "$CONTAINER_NAME" ]; then
#   echo "🚀 Starting container: $CONTAINER_NAME"
#   docker start "$CONTAINER_NAME"

#   echo "🔍 Verifying restoration inside container..."
#   docker exec "$CONTAINER_NAME" cat /data/test.txt 2>/dev/null || echo "⚠️ Could not verify test.txt inside container."
# fi

# echo "✅ Restore complete."


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

ZIP_FILENAME=$(basename "$LATEST_ZIP")
LOCAL_ZIP_PATH="$LOCAL_BACKUP_DIR/$ZIP_FILENAME"

echo "⬇️ Downloading: $ZIP_FILENAME from remote server..."
scp -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST:$LATEST_ZIP" "$LOCAL_ZIP_PATH"

echo "🔍 Finding container using volume: $VOLUME_NAME"
CONTAINER_ID=$(docker ps -q --filter volume="$VOLUME_NAME")

if [ -n "$CONTAINER_ID" ]; then
  CONTAINER_NAME=$(docker inspect --format '{{.Name}}' "$CONTAINER_ID" | sed 's/^\/\(.*\)/\1/')
  echo "🛑 Stopping container: $CONTAINER_NAME"
  docker stop "$CONTAINER_NAME"
else
  echo "⚠️ No running container using volume $VOLUME_NAME. Proceeding to restore data only."
fi

# MOUNT_POINT="/var/lib/docker/volumes/${VOLUME_NAME}/_data"

# if [ ! -d "$MOUNT_POINT" ]; then
#   echo "❌ Volume mount point not found: $MOUNT_POINT"
#   exit 1
# fi

# echo "🧹 Clearing volume data at: $MOUNT_POINT"
# rm -rf "${MOUNT_POINT:?}/"*

# echo "🗂️ Restoring from zip to volume..."
# unzip -q "$LOCAL_ZIP_PATH" -d "$MOUNT_POINT"

echo "🧹 Restoring into volume $VOLUME_NAME using helper container..."

docker run --rm \
  -v "$VOLUME_NAME":/data \
  -v "$LOCAL_BACKUP_DIR":/backup \
  busybox sh -c "
    rm -rf /data/* && \
    unzip /backup/$(basename "$LOCAL_ZIP_PATH") -d /data
  "


if [ -n "$CONTAINER_NAME" ]; then
  echo "🚀 Starting container: $CONTAINER_NAME"
  docker start "$CONTAINER_NAME"

fi

echo "✅ Restore complete."
