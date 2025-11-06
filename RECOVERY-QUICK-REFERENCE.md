# Proxmox Recovery - Quick Reference Card

**Server:** proxmox | **Storage:** ZFS Mirror | **Boot:** UEFI

---

## 🚨 Emergency Recovery Access

### Method 1: GRUB Recovery Mode (RECOMMENDED)
```
1. Reboot server
2. Press ESC at GRUB
3. "Advanced options for Proxmox VE GNU/Linux"
4. Select "(recovery mode)"
5. Root shell access granted
```

### Method 2: Emergency Boot Parameter
```
At GRUB: Press 'e'
Add to kernel line: systemd.unit=emergency.target
Press Ctrl+X to boot
```

### Method 3: Proxmox ISO Rescue
```
Boot from Proxmox USB/ISO
Ctrl+Alt+F2 for console
zpool import -f rpool
mount -t zfs rpool/ROOT/pve-1 /mnt
```

---

## 💾 ZFS Recovery Commands

```bash
# Check pool health
zpool status

# Import pool (if not auto-imported)
zpool import -f rpool

# Mount all datasets
zfs mount -a

# Create emergency snapshot
zfs snapshot rpool/ROOT/pve-1@emergency-$(date +%Y%m%d-%H%M)

# List snapshots
zfs list -t snapshot

# Rollback to snapshot
zfs rollback rpool/ROOT/pve-1@snapshot-name

# Check for errors
zpool status -v
```

---

## 🔧 Common Recovery Tasks

### Fix Boot Issues
```bash
mount -o remount,rw /
update-grub
grub-install /dev/nvme0n1
grub-install /dev/nvme1n1
```

### Reset Root Password
```bash
# In recovery mode:
passwd root
```

### Fix Broken Packages
```bash
mount -o remount,rw /
apt --fix-broken install
dpkg --configure -a
```

### Remount Filesystem as Writable
```bash
mount -o remount,rw /
```

### Start Network in Recovery
```bash
systemctl start networking
ip addr show
```

---

## ⚠️ Critical Issues Found

### 1. EFI Partition Needs Repair
```bash
umount /boot/efi
fsck.vfat -a /dev/nvme1n1p2
fsck.vfat -a /dev/nvme2n1p2
mount /boot/efi
```

### 2. No Backups Configured
```bash
# Quick backup all VMs
vzdump --all --storage local --mode snapshot --compress zstd

# Setup ZFS snapshots
zfs snapshot rpool/ROOT/pve-1@backup-$(date +%Y%m%d)
zfs snapshot rpool/data@backup-$(date +%Y%m%d)
```

---

## 📊 System Health Check

```bash
# Full system status
zpool status                    # ZFS health
df -h                           # Disk usage
systemctl status pve-cluster    # Cluster status
journalctl -p err -b            # Boot errors
pvecm status                    # Cluster info
pveversion -v                   # Version info
```

---

## 🔑 Important Paths

```
/etc/pve/              - Proxmox config
/etc/network/          - Network config
/boot/grub/grub.cfg    - GRUB config
/etc/default/grub      - GRUB settings
/var/lib/vz/           - VM/CT storage
```

---

## 📞 Recovery Decision Tree

```
Can't boot?
├─ Yes → Try GRUB Recovery Mode
│   ├─ Works → Fix issue, remount rw
│   └─ Fails → Try Emergency Boot Parameter
│       ├─ Works → Import ZFS, mount manually
│       └─ Fails → Boot from Proxmox ISO
│
└─ Boots but issues?
    ├─ Service failure → systemctl status <service>
    ├─ Storage issue → zpool status
    └─ Network issue → ip addr, systemctl status networking
```

---

## 🎯 Available Kernels & Recovery Modes

| Kernel | Status | Recovery Mode |
|--------|--------|---------------|
| 6.14.11-3-pve | Current ✅ | Available |
| 6.14.11-2-pve | Backup | Available |
| 6.14.8-2-pve | Backup | Available |

---

## 🛡️ ZFS Mirror Status

```
Pool: rpool
State: ONLINE ✅
Drives: 2x NVMe in mirror
Last Scrub: 2025-10-12 (0 errors)
Capacity: 282G / 98G free
```

**If drive fails:**
```bash
# Check which drive failed
zpool status

# Replace failed drive (example)
zpool replace rpool old-drive-id new-drive-id

# Monitor resilver
watch -n 5 'zpool status'
```

---

## 📝 Pre-Change Checklist

Before making system changes:

- [ ] Create ZFS snapshot: `zfs snapshot rpool/ROOT/pve-1@pre-change-$(date +%Y%m%d)`
- [ ] Backup configs: `tar -czf /root/backup-$(date +%Y%m%d).tar.gz /etc/pve /etc/network`
- [ ] Note current kernel: `uname -r`
- [ ] Verify backups exist
- [ ] Have recovery plan ready

---

## 🚀 Quick Actions

```bash
# Create snapshot NOW
zfs snapshot rpool/ROOT/pve-1@manual-$(date +%Y%m%d-%H%M%S)

# Backup all VMs NOW
vzdump --all --storage local --mode snapshot

# Fix EFI partition NOW
umount /boot/efi && fsck.vfat -a /dev/nvme1n1p2 && fsck.vfat -a /dev/nvme2n1p2 && mount /boot/efi

# Check system health NOW
zpool status && journalctl -p err -b | tail -20
```

---

**Keep this reference accessible offline!**
**Print or save to external device**

Last Updated: 2025-11-06
