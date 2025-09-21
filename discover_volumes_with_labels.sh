#!/bin/bash


# ==========================================
# Docker Volume Discovery + Metadata Script
# ==========================================

echo "📦 Listing all Docker volumes..."
docker volume ls

echo ""
echo "🔍 Inspecting each volume for mount path, usage, and labels..."

for vol in $(docker volume ls -q); do
    echo "----------------------------------"
    echo "Volume: $vol"

    # Get mountpoint
    mountpoint=$(docker volume inspect "$vol" --format '{{ .Mountpoint }}')
    echo "Mountpoint: $mountpoint"

    # Get labels
    last_backup=$(docker volume inspect "$vol" --format '{{ index .Labels "backup.last" }}')
    policy=$(docker volume inspect "$vol" --format '{{ index .Labels "backup.policy" }}')

    echo "Last Backup: ${last_backup:-Not set}"
    echo "Backup Policy: ${policy:-Not set}"

    # Check if any container is using this volume
    echo "Checking which containers are using this volume..."
    used_by=""
    for cont in $(docker ps -aq); do
        if docker inspect "$cont" | grep -q "$vol"; then
            container_name=$(docker inspect --format '{{.Name}}' "$cont" | sed 's/\///')
            echo "  → Used by container: $container_name"
            used_by="yes"
        fi
    done

    if [[ -z "$used_by" ]]; then
        echo "  → Not used by any container."
    fi
done
