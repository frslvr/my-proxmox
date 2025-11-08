# Custom GRUB Recovery Entry - Final Fixed Version

**Issue:** Custom "Proxmox VE (Recovery)" entry not working
**Root Cause:** Entry tried to load kernel 6.14.8-2-pve which doesn't exist on EFI partition
**Status:** ✅ FIXED

---

## Problem Analysis

### What Was Wrong

Your custom entry in `/etc/grub.d/40_custom` tried to load:
- ❌ Kernel: `vmlinuz-6.14.8-2-pve` (doesn't exist on EFI)
- ❌ Initrd: `initrd.img-6.14.8-2-pve` (doesn't exist on EFI)

**Available on EFI partition (UUID: A544-A5B3):**
- ✅ vmlinuz-6.14.11-2-pve
- ✅ vmlinuz-6.14.11-3-pve
- ✅ initrd.img-6.14.11-2-pve
- ✅ initrd.img-6.14.11-3-pve

---

## Fixed Version

### Complete `/etc/grub.d/40_custom` Content:

```bash
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
```

**Changes:**
- Updated: `6.14.8-2-pve` → `6.14.11-3-pve`

---

## Quick Installation

### Option 1: Manual Edit

```bash
nano /etc/grub.d/40_custom
# Replace content with fixed version above
# Save and exit

update-grub
```

### Option 2: Automated Script

```bash
# Use the provided script
./fix-custom-recovery-entry.sh
```

---

## What This Entry Does

**Boot Configuration:**
- Boot mode: `rescue.target` (more services than single-user)
- Blacklisted drivers: `vfio, vfio_pci, vfio_iommu_type1`
- Network: Available
- Best for: GPU/PCIe passthrough recovery

---

## Menu Position Fix

To move entry to **top of menu** instead of bottom:

```bash
# Rename for higher priority (lower number = earlier in menu)
mv /etc/grub.d/40_custom /etc/grub.d/06_custom
update-grub
```

Now "Proxmox VE (Recovery)" will appear near the top!

---

**Fixed:** 2025-11-06
**Status:** Ready to deploy
