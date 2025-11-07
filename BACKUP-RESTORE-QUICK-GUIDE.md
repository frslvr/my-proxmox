# Proxmox Backup & Restore - Quick Guide

**Safe Scripts for Configuration Management**

---

## 🚨 CRITICAL WARNING

**Your original `/root/restore-config.sh` is UNSAFE!**
- ❌ No ZFS snapshot (no rollback)
- ❌ No current config backup
- ❌ Could cause data loss
- ❌ Could lock you out

**DO NOT USE IT!**

---

## ✅ Safe Scripts

### 1. Backup Script: `backup-config-safe.sh`

**What it backs up:**
- /etc/pve (VM/CT configs, storage, users)
- /etc/network (network configuration)
- /etc/default/grub (boot config)
- /etc/fstab, /etc/hosts, /etc/hostname
- /etc/vzdump.conf (backup settings)
- /etc/cron.d (scheduled tasks)
- System configuration files

**What it does NOT backup:**
- VM/CT disk images (use `vzdump` for that)
- Large data files
- Temporary files

---

## 📝 Usage

### Daily Automatic Backup

```bash
# Copy script to server
scp backup-config-safe.sh root@proxmox:/root/
ssh root@proxmox chmod +x /root/backup-config-safe.sh

# Add to crontab (runs daily at 3 AM)
echo "0 3 * * * /root/backup-config-safe.sh >> /var/log/proxmox-backup.log 2>&1" | crontab -
```

### Manual Backup

```bash
# Simple backup
./backup-config-safe.sh

# Backup + verify integrity
./backup-config-safe.sh --verify

# Backup + copy to remote NFS/SMB
REMOTE_BACKUP_DIR=/mnt/nfs-backup ./backup-config-safe.sh --remote
```

---

### 2. Restore Script: `restore-config-improved.sh`

**Safety features:**
- ✅ Creates ZFS snapshot before restore (rollback capability)
- ✅ Backs up current config before overwrite
- ✅ Verifies backup file integrity
- ✅ Warns about network config changes
- ✅ Checks for cluster membership
- ✅ Full logging for audit trail
- ✅ Dry-run mode for testing

---

## 🔄 Restore Process

### Step 1: Test First (DRY-RUN)

**ALWAYS run dry-run first!**

```bash
# Copy script to server
scp restore-config-improved.sh root@proxmox:/root/
ssh root@proxmox chmod +x /root/restore-config-improved.sh

# Test restore (no changes made)
./restore-config-improved.sh --dry-run
```

Output:
```
ℹ️  DRY-RUN MODE - No changes will be made
ℹ️  Would create ZFS snapshot: rpool/ROOT/pve-1@pre-restore-20251106
ℹ️  Would backup current config
ℹ️  Would stop services: pvedaemon pveproxy pve-cluster
ℹ️  Would restore from: proxmox-config-2025-11-06.tar.gz
```

### Step 2: Real Restore (Interactive)

```bash
./restore-config-improved.sh
```

Interactive prompts:
1. Select backup from list
2. Review backup contents
3. Confirm restore
4. Creates ZFS snapshot automatically
5. Backs up current config
6. Final confirmation
7. Performs restore
8. Shows rollback instructions

### Step 3: If Problems - Rollback

```bash
# Rollback to pre-restore state
zfs rollback rpool/ROOT/pve-1@pre-restore-TIMESTAMP
reboot

# Or restore the current config backup
cd /root/config-backups
tar -xzf pre-restore-backup-TIMESTAMP.tar.gz -C /
reboot
```

---

## 🎯 Common Scenarios

### Scenario 1: Accidental Configuration Change

```bash
# 1. Run backup immediately to save current state
./backup-config-safe.sh

# 2. Restore from before the change
./restore-config-improved.sh
# Select backup from yesterday
```

### Scenario 2: Testing Configuration Changes

```bash
# 1. Create backup before change
./backup-config-safe.sh
# Creates: proxmox-config-20251106-190000.tar.gz

# 2. Make your configuration changes
nano /etc/network/interfaces
# ... make changes ...

# 3. Test changes
systemctl restart networking

# 4. If problems, restore immediately
./restore-config-improved.sh
# Select: proxmox-config-20251106-190000.tar.gz
```

### Scenario 3: System Upgrade Protection

```bash
# Before upgrade
./backup-config-safe.sh --verify

# Perform Proxmox upgrade
apt update && apt dist-upgrade

# If issues after upgrade
./restore-config-improved.sh
# Select backup from before upgrade
```

### Scenario 4: Disaster Recovery

```bash
# Regular automated backups running
# Copy backups to remote location:
rsync -av /root/config-backups/ user@backup-server:/backups/proxmox/

# After disaster (fresh Proxmox install):
# 1. Copy backup to new system
scp user@backup-server:/backups/proxmox/proxmox-config-LATEST.tar.gz /root/

# 2. Place in backup directory
mkdir -p /root/config-backups
mv proxmox-config-LATEST.tar.gz /root/config-backups/

# 3. Restore
./restore-config-improved.sh --auto proxmox-config-LATEST.tar.gz
```

---

## 📊 Backup Management

### View Backups

```bash
# List all backups
ls -lh /root/config-backups/

# View backup contents without restoring
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | less

# Check backup size and date
ls -lth /root/config-backups/ | head -10
```

### Delete Old Backups

```bash
# Automatic: Configure retention
RETENTION_DAYS=7 ./backup-config-safe.sh
# Keeps only last 7 days

# Manual: Delete specific backup
rm /root/config-backups/proxmox-config-old.tar.gz

# Delete all backups older than 60 days
find /root/config-backups/ -name "*.tar.gz" -mtime +60 -delete
```

### Copy to Remote Storage

```bash
# One-time copy
rsync -av /root/config-backups/ /mnt/nfs-backup/

# Or use built-in remote copy
REMOTE_BACKUP_DIR=/mnt/nfs-backup ./backup-config-safe.sh --remote
```

---

## 🛡️ Best Practices

### 1. Regular Automated Backups

```bash
# Daily at 3 AM
0 3 * * * /root/backup-config-safe.sh >> /var/log/proxmox-backup.log 2>&1

# Weekly verification
0 4 * * 0 /root/backup-config-safe.sh --verify >> /var/log/proxmox-backup.log 2>&1
```

### 2. Before Major Changes

**ALWAYS backup before:**
- System upgrades
- Network configuration changes
- Storage configuration changes
- Adding/removing cluster nodes
- GRUB modifications

```bash
./backup-config-safe.sh --verify
```

### 3. Test Restores Quarterly

```bash
# Every 3 months, test restore process
./restore-config-improved.sh --dry-run
# Verify you understand the process
```

### 4. Multiple Backup Locations

```bash
# Local + Remote
./backup-config-safe.sh --remote

# Or manual copy
rsync -av /root/config-backups/ /mnt/nfs-backup/
```

### 5. Monitor Backup Status

```bash
# Check recent backups
ls -lth /root/config-backups/ | head -5

# Check backup log
tail -50 /var/log/proxmox-backup.log

# Check disk space
df -h /root
```

---

## ⚠️ Important Notes

### What Backups Include
- ✅ VM/CT configurations (not disk images)
- ✅ Network settings
- ✅ Storage configurations
- ✅ User permissions
- ✅ Scheduled tasks
- ✅ System settings

### What Backups DON'T Include
- ❌ VM/CT disk images (use `vzdump`)
- ❌ ISO images
- ❌ Container templates
- ❌ Large data files

### Restore Warnings

**Network Configuration:**
- Restoring network config can change IP addresses
- Could lose network connectivity
- Always have console access (IPMI/physical) when restoring network

**Cluster Nodes:**
- Don't restore cluster config to standalone server
- Don't restore standalone config to cluster node
- Could cause cluster split-brain

**Different Hardware:**
- Don't restore to different hardware without review
- Network interface names may differ (eth0 vs ens18)
- Storage paths may differ

---

## 📞 Emergency Procedures

### Lost Network Access After Restore

```bash
# From physical console or IPMI:

# Option 1: Rollback
zfs rollback rpool/ROOT/pve-1@pre-restore-TIMESTAMP
reboot

# Option 2: Restore current config backup
cd /root/config-backups
tar -xzf pre-restore-backup-TIMESTAMP.tar.gz -C /
systemctl restart networking
```

### Services Won't Start After Restore

```bash
# Check what's wrong
systemctl status pve-cluster
journalctl -xe

# Rollback
zfs rollback rpool/ROOT/pve-1@pre-restore-TIMESTAMP
reboot
```

### Backup File Corrupted

```bash
# Verify integrity
tar -tzf /root/config-backups/proxmox-config-SUSPICIOUS.tar.gz

# If corrupted, use older backup
ls -lth /root/config-backups/
# Select older backup that's verified working
```

---

## 📁 File Locations

```
/root/backup-config-safe.sh           # Backup script
/root/restore-config-improved.sh      # Restore script
/root/config-backups/                 # Backup storage
├── proxmox-config-*.tar.gz          # Backup files
├── manifest-*.txt                   # Backup manifests
└── pre-restore-backup-*.tar.gz      # Pre-restore safety backups

/var/log/proxmox-backup.log          # Backup log
/var/log/proxmox-restore-*.log       # Restore logs
```

---

## 🔍 Verification

### Test Backup Integrity

```bash
# Verify a backup is valid
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz > /dev/null
echo $?  # Should be 0 (success)

# Count files
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | wc -l

# View contents
tar -tzf /root/config-backups/proxmox-config-2025-11-06.tar.gz | less
```

### Test Restore Process

```bash
# Dry-run (safe, no changes)
./restore-config-improved.sh --dry-run

# Check logs
tail -100 /var/log/proxmox-restore-*.log
```

---

## 🎓 Additional Resources

- **Full analysis:** See `RESTORE-SCRIPT-ANALYSIS.md`
- **Recovery guide:** See `PROXMOX-RECOVERY-ANALYSIS.md`
- **Quick reference:** See `RECOVERY-QUICK-REFERENCE.md`
- **Action items:** See `ACTION-ITEMS.md`

---

## ✅ Migration from Old Script

```bash
# 1. Backup the old script (DON'T delete yet)
mv /root/restore-config.sh /root/restore-config.sh.OLD.UNSAFE

# 2. Install new scripts
cp backup-config-safe.sh /root/
cp restore-config-improved.sh /root/
chmod +x /root/backup-config-safe.sh
chmod +x /root/restore-config-improved.sh

# 3. Create initial backup with new script
/root/backup-config-safe.sh --verify

# 4. Test dry-run
/root/restore-config-improved.sh --dry-run

# 5. Set up automation
echo "0 3 * * * /root/backup-config-safe.sh >> /var/log/proxmox-backup.log 2>&1" | crontab -

# 6. Verify cron
crontab -l

# 7. After confirming everything works, delete old script
rm /root/restore-config.sh.OLD.UNSAFE
```

---

**Quick Start:**
1. Install scripts ✅
2. Run first backup: `./backup-config-safe.sh --verify`
3. Test restore: `./restore-config-improved.sh --dry-run`
4. Set up daily backup cron
5. Keep backups in multiple locations

**Remember:** Always backup before making changes!

---

**Last Updated:** 2025-11-06
