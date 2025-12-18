# Proxmox VM GPU + USB4 Passthrough Configuration

**Status:** ✅ Production-Ready
**Last Updated:** 2025-11-08
**Server:** Proxmox VE on ASUS ProArt X870E-CREATOR WIFI
**VM:** Windows Server 2025 (VM 102)

---

## Quick Start

**If you just need the solution:**
1. Read [`docs/FINAL-SOLUTION-SUMMARY.md`](docs/FINAL-SOLUTION-SUMMARY.md) - Complete solution guide
2. Read [`docs/usb4/USB4-SUCCESS.md`](docs/usb4/USB4-SUCCESS.md) - USB4 architecture explanation

**If you need emergency recovery:**
1. Read [`docs/recovery/RECOVERY-QUICK-REFERENCE.md`](docs/recovery/RECOVERY-QUICK-REFERENCE.md) - Emergency procedures

---

## What This Repository Contains

This repository documents a complete, successful configuration of:
- ✅ NVIDIA GPU passthrough (RTX 4070 SUPER)
- ✅ USB4 40 Gbps passthrough (ASMedia ASM4242)
- ✅ Multiple USB controller passthrough
- ✅ Proxmox recovery mode configuration
- ✅ Backup/restore script security improvements

### Key Achievement

**USB4 40 Gbps passthrough working in Proxmox VM** - Previously thought to be unreliable, now proven production-ready with proper driver and understanding of USB4 tunneling architecture.

---

## Repository Structure

```
.
├── README.md                          # This file
├── claude.md                          # Complete session log (detailed history)
│
├── docs/                              # Documentation
│   ├── FINAL-SOLUTION-SUMMARY.md      # ⭐ START HERE - Complete solution
│   │
│   ├── usb4/                          # USB4 Passthrough Documentation
│   │   ├── USB4-SUCCESS.md            # Success story & architecture
│   │   ├── QUICK-START-USB4.txt       # Quick start guide
│   │   ├── usb4-commands.txt          # PowerShell command reference
│   │   └── test-usb-port-commands.txt # Port testing commands
│   │
│   ├── recovery/                      # Recovery & System Repair
│   │   ├── RECOVERY-QUICK-REFERENCE.md      # ⚠️ Emergency procedures
│   │   ├── PROXMOX-RECOVERY-ANALYSIS.md     # Complete recovery analysis
│   │   ├── RECOVERY-MODE-GUIDE.md           # Recovery mode guide
│   │   ├── EFI-REPAIR-SUMMARY.md            # EFI partition repair
│   │   └── CUSTOM-RECOVERY-ENTRY-FIX.md     # GRUB recovery fix
│   │
│   └── backup/                        # Backup & Restore
│       ├── BACKUP-DIRECTORY-ANALYSIS.md     # Backup security analysis
│       ├── BACKUP-SCRIPT-ANALYSIS.md        # Backup script review
│       ├── RESTORE-SCRIPT-ANALYSIS.md       # Restore script safety
│       └── BACKUP-RESTORE-QUICK-GUIDE.md    # Quick guide
│
├── scripts/                           # Scripts
│   ├── windows/                       # Windows PowerShell Scripts
│   │   ├── check-usb4-windows.ps1           # Verify USB4 status
│   │   ├── monitor-new-usb-devices.ps1      # Find USB4 ports (recommended)
│   │   └── identify-usb4-port.ps1           # Port identification
│   │
│   ├── proxmox/                       # Proxmox Host Scripts
│   │   ├── restore-config-improved.sh       # Safe restore script
│   │   ├── backup-config-safe.sh            # Enhanced backup script
│   │   ├── fix-backup-permissions.sh        # Security fix
│   │   └── fix-custom-recovery-entry.sh     # GRUB recovery fix
│   │
│   └── diagnostic/                    # Diagnostic Tools
│       ├── find-usb4-in-tree.ps1            # USB4 device tree analysis
│       ├── check-proxmox-controllers.sh     # Controller verification
│       └── proxmox-recovery-info-commands.sh # System info gathering
│
└── archive/                           # Archived/Historical Files
    ├── ACTION-ITEMS.md                      # Completed task tracking
    └── quick-commands.txt                   # Historical reference
```

---

## Hardware Configuration

### Motherboard
**ASUS ProArt X870E-CREATOR WIFI**
- AMD X870E chipset with Ryzen 9000 series
- 2x USB4 40Gbps Type-C ports (ASMedia ASM4242)
- Multiple AMD USB 3.1 controllers

### VM 102 - Windows Server 2025 Workstation

**Passthrough Devices (All Working):**
| Device | PCI Address | Speed | Status |
|--------|-------------|-------|--------|
| NVIDIA RTX 4070 SUPER | 02:00.0 | - | ✅ |
| NVIDIA HD Audio | 02:00.1 | - | ✅ |
| ASMedia USB 3.2 | 77:00.0 | 20 Gbps | ✅ |
| ASMedia USB4 | 78:00.0 | 40 Gbps | ✅ |
| AMD USB 3.1 | 79:00.3 | 10 Gbps | ✅ |
| AMD USB 3.1 | 79:00.4 | 10 Gbps | ✅ |

**Physical USB4 Ports:** #9 and #10 on rear I/O (USB Type-C)

---

## Quick Solutions

### I need to configure USB4 passthrough
→ Read [`docs/FINAL-SOLUTION-SUMMARY.md`](docs/FINAL-SOLUTION-SUMMARY.md)

### USB4 shows Code 28/31 in Windows Device Manager
→ Install ASMedia USB4 driver v1.0.0.0 (see USB4-SUCCESS.md)

### Devices appear under AMD controllers, not ASMedia
→ **This is correct!** USB4 uses tunneling (see USB4-SUCCESS.md section on architecture)

### I need to find which physical port is USB4
→ Run `scripts/windows/monitor-new-usb-devices.ps1`

### System won't boot after passthrough
→ Use GRUB recovery mode (see docs/recovery/RECOVERY-QUICK-REFERENCE.md)

### I want to set up remote server with long cable
→ See FINAL-SOLUTION-SUMMARY.md section "User's Use Case"

---

## Key Insights

### USB4 Tunneling Architecture

**Critical Understanding:** USB4 is a ROUTER, not a direct USB controller.

**How it works:**
- USB 3.x devices → Tunneled through AMD controllers (backwards compatibility)
- USB4/Thunderbolt devices → Direct 40 Gbps handling
- DisplayPort → Tunneled for video output

**Why this matters:** Devices appearing under AMD controllers in Device Manager is **CORRECT behavior**, not a failure. Only USB4-native devices bypass tunneling.

### What We Learned

Initial research suggested USB4 passthrough was unreliable in VMs. **This was incorrect.**

**USB4 passthrough works perfectly when you:**
1. Install the correct ASMedia USB4 driver
2. Understand USB4 tunneling architecture
3. Recognize backwards compatibility routing is intentional

---

## Use Cases

### Remote Server Setup (5m Cable)

**Requirement:** Proxmox server in separate room, 5m cable to desk

**Solution:**
- Single USB4/Thunderbolt 4 active cable (5m)
- Connect to Port #9 or #10
- USB4/Thunderbolt dock at desk
- One cable provides: 40 Gbps data + 8K display + USB devices + power

**Recommended Cables:**
- Cable Matters Thunderbolt 4 (5m) - $60-80
- CalDigit Thunderbolt 4 (5m) - $70-90
- Sabrent Thunderbolt 4 (5m) - $50-70

---

## Troubleshooting

### Common Issues

**Problem:** USB4 Host Router shows Code 31
**Solution:** Install ASMedia USB4 driver v1.0.0.0 from station-drivers.com

**Problem:** Can't find USB4 ports
**Solution:** Ports #9 and #10 on rear I/O (USB Type-C)

**Problem:** Devices show under AMD controllers
**Solution:** This is correct! USB4 tunneling for backwards compatibility

**Problem:** VM won't start after passthrough
**Solution:** Boot to GRUB recovery mode, remove passthrough config

### Recovery Procedures

**Quick Recovery:**
```bash
# Boot to "Proxmox VE (Recovery)" in GRUB menu
# All USB controllers return to host
# VFIO drivers disabled
```

**Remove Passthrough:**
```bash
qm set 102 --delete hostpci2
qm set 102 --delete hostpci3
qm set 102 --delete hostpci4
qm set 102 --delete hostpci5
rm /etc/modprobe.d/vfio.conf
update-initramfs -u -k all
reboot
```

---

## Documentation History

### Session 1 (2025-11-06)
- Complete recovery mode analysis
- EFI partition repair
- Backup/restore script security review
- System health assessment

### Session 2 (2025-11-07 to 2025-11-08)
- GPU passthrough configuration
- USB4 passthrough setup
- USB4 driver Code 31 resolution
- USB4 tunneling architecture discovery
- Physical port mapping analysis
- Complete success confirmation

---

## Credits

**Solution Sources:**
- Reddit: https://www.reddit.com/r/buildapc/comments/1i68muo/weird_missing_driver_in_device_manager/
- ASMedia driver: station-drivers.com
- Community forums: Level1Techs, Proxmox forums

**What Worked:**
- Community-provided driver solution
- Understanding USB4 architecture
- Systematic troubleshooting approach

---

## License

This documentation is provided as-is for educational and reference purposes.

---

## Contact

**Repository:** test-git
**Branch:** claude/analyze-proxmox-recovery-011CUsWnBa1uLALZSMfxLpQZ
**Status:** Production-ready, all systems operational

---

**Last Session:** 2025-11-08
**Result:** ✅ Complete success - USB4 40 Gbps passthrough fully functional
