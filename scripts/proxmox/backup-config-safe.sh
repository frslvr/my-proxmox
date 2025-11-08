#!/bin/bash
#
# Safe Proxmox Configuration Backup Script
#
# This script creates comprehensive backups of Proxmox configuration files
# including network settings, GRUB config, and PVE cluster configuration.
#
# Features:
# - Automatic retention management
# - Integrity verification
# - Detailed logging
# - Email notifications (optional)
# - Backup to multiple locations (optional)
#
# Usage:
#   ./backup-config-safe.sh           # Standard backup
#   ./backup-config-safe.sh --verify  # Backup + verify
#   ./backup-config-safe.sh --remote  # Backup + copy to remote location
#

set -e
set -o pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/root/config-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/proxmox-config-$DATE.tar.gz"
LOG_FILE="/var/log/proxmox-backup.log"
REMOTE_BACKUP_DIR="${REMOTE_BACKUP_DIR:-}"
MAIL_TO="${MAIL_TO:-root}"
VERIFY_BACKUP=false
COPY_REMOTE=false

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verify) VERIFY_BACKUP=true; shift ;;
        --remote) COPY_REMOTE=true; shift ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Options:
    --verify    Verify backup integrity after creation
    --remote    Copy backup to remote location
    -h, --help  Show this help

Environment Variables:
    BACKUP_DIR         Backup directory (default: /root/config-backups)
    RETENTION_DAYS     Keep backups for N days (default: 30)
    REMOTE_BACKUP_DIR  Remote backup location (default: none)
    MAIL_TO            Email for notifications (default: root)

Example:
    REMOTE_BACKUP_DIR=/mnt/nfs-backup $0 --remote --verify

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

log_error() {
    log "ERROR: $*"
    echo -e "${RED}❌ ERROR: $*${NC}" >&2
}

log_warn() {
    log "WARN: $*"
    echo -e "${YELLOW}⚠️  WARN: $*${NC}"
}

log_info() {
    log "INFO: $*"
    echo -e "${GREEN}✅ $*${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

log "=== Configuration Backup Started ==="
log "Hostname: $(hostname)"
log "PVE Version: $(pveversion 2>/dev/null | head -1 || echo 'Unknown')"
log "Backup file: $BACKUP_FILE"

echo
log_info "Creating configuration backup..."

# List of files/directories to backup
BACKUP_PATHS=(
    "/etc/pve"
    "/etc/network/interfaces"
    "/etc/network/interfaces.d"
    "/etc/default/grub"
    "/etc/fstab"
    "/etc/hosts"
    "/etc/hostname"
    "/etc/resolv.conf"
    "/etc/vzdump.conf"
    "/etc/cron.d"
    "/etc/crontab"
    "/etc/systemd/system"
    "/etc/sysctl.conf"
    "/etc/sysctl.d"
    "/etc/modules"
    "/etc/modprobe.d"
)

# Check which paths exist
EXISTING_PATHS=()
MISSING_PATHS=()
for path in "${BACKUP_PATHS[@]}"; do
    if [ -e "$path" ]; then
        EXISTING_PATHS+=("$path")
    else
        MISSING_PATHS+=("$path")
    fi
done

if [ ${#MISSING_PATHS[@]} -gt 0 ]; then
    log_warn "Some paths don't exist and will be skipped:"
    for path in "${MISSING_PATHS[@]}"; do
        log "  - $path"
    done
fi

# Create backup
if tar -czf "$BACKUP_FILE" "${EXISTING_PATHS[@]}" 2>/dev/null; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log_info "Backup created: $BACKUP_FILE ($SIZE)"

    # Set secure permissions
    chmod 600 "$BACKUP_FILE"

    # Count files in backup
    FILE_COUNT=$(tar -tzf "$BACKUP_FILE" | wc -l)
    log "Backup contains $FILE_COUNT files/directories"
else
    log_error "Backup creation failed!"
    exit 1
fi

# Verify backup integrity
if [ "$VERIFY_BACKUP" = true ]; then
    echo
    log_info "Verifying backup integrity..."
    if tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
        log_info "Backup integrity verified"
    else
        log_error "Backup verification failed! File may be corrupted."
        exit 1
    fi
fi

# Create backup manifest
MANIFEST_FILE="$BACKUP_DIR/manifest-$DATE.txt"
{
    echo "Proxmox Configuration Backup Manifest"
    echo "========================================"
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "PVE Version: $(pveversion 2>/dev/null | head -1 || echo 'Unknown')"
    echo "Backup File: $(basename "$BACKUP_FILE")"
    echo "Backup Size: $SIZE"
    echo "File Count: $FILE_COUNT"
    echo ""
    echo "Contents:"
    tar -tzf "$BACKUP_FILE" | head -50
    echo "... (showing first 50 entries)"
} > "$MANIFEST_FILE"
chmod 600 "$MANIFEST_FILE"
log "Created manifest: $MANIFEST_FILE"

# Copy to remote location if requested
if [ "$COPY_REMOTE" = true ] && [ -n "$REMOTE_BACKUP_DIR" ]; then
    echo
    log_info "Copying backup to remote location: $REMOTE_BACKUP_DIR"

    if [ ! -d "$REMOTE_BACKUP_DIR" ]; then
        log_error "Remote backup directory doesn't exist: $REMOTE_BACKUP_DIR"
    else
        if cp "$BACKUP_FILE" "$REMOTE_BACKUP_DIR/" 2>/dev/null; then
            log_info "Remote copy successful"
            cp "$MANIFEST_FILE" "$REMOTE_BACKUP_DIR/" 2>/dev/null || true
        else
            log_error "Remote copy failed"
        fi
    fi
fi

# Cleanup old backups
echo
log_info "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."

DELETED_COUNT=0
while IFS= read -r old_backup; do
    rm -f "$old_backup"
    DELETED_COUNT=$((DELETED_COUNT + 1))
    log "Deleted: $(basename "$old_backup")"
done < <(find "$BACKUP_DIR" -name "proxmox-config-*.tar.gz" -mtime +$RETENTION_DAYS -type f)

# Cleanup old manifests
find "$BACKUP_DIR" -name "manifest-*.txt" -mtime +$RETENTION_DAYS -type f -delete

if [ $DELETED_COUNT -gt 0 ]; then
    log_info "Deleted $DELETED_COUNT old backup(s)"
else
    log "No old backups to delete"
fi

# Count remaining backups
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "proxmox-config-*.tar.gz" -type f | wc -l)
log "Current backup count: $BACKUP_COUNT"

# Calculate total backup size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
log "Total backup directory size: $TOTAL_SIZE"

# Summary
echo
log "=== Configuration Backup Completed Successfully ==="
log_info "Latest backup: $BACKUP_FILE"
log_info "Backup size: $SIZE"
log_info "Total backups: $BACKUP_COUNT"
log_info "Directory size: $TOTAL_SIZE"

# List recent backups
echo
echo "Recent backups:"
ls -lth "$BACKUP_DIR"/proxmox-config-*.tar.gz 2>/dev/null | head -5 | awk '{print $9, $5, $6, $7, $8}'

echo
log_info "Backup log: $LOG_FILE"

# Send email notification if mailutils is available
if command -v mail &>/dev/null && [ -n "$MAIL_TO" ]; then
    {
        echo "Proxmox Configuration Backup Completed"
        echo "======================================"
        echo ""
        echo "Server: $(hostname)"
        echo "Date: $(date)"
        echo "Backup: $BACKUP_FILE"
        echo "Size: $SIZE"
        echo "Files: $FILE_COUNT"
        echo ""
        echo "Recent backups:"
        ls -lth "$BACKUP_DIR"/proxmox-config-*.tar.gz 2>/dev/null | head -5
    } | mail -s "Proxmox Config Backup: $(hostname)" "$MAIL_TO" 2>/dev/null || true
fi

exit 0
