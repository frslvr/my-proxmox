# USB4 Controller Detection Script for Windows
# Run this in PowerShell as Administrator

# Command 1: Quick check - Show all ASMedia devices
Write-Host "`n=== QUICK CHECK: All ASMedia Devices ===" -ForegroundColor Cyan
Get-PnpDevice | Where-Object {$_.InstanceId -like '*VEN_1B21*'} | Select-Object FriendlyName, InstanceId, Status | Format-Table -AutoSize

# Command 2: Find USB4 specific devices
Write-Host "`n=== USB4 Devices ===" -ForegroundColor Yellow
Get-PnpDevice | Where-Object {$_.FriendlyName -like '*USB4*'} | Select-Object FriendlyName, Status, Class | Format-List

# Command 3: All USB Host Controllers
Write-Host "`n=== All USB Host Controllers ===" -ForegroundColor Green
Get-PnpDevice -Class USB | Where-Object {$_.FriendlyName -like '*Host Controller*'} | Select-Object FriendlyName, Status | Format-Table -AutoSize

# Command 4: Detailed ASMedia controller info with hardware IDs
Write-Host "`n=== Detailed ASMedia Controller Information ===" -ForegroundColor Magenta
Get-PnpDevice | Where-Object {$_.InstanceId -like '*VEN_1B21*'} | ForEach-Object {
    Write-Host "`n--- $($_.FriendlyName) ---" -ForegroundColor White
    Write-Host "Status: $($_.Status)"
    Write-Host "InstanceId: $($_.InstanceId)"
    if ($_.InstanceId -like '*DEV_2425*') {
        Write-Host "*** THIS IS THE USB4 CONTROLLER (40 Gbps) ***" -ForegroundColor Red
    }
    if ($_.InstanceId -like '*DEV_2426*') {
        Write-Host "*** THIS IS THE USB 3.2 CONTROLLER (20 Gbps) ***" -ForegroundColor Blue
    }
}

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "Look for device with VEN_1B21&DEV_2425 = USB4 (40 Gbps)"
Write-Host "Look for device with VEN_1B21&DEV_2426 = USB 3.2 (20 Gbps)"
