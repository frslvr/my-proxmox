#!/bin/bash
#
# Quick Fix: Secure Proxmox Backup Directory Permissions
#
# This script fixes insecure file permissions on backup directory
# ISSUE: Backups currently readable by all users (644)
# FIX: Set to root-only access (600/700)
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Proxmox Backup Permission Fix ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

BACKUP_DIR="/root/config-backups"

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

echo "🔍 Current permissions:"
ls -la "$BACKUP_DIR" | head -10
echo

echo "🔒 Securing backup directory..."

# Secure directory
chmod 700 "$BACKUP_DIR"
echo -e "${GREEN}✅ Directory secured: drwx------ (700)${NC}"

# Secure all backup files
chmod 600 "$BACKUP_DIR"/*.tar.gz 2>/dev/null || true
chmod 600 "$BACKUP_DIR"/*.list 2>/dev/null || true
chmod 600 "$BACKUP_DIR"/*.txt 2>/dev/null || true
echo -e "${GREEN}✅ Backup files secured: -rw------- (600)${NC}"

echo
echo "🔍 New permissions:"
ls -la "$BACKUP_DIR" | head -10
echo

# Count files
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
PACKAGE_COUNT=$(ls -1 "$BACKUP_DIR"/*.list 2>/dev/null | wc -l)

echo -e "${GREEN}✅ Security fix complete!${NC}"
echo
echo "Summary:"
echo "  • Directory: $BACKUP_DIR"
echo "  • Config backups: $BACKUP_COUNT"
echo "  • Package lists: $PACKAGE_COUNT"
echo "  • Permissions: Root access only"
echo

# Verify
INSECURE=$(find "$BACKUP_DIR" -type f \( -perm /g+r -o -perm /o+r \) | wc -l)
if [ "$INSECURE" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: Found $INSECURE files with group/other read permissions${NC}"
    find "$BACKUP_DIR" -type f \( -perm /g+r -o -perm /o+r \) -ls
else
    echo -e "${GREEN}✅ All files properly secured${NC}"
fi

echo
echo "Next steps:"
echo "  1. Verify backups contain all needed files"
echo "  2. Increase retention to 30 days"
echo "  3. Set up remote backup location"
echo
echo "Run: tar -tzf $BACKUP_DIR/proxmox-config-*.tar.gz | less"
echo "     to verify backup contents"
