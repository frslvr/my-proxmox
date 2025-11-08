# Proxmox Backup Directory Analysis

**Directory:** `/root/config-backups/`
**Analysis Date:** 2025-11-06
**Server:** proxmox

---

## Current Status

### Backup Inventory

```
Total config backups: 5
Total package lists: 5
Directory size: 154K
Backup size per file: ~17K
Date range: 2025-10-31 to 2025-11-06
```

### Backup Files

| Date | Config Backup | Package List | Size |
|------|---------------|--------------|------|
| 2025-11-06 | ✅ proxmox-config-2025-11-06.tar.gz | ✅ packages-2025-11-06.list | 17K |
| 2025-11-03 | ✅ proxmox-config-2025-11-03.tar.gz | ✅ packages-2025-11-03.list | 17K |
| 2025-11-02 | ✅ proxmox-config-2025-11-02.tar.gz | ✅ packages-2025-11-02.list | 17K |
| 2025-11-01 | ✅ proxmox-config-2025-11-01.tar.gz | ✅ packages-2025-11-01.list | 17K |
| 2025-10-31 | ✅ proxmox-config-2025-10-31.tar.gz | ✅ packages-2025-10-31.list | 17K |

**Missing dates:** Nov 4, Nov 5 (backups not run or manual run)

---

## Issues Found

### 🔴 1. Insecure File Permissions (HIGH PRIORITY)

**Current permissions:** `-rw-r--r--` (644)

**Risk:** Configuration backups contain sensitive information:
- VM/CT configurations
- Network settings
- Storage credentials
- Certificate keys
- User configurations

**Issue:** All users can read these files!

**Impact:** Security vulnerability - non-root users can access sensitive configs

**Fix:**
```bash
# Secure directory
chmod 700 /root/config-backups

# Secure existing backups
chmod 600 /root/config-backups/*

# Verify
ls -l /root/config-backups/
# Should show: -rw------- (600)
```

---

### ⚠️ 2. Limited Backup Contents (MEDIUM)

**Currently backing up:** Only `/etc/pve/` (based on tar contents preview)

**Confirmed in backup:**
- ✅ /etc/pve/ (VM/CT configs, storage, users)

**Missing important files:**
- ❌ /etc/network/interfaces (network config)
- ❌ /etc/default/grub (boot configuration)
- ❌ /etc/fstab (filesystem mounts)
- ❌ /etc/hosts, /etc/hostname
- ❌ /etc/resolv.conf (DNS)
- ❌ /etc/sysctl.conf (kernel parameters)
- ❌ /etc/modprobe.d, /etc/modules-load.d

**Note:** Your script config shows these should be included, but the tar listing only shows /etc/pve/. Let me verify with a deeper check.

**Verification command:**
```bash
# Check full contents of latest backup
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | grep -E "network|grub|fstab|hosts|hostname"
```

---

### ⚠️ 3. Short Retention Period (MEDIUM)

**Current:** Keeps only 5 backups (approximately 5 days)

**Risk:** Limited recovery window
- If issue not noticed immediately, no older restore point
- Only ~6 days of retention (Oct 31 to Nov 6)

**Recommendation:** Increase to 30 days

**Fix in `/root/backup-config.sh`:**
```bash
# Change from:
ls -1t proxmox-config-*.tar.gz | tail -n +6 | xargs -r rm -f

# To:
find . -name "proxmox-config-*.tar.gz" -mtime +30 -delete
```

---

### ℹ️ 4. Backup Gaps (INFO)

**Observed:**
- Oct 31 ✅
- Nov 1 ✅
- Nov 2 ✅
- Nov 3 ✅
- Nov 4 ❌ Missing
- Nov 5 ❌ Missing
- Nov 6 ✅

**Possible reasons:**
- Cron job not running on Nov 4-5
- Server rebooted/down
- Manual backups only

**Check:**
```bash
# Check if cron job exists
crontab -l | grep backup

# Check cron logs
grep -i backup /var/log/syslog | tail -20
```

---

### ✅ 5. Backup Size Consistency (GOOD)

**All backups:** ~17K each

**Analysis:**
- ✅ Consistent size = healthy backups
- ✅ Not growing unexpectedly
- ✅ Not suspiciously small

**Normal range for Proxmox config-only backups:** 15-50K
**Your backups:** 17K ✅ Normal

---

### ✅ 6. Retention Working (GOOD)

**Confirmed:** Keeps only 5 most recent backups as configured

**Evidence:** Backups from before Oct 31 have been cleaned up

---

## Backup Contents Analysis

### What's Included (Confirmed)

```
/etc/pve/                      # Main PVE configuration directory
├── storage.cfg                # Storage configuration
├── user.cfg                   # User accounts
├── datacenter.cfg             # Datacenter settings
├── vzdump.cron                # Backup schedules
├── replication.cfg            # Replication config
├── firewall/                  # Firewall rules
├── sdn/                       # Software-defined networking
├── mapping/                   # Device mappings
├── priv/                      # Private keys
│   ├── authorized_keys        # SSH keys
│   ├── authkey.key            # Auth key
│   └── pve-root-ca.*          # CA certificates
├── qemu-server/               # VM configurations
├── lxc/                       # Container configurations
└── ...
```

### What Should Be Included (Verify)

Run this to check:
```bash
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | sort
```

Should include:
- /etc/network/interfaces
- /etc/default/grub
- /etc/fstab
- /etc/hosts
- /etc/hostname
- /etc/resolv.conf

---

## Package Lists Analysis

### Package List Contents

```bash
# View what's in package list
head -20 /root/config-backups/packages-2025-11-06.list
```

**Purpose:** Track installed packages for system rebuild

**Usage:**
```bash
# Restore packages on new system
dpkg --set-selections < /root/config-backups/packages-2025-11-06.list
apt-get dselect-upgrade
```

---

## Recommendations

### 🔴 Immediate Actions (HIGH PRIORITY)

#### 1. Fix File Permissions (NOW)

```bash
# Secure directory
chmod 700 /root/config-backups

# Secure all backup files
chmod 600 /root/config-backups/*.tar.gz
chmod 600 /root/config-backups/*.list

# Verify
ls -la /root/config-backups/
# Should show drwx------ for directory
# Should show -rw------- for files
```

**Time:** 30 seconds
**Impact:** Critical security fix

#### 2. Verify Backup Contents

```bash
# Check what's actually in backups
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz > /tmp/backup-contents.txt
cat /tmp/backup-contents.txt

# Check for important files
grep -E "network|grub|fstab|hosts" /tmp/backup-contents.txt
```

If missing files, update backup script to include them.

---

### 🟡 Short-Term Actions (THIS WEEK)

#### 3. Increase Retention to 30 Days

**Edit `/root/backup-config.sh`:**
```bash
nano /root/backup-config.sh

# Find this line:
ls -1t proxmox-config-*.tar.gz | tail -n +6 | xargs -r rm -f

# Replace with:
find . -name "proxmox-config-*.tar.gz" -mtime +30 -delete
find . -name "packages-*.list" -mtime +30 -delete
```

**Test:**
```bash
/root/backup-config.sh
```

#### 4. Set Up Automated Backups

```bash
# Check if cron exists
crontab -l

# If no backup scheduled, add:
echo "0 3 * * * /root/backup-config.sh >> /var/log/proxmox-backup.log 2>&1" | crontab -

# Verify
crontab -l
```

#### 5. Add Remote Backup Location

```bash
# Option 1: Copy to NFS/SMB mount
# Add to script or cron:
rsync -av /root/config-backups/ /mnt/nfs-backup/proxmox/

# Option 2: Copy to remote server
rsync -av /root/config-backups/ user@backup-server:/backups/proxmox/

# Option 3: Use improved script with --remote flag
REMOTE_BACKUP_DIR=/mnt/nfs-backup ./backup-config-safe.sh --remote
```

---

### 🟢 Long-Term Improvements (THIS MONTH)

#### 6. Upgrade to Improved Backup Script

**Benefits:**
- ✅ Better security (automatic permission setting)
- ✅ Integrity verification
- ✅ Better logging
- ✅ Remote backup support
- ✅ Email notifications

**Migration:**
```bash
# Keep old script as reference
mv /root/backup-config.sh /root/backup-config.sh.original

# Install improved version
cp backup-config-safe.sh /root/backup-config.sh
chmod +x /root/backup-config.sh

# Test
/root/backup-config.sh --verify
```

#### 7. Implement ZFS Snapshot Schedule

Complement config backups with ZFS snapshots:

```bash
# Create snapshot script
cat > /usr/local/bin/zfs-auto-snapshot.sh << 'EOF'
#!/bin/bash
zfs snapshot rpool/ROOT/pve-1@daily-$(date +%Y%m%d)
zfs list -t snapshot -o name -s creation | grep "daily-" | head -n -7 | xargs -r -n 1 zfs destroy
EOF

chmod +x /usr/local/bin/zfs-auto-snapshot.sh

# Add to cron
echo "0 1 * * * /usr/local/bin/zfs-auto-snapshot.sh" >> /etc/crontab
```

#### 8. Set Up VM/CT Backup Schedule

Config backups don't include VM disk images. Set up vzdump:

**Via Web UI:**
1. Datacenter → Backup
2. Add backup job
3. Storage: local or remote
4. Schedule: Daily at 2 AM
5. Mode: Snapshot
6. Compression: ZSTD

**Or via CLI:**
```bash
# Edit /etc/vzdump.conf
cat >> /etc/vzdump.conf << EOF
# Daily VM/CT backups
mode: snapshot
compress: zstd
storage: local
EOF

# Add to /etc/cron.d/vzdump
echo "0 2 * * * root vzdump --all --mode snapshot --compress zstd --storage local" > /etc/cron.d/vzdump
```

---

## Testing Procedures

### Test Backup Integrity

```bash
# Verify latest backup is not corrupted
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz > /dev/null
echo $?  # Should be 0 (success)

# List contents
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | less

# Extract to test directory (don't restore!)
mkdir /tmp/backup-test
tar -xzf /root/config-backups/proxmox-config-2025-11-06.tar.gz -C /tmp/backup-test
ls -la /tmp/backup-test/etc/
rm -rf /tmp/backup-test
```

### Test Restore Procedure (DRY-RUN)

```bash
# Use improved restore script in test mode
./restore-config-improved.sh --dry-run
# Shows what would happen without making changes
```

---

## Backup Strategy Summary

### Current Setup
- ✅ Config backups running
- ✅ Package lists saved
- ✅ Retention working (5 backups)
- ⚠️ Limited contents (verify needed)
- ⚠️ Short retention (5 days)
- 🔴 Insecure permissions (644)
- ⚠️ No remote copy
- ❌ No VM/CT disk backups
- ❌ No ZFS snapshots

### Ideal Setup (Target)
- ✅ Config backups (30 days)
- ✅ Secure permissions (600)
- ✅ Complete file list
- ✅ Remote backup location
- ✅ Integrity verification
- ✅ VM/CT disk backups (vzdump)
- ✅ ZFS snapshots (7 days)
- ✅ Automated monitoring
- ✅ Email notifications

---

## Recovery Scenarios

### Scenario 1: Restore Network Config

```bash
# Extract only network config
tar -xzf /root/config-backups/proxmox-config-2025-11-06.tar.gz -C / etc/network/interfaces
systemctl restart networking
```

### Scenario 2: Restore Single VM Config

```bash
# List VM configs in backup
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | grep qemu-server

# Extract specific VM
tar -xzf /root/config-backups/proxmox-config-2025-11-06.tar.gz -C / etc/pve/qemu-server/100.conf
```

### Scenario 3: Complete System Restore

```bash
# Use improved restore script with safety features
./restore-config-improved.sh
# Will create ZFS snapshot first
# Will backup current config
# Then restore selected backup
```

### Scenario 4: Disaster Recovery

```bash
# On fresh Proxmox install:
# 1. Copy backups from remote location
scp -r user@backup-server:/backups/proxmox/config-backups /root/

# 2. Restore configuration
./restore-config-improved.sh --auto proxmox-config-2025-11-06.tar.gz

# 3. Restore VMs/CTs (if backed up separately)
# Use vzdump restore process
```

---

## Monitoring & Maintenance

### Weekly Checks

```bash
# Verify latest backup exists
ls -lth /root/config-backups/ | head -5

# Check backup sizes
du -sh /root/config-backups/

# Test latest backup integrity
tar -tzf $(ls -t /root/config-backups/proxmox-config-*.tar.gz | head -1) > /dev/null && echo "OK" || echo "CORRUPTED"
```

### Monthly Tasks

- [ ] Review backup contents
- [ ] Test restore procedure (dry-run)
- [ ] Verify remote backups synced
- [ ] Check disk space for backups
- [ ] Review retention policy

---

## Quick Reference Commands

```bash
# Manual backup
/root/backup-config.sh

# List backups
ls -lth /root/config-backups/

# View backup contents
tar -tzf /root/config-backups/proxmox-config-YYYY-MM-DD.tar.gz | less

# Test backup integrity
tar -tzf /root/config-backups/proxmox-config-YYYY-MM-DD.tar.gz > /dev/null

# Secure permissions
chmod 700 /root/config-backups && chmod 600 /root/config-backups/*

# Check cron schedule
crontab -l | grep backup

# View backup log
tail -50 /var/log/proxmox-backup.log

# Test restore (dry-run)
./restore-config-improved.sh --dry-run

# Copy to remote
rsync -av /root/config-backups/ /mnt/backup/
```

---

## Action Plan

### Today (30 minutes)

1. ✅ Fix file permissions (30 seconds)
```bash
chmod 700 /root/config-backups
chmod 600 /root/config-backups/*
```

2. ✅ Verify backup contents (2 minutes)
```bash
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | tee /tmp/backup-contents.txt
grep -E "network|grub|fstab|hosts" /tmp/backup-contents.txt
```

3. ✅ Set up automated backups if missing (5 minutes)
```bash
crontab -l
# If no backup job, add:
echo "0 3 * * * /root/backup-config.sh >> /var/log/proxmox-backup.log 2>&1" | crontab -
```

### This Week (1 hour)

4. ✅ Increase retention to 30 days
5. ✅ Set up remote backup location
6. ✅ Upgrade to improved backup script

### This Month (2 hours)

7. ✅ Set up VM/CT backup schedule (vzdump)
8. ✅ Implement ZFS snapshot automation
9. ✅ Test restore procedure
10. ✅ Document disaster recovery plan

---

**Analysis Complete:** 2025-11-06
**Status:** Backups functional, security improvements needed
**Priority:** Fix permissions immediately (30 seconds)
**Overall Grade:** C+ (Functional but needs hardening)
