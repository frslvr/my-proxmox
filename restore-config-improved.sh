#!/bin/bash
#
# Proxmox Configuration Restore Script (IMPROVED & SAFE VERSION)
#
# This script safely restores Proxmox configuration from backups with:
# - Automatic ZFS snapshot before restore (rollback capability)
# - Current config backup before overwrite
# - Integrity verification
# - Detailed logging
# - Dry-run mode for testing
# - Network protection
# - Cluster awareness
#
# Usage:
#   ./restore-config-improved.sh           # Interactive mode
#   ./restore-config-improved.sh --dry-run # Test mode (no changes)
#   ./restore-config-improved.sh --auto proxmox-config-2025-11-06.tar.gz # Auto mode
#

set -e
set -o pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/root/config-backups}"
TMP_DIR="/tmp/proxmox-restore-$$"
LOG_FILE="/var/log/proxmox-restore-$(date +%Y%m%d-%H%M%S).log"
SNAPSHOT_NAME="pre-restore-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
AUTO_MODE=false
AUTO_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# Print colored message
print_status() {
    local color="$1"
    local icon="$2"
    shift 2
    echo -e "${color}${icon} $*${NC}"
}

print_info() { print_status "$BLUE" "ℹ️" "$@"; }
print_success() { print_status "$GREEN" "✅" "$@"; }
print_warn() { print_status "$YELLOW" "⚠️" "$@"; }
print_error() { print_status "$RED" "❌" "$@"; }

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --auto)
            AUTO_MODE=true
            AUTO_FILE="$2"
            shift 2
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Options:
    --dry-run           Test mode - show what would be done without making changes
    --auto FILENAME     Automatic mode - restore specified backup without prompts
    -h, --help          Show this help message

Examples:
    $0                                    # Interactive mode
    $0 --dry-run                         # Test restore without changes
    $0 --auto proxmox-config-2025-11-06.tar.gz  # Automatic restore

EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Cleanup function
cleanup() {
    if [ -d "$TMP_DIR" ]; then
        log_info "Cleaning up temporary directory: $TMP_DIR"
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

# Check if cluster node
is_cluster_node() {
    pvecm status &>/dev/null
}

# Check for required commands
check_dependencies() {
    local missing=()
    for cmd in tar zfs systemctl pveversion; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

# Create ZFS snapshot for rollback
create_snapshot() {
    local dataset="rpool/ROOT/pve-1"

    if $DRY_RUN; then
        print_info "DRY-RUN: Would create ZFS snapshot: ${dataset}@${SNAPSHOT_NAME}"
        return 0
    fi

    print_info "Creating ZFS snapshot for rollback: ${dataset}@${SNAPSHOT_NAME}"
    log_info "Creating ZFS snapshot: ${dataset}@${SNAPSHOT_NAME}"

    if zfs snapshot "${dataset}@${SNAPSHOT_NAME}"; then
        print_success "Snapshot created successfully"
        log_success "ZFS snapshot created: ${dataset}@${SNAPSHOT_NAME}"
        echo
        print_warn "If restore fails, rollback with:"
        echo "    zfs rollback ${dataset}@${SNAPSHOT_NAME}"
        echo
        return 0
    else
        print_error "Failed to create ZFS snapshot"
        log_error "Failed to create ZFS snapshot: ${dataset}@${SNAPSHOT_NAME}"
        return 1
    fi
}

# Backup current configuration before restore
backup_current_config() {
    local backup_file="${BACKUP_DIR}/pre-restore-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    if $DRY_RUN; then
        print_info "DRY-RUN: Would backup current config to: $backup_file"
        return 0
    fi

    print_info "Backing up current configuration..."
    log_info "Creating backup of current config: $backup_file"

    mkdir -p "$BACKUP_DIR"

    if tar -czf "$backup_file" \
        /etc/pve \
        /etc/network/interfaces \
        /etc/default/grub \
        /etc/fstab \
        /etc/hosts \
        /etc/hostname \
        /etc/resolv.conf \
        /etc/vzdump.conf \
        2>/dev/null; then
        print_success "Current config backed up to: $backup_file"
        log_success "Current config backed up: $backup_file"
        return 0
    else
        print_error "Failed to backup current configuration"
        log_error "Failed to backup current config"
        return 1
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"

    print_info "Verifying backup integrity..."
    log_info "Verifying backup: $backup_path"

    if ! tar -tzf "$backup_path" &>/dev/null; then
        print_error "Backup file is corrupted or invalid"
        log_error "Backup verification failed: $backup_path"
        return 1
    fi

    print_success "Backup integrity verified"
    log_success "Backup verified: $backup_path"
    return 0
}

# Show backup contents
preview_backup() {
    local backup_path="$1"

    print_info "Backup contents:"
    echo
    tar -tzf "$backup_path" | head -20

    local total_files=$(tar -tzf "$backup_path" | wc -l)
    echo "... (showing first 20 of $total_files files)"
    echo
}

# Check if backup contains network config
has_network_config() {
    local backup_path="$1"
    tar -tzf "$backup_path" | grep -q "etc/network/interfaces"
}

# Restore configuration
restore_config() {
    local backup_path="$1"

    if $DRY_RUN; then
        print_info "DRY-RUN: Would restore from: $backup_path"
        print_info "DRY-RUN: Would stop services: pvedaemon pveproxy pve-cluster"
        print_info "DRY-RUN: Would extract backup to /"
        print_info "DRY-RUN: Would update GRUB"
        print_info "DRY-RUN: Would start services"
        return 0
    fi

    print_info "Stopping Proxmox services..."
    log_info "Stopping PVE services"
    systemctl stop pvedaemon pveproxy pve-cluster || true
    sleep 2

    print_info "Restoring configuration files..."
    log_info "Extracting backup: $backup_path"

    if tar -xzf "$backup_path" -C /; then
        print_success "Configuration files restored"
        log_success "Backup extracted successfully"
    else
        print_error "Failed to restore configuration"
        log_error "Backup extraction failed"
        return 1
    fi

    print_info "Updating boot configuration..."
    log_info "Updating GRUB"
    update-grub >/dev/null 2>&1 || proxmox-boot-tool refresh >/dev/null 2>&1 || true

    print_info "Starting Proxmox services..."
    log_info "Starting PVE services"
    systemctl start pve-cluster
    sleep 3
    systemctl start pvedaemon pveproxy
    sleep 2

    print_success "Services restarted"
    log_success "PVE services restarted"

    return 0
}

# Main function
main() {
    echo
    print_info "Proxmox Configuration Restore Tool"
    print_info "Log file: $LOG_FILE"
    echo

    log_info "=== Restore process started ==="
    log_info "User: $(whoami)"
    log_info "Hostname: $(hostname)"
    log_info "PVE Version: $(pveversion | head -1)"

    if $DRY_RUN; then
        print_warn "DRY-RUN MODE - No changes will be made"
        echo
    fi

    # Check dependencies
    check_dependencies

    # Check if cluster node
    if is_cluster_node; then
        print_warn "This server is part of a Proxmox cluster!"
        print_warn "Restoring configuration on a cluster node can cause issues."
        echo
        if ! $AUTO_MODE; then
            read -rp "⚠️  Continue anyway? (y/N): " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] || { print_info "Cancelled."; exit 0; }
            echo
        fi
    fi

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # List available backups
    print_info "Available configuration backups:"
    echo

    local backups=($(ls -1t "$BACKUP_DIR"/proxmox-config-*.tar.gz 2>/dev/null || true))

    if [ ${#backups[@]} -eq 0 ]; then
        print_error "No backups found in $BACKUP_DIR"
        exit 1
    fi

    for i in "${!backups[@]}"; do
        local filename=$(basename "${backups[$i]}")
        local size=$(du -h "${backups[$i]}" | cut -f1)
        local date=$(stat -c %y "${backups[$i]}" | cut -d' ' -f1,2 | cut -d'.' -f1)
        printf "%2d) %-40s %8s  %s\n" $((i+1)) "$filename" "$size" "$date"
    done
    echo

    # Select backup
    local selected_backup
    if $AUTO_MODE; then
        selected_backup="$BACKUP_DIR/$AUTO_FILE"
        if [ ! -f "$selected_backup" ]; then
            print_error "Backup not found: $selected_backup"
            exit 1
        fi
        print_info "Auto-mode: Using backup: $(basename "$selected_backup")"
    else
        read -rp "📦 Enter backup number or filename: " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#backups[@]} ]; then
            selected_backup="${backups[$((selection-1))]}"
        else
            selected_backup="$BACKUP_DIR/$selection"
        fi

        if [ ! -f "$selected_backup" ]; then
            print_error "Backup not found: $selected_backup"
            exit 1
        fi
    fi

    echo
    print_info "Selected backup: $(basename "$selected_backup")"
    log_info "Selected backup: $selected_backup"

    # Verify backup
    verify_backup "$selected_backup" || exit 1
    echo

    # Preview backup
    preview_backup "$selected_backup"

    # Check for network config
    if has_network_config "$selected_backup"; then
        print_warn "This backup contains network configuration!"
        print_warn "Restoring could change network settings and potentially lock you out."
        echo
    fi

    # Confirmation
    if ! $AUTO_MODE && ! $DRY_RUN; then
        read -rp "⚠️  This will overwrite existing configs. Continue? (y/N): " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { print_info "Cancelled."; exit 0; }
        echo
    fi

    # Create ZFS snapshot
    if ! create_snapshot; then
        print_error "Failed to create snapshot. Aborting for safety."
        exit 1
    fi

    # Backup current config
    if ! backup_current_config; then
        print_warn "Failed to backup current config, but continuing..."
    fi

    echo

    # Final confirmation for non-dry-run
    if ! $DRY_RUN && ! $AUTO_MODE; then
        print_warn "FINAL CONFIRMATION"
        print_warn "This will:"
        echo "  • Stop Proxmox services (affecting running VMs/CTs)"
        echo "  • Restore configuration from backup"
        echo "  • Restart services"
        echo
        read -rp "✅ Proceed with restore? (yes/NO): " final_confirm
        [[ "$final_confirm" == "yes" ]] || { print_info "Cancelled."; exit 0; }
        echo
    fi

    # Perform restore
    if restore_config "$selected_backup"; then
        echo
        print_success "=========================================="
        print_success "Configuration restore completed!"
        print_success "=========================================="
        echo
        print_info "ZFS snapshot created: rpool/ROOT/pve-1@${SNAPSHOT_NAME}"
        print_info "Log file: $LOG_FILE"
        echo
        print_warn "If you experience issues, rollback with:"
        echo "    zfs rollback rpool/ROOT/pve-1@${SNAPSHOT_NAME}"
        echo "    reboot"
        echo
        print_info "You may need to reconnect to the Web UI"

        log_success "=== Restore completed successfully ==="
    else
        echo
        print_error "=========================================="
        print_error "Configuration restore FAILED!"
        print_error "=========================================="
        echo
        print_error "Rollback with:"
        echo "    zfs rollback rpool/ROOT/pve-1@${SNAPSHOT_NAME}"
        echo "    reboot"
        echo
        print_error "Log file: $LOG_FILE"

        log_error "=== Restore FAILED ==="
        exit 1
    fi
}

# Run main function
main "$@"
