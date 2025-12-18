#!/bin/bash
# Proxmox Recovery Mode Information Gathering Script
# Run these commands on your Proxmox server and provide the output

echo "==============================================="
echo "PROXMOX RECOVERY MODE ANALYSIS - INFO GATHERING"
echo "==============================================="
echo ""

echo "=== 1. SYSTEM INFORMATION ==="
echo "--- Proxmox Version ---"
pveversion -v
echo ""

echo "--- System Boot Mode (UEFI/BIOS) ---"
[ -d /sys/firmware/efi ] && echo "UEFI Boot" || echo "Legacy BIOS Boot"
echo ""

echo "=== 2. GRUB CONFIGURATION ==="
echo "--- GRUB Default Settings ---"
cat /etc/default/grub
echo ""

echo "--- GRUB Menu Entries ---"
grep menuentry /boot/grub/grub.cfg | head -20
echo ""

echo "=== 3. KERNEL AND BOOT PARAMETERS ==="
echo "--- Current Boot Parameters ---"
cat /proc/cmdline
echo ""

echo "--- Installed Kernels ---"
dpkg -l | grep -E 'pve-kernel|linux-image'
echo ""

echo "--- Available Kernels in /boot ---"
ls -lh /boot/vmlinuz-* /boot/initrd.img-* 2>/dev/null
echo ""

echo "=== 4. SYSTEMD RECOVERY TARGETS ==="
echo "--- Available Systemd Targets ---"
systemctl list-units --type=target --all | grep -E 'rescue|emergency|multi-user|graphical'
echo ""

echo "--- Default Systemd Target ---"
systemctl get-default
echo ""

echo "=== 5. ZFS STATUS (if applicable) ==="
echo "--- ZFS Pool Status ---"
zpool status 2>/dev/null || echo "ZFS not in use or not available"
echo ""

echo "--- ZFS Snapshots ---"
zfs list -t snapshot 2>/dev/null | head -20 || echo "No ZFS snapshots or ZFS not available"
echo ""

echo "=== 6. LVM CONFIGURATION ==="
echo "--- LVM Physical Volumes ---"
pvdisplay 2>/dev/null || echo "No LVM PVs found"
echo ""

echo "--- LVM Volume Groups ---"
vgdisplay 2>/dev/null || echo "No LVM VGs found"
echo ""

echo "--- LVM Logical Volumes ---"
lvdisplay 2>/dev/null || echo "No LVM LVs found"
echo ""

echo "=== 7. FILESYSTEM AND MOUNT INFORMATION ==="
echo "--- Current Mounts ---"
mount | grep -v tmpfs
echo ""

echo "--- /etc/fstab ---"
cat /etc/fstab
echo ""

echo "--- Disk Usage ---"
df -h
echo ""

echo "=== 8. BACKUP CONFIGURATION ==="
echo "--- Proxmox Backup Jobs ---"
cat /etc/pve/jobs.cfg 2>/dev/null || echo "No backup jobs configured"
echo ""

echo "--- vzdump.conf ---"
cat /etc/vzdump.conf 2>/dev/null || echo "No vzdump.conf found"
echo ""

echo "=== 9. CLUSTER INFORMATION ==="
echo "--- Cluster Status ---"
pvecm status 2>/dev/null || echo "Not part of a cluster or cluster service not running"
echo ""

echo "--- Cluster Configuration ---"
cat /etc/pve/corosync.conf 2>/dev/null || echo "No cluster configuration found"
echo ""

echo "=== 10. RECENT SYSTEM LOGS ==="
echo "--- Recent Boot Logs ---"
journalctl -b -0 | tail -100
echo ""

echo "--- System Errors (last 50) ---"
journalctl -p err -n 50
echo ""

echo "--- Proxmox Service Status ---"
systemctl status pve-cluster pvedaemon pveproxy pvestatd -l --no-pager
echo ""

echo "=== 11. RECOVERY/RESCUE TOOLS AVAILABLE ==="
echo "--- Installed Recovery Tools ---"
dpkg -l | grep -E 'grub-rescue|systemd-boot|recovery'
echo ""

echo "=== 12. INITRAMFS INFORMATION ==="
echo "--- Initramfs Contents (sample) ---"
lsinitramfs /boot/initrd.img-$(uname -r) 2>/dev/null | head -50 || echo "Cannot list initramfs"
echo ""

echo "==============================================="
echo "END OF INFORMATION GATHERING"
echo "==============================================="
