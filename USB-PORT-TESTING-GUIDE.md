# USB4 Physical Port Testing Guide

## Problem Summary

**Discovered Issue:**
- PowerShell shows ASMedia USB4 controller (78:00.0) is **working** - Status: OK ✅
- USB Tree Viewer shows **NO ASMedia controllers** in the device list ❌
- The motherboard port labeled **"40G"** is actually connected to **AMD USB 3.1** (10 Gbps), NOT ASMedia USB4 (40 Gbps) ⚠️

**Conclusion:** The ASMedia USB4 port is on a **different physical port** than the one labeled "40G"!

---

## Current Port Mapping (INCOMPLETE)

### Known Ports:

| Physical Label | Controller | PCI Address | Speed | Device ID | Current Device |
|----------------|------------|-------------|-------|-----------|----------------|
| **"40G"** ❌ | AMD USB 3.1 | 79:00.3 or 79:00.4 | 10 Gbps | 1022:15b6 | Anker A83B3 Hub |
| **UNKNOWN** ❓ | ASMedia USB4 | 78:00.0 | **40 Gbps** | **1b21:2425** | **NOT FOUND YET** |
| **UNKNOWN** ❓ | ASMedia USB 3.2 | 77:00.0 | 20 Gbps | 1b21:2426 | NOT FOUND YET |

### Controllers to Find:

**ASMedia Controllers (passed to VM 102):**
- ✅ Detected by Windows (PowerShell shows Status: OK)
- ❌ NOT visible in USB Tree Viewer (no devices connected to them)
- ❓ Physical port location UNKNOWN

**We need to find which rear USB ports connect to ASMedia!**

---

## Testing Method 1: Automated Script (RECOMMENDED)

### Quick Start:

```powershell
cd C:\Users\User1\source\repos\test-git
.\find-asmedia-physical-port.ps1
```

When prompted, type **`y`** to enable monitoring mode.

### Testing Procedure:

1. **Run the script** (it will start monitoring)
2. **Unplug Anker hub** from current "40G" port
3. **Try each rear USB port** one at a time:
   - Plug Anker hub into port
   - Wait 3 seconds
   - Watch for **GREEN alert** when ASMedia detected
4. **Mark the port** when found
5. **Press Ctrl+C** to stop monitoring

### What Success Looks Like:

When you plug into the ASMedia port, you'll see:

```
╔════════════════════════════════════════════════════════════════╗
║  ✅ ASMedia CONTROLLER DETECTED!                              ║
╚════════════════════════════════════════════════════════════════╝

🎉 YOU FOUND THE ASMedia PORT!

  • ASMedia USB 3.20 eXtensible Host Controller
    ⚡ USB4 40 Gbps Controller!

📍 MARK THIS PORT! This is your ASMedia port!
```

---

## Testing Method 2: USB Tree Viewer

### Procedure:

1. **Open USB Device Tree Viewer** (keep it open)
2. **Unplug Anker hub** from "40G" port
3. **Try each rear port** systematically:
   - Plug Anker hub into port
   - Press **F5** to refresh USB Tree Viewer
   - Look for **ASMedia** in the controller list

### What to Look For:

**Currently (in AMD port):**
```
└─ AMD USB 3.10 eXtensible Host Controller - 1.20 (Microsoft)
    └─ USB Root Hub (USB 3.0)
        └─ [Port1] - Anker Prime Docking Station
```

**When you find ASMedia port:**
```
└─ ASMedia USB 3.20 eXtensible Host Controller - 1.20 (Microsoft)  ✅ THIS!
    └─ USB Root Hub (USB 3.0)
        └─ [Port1] - Anker Prime Docking Station
```

**Or:**
```
└─ USB4 Host Router  ✅ THIS!
    └─ USB Root Hub
        └─ [Port1] - Anker Prime Docking Station
```

---

## Testing Method 3: Manual PowerShell

### Quick Command:

```powershell
Get-PnpDevice -Class USB | Where-Object {$_.FriendlyName -like '*Host Controller*' -and $_.InstanceId -like '*VEN_1B21*'} | Measure-Object | Select-Object Count
```

**Before plugging into ASMedia port:**
```
Count
-----
0  (or very low number)
```

**After plugging into ASMedia port:**
```
Count
-----
4  (or higher - controllers become active)
```

---

## Motherboard Rear I/O Panel Layout

**Typical Layout (fill in as you test):**

```
┌─────────────────────────────────────────┐
│  Rear I/O Panel (view from outside)    │
├─────────────────────────────────────────┤
│                                         │
│  🔌 Port 1: [ Controller: __________ ] │
│  🔌 Port 2: [ Controller: __________ ] │
│  🔌 Port 3: [ Controller: __________ ] │
│  🔌 Port 4: [ Controller: AMD 3.1 "40G" - WRONG!] ✅ TESTED
│  🔌 Port 5: [ Controller: __________ ] │
│  🔌 Port 6: [ Controller: __________ ] │
│  🔌 Port 7: [ Controller: __________ ] │
│  🔌 Port 8: [ Controller: __________ ] │
│                                         │
└─────────────────────────────────────────┘
```

**Testing Checklist:**
- [ ] Port 1 - Controller: _________________
- [ ] Port 2 - Controller: _________________
- [ ] Port 3 - Controller: _________________
- [x] Port 4 - Controller: AMD USB 3.1 (labeled "40G" - misleading!)
- [ ] Port 5 - Controller: _________________
- [ ] Port 6 - Controller: _________________
- [ ] Port 7 - Controller: _________________
- [ ] Port 8 - Controller: _________________

**Look for ASMedia USB4 (1b21:2425) or ASMedia USB 3.2 (1b21:2426)**

---

## Expected Outcome

### Success Criteria:

✅ Identify which physical port connects to ASMedia USB4 controller
✅ Verify USB4 Host Router appears in USB Tree Viewer
✅ Move Anker hub to correct port
✅ Confirm 40 Gbps capability available

### After Finding the Port:

1. **Mark the physical port** (sticker, label, etc.)
2. **Update documentation** with port location
3. **Keep Anker hub connected there** for maximum speed
4. **Document the misleading "40G" label** issue

---

## Troubleshooting

### ASMedia Controllers Never Appear

**Possible causes:**
1. ASMedia ports might be disabled in BIOS
2. Controllers might need specific devices to activate
3. Might be USB-C ports instead of USB-A

**Try:**
- Check BIOS settings for USB4/Thunderbolt
- Try USB-C ports if available
- Use USB 3.2 or USB4 certified device

### All Ports Show AMD/Intel Controllers

**If no ASMedia ports found:**
1. Verify in Proxmox that 77:00.0 and 78:00.0 are bound to vfio-pci
2. Check VM 102 config has hostpci2 and hostpci3
3. Verify drivers installed in Windows (PowerShell should show Status: OK)

### Need More Help

**Diagnostic commands:**

```powershell
# Show all ASMedia devices
Get-PnpDevice | Where-Object {$_.InstanceId -like '*VEN_1B21*'} | Format-List

# Show all USB controllers
Get-PnpDevice -Class USB | Where-Object {$_.FriendlyName -like '*Host Controller*'} | Select-Object FriendlyName, Status
```

---

## Next Steps After Finding Port

1. **Document in claude.md**
2. **Update USB4-SUCCESS.md** with physical port info
3. **Test USB4 speed** with fast device
4. **Mark port permanently** for future reference

---

**Created:** 2025-11-07
**Status:** Testing in progress
**Goal:** Find physical location of ASMedia USB4 40 Gbps port
