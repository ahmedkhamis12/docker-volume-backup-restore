#!/bin/bash

# --- Load environment variables ---
set -a
source .env
set +a

BACKUP_DIR="./backups"
LOG_DIR="./logs"
MAX_CONCURRENT=1  # Number of concurrent backups
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

echo "🔍 Scanning volumes with backup-policy..."

# --- Prepare list of volumes that need backup ---
VOLUMES_TO_BACKUP=()

for VOLUME in $(docker volume ls -q); do
  POLICY=$(docker volume inspect "$VOLUME" --format '{{ index .Labels "backup-policy" }}')

  if [ -z "$POLICY" ]; then
    continue
  fi

  echo "📦 Volume: $VOLUME | Policy: $POLICY"
# Validate the policy format using regex: e.g., daily-7, weekly-30, every3days-10
  if [[ "$POLICY" =~ ^(daily|every([0-9]+)days|weekly)-([0-9]+)$ ]]; then
    if [[ "${BASH_REMATCH[1]}" == "daily" ]]; then
      FREQUENCY_DAYS=1
    elif [[ "${BASH_REMATCH[1]}" == "weekly" ]]; then
      FREQUENCY_DAYS=7
    else
      FREQUENCY_DAYS="${BASH_REMATCH[2]}"
    fi

    RETENTION_DAYS="${BASH_REMATCH[3]}"
  else
    echo "❌ Invalid policy format: $POLICY"
    continue
  fi

  # Define the log file for this volume
  LOG_FILE="$LOG_DIR/${VOLUME}_last_backup.log"

  # Default backup date if no log exists
  LAST_BACKUP_DATE="1970-01-01 00:00:00"

  if [ -f "$LOG_FILE" ]; then
    LAST_BACKUP_DATE=$(grep "Backup Date" "$LOG_FILE" | awk '{ print $3 " " $4 }')
  fi

  # Calculate time since last backup
  NOW=$(date +%s)
  LAST_BACKUP_EPOCH=$(date -d "$LAST_BACKUP_DATE" +%s)
  DIFF_DAYS=$(( (NOW - LAST_BACKUP_EPOCH) / 86400 ))


  # Log volume check details
  echo "🔎 Checking $VOLUME: Last = $LAST_BACKUP_DATE | Diff = $DIFF_DAYS days | Required = $FREQUENCY_DAYS"

  if [ "$DIFF_DAYS" -lt "$FREQUENCY_DAYS" ]; then
      # If not enough time has passed since last backup, skip
    echo "⏩ Skipping $VOLUME: Not due yet"
    continue
  fi

  # Add volume to backup queue
  VOLUMES_TO_BACKUP+=("$VOLUME:$RETENTION_DAYS")
done

# --- Backup with max N in parallel ---
echo "🚀 Starting backups in queue (max $MAX_CONCURRENT at a time)..."

# Track how many backup jobs are currently running
running_jobs=0

# Array to store process IDs of running jobs
PIDS=()

# Extract the volume name
for item in "${VOLUMES_TO_BACKUP[@]}"; do
  VOLUME="${item%%:*}"
  RETENTION_DAYS="${item##*:}"

  (
    # Indicate which volume is being backed up
    echo "▶️ Backing up $VOLUME..."
    # Run the actual backup script for the volume
    ./backup_volume.sh "$VOLUME"
    # Remove old backups from remote server using SSH
    echo "🧹 Cleaning backups older than $RETENTION_DAYS days for $VOLUME on remote server..."
    ssh -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST" <<EOF
      find "$REMOTE_BACKUP_PATH" -name "${VOLUME}_*.zip" -type f -mtime +$RETENTION_DAYS -exec rm -f {} \;
EOF
    echo "✅ Done with $VOLUME."
  ) &

  PIDS+=($!)
  running_jobs=$((running_jobs + 1))

  # If max concurrent jobs reached, wait for one to finish
  if [ "$running_jobs" -ge "$MAX_CONCURRENT" ]; then
    wait -n
    running_jobs=$((running_jobs - 1))
  fi
done

# Wait for any remaining jobs
wait

echo "🎉 All backups finished.."
