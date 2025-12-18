# Windows WSL2 High Interrupt Performance Issue

**Issue:** High CPU interrupt overhead (5-10%) after installing WSL2
**Affected:** Windows Server 2025 (VM 102), Windows 10/11
**Root Cause:** Hyper-V hypervisor always running when VirtualMachinePlatform is enabled
**Solution:** Use WSL1 instead, or disable hypervisor if WSL not needed

---

## Symptoms

- **System Idle Process** shows normal (80-90%)
- **Interrupts** shows 5-10% CPU usage (normal is <1%)
- System feels sluggish, UI lag
- High DPC latency
- Issue persists even after `wsl --shutdown`

---

## Diagnosis

### 1. Check Interrupt Level

Open Process Explorer (Sysinternals) or Task Manager:
- Look for "Interrupts" or "Hardware Interrupts and DPCs"
- Normal: <1%
- Problem: >3%

### 2. Check WSL Version

```powershell
wsl -l -v
```

If VERSION shows `2`, you're using WSL2 which requires the hypervisor.

### 3. Check if Hypervisor is Active

```powershell
systeminfo | findstr "Hyper-V"
```

If you see: `"A hypervisor has been detected"` - the hypervisor is running.

### 4. Check Windows Features

```powershell
Get-WindowsOptionalFeature -Online | Where-Object {$_.FeatureName -match "Hyper|Virtual|WSL"}
```

Key features that enable hypervisor:
- `VirtualMachinePlatform` - Required for WSL2
- `Microsoft-Hyper-V` - Full Hyper-V
- `HypervisorPlatform` - Windows Hypervisor Platform

### 5. Check Hyper-V Services

```powershell
Get-Service | Where-Object {$_.Name -match "vmcompute|hvhost|vmms"} | Format-Table Name, Status, DisplayName
```

- `HvHost` Running = Hypervisor active at boot level

---

## Why This Happens

When WSL2 or any Hyper-V feature is enabled:

1. **VirtualMachinePlatform** gets enabled
2. Windows boots with the **hypervisor layer** active
3. Your entire Windows installation runs as a **VM guest** on top of Hyper-V
4. This adds interrupt overhead for all hardware operations
5. The overhead persists **even when WSL is not running**

```
Without Hypervisor:        With Hypervisor:
┌─────────────────┐        ┌─────────────────┐
│    Windows      │        │    Windows      │ ← Now a VM guest
│                 │        ├─────────────────┤
│    Hardware     │        │   Hypervisor    │ ← Always running
└─────────────────┘        ├─────────────────┤
                           │    Hardware     │
                           └─────────────────┘
```

---

## Solutions

### Option 1: Switch to WSL1 (Recommended)

WSL1 doesn't require the hypervisor - it translates Linux syscalls directly.

```powershell
# Convert existing distro to WSL1
wsl --set-version Ubuntu 1

# Set WSL1 as default for new distros
wsl --set-default-version 1
```

**WSL1 vs WSL2 Comparison:**

| Feature | WSL1 | WSL2 |
|---------|------|------|
| Interrupt overhead | None | 5-10% |
| Windows file access | Fast | Slow |
| Linux file access | Slower | Fast |
| Docker support | Limited | Full |
| Full Linux kernel | No | Yes |
| Systemd | No | Yes |

**WSL1 works well for:**
- Development (Node, Python, Go, Rust, etc.)
- CLI tools (git, grep, ssh, curl, etc.)
- Most programming tasks

**WSL2 needed for:**
- Docker Desktop (native containers)
- Apps requiring real Linux kernel
- Systemd services

### Option 2: Disable Hypervisor (If WSL Not Needed)

```powershell
# Disable hypervisor (requires reboot)
bcdedit /set hypervisorlaunchtype off
```

Reboot and verify interrupts drop to <1%.

**To re-enable later:**
```powershell
bcdedit /set hypervisorlaunchtype auto
```

### Option 3: Uninstall WSL Completely

```powershell
# Unregister distros first
wsl --unregister Ubuntu

# Disable Windows features
Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
Disable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

# Disable hypervisor
bcdedit /set hypervisorlaunchtype off
```

Reboot.

### Option 4: Keep WSL2 and Mitigate

If you must use WSL2:

1. **Update all drivers** - especially chipset, network, and storage
2. **Limit WSL2 memory** - Create `%USERPROFILE%\.wslconfig`:
   ```ini
   [wsl2]
   memory=4GB
   processors=2
   swap=0
   ```
3. **Shut down WSL when not using** - `wsl --shutdown`
4. **Accept the overhead** - some systems tolerate it better than others

---

## Advanced Diagnostics

### Use LatencyMon

Download from: https://www.resplendence.com/latencymon

LatencyMon identifies the specific driver causing high DPC/interrupt latency:
- Run for 30-60 seconds
- Check "Drivers" tab
- Look for high "DPC count" or "Highest execution (ms)"

Common culprits:
- `Wdf01000.sys` - Windows Driver Framework
- `ndis.sys` - Network drivers
- `storport.sys` - Storage drivers
- `dxgkrnl.sys` - Graphics
- `ACPI.sys` - Power management

### Check with PowerShell

```powershell
# Detailed interrupt information
Get-Counter '\Processor(_Total)\% Interrupt Time'

# DPC time
Get-Counter '\Processor(_Total)\% DPC Time'
```

---

## Quick Reference

### Diagnostic Commands

```powershell
# Check WSL version
wsl -l -v

# Check hypervisor status
systeminfo | findstr "Hyper-V"

# Check Hyper-V services
Get-Service HvHost

# Shut down WSL
wsl --shutdown
```

### Fix Commands

```powershell
# Switch to WSL1
wsl --set-version <distro-name> 1
wsl --set-default-version 1

# Disable hypervisor
bcdedit /set hypervisorlaunchtype off

# Re-enable hypervisor
bcdedit /set hypervisorlaunchtype auto
```

---

## Session Log

**Date:** 2025-12-18
**Issue:** User reported ~10% interrupt CPU usage after installing WSL
**Diagnosis:**
1. Process Explorer showed Interrupts at 6.76%
2. WSL2 (Ubuntu) was installed
3. VirtualMachinePlatform was enabled
4. HvHost service was running
5. `wsl --shutdown` did not reduce interrupts (hypervisor still active)

**Resolution:**
1. Disabled hypervisor: `bcdedit /set hypervisorlaunchtype off`
2. Rebooted
3. Interrupts dropped to <1%
4. Recommended switching to WSL1 for continued Linux usage without hypervisor overhead

---

## Related Documentation

- [QUICK-REFERENCE.md](../QUICK-REFERENCE.md) - General troubleshooting
- [FINAL-SOLUTION-SUMMARY.md](../FINAL-SOLUTION-SUMMARY.md) - VM configuration
