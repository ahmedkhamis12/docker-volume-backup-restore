# #!/bin/bash
# set -e

# # Load environment variables
# if [ -f .env ]; then
#   source .env
# else
#   echo "❌ .env file not found!"
#   exit 1
# fi

# VOLUME_NAME="$1"

# if [ -z "$VOLUME_NAME" ]; then
#   echo "❌ Usage: $0 <volume_name>"
#   exit 1
# fi

# mkdir -p "$LOCAL_BACKUP_DIR"

# # 📥 Get latest backup file from EC2
# REMOTE_BACKUP=$(ssh -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP" "ls -t $EC2_BACKUP_PATH/${VOLUME_NAME}_*.zip 2>/dev/null | head -n1")
# if [ -z "$REMOTE_BACKUP" ]; then
#   echo "❌ No backup found on EC2 for volume: $VOLUME_NAME"
#   exit 1
# fi

# FILENAME=$(basename "$REMOTE_BACKUP")
# LOCAL_ZIP="$LOCAL_BACKUP_DIR/$FILENAME"

# echo "📥 Downloading $FILENAME from EC2..."
# scp -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP:$REMOTE_BACKUP" "$LOCAL_ZIP"

# # 🛑 Stop containers using the volume
# CONTAINERS=$(docker ps -q --filter "volume=$VOLUME_NAME")
# if [ -n "$CONTAINERS" ]; then
#   echo "🛑 Stopping containers using volume: $VOLUME_NAME"
#   docker stop $CONTAINERS
# fi

# # 📂 Find volume mount path
# MOUNT_PATH=$(docker volume inspect "$VOLUME_NAME" -f '{{ .Mountpoint }}')
# echo "📂 Detected mount path: $MOUNT_PATH"

# sudo mkdir -p "$MOUNT_PATH"
# if ! sudo test -d "$MOUNT_PATH"; then
#   echo "❌ Mount path does not exist or is inaccessible: $MOUNT_PATH"
#   sudo ls -ld "$MOUNT_PATH" 2>/dev/null || echo "🔍 Not visible to current user"
#   echo "⚠️ Trying to continue anyway..."
# fi


# # 🧹 Clean and restore
# echo "🧹 Cleaning volume content..."
# sudo rm -rf "${MOUNT_PATH:?}/"*

# echo "📦 Extracting backup into volume..."
# # sudo unzip -oq "$LOCAL_ZIP" -d "$MOUNT_PATH"
# sudo rm -rf "$MOUNT_PATH"/*
# sudo unzip -oq "$LOCAL_ZIP" -d "$MOUNT_PATH"
# sudo chown -R $USER:$USER "$MOUNT_PATH"


# # ▶️ Restart containers
# if [ -n "$CONTAINERS" ]; then
#   echo "▶️ Restarting containers..."
#   docker start $CONTAINERS
# fi

# echo "✅ Restore completed: $VOLUME_NAME"


#!/bin/bash
set -eo pipefail

# ---------------------------
# 📜 Docker Volume Restore Script
# Version: 2.1
# Usage: ./restore_volume.sh <volume_name>
# ---------------------------

# 🎨 Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📝 Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $1"; }

# 🔄 Cleanup and rollback handler
cleanup() {
  local exit_code=$?
  
  if [ $exit_code -ne 0 ]; then
    log_warn "Restore failed! (Exit Code: $exit_code)"
    
    if [ -f "$TEMP_BACKUP" ]; then
      log_info "Attempting rollback from $TEMP_BACKUP"
      sudo rm -rf "${MOUNT_PATH:?}/"*
      if sudo unzip -oq "$TEMP_BACKUP" -d "$MOUNT_PATH"; then
        log_info "Rollback completed successfully"
      else
        log_error "Rollback failed! Manual intervention required."
      fi
    fi
    
    if [ -n "$CONTAINERS" ]; then
      log_info "Restarting original containers..."
      docker start $CONTAINERS >/dev/null || log_warn "Some containers failed to restart"
    fi
  fi
  
  # Clean temporary files
  [ -f "$TEMP_BACKUP" ] && sudo rm -f "$TEMP_BACKUP"
  # [ -n "$LOCAL_ZIP" ] && [ -f "$LOCAL_ZIP" ] && rm -f "$LOCAL_ZIP"
  
  log_info "Cleanup completed at $(date)"
}
trap cleanup EXIT

# 🔍 Validate environment and arguments
validate_environment() {
  # Check .env file
  if [ ! -f .env ]; then
    log_error ".env file not found!"
    exit 1
  fi
  
  # Load environment variables
  source .env || { log_error "Failed to load .env file"; exit 1; }
  
  # Verify required variables
  local required_vars=("EC2_KEY_PATH" "EC2_USER" "EC2_IP" "EC2_BACKUP_PATH" "LOCAL_BACKUP_DIR")
  for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
      log_error "Missing required variable: $var"
      exit 1
    fi
  done
  
  # Check volume name argument
  VOLUME_NAME="$1"
  if [ -z "$VOLUME_NAME" ]; then
    log_error "Usage: $0 <volume_name>"
    exit 1
  fi
  
  # Verify docker is running
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker daemon is not running!"
    exit 1
  fi
}

# 🔌 Test SSH connection
test_ssh_connection() {
  log_info "Testing SSH connection to EC2..."
  if ! ssh -q -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP" exit; then
    log_error "SSH connection failed!"
    exit 1
  fi
}

# 📥 Find and download latest backup
download_backup() {
  log_info "Finding latest backup for volume: $VOLUME_NAME"
  
  # Find most recent backup
  REMOTE_BACKUP=$(ssh -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP" \
    "ls -t $EC2_BACKUP_PATH/${VOLUME_NAME}_*.zip 2>/dev/null | head -n1")
  
  if [ -z "$REMOTE_BACKUP" ]; then
    log_error "No backups found matching pattern: $EC2_BACKUP_PATH/${VOLUME_NAME}_*.zip"
    exit 1
  fi
  
  FILENAME=$(basename "$REMOTE_BACKUP")
  LOCAL_ZIP="$LOCAL_BACKUP_DIR/$FILENAME"
  TEMP_BACKUP="/tmp/${VOLUME_NAME}_pre_restore_$(date +%s).zip"
  
  # Create backup directory if needed
  mkdir -p "$LOCAL_BACKUP_DIR" || { log_error "Cannot create backup directory"; exit 1; }
  
  # Download with progress
  log_info "Downloading $FILENAME from EC2..."
  scp -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP:$REMOTE_BACKUP" "$LOCAL_ZIP" || {
    log_error "SCP download failed!"
    exit 1
  }
  
  # Verify download
  if [ ! -f "$LOCAL_ZIP" ]; then
    log_error "Downloaded file not found at $LOCAL_ZIP"
    exit 1
  fi
  
  log_info "Download completed ($(du -h "$LOCAL_ZIP" | cut -f1))"
}

# ✅ Verify backup integrity
verify_backup() {
  log_info "Verifying backup integrity..."
  
  if ! unzip -tq "$LOCAL_ZIP" >/dev/null 2>&1; then
    log_error "Backup file is corrupted!"
    exit 1
  fi
  
  log_info "Backup verification passed"
}

# 🐳 Docker operations
handle_containers() {
  # Get containers using the volume
  CONTAINERS=$(docker ps -q --filter "volume=$VOLUME_NAME")
  
  if [ -n "$CONTAINERS" ]; then
    log_info "Stopping containers using volume..."
    docker stop $CONTAINERS >/dev/null || {
      log_error "Failed to stop some containers"
      exit 1
    }
  else
    log_info "No running containers using this volume"
  fi
}

# 📂 Prepare volume
prepare_volume() {
  log_info "Preparing volume..."
  
  # Get mount path
  MOUNT_PATH=$(docker volume inspect "$VOLUME_NAME" -f '{{ .Mountpoint }}' 2>/dev/null || {
    log_error "Volume $VOLUME_NAME not found!"
    exit 1
  })
  
  log_info "Volume mount path: $MOUNT_PATH"
  
  # Create pre-restore backup
  log_info "Creating pre-restore backup..."
  if sudo test -d "$MOUNT_PATH"; then
    if ! sudo zip -qr "$TEMP_BACKUP" "$MOUNT_PATH"; then
      log_warn "Pre-restore backup failed (continuing anyway)..."
    else
      log_info "Pre-restore backup created: $TEMP_BACKUP ($(sudo du -h "$TEMP_BACKUP" | cut -f1))"
    fi
  else
    log_warn "Mount path doesn't exist yet - no pre-restore backup made"
  fi
  
  # Clean volume
  log_info "Cleaning volume..."
  sudo rm -rf "${MOUNT_PATH:?}/"* || {
    log_error "Failed to clean volume"
    exit 1
  }
}

# 🚀 Restore data
restore_data() {
  log_info "Restoring data to volume..."
  
  if ! sudo unzip -oq "$LOCAL_ZIP" -d "$MOUNT_PATH"; then
    log_error "Extraction failed!"
    exit 1
  fi
  
  # Adjust permissions
  log_info "Adjusting permissions..."
  sudo find "$MOUNT_PATH" -type d -exec chmod 755 {} \;
  sudo find "$MOUNT_PATH" -type f -exec chmod 644 {} \;
  sudo chown -R 1000:1000 "$MOUNT_PATH" || log_warn "Permission adjustment had some issues"
  
  log_info "Data restoration completed"
}

# 🔄 Restart containers
restart_containers() {
  if [ -n "$CONTAINERS" ]; then
    log_info "Restarting containers..."
    docker start $CONTAINERS >/dev/null
    
    # Verify container status
    local all_healthy=true
    for container in $CONTAINERS; do
      status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
      if [ "$status" != "running" ]; then
        log_error "Container $container failed to start (Status: $status)"
        all_healthy=false
      fi
    done
    
    if ! $all_healthy; then
      log_error "Some containers failed to start properly"
      exit 1
    fi
  fi
}

# 🏁 Main execution
main() {
  log_info "Starting volume restore at $(date)"
  validate_environment "$@"
  test_ssh_connection
  download_backup
  verify_backup
  handle_containers
  prepare_volume
  restore_data
  restart_containers
  
  log_info "Successfully restored volume: $VOLUME_NAME"
  log_info "Mount Path: $MOUNT_PATH"
  [ -n "$CONTAINERS" ] && log_info "Restarted containers: $CONTAINERS"
  exit 0
}

main "$@"