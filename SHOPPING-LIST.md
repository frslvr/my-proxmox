# Shopping List - Dual Monitor Extension Setup

**Goal:** Connect 6K + 4K monitors to server ~5 meters away

**Server:** Proxmox VM 102 (Windows)
**GPU:** RTX 4070 SUPER (3x DP 1.4a, 1x HDMI 2.1a) - Supports DSC
**Motherboard:** ASUS ProArt X870E-CREATOR WIFI (has DP In → USB4 Out feature)
**Monitors:**
- Primary: ASUS ProArt PA32QCV (6K@60Hz, 6016x3384)
  - Inputs: 2x Thunderbolt 4, DisplayPort 1.4, HDMI 2.1
  - USB hub: USB-C upstream port (provides 4 downstream USB ports)
- Secondary: 4K monitor @ 60Hz (no USB hub)

---

## Required Cables - READY TO BUY ✅

### Video Cables (Both Monitors)

**Capshi DisplayPort 1.4 Cable - 15ft (Quantity: 2)**
```
☐ Capshi 8K DisplayPort 1.4 Cable - 15 feet x2
  - VESA Certified ✅
  - Supports 8K@60Hz, 4K@144Hz, 2K@240Hz
  - 32.4 Gbps HBR3 bandwidth
  - DSC support (required for 6K)
  - Passive copper (reliable at this length with VESA cert)
  - Price: ~$25 each = $50 total
  - Amazon Link: https://www.amazon.com/dp/B094VYSZXW

Notes:
- Use one cable for 6K monitor (ASUS ProArt PA32QCV)
- Use one cable for 4K monitor
- VESA certified means tested and validated for DP 1.4 spec
- If 6K has any issues, can upgrade to fiber later
```

### USB Cable (6K Monitor Hub)

**USB-C to USB-C Cable - 16ft**
```
☐ KING KABLE USB-C 3.2 Gen 2 Cable - 16ft (5m)
  - USB 3.2 Gen 2 (20 Gbps capable)
  - USB-C to USB-C connection
  - Price: ~$15-20
  - Alternative: Any quality USB-C to USB-C cable (USB 3.2 Gen 1/5Gbps minimum)

Notes:
- Connects server USB4/USB-C port → 6K monitor's USB-C upstream port
- Monitor provides 4 USB ports at desk for peripherals
- IMPORTANT: Monitor uses USB-C upstream (NOT USB-B)
```

---

## Total Cost

**SELECTED CONFIGURATION: Separate Cables (RECOMMENDED)**

| Item | Qty | Price | Total |
|------|-----|-------|-------|
| Capshi DP 1.4 Cable (15ft) | 2 | $25 | $50 |
| USB-C to USB-C Cable (16ft) | 1 | $15-20 | $20 |
| **GRAND TOTAL** | | | **$65-70** |

**Alternative Configurations:**
| Configuration | Cost | Notes |
|---------------|------|-------|
| Premium (both fiber DP) | $150+ | Unnecessary for 15ft |
| Mixed (6K fiber + 4K Capshi) | $115+ | Unnecessary for 15ft |
| OWC USB4 Active Optical (single cable) | $130 | See limitations below |

---

## Connection Diagram

```
Server Room - Proxmox VM 102 (RTX 4070 SUPER):

GPU DisplayPort 1 ──[15ft Capshi DP Cable]──> 6K Monitor (DP input)
                                                  └─ Built-in USB hub

GPU DisplayPort 2 ──[15ft Capshi DP Cable]──> 4K Monitor (DP input)

Server USB4/USB-C ──[16ft USB-C Cable]─────> 6K Monitor (USB-C upstream)
                                                  └─ Provides 4 USB ports at desk
```

---

## Setup Notes

**Physical Layout:**
- Server: Separate room (VM 102 with GPU/USB passthrough)
- Desk: ~5 meters away with both monitors
- Each monitor needs its own video cable from server to desk
- USB extension only needed for 6K monitor (has built-in hub)

**Installation:**
1. Run 2x DisplayPort cables from GPU to each monitor
2. Run 1x USB-C to USB-C cable from server USB4/USB-C port to 6K monitor's USB-C upstream port
3. Connect peripherals to 6K monitor's USB hub (provides 4 ports at desk)

**Bandwidth Usage:**
- 6K@60Hz: ~14.66 Gbps (with DSC)
- 4K@60Hz: ~12.54 Gbps (uncompressed)
- Total: Well within GPU capabilities

**Port Usage:**
- DP Port 1: 6K monitor
- DP Port 2: 4K monitor
- DP Port 3: Available
- HDMI: Available

---

## FINAL PURCHASE LIST ✅

**Separate Cables Setup - $65-70 Total (RECOMMENDED):**

```
CART:
1. Capshi 8K DP 1.4 Cable 15ft (Qty: 2) = $50
   Amazon ASIN: B094VYSZXW
   Link: https://www.amazon.com/dp/B094VYSZXW

2. USB-C to USB-C Cable 16ft (USB 3.2) = $15-20
   Options:
   - KING KABLE USB-C 20Gbps cable
   - Any quality USB 3.2 Gen 1 (5Gbps) or better cable

TOTAL: $65-70
```

**Why this config:**
- ✅ Most cost-effective solution ($65-70 vs $130 for OWC USB4 cable)
- ✅ Both monitors use identical VESA certified cables (easier troubleshooting)
- ✅ Saves $60-65 vs USB4 active optical cable option
- ✅ VESA certification ensures DP 1.4 compliance
- ✅ Can upgrade 6K monitor cable to fiber later if needed
- ✅ All cables support required bandwidth (6K needs DSC, 4K uncompressed)
- ✅ 6K monitor USB hub provides 4 USB ports at desk
- ✅ Simple, proven configuration with no complexity

---

## Alternative Products & Considerations

### Option 1: Single USB4 Cable Solution (NOT RECOMMENDED)

**OWC USB4 40Gbps Active Optical Cable - 15ft**
```
Price: $129.99
Model: OWCCBLUS4A04.5M
Length: 4.5m (15ft)
Bandwidth: 40 Gbps

IMPORTANT LIMITATION:
"Displays using DisplayPort Alt Mode via USB-C are not supported"
- Does NOT support DP Alt Mode displays
- DOES support native Thunderbolt displays
- ASUS ProArt PA32QCV has Thunderbolt 4 inputs (might work)
- RTX 4070 SUPER would need to route through motherboard's DP In → USB4 Out feature
- Complexity with VM passthrough (unclear if routing works with passed-through USB4)

Why NOT recommended:
- 🔴 High cost ($130 vs $65-70 for separate cables)
- 🔴 DP Alt Mode limitation unclear with monitor's TB4 input
- 🔴 Complexity with motherboard DP routing + VM passthrough
- 🔴 Unproven configuration
- 🔴 Separate cables are simpler and cheaper
```

### Option 2: Fiber DisplayPort Cables (if needed)

**If you need to upgrade 6K monitor to fiber optic later:**

**DisplayPort Fiber (5m):**
- Cable Matters DP 1.4 Fiber 16ft - $65 (recommended)
- StarTech DP14MM15MAO (15m) - $130 (premium, longer)
- IOGEAR GDP14AOC20 - $80-100
- Unitek UltraPro DP 1.4 AOC - $70-90

**Note:** Passive copper (Capshi) should work fine at 15ft for both 6K and 4K. Only upgrade if you experience issues.

### Option 3: USB-C Cable Alternatives

**USB-C to USB-C Cables (16ft):**
- KING KABLE USB-C 20Gbps - $15-20 (recommended)
- Cable Matters USB-C 3.2 Gen 2 - $20-25
- Anker USB-C cable (USB 3.2 Gen 1) - $15
- Any quality USB-C 3.2 cable will work (5Gbps minimum)

---

## Troubleshooting Notes

**If 6K monitor has issues (flickering, no signal, wrong resolution):**

1. **Verify DSC is enabled:**
   - RTX 4070 SUPER supports DSC (Display Stream Compression)
   - 6K@60Hz requires DSC over DP 1.4a (~14.66 Gbps compressed)
   - Check NVIDIA Control Panel → Change Resolution → Enable DSC

2. **Check Windows Display Settings:**
   - Should show 6016x3384@60Hz
   - If lower resolution, DSC may not be enabled

3. **Try different DisplayPort on GPU:**
   - Use Port 2 or 3 if Port 1 has issues
   - All DP 1.4a ports support DSC

4. **Cable troubleshooting:**
   - Ensure cable is fully seated on both ends
   - Try swapping 6K and 4K cables to isolate issue
   - VESA certification means cable is validated for DP 1.4

5. **If issues persist:**
   - Upgrade to fiber optic cable for 6K monitor (~$65)
   - Though passive copper at 15ft should work with VESA cert

**Expected behavior:**
- Both monitors should auto-detect and work immediately
- 6K should show as "ASUS PA32QCV" at 6016x3384@60Hz (DSC enabled)
- 4K should show at 3840x2160@60Hz (no compression needed)
- USB devices on 6K monitor hub should appear in Windows
- Monitor hub provides 4 downstream USB ports for peripherals

**USB Hub Connection:**
- USB-C cable connects server USB4/USB-C port to monitor's USB-C upstream port
- NOT USB-B (common mistake - monitor has USB-C upstream)
- Hub functionality extends server USB to desk via monitor

---

## Important Corrections Made During Research

**Initial Assumptions → Reality:**
1. Monitor USB port: Assumed USB-B → Actually USB-C upstream
2. USB cable recommendation: Initially USB-A extension → Corrected to USB-C to USB-C
3. OWC USB4 cable: Initially considered viable → Discovered "DP Alt Mode not supported" limitation
4. Monitor Thunderbolt ports: Not just DP Alt Mode → Native TB4 input support (but adds complexity)

**Key Technical Findings:**
- ASUS ProArt PA32QCV has native Thunderbolt 4 input (not just DP Alt Mode)
- RTX 4070 SUPER confirmed to support DSC (required for 6K@60Hz over DP 1.4a)
- Motherboard has "DP In → USB4 Out" feature (theoretical single-cable routing, not recommended)
- Separate cables approach is simpler, cheaper, and proven

---

**Last Updated:** 2025-11-08
**Status:** ✅ Ready to purchase - $65-70 total (RECOMMENDED: Separate cables)
