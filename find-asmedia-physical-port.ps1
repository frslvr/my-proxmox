# Find ASMedia USB4 Physical Port Location
# This script helps identify which physical USB port is connected to ASMedia USB4 controller

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  ASMedia USB4 Physical Port Finder                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Check if ASMedia controllers are detected by Windows
Write-Host "=== Step 1: Verify ASMedia Controllers Detected ===" -ForegroundColor Yellow
$asMediaDevices = Get-PnpDevice | Where-Object {$_.InstanceId -like '*VEN_1B21*'}

if ($asMediaDevices) {
    Write-Host "✅ ASMedia controllers detected in Windows:`n" -ForegroundColor Green
    $asMediaDevices | ForEach-Object {
        $color = if ($_.Status -eq 'OK') { 'Green' } else { 'Yellow' }
        Write-Host "  • $($_.FriendlyName) - Status: $($_.Status)" -ForegroundColor $color

        if ($_.InstanceId -like '*DEV_2425*') {
            Write-Host "    → USB4 Controller (40 Gbps capability)" -ForegroundColor Magenta
        } elseif ($_.InstanceId -like '*DEV_2426*') {
            Write-Host "    → USB 3.2 Controller (20 Gbps capability)" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "❌ No ASMedia controllers found!" -ForegroundColor Red
    Write-Host "   This is unexpected. The controllers should be visible in Windows." -ForegroundColor Red
    exit
}

# Get baseline - currently connected USB devices
Write-Host "`n=== Step 2: Current USB Controller Status ===" -ForegroundColor Yellow

$controllers = @{
    'AMD' = @()
    'Intel' = @()
    'ASMedia' = @()
}

Get-PnpDevice -Class USB | Where-Object {$_.FriendlyName -like '*Host Controller*'} | ForEach-Object {
    $props = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds'
    $hwId = $props.Data[0]

    if ($hwId -like '*VEN_1B21*') {
        $controllers['ASMedia'] += $_
    } elseif ($hwId -like '*VEN_1022*') {
        $controllers['AMD'] += $_
    } elseif ($hwId -like '*VEN_8086*') {
        $controllers['Intel'] += $_
    }
}

Write-Host "`nController Summary:" -ForegroundColor Cyan
Write-Host "  AMD Controllers:     $($controllers['AMD'].Count)" -ForegroundColor Green
Write-Host "  Intel Controllers:   $($controllers['Intel'].Count)" -ForegroundColor Green
Write-Host "  ASMedia Controllers: $($controllers['ASMedia'].Count)" -ForegroundColor Green

if ($controllers['ASMedia'].Count -eq 0) {
    Write-Host "`n⚠️  WARNING: ASMedia controllers detected by Windows but not appearing" -ForegroundColor Yellow
    Write-Host "    as active USB Host Controllers. This means:" -ForegroundColor Yellow
    Write-Host "    → No devices currently plugged into ASMedia ports" -ForegroundColor Yellow
    Write-Host "    → ASMedia ports are physically empty" -ForegroundColor Yellow
    Write-Host "`n    We need to test different physical ports to find them!`n" -ForegroundColor Yellow
}

# Instructions for testing
Write-Host "`n=== Step 3: Physical Port Testing Instructions ===" -ForegroundColor Yellow
Write-Host @"

To find the ASMedia USB4 port, follow these steps:

1️⃣  UNPLUG your Anker hub from the current '40G' port
    (That port is AMD USB 3.1, not ASMedia USB4)

2️⃣  Try EACH rear USB port ONE AT A TIME:
    • Plug the Anker hub into a port
    • Run this script again: .\find-asmedia-physical-port.ps1
    • Look for "ASMedia Controllers: 4" (or more) in the summary above

3️⃣  When ASMedia controllers appear:
    • That physical port is connected to ASMedia!
    • Note which port it is (mark it with tape/sticker)
    • That's your REAL USB4 port!

4️⃣  ALTERNATIVE - Use USB Tree Viewer:
    • Keep USB Tree Viewer open
    • Plug Anker hub into different ports
    • When you see "ASMedia USB 3.20 eXtensible Host Controller"
      appear in the left panel → You found it!

"@ -ForegroundColor White

# Continuous monitoring option
Write-Host "`n=== Step 4: Enable Continuous Monitoring? ===" -ForegroundColor Yellow
$monitor = Read-Host "Monitor for ASMedia controller appearance in real-time? (y/n)"

if ($monitor -eq 'y' -or $monitor -eq 'Y') {
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║  MONITORING MODE ACTIVE - Press Ctrl+C to stop                ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host "Plug your Anker hub into different rear USB ports...`n" -ForegroundColor White

    $lastAsMediaCount = $controllers['ASMedia'].Count

    while ($true) {
        Start-Sleep -Seconds 3

        $currentAsMedia = @(Get-PnpDevice -Class USB | Where-Object {
            $_.FriendlyName -like '*Host Controller*' -and
            $_.InstanceId -like '*VEN_1B21*'
        })

        if ($currentAsMedia.Count -ne $lastAsMediaCount) {
            Clear-Host

            if ($currentAsMedia.Count -gt $lastAsMediaCount) {
                Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
                Write-Host "║  ✅ ASMedia CONTROLLER DETECTED!                              ║" -ForegroundColor Green
                Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

                Write-Host "🎉 YOU FOUND THE ASMedia PORT!`n" -ForegroundColor Green
                Write-Host "The physical USB port you just plugged into is connected to:" -ForegroundColor Yellow

                $currentAsMedia | ForEach-Object {
                    Write-Host "  • $($_.FriendlyName)" -ForegroundColor Cyan
                    if ($_.InstanceId -like '*DEV_2425*') {
                        Write-Host "    ⚡ USB4 40 Gbps Controller!" -ForegroundColor Magenta
                    } elseif ($_.InstanceId -like '*DEV_2426*') {
                        Write-Host "    ⚡ USB 3.2 20 Gbps Controller!" -ForegroundColor Cyan
                    }
                }

                Write-Host "`n📍 MARK THIS PORT! This is your ASMedia port!" -ForegroundColor Green
                Write-Host "   Leave your Anker hub connected here for maximum speed.`n" -ForegroundColor Yellow

            } else {
                Write-Host "`n⚠️  Device unplugged from ASMedia port" -ForegroundColor Yellow
            }

            $lastAsMediaCount = $currentAsMedia.Count
            Write-Host "`nASMedia Controllers Active: $lastAsMediaCount" -ForegroundColor Cyan
            Write-Host "Continuing to monitor... (Ctrl+C to stop)`n" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "`nManual testing mode. Run this script after trying each port!`n" -ForegroundColor Cyan
}
