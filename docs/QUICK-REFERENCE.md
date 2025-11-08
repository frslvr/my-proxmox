# Proxmox Quick Reference Guide

**Server:** proxmox
**Last Updated:** 2025-11-08

---

## Emergency Recovery

### Boot to Recovery Mode

```bash
# At GRUB menu (press ESC at boot):
# Select: "Proxmox VE (Recovery)"
# Result: VFIO disabled, all USB returns to host
```

### ZFS Emergency Commands

```bash
# List snapshots
zfs list -t snapshot

# Rollback to snapshot
zfs rollback rpool/ROOT/pve-1@snapshot-name

# Check pool status
zpool status

# Scrub pool
zpool scrub rpool

# Import pool (from rescue mode)
zpool import -f rpool
```

---

## System Health Checks

### Quick Status

```bash
# ZFS pool health
zpool status

# Check for errors in system log
journalctl -p err -b | tail -20

# Check EFI partitions
dmesg | grep -i fat

# List kernels
ls -lh /boot/vmlinuz-*

# Check backup status
ls -lth /root/config-backups/ | head -5
```

### VFIO Passthrough Status

```bash
# Check which driver is bound to devices
for dev in 02:00.0 02:00.1 77:00.0 78:00.0 79:00.3 79:00.4; do
  echo -n "$dev: "
  lspci -nnk -s $dev | grep "driver in use" | awk '{print $5}'
done

# Expected output:
# 02:00.0: vfio-pci  (GPU)
# 02:00.1: vfio-pci  (Audio)
# 77:00.0: vfio-pci  (ASMedia USB 3.2)
# 78:00.0: vfio-pci  (ASMedia USB4)
# 79:00.3: vfio-pci  (AMD USB 3.1)
# 79:00.4: vfio-pci  (AMD USB 3.1)

# Check host keyboard is still available
lspci -nnk -s 0d:00.0 | grep "driver in use"
# Expected: driver in use: xhci_hcd
```

---

## VM Management

### VM 102 (ws1) Commands

```bash
# Start VM
qm start 102

# Stop VM (graceful shutdown)
qm shutdown 102

# Force stop VM
qm stop 102

# Restart VM
qm shutdown 102 && sleep 3 && qm start 102

# Check VM status
qm status 102

# View VM configuration
cat /etc/pve/qemu-server/102.conf

# Monitor VM logs
journalctl -u qemu-server@102 -f

# Check recent VM errors
journalctl -u qemu-server@102 -n 50 --no-pager
```

---

## USB Controller Reference

### Host Keyboard (DO NOT PASS)

```
Controller: 0d:00.0
Buses: 1, 2
Device: Keyboard (UHK 60 v2)
Status: KEEP ON HOST ⚠️
```

### Passed to VM 102

```
77:00.0 (ASMedia USB 3.2 20Gbps)
  - Buses: 5, 6
  - Mouse is on this controller ⚠️
  - Status: Passed to VM

78:00.0 (ASMedia USB4/TB3 40Gbps)
  - USB4 Host Router
  - Physical ports: #9 and #10 (rear I/O)
  - Status: Passed to VM ✅

79:00.3 (AMD USB 3.1)
  - Buses: 7, 8
  - Status: Passed to VM

79:00.4 (AMD USB 3.1)
  - Buses: 9, 10
  - Status: Passed to VM
```

### USB Diagnostics

```bash
# List all USB devices
lsusb

# USB device tree
lsusb -t

# Find which controller owns a specific bus
readlink -f /sys/bus/usb/devices/usb1

# List devices on specific bus
lsusb -s 1:
```

---

## Backup & Restore

### Manual Backup

```bash
# Run backup script
/root/backup-config.sh

# Or use improved version
/root/backup-config-safe.sh

# List backups
ls -lh /root/config-backups/

# View backup contents
tar -tzf /root/config-backups/proxmox-config-YYYY-MM-DD.tar.gz
```

### Restore Configuration

```bash
# ⚠️ IMPORTANT: Use improved script only
# DO NOT use /root/restore-config.sh - it's unsafe!

# Use improved restore script
/root/restore-config-improved.sh

# Or manual restore with snapshot
zfs snapshot rpool/ROOT/pve-1@before-restore
tar -xzf /root/config-backups/proxmox-config-YYYY-MM-DD.tar.gz -C /
systemctl restart pveproxy pvedaemon pve-cluster
```

### Fix Backup Permissions (CRITICAL)

```bash
# Fix permissions on backup directory
chmod 700 /root/config-backups
chmod 600 /root/config-backups/*

# Verify
ls -la /root/config-backups/
# Should show: drwx------ (700) for directory
# Should show: -rw------- (600) for files
```

---

## VFIO Configuration

### Current Configuration

**File:** `/etc/modprobe.d/vfio.conf`
```bash
options vfio-pci ids=10de:2783,10de:22bc,1b21:2426,1b21:2425,1022:15b6,1022:15b7
```

**Device IDs:**
- `10de:2783` = NVIDIA RTX 4070 SUPER
- `10de:22bc` = NVIDIA HD Audio
- `1b21:2426` = ASMedia USB 3.2 (20 Gbps)
- `1b21:2425` = ASMedia USB4/TB3 (40 Gbps)
- `1022:15b6` = AMD USB 3.1 (79:00.3)
- `1022:15b7` = AMD USB 3.1 (79:00.4)

### Modify VFIO Configuration

```bash
# Edit VFIO config
nano /etc/modprobe.d/vfio.conf

# After changes, rebuild initramfs
update-initramfs -u -k all

# Reboot to apply
reboot
```

### Remove Passthrough (Emergency)

```bash
# Boot to recovery mode first!
# Then run:

# Remove VM passthrough devices
qm set 102 --delete hostpci2
qm set 102 --delete hostpci3
qm set 102 --delete hostpci4
qm set 102 --delete hostpci5

# Remove VFIO configuration
rm /etc/modprobe.d/vfio.conf

# Rebuild initramfs
update-initramfs -u -k all

# Reboot
reboot
```

---

## Network & Remote Access

### Web UI

```
https://proxmox-ip:8006
```

### SSH Access

```bash
# From another machine
ssh root@proxmox-ip

# Check if SSH is running
systemctl status sshd
```

### Check Network Status

```bash
# Show IP addresses
ip addr show

# Show network interfaces
ip link show

# Test connectivity
ping -c 4 8.8.8.8

# Check DNS
nslookup google.com
```

---

## Common Issues & Solutions

### VM Won't Start - VFIO Error

```bash
# Check driver bindings
lspci -nnk -s 77:00.0
lspci -nnk -s 78:00.0

# Verify VFIO config
cat /etc/modprobe.d/vfio.conf

# Rebuild initramfs
update-initramfs -u -k all

# Reboot
reboot
```

### Lost Host Keyboard/Mouse

**Option 1: Use Recovery Mode**
```bash
# Reboot and select "Proxmox VE (Recovery)" from GRUB menu
# All USB returns to host
```

**Option 2: Use Network Access**
```bash
# SSH from another computer
ssh root@proxmox-ip

# Or use Web UI
https://proxmox-ip:8006
```

**Option 3: Connect Different USB Device**
```bash
# Plug keyboard/mouse into:
# - Front panel USB ports
# - Any port on Bus 1, 3, 4, 11, or 12
# - Avoid Bus 5, 6, 7, 8, 9, 10 (passed to VM)
```

### GPU Not Showing in Windows

```bash
# On Proxmox host:
# Check GPU is bound to vfio-pci
lspci -nnk -s 02:00.0 | grep "driver in use"
# Expected: vfio-pci

# Check VM config
grep hostpci0 /etc/pve/qemu-server/102.conf
# Expected: hostpci0: 0000:02:00.0,pcie=1,x-vga=1

# Check VM logs
journalctl -u qemu-server@102 -n 50
```

### USB4 Not Working in Windows

**Expected Behavior:**
- USB 3.x devices on USB4 ports appear under "AMD USB 3.10" controllers
- This is CORRECT - USB4 tunneling routes through AMD controllers
- USB4 Host Router should show "Status: OK" in Device Manager

**If USB4 Host Router shows error:**
1. Install ASMedia USB4 driver (version 1.0.0.0)
2. Source: station-drivers.com
3. Reboot Windows VM
4. Verify "USB4 Host Router - Status: OK"

---

## Maintenance Tasks

### Monthly Checklist

```bash
# 1. Check ZFS pool health
zpool status

# 2. Run ZFS scrub if needed
zpool scrub rpool

# 3. Check system logs for errors
journalctl -p err --since "7 days ago"

# 4. Verify backups exist
ls -lth /root/config-backups/ | head -10

# 5. Check disk space
df -h

# 6. Update packages (if needed)
apt update
apt list --upgradable

# 7. Test recovery mode boot
# (Reboot and verify recovery mode accessible)
```

### Backup Retention

```bash
# Current: 5 days retention
# Recommended: 30 days retention

# To change, edit backup script:
nano /root/backup-config.sh
# Change: find /root/config-backups -name "*.tar.gz" -mtime +5 -delete
# To:     find /root/config-backups -name "*.tar.gz" -mtime +30 -delete
```

---

## Important Notes

### USB4 Architecture

**Remember:** USB4 uses tunneling:
- USB 3.x devices → Route through AMD USB 3.1 controllers (backwards compatibility)
- USB4/Thunderbolt devices → Route through USB4 controller at 40 Gbps
- Devices showing under "AMD USB 3.10" is CORRECT behavior
- Physical ports #9 and #10 (rear I/O) are USB4 40Gbps ports

### ZFS Snapshots

```bash
# Create snapshot before major changes
zfs snapshot rpool/ROOT/pve-1@before-change-description

# List snapshots
zfs list -t snapshot

# Rollback if needed
zfs rollback rpool/ROOT/pve-1@before-change-description
```

### Boot Parameters

Current kernel parameters:
```
root=ZFS=rpool/ROOT/pve-1
boot=zfs
amd_iommu=on
iommu=pt
pcie_aspm=off
pcie_port_pm=off
pcie_aspm.policy=performance
```

---

## Contact & Documentation

**Full Documentation:**
- Session History: `docs/SESSION-HISTORY.md`
- Current State: `CLAUDE.md` (this is read by Claude)
- Recovery Guide: `PROXMOX-RECOVERY-ANALYSIS.md`
- Passthrough Guide: `VM102-USB4-PASSTHROUGH-FINAL.md`
- USB Map: `USB-CONTROLLER-REFERENCE.md`

**Useful Scripts:**
- `restore-config-improved.sh` - Safe restore with snapshots
- `backup-config-safe.sh` - Enhanced backup
- `fix-backup-permissions.sh` - Fix backup security
- `check-passthrough-full.sh` - Diagnostic tool

---

**Quick Help:**
- Recovery Mode: Reboot → ESC → Select "Proxmox VE (Recovery)"
- Web UI: https://proxmox-ip:8006
- SSH: ssh root@proxmox-ip
- Emergency: Boot from Proxmox ISO in rescue mode
