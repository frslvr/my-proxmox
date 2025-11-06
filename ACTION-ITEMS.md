# Proxmox Server - Action Items

**Priority Tasks Based on Recovery Analysis**

---

## 🔴 HIGH PRIORITY (Do This Week)

### 1. Fix EFI Partition Corruption ⚠️
**Issue:** FAT-fs warnings indicate improper unmount
**Risk:** Boot failure possible
**Action:**
```bash
umount /boot/efi
fsck.vfat -a /dev/nvme1n1p2
fsck.vfat -a /dev/nvme2n1p2
mount /boot/efi
# Verify
dmesg | grep -i fat
```
**Time Required:** 5 minutes
**Status:** ⬜ Not Started

---

### 2. Configure Automated Backups ⚠️
**Issue:** No backup jobs configured
**Risk:** Data loss if hardware fails
**Action:**

**Option A: Proxmox Web UI**
1. Navigate to: Datacenter → Backup
2. Click "Add" to create backup job
3. Configure:
   - Storage: (Add external storage first if needed)
   - Schedule: Daily at 2:00 AM
   - Selection Mode: All
   - Retention: Keep last 7
   - Mode: Snapshot
   - Compression: ZSTD
4. Test backup manually

**Option B: Command Line**
```bash
# Create backup destination (example: NFS)
# Edit /etc/pve/storage.cfg to add backup storage

# Manual test backup
vzdump --all --storage local --mode snapshot --compress zstd

# Add to /etc/cron.d/vzdump-backup
0 2 * * * root vzdump --all --storage backup --mode snapshot --compress zstd --mailto root
```

**Time Required:** 30 minutes
**Status:** ⬜ Not Started

---

### 3. Implement ZFS Snapshot Schedule
**Issue:** No automated snapshots for system recovery
**Risk:** Cannot rollback from system changes
**Action:**
```bash
# Create snapshot script
cat > /usr/local/bin/zfs-auto-snapshot.sh << 'EOF'
#!/bin/bash
# Daily root snapshot
zfs snapshot rpool/ROOT/pve-1@daily-$(date +%Y%m%d)

# Keep only last 7 daily snapshots
zfs list -t snapshot -o name -s creation | grep "rpool/ROOT/pve-1@daily-" | head -n -7 | xargs -r -n 1 zfs destroy

# Weekly data snapshot (Sundays)
if [ $(date +%u) -eq 7 ]; then
    zfs snapshot rpool/data@weekly-$(date +%Y%m%d)
    # Keep only last 4 weekly snapshots
    zfs list -t snapshot -o name -s creation | grep "rpool/data@weekly-" | head -n -4 | xargs -r -n 1 zfs destroy
fi
EOF

chmod +x /usr/local/bin/zfs-auto-snapshot.sh

# Add to crontab
echo "0 1 * * * root /usr/local/bin/zfs-auto-snapshot.sh" >> /etc/crontab
```

**Time Required:** 10 minutes
**Status:** ⬜ Not Started

---

## 🟡 MEDIUM PRIORITY (Do This Month)

### 4. Test Recovery Procedures
**Action:** Boot into GRUB recovery mode to verify it works
**Time Required:** 15 minutes
**Status:** ⬜ Not Started

### 5. Document Network Configuration
**Action:**
```bash
cp /etc/network/interfaces /root/network-backup-$(date +%Y%m%d).conf
cp /etc/pve/nodes/proxmox/network /root/pve-network-backup-$(date +%Y%m%d).conf
```
**Time Required:** 5 minutes
**Status:** ⬜ Not Started

### 6. Create Recovery USB
**Action:**
- Download latest Proxmox VE ISO
- Flash to USB drive using Etcher/dd
- Test booting from it
- Store in safe location

**Time Required:** 30 minutes
**Status:** ⬜ Not Started

### 7. Set Up ZFS Health Monitoring
**Action:**
```bash
# Install if needed
apt install mailutils

# Add health check script
cat > /usr/local/bin/zfs-health-check.sh << 'EOF'
#!/bin/bash
STATUS=$(zpool status rpool | grep -c "state: ONLINE")
if [ $STATUS -eq 0 ]; then
    echo "ZFS Pool is not ONLINE!" | mail -s "CRITICAL: ZFS Pool Issue on proxmox" root
    zpool status rpool | mail -s "ZFS Pool Status" root
fi
EOF

chmod +x /usr/local/bin/zfs-health-check.sh
echo "0 6 * * * root /usr/local/bin/zfs-health-check.sh" >> /etc/crontab
```
**Time Required:** 10 minutes
**Status:** ⬜ Not Started

---

## 🟢 LOW PRIORITY (Nice to Have)

### 8. Configure Email Alerts
**Action:** Set up proper email relay for system alerts
**Status:** ⬜ Not Started

### 9. Review and Optimize Boot Parameters
**Action:** Document custom kernel parameters and rationale
**Status:** ⬜ Not Started

### 10. Set Up Remote Backup Target
**Action:** Configure Proxmox Backup Server or remote NFS/SMB for backups
**Status:** ⬜ Not Started

---

## 📋 Verification Checklist

After completing high priority items:

- [ ] EFI partitions clean (no FAT-fs errors in dmesg)
- [ ] At least one successful backup completed
- [ ] ZFS snapshots being created daily
- [ ] Can boot into GRUB recovery mode
- [ ] Recovery documentation accessible offline

---

## 📊 Progress Tracking

| Task # | Priority | Status | Completed Date |
|--------|----------|--------|----------------|
| 1 | HIGH | ⬜ | |
| 2 | HIGH | ⬜ | |
| 3 | HIGH | ⬜ | |
| 4 | MEDIUM | ⬜ | |
| 5 | MEDIUM | ⬜ | |
| 6 | MEDIUM | ⬜ | |
| 7 | MEDIUM | ⬜ | |
| 8 | LOW | ⬜ | |
| 9 | LOW | ⬜ | |
| 10 | LOW | ⬜ | |

---

## 🎯 Recommended Order

1. **Fix EFI partition** (5 min) - Prevents potential boot issues
2. **Create manual ZFS snapshot** (1 min) - Immediate recovery point
3. **Test GRUB recovery mode** (15 min) - Verify recovery works
4. **Set up ZFS snapshot automation** (10 min) - Ongoing protection
5. **Configure VM backups** (30 min) - Critical data protection
6. **Document and test** (1 hour) - Preparation for emergencies

**Total Time for High Priority:** ~1 hour
**Total Time for All Tasks:** ~3 hours

---

## 📝 Notes

- Keep this file updated as you complete tasks
- Mark completion dates for reference
- Add any issues encountered during implementation
- Review monthly and add new items as needed

---

**Created:** 2025-11-06
**Last Updated:** 2025-11-06
**Next Review:** 2025-12-06
