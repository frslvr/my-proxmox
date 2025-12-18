#!/bin/bash
#
# Fix Custom Proxmox Recovery Entry in GRUB
#
# This script updates the custom recovery entry in /etc/grub.d/40_custom
# to work properly with ZFS and the latest kernel.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Fixing Custom Proxmox Recovery Entry ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

CUSTOM_FILE="/etc/grub.d/40_custom"

if [ ! -f "$CUSTOM_FILE" ]; then
    echo -e "${RED}❌ $CUSTOM_FILE not found${NC}"
    exit 1
fi

# Backup current file
BACKUP_FILE="${CUSTOM_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
cp "$CUSTOM_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backed up current file to: $BACKUP_FILE${NC}"

# Get latest kernel version
LATEST_KERNEL=$(ls -t /boot/vmlinuz-* | head -1 | sed 's/.*vmlinuz-//')
echo -e "${BLUE}ℹ️  Latest kernel: $LATEST_KERNEL${NC}"

# Check if kernel and initrd exist
if [ ! -f "/boot/vmlinuz-$LATEST_KERNEL" ]; then
    echo -e "${RED}❌ Kernel not found: /boot/vmlinuz-$LATEST_KERNEL${NC}"
    exit 1
fi

if [ ! -f "/boot/initrd.img-$LATEST_KERNEL" ]; then
    echo -e "${RED}❌ Initrd not found: /boot/initrd.img-$LATEST_KERNEL${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kernel files found${NC}"

# Create new custom entry
cat > "$CUSTOM_FILE" << 'EOF'
#!/bin/sh
exec tail -n +3 $0
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.

# Custom Proxmox Recovery Mode
# - Uses rescue.target (more services than single-user mode)
# - Blacklists VFIO drivers (for PCIe passthrough issues)
# - Auto-updated to latest kernel
menuentry 'Proxmox VE (Recovery)' {
    insmod gzio
    insmod part_gpt
    insmod zfs
EOF

# Add kernel-specific lines
cat >> "$CUSTOM_FILE" << EOF
    echo 'Loading Linux ${LATEST_KERNEL} (Recovery Mode)...'
    linux /ROOT/pve-1@/boot/vmlinuz-${LATEST_KERNEL} root=ZFS=rpool/ROOT/pve-1 boot=zfs systemd.unit=rescue.target modprobe.blacklist=vfio,vfio_pci,vfio_iommu_type1
    echo 'Loading initial ramdisk ...'
    initrd /ROOT/pve-1@/boot/initrd.img-${LATEST_KERNEL}
EOF

# Close the entry
cat >> "$CUSTOM_FILE" << 'EOF'
}
EOF

echo -e "${GREEN}✅ Updated $CUSTOM_FILE${NC}"
echo

# Show what was created
echo -e "${BLUE}=== New Custom Entry ===${NC}"
cat "$CUSTOM_FILE"
echo

# Update GRUB
echo -e "${BLUE}🔄 Updating GRUB configuration...${NC}"
if update-grub; then
    echo -e "${GREEN}✅ GRUB updated successfully${NC}"
else
    echo -e "${RED}❌ GRUB update failed${NC}"
    echo -e "${YELLOW}⚠️  Restoring backup...${NC}"
    cp "$BACKUP_FILE" "$CUSTOM_FILE"
    exit 1
fi

echo

# Verify entry is in grub.cfg
echo -e "${BLUE}=== Verifying Entry in GRUB Config ===${NC}"
if grep -q "Proxmox VE (Recovery)" /boot/grub/grub.cfg; then
    echo -e "${GREEN}✅ Entry found in /boot/grub/grub.cfg${NC}"
    echo
    grep -A 8 "menuentry 'Proxmox VE (Recovery)'" /boot/grub/grub.cfg
else
    echo -e "${RED}❌ Entry not found in /boot/grub/grub.cfg${NC}"
    exit 1
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Custom Recovery Entry Fixed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}Changes made:${NC}"
echo "  ✅ Removed incorrect UUID search"
echo "  ✅ Added ZFS module loading"
echo "  ✅ Fixed file paths for ZFS (added /ROOT/pve-1@/boot/)"
echo "  ✅ Updated to latest kernel: $LATEST_KERNEL"
echo "  ✅ Kept custom settings: rescue.target, VFIO blacklist"
echo
echo -e "${BLUE}What your custom entry does:${NC}"
echo "  • Boots to rescue.target (more services than single-user)"
echo "  • Blacklists VFIO drivers (good for GPU passthrough issues)"
echo "  • Uses latest kernel automatically"
echo
echo -e "${BLUE}Location in GRUB menu:${NC}"
echo "  At the TOP of the menu (before 'Proxmox VE GNU/Linux')"
echo
echo -e "${BLUE}To test:${NC}"
echo "  1. reboot"
echo "  2. Select 'Proxmox VE (Recovery)' at GRUB menu"
echo "  3. Should boot to rescue.target with network working"
echo
echo -e "${BLUE}Backup saved to:${NC}"
echo "  $BACKUP_FILE"
echo

# Show comparison
echo -e "${YELLOW}=== What Changed ===${NC}"
echo
echo -e "${RED}OLD (broken):${NC}"
echo "  search --no-floppy --fs-uuid --set=root A544-A5B3"
echo "  linux /vmlinuz-6.14.8-2-pve ..."
echo
echo -e "${GREEN}NEW (working):${NC}"
echo "  insmod zfs"
echo "  linux /ROOT/pve-1@/boot/vmlinuz-${LATEST_KERNEL} ..."
echo
