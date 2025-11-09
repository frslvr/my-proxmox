# Custom Recovery Entry Fix

**Issue:** Custom "Proxmox VE (Recovery)" entry not working
**Root Cause:** Trying to boot from EFI partition instead of ZFS
**Status:** Fix ready to apply

---

## Problem Analysis

### Your Current Entry (Broken)

```bash
menuentry 'Proxmox VE (Recovery)' {
    insmod gzio
    insmod part_gpt
    insmod fat
    search --no-floppy --fs-uuid --set=root A544-A5B3  # ❌ WRONG
    echo 'Loading Linux 6.14.8-2-pve (Recovery Mode)...'
    linux /vmlinuz-6.14.8-2-pve ...                     # ❌ WRONG PATH
    echo 'Loading initial ramdisk ...'
    initrd /initrd.img-6.14.8-2-pve                     # ❌ WRONG PATH
}
```

### Why It Doesn't Work

**Issue 1: Looking in Wrong Place**
```bash
search --no-floppy --fs-uuid --set=root A544-A5B3
```
- This searches for UUID `A544-A5B3` (your nvme2n1p2 EFI partition)
- Sets that as the root for finding files
- BUT: Your kernel/initrd are NOT on the EFI partition!

**Issue 2: Wrong File Paths**
```bash
linux /vmlinuz-6.14.8-2-pve
```
- This looks for kernel in `/vmlinuz-6.14.8-2-pve`
- On the EFI partition (from Issue 1)
- But kernel is actually on ZFS at `/ROOT/pve-1@/boot/vmlinuz-...`

**Issue 3: Old Kernel**
```bash
vmlinuz-6.14.8-2-pve
```
- You're running 6.14.11-3-pve (latest)
- Entry uses 6.14.8-2-pve (old)

### Where Files Actually Are

```
EFI Partition (nvme2n1p2, UUID A544-A5B3):
└── EFI/
    ├── BOOT/
    │   └── BOOTX64.EFI         # GRUB bootloader only
    └── proxmox/
        └── grubx64.efi         # GRUB files only

ZFS (rpool/ROOT/pve-1, mounted at /):
└── boot/
    ├── vmlinuz-6.14.11-3-pve   # ← Kernels are HERE
    ├── vmlinuz-6.14.11-2-pve
    ├── vmlinuz-6.14.8-2-pve
    ├── initrd.img-6.14.11-3-pve # ← Initrds are HERE
    ├── initrd.img-6.14.11-2-pve
    └── initrd.img-6.14.8-2-pve
```

**Boot Process:**
1. UEFI → Loads GRUB from EFI partition (A544-A5B3)
2. GRUB → Loads kernel/initrd from **ZFS** (not EFI partition!)
3. Kernel → Boots from ZFS root

---

## The Fix

### Corrected Entry

```bash
menuentry 'Proxmox VE (Recovery)' {
    insmod gzio
    insmod part_gpt
    insmod zfs                                          # ✅ Load ZFS module
    echo 'Loading Linux 6.14.11-3-pve (Recovery Mode)...'
    linux /ROOT/pve-1@/boot/vmlinuz-6.14.11-3-pve root=ZFS=rpool/ROOT/pve-1 boot=zfs systemd.unit=rescue.target modprobe.blacklist=vfio,vfio_pci,vfio_iommu_type1
    echo 'Loading initial ramdisk ...'
    initrd /ROOT/pve-1@/boot/initrd.img-6.14.11-3-pve  # ✅ ZFS path
}
```

### What Changed

| Item | Old (Broken) | New (Working) |
|------|--------------|---------------|
| Module loading | `insmod fat` | `insmod zfs` ✅ |
| Root search | `search --fs-uuid A544-A5B3` | Removed (not needed) ✅ |
| Kernel path | `/vmlinuz-6.14.8-2-pve` | `/ROOT/pve-1@/boot/vmlinuz-6.14.11-3-pve` ✅ |
| Initrd path | `/initrd.img-6.14.8-2-pve` | `/ROOT/pve-1@/boot/initrd.img-6.14.11-3-pve` ✅ |
| Kernel version | 6.14.8-2-pve (old) | 6.14.11-3-pve (latest) ✅ |

---

## How to Apply the Fix

### Method 1: Automatic (Recommended)

```bash
# Copy script to Proxmox
scp fix-custom-recovery-entry.sh root@proxmox:/root/

# Run it
ssh root@proxmox
chmod +x /root/fix-custom-recovery-entry.sh
/root/fix-custom-recovery-entry.sh
```

The script will:
- ✅ Backup current /etc/grub.d/40_custom
- ✅ Auto-detect latest kernel
- ✅ Create corrected entry
- ✅ Update GRUB
- ✅ Verify entry is working

### Method 2: Manual

```bash
# Backup current file
cp /etc/grub.d/40_custom /etc/grub.d/40_custom.backup

# Edit file
nano /etc/grub.d/40_custom
```

Replace the menuentry with:

```bash
#!/bin/sh
exec tail -n +3 $0
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.

menuentry 'Proxmox VE (Recovery)' {
    insmod gzio
    insmod part_gpt
    insmod zfs
    echo 'Loading Linux 6.14.11-3-pve (Recovery Mode)...'
    linux /ROOT/pve-1@/boot/vmlinuz-6.14.11-3-pve root=ZFS=rpool/ROOT/pve-1 boot=zfs systemd.unit=rescue.target modprobe.blacklist=vfio,vfio_pci,vfio_iommu_type1
    echo 'Loading initial ramdisk ...'
    initrd /ROOT/pve-1@/boot/initrd.img-6.14.11-3-pve
}
```

Save (Ctrl+X, Y, Enter), then:

```bash
# Update GRUB
update-grub

# Verify
grep -A 8 "Proxmox VE (Recovery)" /boot/grub/grub.cfg
```

---

## Testing the Fixed Entry

### Step 1: Reboot

```bash
reboot
```

### Step 2: Select Entry

At GRUB menu:
```
┌─────────────────────────────────────────────────┐
│  GNU GRUB                                       │
├─────────────────────────────────────────────────┤
│ >Proxmox VE (Recovery)                          │  ← YOUR ENTRY (top!)
│  Proxmox VE GNU/Linux                           │
│  Advanced options for Proxmox VE GNU/Linux     │
└─────────────────────────────────────────────────┘
```

Press Enter on "Proxmox VE (Recovery)"

### Step 3: Verify It Works

You should boot to rescue.target. Verify:

```bash
# Check you're in rescue target
systemctl get-default
# Should show: rescue.target or graphical.target

# Check VFIO is blacklisted
lsmod | grep vfio
# Should show nothing (VFIO not loaded)

# Check network works
ip addr
# Should show IP address

# Check more services than single-user mode
systemctl list-units --state=running | wc -l
# Should show more units than recovery mode
```

### Step 4: Exit

```bash
# Reboot to normal mode
reboot
```

---

## What Your Custom Entry Does

### vs Default Recovery Mode

| Feature | Default Recovery | Your Custom Recovery |
|---------|------------------|---------------------|
| Boot parameter | `single` | `systemd.unit=rescue.target` |
| Services | Minimal (single-user) | More (rescue.target) |
| Network | Must start manually | Auto-started |
| VFIO drivers | Loaded normally | **Blacklisted** ✅ |
| Use case | General repairs | GPU/PCIe passthrough issues |

### Why You Created This

**Purpose:** Troubleshoot PCIe passthrough / GPU issues

**The `modprobe.blacklist=vfio,vfio_pci,vfio_iommu_type1` parameter:**
- Prevents VFIO drivers from loading
- Useful when GPU passthrough causes boot issues
- Allows you to boot and fix VFIO configuration
- Lets you access system when GPU is passed through to VM

**The `systemd.unit=rescue.target` parameter:**
- More services than single-user mode
- Network auto-starts (unlike recovery mode)
- Can access Proxmox configs
- Can manage VMs if needed

### When to Use Your Custom Entry

✅ **Use "Proxmox VE (Recovery)" when:**
- GPU passthrough preventing boot
- VFIO driver issues
- Need network in recovery
- Want more services than single-user

✅ **Use default "(recovery mode)" when:**
- General system repairs
- Don't need network
- Want absolute minimal system
- Not related to PCIe/GPU

---

## Keeping Entry Updated

### Problem: Kernel Updates

When Proxmox updates to a new kernel, your custom entry will use the old kernel unless updated.

### Solution 1: Manual Update

After each kernel update:

```bash
# Check new kernel
ls -lt /boot/vmlinuz-* | head -1

# Edit custom entry
nano /etc/grub.d/40_custom
# Update kernel version

# Update GRUB
update-grub
```

### Solution 2: Auto-Update Script

The `fix-custom-recovery-entry.sh` script auto-detects the latest kernel. Run it after updates:

```bash
# After apt dist-upgrade:
/root/fix-custom-recovery-entry.sh
```

### Solution 3: Add to Hook

Create an auto-update hook (advanced):

```bash
# Create hook
cat > /etc/kernel/postinst.d/zz-update-custom-recovery << 'EOF'
#!/bin/bash
# Auto-update custom recovery entry with latest kernel
/root/fix-custom-recovery-entry.sh
EOF

chmod +x /etc/kernel/postinst.d/zz-update-custom-recovery
```

Now it updates automatically when kernels are installed!

---

## Troubleshooting

### Entry Not Showing in GRUB Menu

**Check:**
```bash
# Verify file syntax
sh -n /etc/grub.d/40_custom
# Should show no errors

# Verify file is executable
ls -la /etc/grub.d/40_custom
# Should show -rwxr-xr-x

# Make executable if needed
chmod +x /etc/grub.d/40_custom

# Update GRUB
update-grub

# Check GRUB config
grep "Proxmox VE (Recovery)" /boot/grub/grub.cfg
```

### Entry Boots to Wrong Kernel

**Check paths:**
```bash
# Verify kernel exists
ls -la /boot/vmlinuz-6.14.11-3-pve

# Check what's in grub.cfg
grep -A 3 "Proxmox VE (Recovery)" /boot/grub/grub.cfg | grep linux

# Should show: /ROOT/pve-1@/boot/vmlinuz-...
```

### Entry Boots but Hangs

**Possible causes:**
1. Wrong initrd path
2. Wrong ZFS dataset name
3. ZFS module not loaded

**Fix:**
```bash
# Verify in custom entry:
cat /etc/grub.d/40_custom

# Should have:
# insmod zfs
# linux /ROOT/pve-1@/boot/vmlinuz-...
# initrd /ROOT/pve-1@/boot/initrd.img-...

# Verify ZFS dataset name
zfs list | grep ROOT
# Should show: rpool/ROOT/pve-1
```

### VFIO Still Loading

**Check blacklist worked:**
```bash
# Boot to custom recovery
# Then check:
lsmod | grep vfio
# Should show nothing

# If VFIO is loaded, check boot parameters:
cat /proc/cmdline
# Should include: modprobe.blacklist=vfio,vfio_pci,vfio_iommu_type1
```

---

## Technical Details

### ZFS Path Format in GRUB

**Format:** `/DATASET@/path/to/file`

For Proxmox:
- Dataset: `ROOT/pve-1` (the @ is literal)
- Path: `/boot/vmlinuz-6.14.11-3-pve`
- Full: `/ROOT/pve-1@/boot/vmlinuz-6.14.11-3-pve`

**Why the `@` symbol:**
- Tells GRUB this is a ZFS dataset
- Format: `POOL/DATASET@PATH`
- Example: `rpool/ROOT/pve-1@/boot/file`

### How GRUB Finds Files on ZFS

1. GRUB loads from EFI partition (BOOTX64.EFI)
2. GRUB loads ZFS module (`insmod zfs`)
3. GRUB can now read ZFS datasets
4. GRUB reads kernel from `/ROOT/pve-1@/boot/vmlinuz-...`
5. GRUB reads initrd from `/ROOT/pve-1@/boot/initrd.img-...`
6. Kernel boots with `root=ZFS=rpool/ROOT/pve-1`
7. Initrd imports ZFS pool
8. System continues booting from ZFS

**No UUID search needed** - ZFS module handles dataset access directly.

---

## Comparison with Auto-Generated Entries

### Auto-Generated Recovery Entry

```bash
menuentry 'Proxmox VE GNU/Linux, with Linux 6.14.11-3-pve (recovery mode)' {
    load_video
    insmod gzio
    if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
    insmod part_gpt
    insmod part_gpt
    echo 'Loading Linux 6.14.11-3-pve ...'
    linux /ROOT/pve-1@/boot/vmlinuz-6.14.11-3-pve root=ZFS=/ROOT/pve-1 ro single dis_ucode_ldr root=ZFS=rpool/ROOT/pve-1 boot=zfs
    echo 'Loading initial ramdisk ...'
    initrd /ROOT/pve-1@/boot/initrd.img-6.14.11-3-pve
}
```

### Your Fixed Custom Entry

```bash
menuentry 'Proxmox VE (Recovery)' {
    insmod gzio
    insmod part_gpt
    insmod zfs
    echo 'Loading Linux 6.14.11-3-pve (Recovery Mode)...'
    linux /ROOT/pve-1@/boot/vmlinuz-6.14.11-3-pve root=ZFS=rpool/ROOT/pve-1 boot=zfs systemd.unit=rescue.target modprobe.blacklist=vfio,vfio_pci,vfio_iommu_type1
    echo 'Loading initial ramdisk ...'
    initrd /ROOT/pve-1@/boot/initrd.img-6.14.11-3-pve
}
```

### Key Differences

| Item | Auto-Generated | Your Custom |
|------|---------------|-------------|
| Boot mode | `single` | `systemd.unit=rescue.target` |
| VFIO | Normal | Blacklisted |
| Microcode | Disabled (`dis_ucode_ldr`) | Normal |
| XEN support | Checked | Not checked |
| Video | Loaded | Not loaded |

---

## Summary

**Problem:** Custom entry tried to boot from EFI partition instead of ZFS

**Root Causes:**
1. ❌ Used `search --fs-uuid` to find EFI partition
2. ❌ Used paths without ZFS dataset prefix
3. ❌ Referenced old kernel version

**Solution:**
1. ✅ Remove UUID search (not needed for ZFS)
2. ✅ Add `insmod zfs` to load ZFS module
3. ✅ Use ZFS paths: `/ROOT/pve-1@/boot/...`
4. ✅ Update to latest kernel

**Result:** Entry will now work and boot to rescue.target with VFIO blacklisted

**To Apply:** Run `fix-custom-recovery-entry.sh` on your Proxmox server

---

**Document Created:** 2025-11-06
**Issue:** Custom recovery entry using wrong paths
**Status:** Fix ready to apply
**Next:** Test entry after applying fix
