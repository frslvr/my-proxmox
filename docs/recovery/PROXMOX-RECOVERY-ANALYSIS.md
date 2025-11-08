# Proxmox Recovery Mode Analysis Report

**Server**: proxmox
**Proxmox Version**: 9.0.11 (pve-manager)
**Kernel**: 6.14.11-3-pve
**Boot Mode**: UEFI
**Storage**: ZFS Mirror (rpool)
**Analysis Date**: 2025-11-06

---

## Executive Summary

Your Proxmox server has **multiple recovery options** available with a healthy ZFS mirrored storage configuration. The system provides:

- ✅ **3 Recovery Kernels** with dedicated recovery modes
- ✅ **ZFS Mirror** in healthy state (ONLINE, no errors)
- ✅ **Systemd Emergency/Rescue Modes**
- ✅ **UEFI Boot** with proper GRUB configuration
- ⚠️ **No automated backups configured**
- ⚠️ **EFI partition needs fsck**

---

## 1. Available Recovery Modes

### 1.1 GRUB Recovery Mode (Primary Method)

Your system has **THREE kernel versions**, each with a dedicated recovery mode:

| Kernel Version | Recovery Mode Available | Location |
|----------------|------------------------|----------|
| 6.14.11-3-pve (current) | ✅ Yes | GRUB submenu |
| 6.14.11-2-pve | ✅ Yes | GRUB submenu |
| 6.14.8-2-pve | ✅ Yes | GRUB submenu |

**Access Method:**
1. Reboot the server
2. Press `ESC` or `Shift` during boot to enter GRUB menu
3. Select "Advanced options for Proxmox VE GNU/Linux"
4. Choose any kernel with "(recovery mode)" suffix

**Recovery Mode Features:**
- Single-user mode (root access, no password if configured)
- Minimal services loaded
- Network typically disabled
- Read-only root filesystem initially
- Manual remount required for write access

### 1.2 Systemd Recovery Targets

Available systemd recovery targets:

```
emergency.target  - Emergency Mode (minimal system)
rescue.target     - Rescue Mode (basic system + essential services)
multi-user.target - Normal multi-user mode (no GUI)
graphical.target  - Full graphical mode (current default)
```

**Access Method:**

**Option A: Boot Parameter**
1. At GRUB menu, press 'e' to edit boot entry
2. Find the line starting with `linux`
3. Add to end: `systemd.unit=rescue.target` or `systemd.unit=emergency.target`
4. Press `Ctrl+X` or `F10` to boot

**Option B: From Running System**
```bash
systemctl isolate rescue.target
# or
systemctl isolate emergency.target
```

---

## 2. Current Boot Configuration

### 2.1 GRUB Settings
```
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_aspm=off pcie_port_pm=off pcie_aspm.policy=performance"
```

**Boot Parameters Explained:**
- `quiet` - Suppress verbose kernel messages
- `amd_iommu=on` - Enable AMD IOMMU for PCIe passthrough
- `iommu=pt` - IOMMU passthrough mode
- `pcie_aspm=off` - PCIe power management disabled (stability)
- `pcie_port_pm=off` - PCIe port power management disabled
- `pcie_aspm.policy=performance` - Performance over power saving

### 2.2 Current Kernel Parameters
```
root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet
```

**Key Points:**
- Root filesystem: ZFS dataset `rpool/ROOT/pve-1`
- ZFS boot support enabled
- Standard quiet boot

---

## 3. ZFS Storage Recovery

### 3.1 ZFS Pool Status

```
Pool: rpool
State: ONLINE ✅
Scrub: Completed 2025-10-12 (0 errors)
Configuration: Mirror (2x NVMe drives)
```

**Mirror Devices:**
```
nvme-eui.e8238fa6bf530001001b448b4d426259-part3 (nvme1n1p3)
nvme-eui.e8238fa6bf530001001b448b4d4254e2-part3 (nvme2n1p3)
```

**Health Status:** ✅ EXCELLENT
- Both mirrors ONLINE
- 0 read errors
- 0 write errors
- 0 checksum errors
- Recent scrub completed successfully

### 3.2 ZFS Datasets

```
NAME                     MOUNTPOINT
rpool/ROOT/pve-1         /           (2.8G used / 98G available)
rpool/var-lib-vz         /var/lib/vz (184G used / 98G available)
rpool/data               /rpool/data
rpool/ROOT               /rpool/ROOT
```

### 3.3 ZFS Snapshots (Recovery Points)

```
rpool/data/base-101-disk-0@__base__
rpool/data/base-101-disk-1@__base__
rpool/data/base-101-disk-2@__base__
```

**Note:** These appear to be template base snapshots for VM 101.

### 3.4 ZFS Recovery Capabilities

**Single Drive Failure:**
- System will continue running on remaining mirror
- No data loss
- Performance impact minimal
- Replace failed drive and resilver

**Both Drives Fail (worst case):**
- Boot from Proxmox installer in rescue mode
- Import pool with: `zpool import -f rpool`
- Access data read-only if needed
- Restore from backups

**Snapshot Rollback:**
```bash
# List snapshots
zfs list -t snapshot

# Rollback to snapshot (example)
zfs rollback rpool/ROOT/pve-1@snapshot-name
```

**ZFS Send/Receive for Backup:**
```bash
# Create snapshot
zfs snapshot rpool/ROOT/pve-1@backup-$(date +%Y%m%d)

# Send to external storage
zfs send rpool/ROOT/pve-1@backup-20251106 | ssh user@backup-server "zfs receive backup/proxmox"
```

---

## 4. Recovery Procedures

### 4.1 Boot into GRUB Recovery Mode

**When to Use:**
- System won't boot normally
- Need to repair filesystem
- Fix configuration files
- Reset passwords
- Repair broken packages

**Steps:**
1. Reboot server
2. Press `ESC` at GRUB menu (timeout: 5 seconds)
3. Select "Advanced options for Proxmox VE GNU/Linux"
4. Select "Proxmox VE GNU/Linux, with Linux 6.14.11-3-pve (recovery mode)"
5. You'll be dropped to root shell

**In Recovery Mode:**
```bash
# Remount root as read-write
mount -o remount,rw /

# Check ZFS pool status
zpool status

# Import pool if needed
zpool import -f rpool

# Mount all ZFS datasets
zfs mount -a

# Check system logs
journalctl -xe

# Fix issues, then reboot
reboot
```

### 4.2 Emergency Mode via Kernel Parameters

**When to Use:**
- GRUB recovery mode fails
- Need absolute minimal system
- ZFS issues preventing normal boot

**Steps:**
1. At GRUB menu, press 'e' on default entry
2. Find line starting with `linux /vmlinuz-6.14.11-3-pve`
3. Go to end of that line (after `quiet`)
4. Add: `systemd.unit=emergency.target`
5. Press `Ctrl+X` to boot

**In Emergency Mode:**
```bash
# Manually import ZFS pool
zpool import -f rpool

# Mount root dataset
zfs mount rpool/ROOT/pve-1

# Mount other datasets
zfs mount -a

# Start essential services manually
systemctl start systemd-journald
systemctl start networking

# Investigate and fix issues
```

### 4.3 Boot from Proxmox Installer (Advanced Recovery)

**When to Use:**
- System completely unbootable
- Need to access data externally
- Perform major repairs
- Restore from backup

**Steps:**
1. Boot from Proxmox VE ISO
2. Select "Install Proxmox VE" but DON'T proceed
3. Switch to console: `Ctrl+Alt+F2`
4. Import existing ZFS pool:
   ```bash
   zpool import -f rpool
   zfs list
   # Mount datasets as needed
   mkdir /mnt/old-root
   mount -t zfs rpool/ROOT/pve-1 /mnt/old-root

   # Access your data
   cd /mnt/old-root
   ```
5. Make repairs, backup data, or restore

### 4.4 ZFS Pool Recovery

**If Pool Won't Import:**
```bash
# Try readonly import
zpool import -o readonly=on rpool

# Force import (if pool was improperly exported)
zpool import -f rpool

# Import by pool ID if name conflicts exist
zpool import
zpool import <pool-id>

# Last resort: import even with errors
zpool import -F rpool
```

**If Mirror Degraded:**
```bash
# Check status
zpool status rpool

# Replace failed drive (example: nvme1n1p3 failed)
zpool replace rpool nvme1n1p3 nvme3n1p3

# Monitor resilver progress
zpool status
watch -n 5 'zpool status rpool'
```

---

## 5. Identified Issues & Recommendations

### 5.1 Critical Issues

#### ⚠️ EFI Partition Not Properly Unmounted
```
Nov 06 18:05:18 proxmox kernel: FAT-fs (nvme2n1p2): Volume was not properly unmounted.
Some data may be corrupt. Please run fsck.
```

**Impact:** Potential EFI boot corruption
**Risk Level:** MEDIUM
**Recommendation:**
```bash
# Identify EFI partitions
lsblk | grep -i efi

# Run fsck on both EFI partitions
umount /boot/efi
fsck.vfat -a /dev/nvme1n1p2
fsck.vfat -a /dev/nvme2n1p2
mount /boot/efi
```

### 5.2 Warning Issues

#### ⚠️ No Backup Jobs Configured
```
No backup jobs configured
```

**Impact:** No automated backups = no recovery points
**Risk Level:** HIGH
**Recommendation:**

**Create Backup Schedule:**
1. In Proxmox Web UI: Datacenter → Backup
2. Add backup job:
   - Storage: External NFS/PBS/SMB share
   - Schedule: Daily at 2 AM
   - Retention: Keep 7 daily, 4 weekly
   - Mode: Snapshot (for minimal downtime)

**Manual Backup Command:**
```bash
# Backup all VMs/CTs to local storage
vzdump --all --storage local --mode snapshot --compress zstd

# Better: Backup to external location
vzdump --all --storage backup-nfs --mode snapshot --compress zstd --mailto root
```

**ZFS Snapshot Schedule:**
```bash
# Add to crontab
0 2 * * * zfs snapshot rpool/ROOT/pve-1@daily-$(date +\%Y\%m\%d)
0 2 * * 0 zfs snapshot rpool/data@weekly-$(date +\%Y\%m\%d)

# Auto-cleanup old snapshots (keep 7 days)
0 3 * * * zfs list -t snapshot -o name | grep daily | head -n -7 | xargs -n 1 zfs destroy
```

### 5.3 Hardware Warnings (Non-Critical)

```
nouveau 0000:02:00.0: gsp ctor failed: -2
Bluetooth: hci0: Opcode 0x0c03 failed: -16
hub 12-0:1.0: config failed, hub doesn't have any ports!
```

**Impact:** Cosmetic errors, not affecting server operation
**Details:**
- Nouveau GPU driver issue (Nvidia GPU present but not used)
- Bluetooth initialization failed (likely not needed)
- USB hub configuration issue (non-critical)

**Recommendation:** Can safely ignore unless planning to use GPU/Bluetooth.

---

## 6. Recovery Mode Access Summary

### Quick Reference Table

| Recovery Type | How to Access | Use Case | Difficulty |
|---------------|---------------|----------|------------|
| **GRUB Recovery** | GRUB menu → Advanced → Recovery | Configuration fixes, package repairs | Easy |
| **Rescue Target** | Add `systemd.unit=rescue.target` to kernel | Service issues, network problems | Easy |
| **Emergency Target** | Add `systemd.unit=emergency.target` | Critical system failures | Medium |
| **Single User Mode** | Add `single` to kernel params | Password reset, minimal repairs | Easy |
| **Init=/bin/bash** | Add `init=/bin/bash` to kernel | Broken systemd, severe issues | Hard |
| **Proxmox ISO Rescue** | Boot from installer USB/ISO | Complete system failure | Medium |
| **ZFS Import** | Boot external OS + `zpool import` | Data recovery, pool corruption | Hard |

### Kernel Boot Parameters (Add to GRUB)

```bash
# Rescue mode
systemd.unit=rescue.target

# Emergency mode
systemd.unit=emergency.target

# Single user mode (old method)
single

# Break to initramfs shell
break=premount

# Force ZFS readonly import
zfs_force=1 ro

# Disable ZFS import (troubleshooting)
zfs=0

# Emergency shell
init=/bin/bash
```

---

## 7. Best Practices & Recommendations

### 7.1 Immediate Actions

1. **Fix EFI Partition** ⚠️ HIGH PRIORITY
   ```bash
   fsck.vfat -a /dev/nvme1n1p2
   fsck.vfat -a /dev/nvme2n1p2
   ```

2. **Configure Automated Backups** ⚠️ HIGH PRIORITY
   - Set up daily VM/CT backups
   - Implement ZFS snapshot schedule
   - Test restore procedure

3. **Create System Snapshots**
   ```bash
   # Before major changes, create snapshot
   zfs snapshot rpool/ROOT/pve-1@pre-upgrade-$(date +%Y%m%d)
   ```

### 7.2 Regular Maintenance

**Weekly:**
- Review system logs: `journalctl -p err -b`
- Check ZFS pool health: `zpool status`
- Verify backup completion

**Monthly:**
- Run ZFS scrub: `zpool scrub rpool` (currently auto-scheduled)
- Test recovery boot (GRUB recovery mode)
- Update Proxmox: `apt update && apt dist-upgrade`

**Quarterly:**
- Test full restore from backup
- Review and update recovery procedures
- Verify ZFS snapshot retention

### 7.3 Recovery Preparedness

**Document and Keep Offsite:**
1. ✅ This recovery analysis report
2. Network configuration (`/etc/network/interfaces`)
3. PVE cluster config (`/etc/pve/`)
4. Custom scripts and cron jobs
5. ZFS pool import commands

**Create Recovery USB:**
```bash
# Download latest Proxmox ISO
# Flash to USB drive
# Test booting from it
# Keep in secure location
```

**Test Recovery Procedures:**
- Boot into GRUB recovery mode quarterly
- Practice ZFS snapshot rollback in test environment
- Verify backup integrity with test restores

### 7.4 Monitoring Setup

**Add ZFS Monitoring:**
```bash
# Install monitoring if not already present
apt install smartmontools nvme-cli

# Add to crontab - daily ZFS health check
0 6 * * * zpool status | grep -v ONLINE && echo "ZFS Pool Issue!" | mail -s "ZFS Alert" root

# NVMe health check
smartctl -a /dev/nvme0n1
smartctl -a /dev/nvme1n1
```

---

## 8. Emergency Contact Procedures

### Before Major Changes

**Always:**
1. Create ZFS snapshot: `zfs snapshot rpool/ROOT/pve-1@pre-change-$(date +%Y%m%d)`
2. Backup critical configs: `tar -czf /root/pve-config-backup-$(date +%Y%m%d).tar.gz /etc/pve /etc/network`
3. Have recovery plan ready
4. Schedule maintenance window

### If System Becomes Unbootable

**Step-by-step Recovery:**

1. **Try GRUB Recovery Mode** (easiest)
2. **Try Emergency Boot** (add kernel parameter)
3. **Boot Proxmox ISO** (import ZFS pool)
4. **Professional Recovery** (if data critical and above fails)

---

## 9. System Specifications Summary

**Hardware:**
- CPU: AMD (IOMMU enabled for virtualization)
- RAM: 192GB (94GB tmpfs allocation)
- Storage: 2x NVMe drives in ZFS mirror
  - Total usable: ~300GB (rpool)
  - Currently used: 186.8GB (66% on /var/lib/vz)
  - Root: 2.8GB / 100GB

**Software:**
- Proxmox VE: 9.0.11
- Kernel: 6.14.11-3-pve (latest)
- ZFS: 2.3.4-pve1
- Boot: UEFI with systemd-boot tools

**Network:**
- Tailscale VPN configured (192.168.100.2)
- Local IP: 192.168.1.212

---

## 10. Conclusion

Your Proxmox server has **excellent recovery capabilities** with:

✅ Multiple kernel versions with dedicated recovery modes
✅ Healthy ZFS mirror with zero errors
✅ UEFI boot configuration
✅ Systemd emergency/rescue targets
✅ Professional-grade storage redundancy

**Critical Next Steps:**
1. Fix EFI partition (fsck)
2. Configure automated backups
3. Set up ZFS snapshot schedule
4. Test recovery procedures

**Overall Recovery Readiness: 7/10**
- Storage: Excellent (ZFS mirror, healthy)
- Boot Recovery: Excellent (multiple options)
- Data Protection: Poor (no backups configured)
- Documentation: Excellent (this report)

With the backup recommendations implemented, this would be a **10/10** recovery-ready system.

---

## Appendix A: Common Recovery Commands

```bash
# === ZFS Commands ===
zpool status                          # Check pool health
zpool scrub rpool                     # Start scrub
zfs list                              # List all datasets
zfs list -t snapshot                  # List snapshots
zfs snapshot rpool/ROOT/pve-1@name    # Create snapshot
zfs rollback rpool/ROOT/pve-1@name    # Rollback to snapshot
zfs send/receive                      # Backup/restore

# === System Recovery ===
systemctl isolate rescue.target       # Enter rescue mode
systemctl isolate emergency.target    # Enter emergency mode
journalctl -xb                        # Boot logs
journalctl -p err                     # Error logs only

# === Filesystem ===
mount -o remount,rw /                 # Remount root as writable
fsck.ext4 /dev/sdX                    # Check ext4 filesystem
fsck.vfat /dev/sdX                    # Check FAT filesystem (EFI)

# === GRUB ===
update-grub                           # Regenerate GRUB config
grub-install /dev/nvme0n1             # Reinstall GRUB

# === Proxmox Specific ===
pveversion -v                         # Full version info
pvecm status                          # Cluster status
vzdump                                # Backup VMs/containers
qm list                               # List VMs
pct list                              # List containers
```

---

## Appendix B: Boot Process Flow

```
1. UEFI Firmware
   ↓
2. GRUB Bootloader (/boot/grub/grub.cfg)
   ↓
3. Kernel Selection (6.14.11-3-pve or recovery mode)
   ↓
4. Initramfs Loading (ZFS modules)
   ↓
5. ZFS Pool Import (rpool)
   ↓
6. Root Mount (rpool/ROOT/pve-1)
   ↓
7. Systemd Init
   ↓
8. Target: graphical.target (default)
   ↓
9. Proxmox Services (pve-cluster, pvedaemon, pveproxy, pvestatd)
   ↓
10. System Ready
```

---

**Report Generated:** 2025-11-06
**Server:** proxmox
**Analyst:** Claude (Automated Analysis)
**Status:** System Healthy with Recommendations
