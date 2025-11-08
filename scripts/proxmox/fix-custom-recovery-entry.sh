#!/bin/bash
#
# Fix Custom GRUB Recovery Entry
# Updates "Proxmox VE (Recovery)" to use correct kernel
#

set -e

echo "=========================================="
echo "Custom GRUB Recovery Entry Fix"
echo "=========================================="
echo

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Must run as root"
    exit 1
fi

# Backup
BACKUP="/etc/grub.d/40_custom.backup.$(date +%Y%m%d-%H%M%S)"
echo "💾 Backing up to: $BACKUP"
cp /etc/grub.d/40_custom "$BACKUP"

# Create fixed version
echo "🔧 Creating fixed entry..."
cat > /etc/grub.d/06_custom << 'EOF'
#!/bin/sh
exec tail -n +3 $0
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.

menuentry 'Proxmox VE (Recovery)' {
    insmod gzio
    insmod part_gpt
    insmod fat
    search --no-floppy --fs-uuid --set=root A544-A5B3
    echo    'Loading Linux 6.14.11-3-pve (Recovery Mode)...'
    linux /vmlinuz-6.14.11-3-pve root=ZFS=rpool/ROOT/pve-1 boot=zfs systemd.unit=rescue.target modprobe.blacklist=vfio,vfio_pci,vfio_iommu_type1
    echo    'Loading initial ramdisk ...'
    initrd /initrd.img-6.14.11-3-pve
}
EOF

chmod +x /etc/grub.d/06_custom
echo "✅ Created /etc/grub.d/06_custom"

# Remove old
if [ -f /etc/grub.d/40_custom ]; then
    rm /etc/grub.d/40_custom
    echo "✅ Removed old /etc/grub.d/40_custom"
fi

# Update GRUB
echo "🔄 Updating GRUB..."
update-grub

echo
echo "=========================================="
echo "✅ Fix Complete!"
echo "=========================================="
echo
echo "Changes:"
echo "  • Kernel: 6.14.8-2-pve → 6.14.11-3-pve"
echo "  • File: 40_custom → 06_custom (top of menu)"
echo
echo "Next: Reboot and select 'Proxmox VE (Recovery)'"
echo "Backup: $BACKUP"
echo
