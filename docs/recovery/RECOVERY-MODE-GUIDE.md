# Proxmox Recovery Mode - Complete Guide

**Server:** proxmox
**Analysis Date:** 2025-11-06
**Status:** ✅ Recovery Mode Working - 3 Entries Available

---

## Executive Summary

Your recovery mode **IS working and properly configured**. You have 3 recovery mode entries (one per kernel). If it seemed "not working" before, it's likely because recovery mode drops you to a root shell and expects manual commands—it doesn't auto-repair or show menus.

---

## Recovery Mode Location in GRUB Menu

### Current Configuration

**GRUB Timeout:** 5 seconds
**Default Boot:** Entry 0 (normal boot)
**Recovery Status:** ✅ Enabled (not disabled)

### Menu Structure

```
┌─────────────────────────────────────────────────┐
│  GNU GRUB                                       │
├─────────────────────────────────────────────────┤
│  Proxmox VE GNU/Linux                           │  ← Default (normal boot)
│ >Advanced options for Proxmox VE GNU/Linux     │  ← SELECT THIS for recovery
│  Memory test (memtest86+x64.efi)                │
└─────────────────────────────────────────────────┘
```

**When you select "Advanced options":**

```
┌──────────────────────────────────────────────────────────────┐
│  Advanced options for Proxmox VE GNU/Linux                   │
├──────────────────────────────────────────────────────────────┤
│  Proxmox VE GNU/Linux, with Linux 6.14.11-3-pve             │ ← Normal
│ >Proxmox VE GNU/Linux, with Linux 6.14.11-3-pve (recovery)  │ ← RECOVERY ✅
│  Proxmox VE GNU/Linux, with Linux 6.14.11-2-pve             │ ← Normal
│  Proxmox VE GNU/Linux, with Linux 6.14.11-2-pve (recovery)  │ ← RECOVERY ✅
│  Proxmox VE GNU/Linux, with Linux 6.14.8-2-pve              │ ← Normal
│  Proxmox VE GNU/Linux, with Linux 6.14.8-2-pve (recovery)   │ ← RECOVERY ✅
│  Memory test (memtest86+x64.efi)                            │
└──────────────────────────────────────────────────────────────┘
```

---

## How to Access Recovery Mode

### Method 1: Via GRUB Menu (Recommended)

```
1. Reboot server:
   reboot

2. Watch for GRUB menu (you have 5 seconds)
   Press ESC to stop auto-boot

3. Arrow down to:
   "Advanced options for Proxmox VE GNU/Linux"
   Press Enter

4. Arrow down to any:
   "Proxmox VE GNU/Linux, with Linux X.X.X (recovery mode)"
   Press Enter

5. Wait for boot...
   You'll see verbose boot messages (no "quiet")

6. You'll arrive at:
   Give root password for maintenance
   (or press Control-D to continue):

7. Press Enter (no password needed in your config)
   Or type root password if set

8. You're now in recovery mode shell:
   root@proxmox:~# _
```

### Method 2: Edit Boot Entry (Advanced)

```
1. Reboot server
2. Press ESC at GRUB
3. Arrow to normal boot entry
4. Press 'e' to edit
5. Find line starting with "linux"
6. Go to end of that line
7. Add: systemd.unit=rescue.target
8. Press Ctrl+X to boot
```

---

## What Recovery Mode Actually Does

### Boot Process in Recovery Mode

```
1. GRUB loads kernel with "single" parameter
   ↓
2. Kernel boots with minimal drivers
   ↓
3. Initramfs loads ZFS modules
   ↓
4. ZFS pool (rpool) imported
   ↓
5. Root filesystem (rpool/ROOT/pve-1) mounted READ-ONLY
   ↓
6. Systemd starts in "rescue" mode
   ↓
7. Root shell presented
   ↓
8. YOU are now in control (manual commands needed)
```

### What's Running

**Services Started:**
- ✅ Basic system initialization
- ✅ ZFS pool imported
- ✅ Root filesystem mounted
- ✅ Console/terminal
- ✅ Basic shell utilities

**Services NOT Started:**
- ❌ Network (no IP address)
- ❌ SSH (can't connect remotely)
- ❌ Proxmox services (pvedaemon, pveproxy, pve-cluster)
- ❌ VMs/Containers
- ❌ Most background services

### Boot Parameters Used

```bash
# Normal boot:
root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet amd_iommu=on iommu=pt...

# Recovery mode boot:
root=ZFS=rpool/ROOT/pve-1 boot=zfs single dis_ucode_ldr
                                    ^^^^^^ ^^^^^^^^^^^^^^
                                    Single  Disable CPU
                                    user    microcode
                                    mode    updates
```

**Key differences:**
- `single` - Boots to single-user mode (root shell)
- `dis_ucode_ldr` - Disables CPU microcode loading (for CPU issues)
- No `quiet` - Shows all boot messages (for diagnostics)
- No `amd_iommu` etc. - Removes performance/passthrough features

---

## Why Recovery Mode "Didn't Work"

### Common Misconceptions

❌ **Myth:** "Recovery mode will fix my system automatically"
✅ **Reality:** Recovery mode gives you a shell to fix things manually

❌ **Myth:** "Recovery mode will show me a menu of repair options"
✅ **Reality:** You get a root shell prompt and must know what commands to run

❌ **Myth:** "Recovery mode will have network access"
✅ **Reality:** Network is NOT started automatically—you must start it manually

❌ **Myth:** "Recovery mode will let me access the Proxmox Web UI"
✅ **Reality:** Web UI is not running—you're at a command line

### What You Probably Experienced

**What you saw:**
```
[lots of boot messages]
...
Give root password for maintenance
(or press Control-D to continue):

root@proxmox:~# _
```

**What you thought:** "It's not working, I'm stuck at a prompt"

**Reality:** This IS recovery mode working perfectly! It's waiting for YOUR commands.

---

## How to Use Recovery Mode Effectively

### First Steps When You Boot to Recovery

```bash
# 1. Verify you're in recovery mode
systemctl list-units --state=running
# Should show minimal services

# 2. Remount root filesystem as writable
mount -o remount,rw /
echo "✅ Root is now read-write"

# 3. Check ZFS status
zpool status rpool
zfs list

# 4. Start networking (if needed)
systemctl start networking
ip addr show
# If no IP, check: cat /etc/network/interfaces
```

### Common Recovery Tasks

#### Task 1: Fix Network Configuration

```bash
# Problem: Changed network config, lost connectivity

# In recovery mode:
mount -o remount,rw /
nano /etc/network/interfaces
# Fix your configuration

# Test the fix
systemctl start networking
ip addr
ping 8.8.8.8

# If working, reboot to normal:
reboot
```

#### Task 2: Fix Broken Packages

```bash
# Problem: apt upgrade failed, system won't boot

# In recovery mode:
mount -o remount,rw /
systemctl start networking

# Fix packages
apt update
apt --fix-broken install
dpkg --configure -a

# Verify
apt list --upgradable

# Reboot
reboot
```

#### Task 3: Restore Configuration

```bash
# Problem: Accidentally broke Proxmox config

# In recovery mode:
mount -o remount,rw /

# List available backups
ls -lth /root/config-backups/

# Restore specific config
cd /root/config-backups
tar -xzf proxmox-config-2025-11-06.tar.gz -C / etc/pve/

# Or full restore
tar -xzf proxmox-config-2025-11-06.tar.gz -C /

# Reboot
reboot
```

#### Task 4: Reset Root Password

```bash
# Problem: Forgot root password

# In recovery mode (already has root access):
mount -o remount,rw /

# Set new password
passwd root
# Enter new password twice

# Reboot
reboot
```

#### Task 5: Check System Logs

```bash
# Problem: System crashes, need to see why

# In recovery mode:
mount -o remount,rw /

# Check recent logs
journalctl -xe | tail -100

# Check specific service
journalctl -u pvedaemon | tail -50

# Check kernel messages
dmesg | tail -50

# Check last boot
journalctl -b -1 | tail -100
```

#### Task 6: Fix GRUB Boot Issues

```bash
# Problem: GRUB not booting correctly

# In recovery mode:
mount -o remount,rw /

# Verify GRUB config
cat /etc/default/grub

# Regenerate GRUB
update-grub

# Reinstall GRUB (if needed)
grub-install /dev/nvme0n1
grub-install /dev/nvme1n1

# Reboot
reboot
```

#### Task 7: ZFS Issues

```bash
# Problem: ZFS pool won't import

# In recovery mode:
# Pool is already imported, but if you need to check:

zpool status -v rpool

# Fix pool errors (if any)
zpool scrub rpool

# Check dataset issues
zfs list -t all

# Mount additional datasets
zfs mount -a

# Check snapshots
zfs list -t snapshot

# Rollback if needed
zfs rollback rpool/ROOT/pve-1@snapshot-name
```

### Exiting Recovery Mode

```bash
# Option 1: Reboot to normal mode (recommended)
reboot

# Option 2: Continue to normal boot
systemctl default
# or
exec /sbin/init

# Option 3: Just press Ctrl+D
# (may start more services)
```

---

## Alternative Recovery Methods

If recovery mode doesn't meet your needs:

### Option 1: Systemd Rescue Target

**More services than recovery mode**

**Access:**
```
At GRUB:
1. Press 'e' on normal boot entry
2. Find line: linux /ROOT/pve-1@/boot/vmlinuz...
3. Go to end, add: systemd.unit=rescue.target
4. Press Ctrl+X
```

**What you get:**
- ✅ Root shell
- ✅ More system services
- ✅ Easier network access
- ❌ Still no Proxmox services

### Option 2: Systemd Emergency Target

**Even more minimal than recovery mode**

**Access:**
```
At GRUB:
1. Press 'e' on normal boot entry
2. Find line: linux /ROOT/pve-1@/boot/vmlinuz...
3. Go to end, add: systemd.unit=emergency.target
4. Press Ctrl+X
```

**What you get:**
- ✅ Root shell
- ✅ Absolute minimum services
- ❌ Must mount everything manually
- ❌ No network

### Option 3: Init Shell (Expert Mode)

**Direct shell, bypassing systemd**

**Access:**
```
At GRUB:
1. Press 'e' on normal boot entry
2. Find line: linux /ROOT/pve-1@/boot/vmlinuz...
3. Go to end, add: init=/bin/bash
4. Press Ctrl+X
```

**What you get:**
- ✅ Immediate root shell
- ❌ No systemd
- ❌ Must start everything manually
- ❌ Root filesystem read-only initially

**First commands:**
```bash
mount -o remount,rw /
mount -a
```

### Option 4: Boot from Proxmox ISO

**Complete external recovery**

**Access:**
```
1. Boot from Proxmox installer USB/ISO
2. Don't install, switch to console: Ctrl+Alt+F2
3. Import ZFS pool:
   zpool import -f rpool
4. Mount root:
   mkdir /mnt/old-root
   mount -t zfs rpool/ROOT/pve-1 /mnt/old-root
5. Access your system:
   chroot /mnt/old-root
```

---

## Testing Recovery Mode

### Safe Test Procedure

**Step 1: Prepare**
```bash
# Create a ZFS snapshot before testing
zfs snapshot rpool/ROOT/pve-1@test-recovery-$(date +%Y%m%d)

# Verify snapshot
zfs list -t snapshot | grep test-recovery
```

**Step 2: Reboot to Recovery**
```bash
# Reboot
reboot

# At GRUB:
# - Press ESC
# - Select "Advanced options"
# - Select "recovery mode"
```

**Step 3: In Recovery Mode**
```bash
# You should see:
# Give root password for maintenance
# (or press Control-D to continue):

# Press Enter

# You're now at:
# root@proxmox:~# _

# Test commands:
mount -o remount,rw /
zpool status
ip addr
ls -la /root/

# Exit
reboot
```

**Step 4: Verify Normal Boot**
```bash
# After reboot, system should boot normally

# Verify
systemctl status pve-cluster
systemctl status pvedaemon

# If everything OK, delete test snapshot
zfs destroy rpool/ROOT/pve-1@test-recovery-YYYYMMDD
```

---

## Troubleshooting Recovery Mode

### Issue: "Can't see GRUB menu"

**Symptoms:** System boots too fast, can't press ESC

**Solution:**
```bash
# Edit GRUB timeout (before testing)
nano /etc/default/grub

# Change:
GRUB_TIMEOUT=5

# To:
GRUB_TIMEOUT=10

# Update GRUB
update-grub

# Reboot
reboot
```

### Issue: "Recovery mode hangs at password prompt"

**Symptoms:** Stuck at "Give root password for maintenance"

**Solutions:**
1. Press **Enter** (password may not be required)
2. Type root password if you set one
3. Press **Ctrl+D** to continue to normal boot
4. If frozen, hard reset and try different kernel recovery

### Issue: "Root filesystem is read-only"

**Symptoms:** Can't edit files, "Read-only file system" errors

**Solution:**
```bash
mount -o remount,rw /
```

### Issue: "Can't start network"

**Symptoms:** No IP address, can't ping

**Solution:**
```bash
# Check interface names
ip link show

# Check configuration
cat /etc/network/interfaces

# Start networking
systemctl start networking

# Check status
ip addr
systemctl status networking
```

### Issue: "ZFS pool not imported"

**Symptoms:** Can't see ZFS datasets

**Solution:**
```bash
# Check if pool is imported
zpool list

# If not, import manually
zpool import rpool

# Or force import
zpool import -f rpool

# Mount datasets
zfs mount -a
```

### Issue: "Want to boot normally after checking"

**Solutions:**
```bash
# Option 1: Reboot
reboot

# Option 2: Continue to normal boot
systemctl default

# Option 3: Press Ctrl+D
# (at the prompt)
```

---

## Recovery Mode vs Normal Boot Comparison

| Feature | Normal Boot | Recovery Mode |
|---------|-------------|---------------|
| Boot time | Fast | Slower (verbose) |
| Boot messages | Hidden (quiet) | Visible (no quiet) |
| Services started | All | Minimal |
| Network | ✅ Auto-started | ❌ Manual |
| SSH access | ✅ Yes | ❌ No |
| Web UI | ✅ Available | ❌ Not running |
| VMs/CTs | ✅ Auto-start | ❌ Stopped |
| Filesystem | Read-write | Read-only* |
| User | All users | Root only |
| Systemd target | graphical.target | rescue.target |
| CPU microcode | ✅ Loaded | ❌ Disabled |
| IOMMU | ✅ Enabled | ❌ Disabled |

*Must remount as read-write manually

---

## Quick Reference

### Access Recovery Mode
```
Reboot → ESC → Advanced options → (recovery mode) → Enter
```

### Essential Commands in Recovery
```bash
mount -o remount,rw /           # Make filesystem writable
systemctl start networking      # Start network
zpool status                    # Check ZFS
journalctl -xe                  # View logs
reboot                          # Exit recovery
```

### Exit Recovery Mode
```bash
reboot                          # Recommended
systemctl default               # Continue to normal
# or press Ctrl+D
```

---

## Summary

**Your Recovery Mode Status: ✅ WORKING**

- **Location:** Advanced options → (recovery mode)
- **Available:** 3 kernels × recovery mode each
- **Boot Parameter:** `single` (single-user mode)
- **What it does:** Drops to root shell for manual repairs
- **What it doesn't do:** Auto-repair, show menus, start services
- **How to use:** Run commands manually to fix issues
- **How to exit:** Type `reboot` or press Ctrl+D

**Key Takeaway:**
Recovery mode IS working—it just requires you to know what commands to run. It's a tool for system administrators who understand Linux, not an automated repair wizard.

If you need help with specific recovery tasks, let me know what you're trying to fix!

---

**Document Created:** 2025-11-06
**Recovery Mode Verified:** 3 entries available
**Status:** Fully functional
**Next:** See PROXMOX-RECOVERY-ANALYSIS.md for complete recovery guide
