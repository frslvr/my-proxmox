# Monitor for New USB Devices
# This script will continuously check for newly connected USB devices
# Useful for identifying which physical port corresponds to USB4

Write-Host "`n=== USB Port Identification Tool ===" -ForegroundColor Cyan
Write-Host "This script will help you identify which physical port is USB4 40 Gbps`n"

Write-Host "=== USB4 Host Router Location ===" -ForegroundColor Yellow
$usb4Router = Get-PnpDevice | Where-Object {$_.FriendlyName -eq 'USB4 Host Router'}
if ($usb4Router) {
    Write-Host "USB4 Host Router: Status = $($usb4Router.Status)" -ForegroundColor Green
    Write-Host "InstanceId: $($usb4Router.InstanceId)"

    # Extract the location identifier
    if ($usb4Router.InstanceId -match '&0&([0-9A-F]+)') {
        $locationCode = $matches[1]
        Write-Host "Location Code: $locationCode" -ForegroundColor Cyan
        Write-Host "`nDevices connected to this controller will have '$locationCode' in their InstanceId`n" -ForegroundColor Yellow
    }
} else {
    Write-Host "USB4 Host Router not found!" -ForegroundColor Red
}

Write-Host "`n=== Current USB Devices ===" -ForegroundColor Cyan
$currentDevices = Get-PnpDevice -PresentOnly | Where-Object {
    $_.InstanceId -like '*USB*' -and $_.Class -ne 'USB'
} | Select-Object FriendlyName, InstanceId

$currentDevices | Format-Table -AutoSize

Write-Host "`n=== Instructions ===" -ForegroundColor Green
Write-Host "1. Note the devices listed above"
Write-Host "2. Plug a USB device into a REAR USB port"
Write-Host "3. Run this script again"
Write-Host "4. Look for the NEW device in the list"
Write-Host "5. Check if its InstanceId contains the USB4 location code"
Write-Host ""

# Optional: Continuous monitoring mode
$monitor = Read-Host "Do you want to enable continuous monitoring? (y/n)"
if ($monitor -eq 'y' -or $monitor -eq 'Y') {
    Write-Host "`n=== MONITORING MODE - Press Ctrl+C to stop ===" -ForegroundColor Magenta
    Write-Host "Plug and unplug USB devices to see which controller they appear under`n"

    $previousCount = $currentDevices.Count

    while ($true) {
        Start-Sleep -Seconds 2

        $newDevices = Get-PnpDevice -PresentOnly | Where-Object {
            $_.InstanceId -like '*USB*' -and $_.Class -ne 'USB'
        } | Select-Object FriendlyName, InstanceId

        if ($newDevices.Count -ne $previousCount) {
            Clear-Host
            Write-Host "`n=== DEVICE CHANGE DETECTED! ===" -ForegroundColor Red
            Write-Host "Current device count: $($newDevices.Count) (was $previousCount)`n"

            $newDevices | ForEach-Object {
                $isUsb4 = $false
                if ($locationCode -and $_.InstanceId -match $locationCode) {
                    $isUsb4 = $true
                }

                if ($isUsb4) {
                    Write-Host ">>> USB4 PORT! <<<" -ForegroundColor Green -NoNewline
                    Write-Host " $($_.FriendlyName)"
                    Write-Host "    $($_.InstanceId)" -ForegroundColor Yellow
                } else {
                    Write-Host "$($_.FriendlyName)"
                }
            }

            $previousCount = $newDevices.Count
        }
    }
}
