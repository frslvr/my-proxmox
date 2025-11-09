# Proxmox Server Configuration & Instructions

**Server:** proxmox
**Branch:** `claude/analyze-proxmox-recovery-011CUsWnBa1uLALZSMfxLpQZ`
**Last Updated:** 2025-11-09
**Status:** ✅ Production Ready

---

## Current System State

### System Health: ✅ Excellent (8/10)

**Storage:**
- ZFS mirror (rpool): ONLINE, 0 errors
- 2x NVMe drives in mirror configuration
- Last scrub: 2025-10-12 (clean)

**Boot:**
- UEFI boot with GRUB 2.12
- Dual EFI partitions (both repaired and verified)
- 3 kernels available: 6.14.11-3-pve (current), 6.14.11-2-pve, 6.14.8-2-pve
- Custom recovery mode configured

**VM 102 (ws1) - Windows Server 2025:**
- NVIDIA RTX 4070 SUPER GPU passthrough ✅
- NVIDIA HD Audio passthrough ✅
- ASMedia USB 3.2 (20 Gbps) ✅
- ASMedia USB4/Thunderbolt (40 Gbps) ✅
- AMD USB 3.1 controllers (2x) ✅
- ⚠️ Note: Windows Server has limited Thunderbolt dock support (see warnings)

---

## Critical Information

### VFIO Passthrough Configuration

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

### Boot Parameters

```
root=ZFS=rpool/ROOT/pve-1
boot=zfs
amd_iommu=on
iommu=pt
pcie_aspm=off
pcie_port_pm=off
pcie_aspm.policy=performance
```

### USB Controller Map

**Preserved for Host:**
- `0d:00.0` (Bus 1, 2) - Keyboard (UHK 60 v2) ✅ KEEP ON HOST

**Passed to VM 102:**
- `77:00.0` (Bus 5, 6) - ASMedia USB 3.2 + Mouse
- `78:00.0` - ASMedia USB4/TB3 (40 Gbps)
- `79:00.3` (Bus 7, 8) - AMD USB 3.1
- `79:00.4` (Bus 9, 10) - AMD USB 3.1

---

## Important Warnings

### 🔴 Critical Issues to Address

1. **Restore Script Security**
   - `/root/restore-config.sh` is UNSAFE - lacks ZFS snapshots
   - Replace with `restore-config-improved.sh` before use

2. **Backup Permissions**
   - `/root/config-backups/` may have insecure permissions (644)
   - Should be 600 (root only)
   - Contains sensitive VM/network configs

3. **Host Mouse Control**
   - Mouse on Bus 5 (controller 77:00.0) passed to VM
   - Host can't use that mouse
   - Use SSH/network or connect different mouse

4. **Windows Server Thunderbolt Dock Limitation**
   - VM 102 running Windows Server 2025
   - Thunderbolt docks (CalDigit TS3 Plus, etc.) have limited functionality
   - Intel blocks Thunderbolt software on Windows Server editions
   - Thunderbolt Control Center not available
   - USB4 controller works, but dock device enumeration fails
   - **Workaround:** Individual USB device passthrough, or switch to Windows 11 Pro
   - See docs/SESSION-HISTORY.md Session 4 for details

---

## Recovery Procedures

### Boot to Recovery Mode

1. Reboot server
2. Press ESC at GRUB menu
3. Select "Proxmox VE (Recovery)"
4. VFIO disabled, all USB returns to host

### ZFS Snapshot Rollback

```bash
zfs list -t snapshot  # List available snapshots
zfs rollback rpool/ROOT/pve-1@snapshot-name
reboot
```

### Tailscale TPM Lockout Recovery

```bash
# If Tailscale fails with TPM lockout error:
systemctl stop tailscaled
mv /var/lib/tailscale/tailscaled.state /var/lib/tailscale/tailscaled.state.tpm-locked
systemctl start tailscaled
tailscale up  # Re-authenticate with Tailscale network
```

**When this happens:**
- Common after system crashes or power loss
- TPM dictionary attack lockout mode activated
- Tailscale cannot decrypt state file
- Re-authentication required but no data lost

### APT Repository Errors

```bash
# If apt-get update fails with 404 errors:
# Find problematic repository
ls -la /etc/apt/sources.list.d/

# Remove outdated/broken repository
find /etc/apt/sources.list.d/ -name '*repository-name*' -exec rm -v {} \;

# Update package list
apt-get update
```

### Remove VM Passthrough (Emergency)

```bash
# Boot to recovery mode first, then:
qm set 102 --delete hostpci2
qm set 102 --delete hostpci3
qm set 102 --delete hostpci4
qm set 102 --delete hostpci5
rm /etc/modprobe.d/vfio.conf
update-initramfs -u -k all
reboot
```

---

## Quick Commands

### System Health Check

```bash
# ZFS status
zpool status

# Check VFIO bindings
for dev in 02:00.0 02:00.1 77:00.0 78:00.0; do
  echo -n "$dev: "
  lspci -nnk -s $dev | grep "driver in use" | awk '{print $5}'
done

# VM status
qm status 102

# System errors
journalctl -p err -b | tail -20
```

### VM Management

```bash
qm start 102    # Start VM
qm stop 102     # Stop VM
qm status 102   # Check status
```

---

## USB4 Architecture Note

**Important:** USB4 uses "tunneling" technology:
- USB 3.x/2.0 devices on USB4 ports → Route through AMD USB 3.1 controllers (backwards compatibility)
- USB4/Thunderbolt devices → Route through USB4 controller at 40 Gbps
- Devices appearing under "AMD USB 3.10" in Windows is CORRECT behavior
- Physical ports #9 and #10 (rear I/O) are USB4 40Gbps capable

---

## Documentation

### Complete Documentation Available

For detailed information, see:

- **docs/SESSION-HISTORY.md** - Complete session history and detailed findings
- **docs/QUICK-REFERENCE.md** - Essential commands and procedures
- **PROXMOX-RECOVERY-ANALYSIS.md** - Recovery mode documentation
- **VM102-USB4-PASSTHROUGH-FINAL.md** - Passthrough configuration guide
- **USB-CONTROLLER-REFERENCE.md** - USB controller mapping

### Key Scripts

- `restore-config-improved.sh` - Safe restore with ZFS snapshots
- `backup-config-safe.sh` - Enhanced backup script
- `fix-backup-permissions.sh` - Security fix for backups
- `check-passthrough-full.sh` - Passthrough diagnostics

---

## Outstanding Tasks

### Priority 1 - Critical (Do Soon)

1. Fix backup permissions: `chmod 700 /root/config-backups && chmod 600 /root/config-backups/*`
2. Replace unsafe restore script with improved version
3. Set up automated VM/CT backups (vzdump)

### Priority 2 - Important (This Month)

4. Increase backup retention from 5 to 30 days
5. Configure ZFS snapshot automation
6. Set up remote backup location
7. Test recovery procedures monthly

---

## Notes for Claude

When working on this system:

1. **Always create ZFS snapshots before major changes**
2. **Never pass USB controller 0d:00.0** (host keyboard)
3. **Recovery mode is available** via GRUB if passthrough breaks
4. **USB4 tunneling is normal** - devices on AMD controllers is expected
5. **Check IOMMU groups** before passing devices
6. **Test changes in recovery mode first** when possible

---

**Repository Structure:**
```
test-git/
├── CLAUDE.md                    # This file (current state)
├── docs/
│   ├── SESSION-HISTORY.md       # Detailed session history
│   └── QUICK-REFERENCE.md       # Essential commands
├── *.md                         # Analysis documents
└── *.sh                         # Utility scripts
```

**For complete session history and detailed technical findings, see `docs/SESSION-HISTORY.md`**
