# Find USB4 Host Router and its relationship to other controllers
# Run as Administrator

Write-Host "`n=== Searching for USB4 Host Router ===" -ForegroundColor Cyan

# Get USB4 device details
$usb4 = Get-PnpDevice | Where-Object {$_.FriendlyName -eq 'USB4 Host Router'}
if ($usb4) {
    Write-Host "`nUSB4 Host Router Found:" -ForegroundColor Green
    Write-Host "  Status: $($usb4.Status)"
    Write-Host "  InstanceId: $($usb4.InstanceId)"

    # Get parent device
    Write-Host "`nParent/Related Devices:" -ForegroundColor Yellow
    Get-PnpDeviceProperty -InstanceId $usb4.InstanceId | Where-Object {
        $_.KeyName -like '*Parent*' -or
        $_.KeyName -like '*Child*' -or
        $_.KeyName -like '*Sibling*' -or
        $_.KeyName -like '*Service*'
    } | Format-Table KeyName, Data -AutoSize
} else {
    Write-Host "USB4 Host Router NOT FOUND!" -ForegroundColor Red
}

# List ALL ASMedia devices with details
Write-Host "`n=== ALL ASMedia Devices ===" -ForegroundColor Cyan
Get-PnpDevice | Where-Object {$_.InstanceId -like '*VEN_1B21*'} | ForEach-Object {
    Write-Host "`n$($_.FriendlyName)" -ForegroundColor White
    Write-Host "  Status: $($_.Status)"
    Write-Host "  InstanceId: $($_.InstanceId)"
    Write-Host "  Class: $($_.Class)"

    if ($_.InstanceId -like '*DEV_2425*') {
        Write-Host "  >>> USB4 CONTROLLER (40 Gbps) <<<" -ForegroundColor Magenta
    } elseif ($_.InstanceId -like '*DEV_2426*') {
        Write-Host "  >>> USB 3.2 CONTROLLER (20 Gbps) <<<" -ForegroundColor Blue
    }
}

# Check if USB4 Router has any child hubs
Write-Host "`n=== USB Hubs (looking for USB4 association) ===" -ForegroundColor Cyan
Get-CimInstance Win32_USBHub | Select-Object Name, DeviceID, Status | Format-List

Write-Host "`n=== Theory Check ===" -ForegroundColor Yellow
Write-Host "The USB4 Host Router might be:"
Write-Host "  1. A logical/software layer that doesn't show in USB Tree Viewer"
Write-Host "  2. Only visible when USB4/Thunderbolt device is connected"
Write-Host "  3. Operating in USB 3.2 compatibility mode (showing as ASMedia USB 3.20)"
Write-Host ""
Write-Host "The physical '40G' port showing under AMD suggests:"
Write-Host "  - Motherboard port labeling doesn't match PCI controller mapping"
Write-Host "  - Need to test ALL rear USB ports to find ASMedia USB4 physical connection"
