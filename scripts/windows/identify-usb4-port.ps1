# Identify USB4 Physical Port Location
# Run this in PowerShell as Administrator

Write-Host "`n=== USB4 Host Router Details ===" -ForegroundColor Cyan
Get-PnpDevice | Where-Object {$_.FriendlyName -eq 'USB4 Host Router'} | ForEach-Object {
    Write-Host "Device: $($_.FriendlyName)"
    Write-Host "Status: $($_.Status)"
    Write-Host "InstanceId: $($_.InstanceId)"
    Write-Host "`nProperties:"
    Get-PnpDeviceProperty -InstanceId $_.InstanceId | Where-Object {
        $_.KeyName -like '*Location*' -or
        $_.KeyName -like '*Address*' -or
        $_.KeyName -like '*Port*' -or
        $_.KeyName -like '*Speed*'
    } | Format-Table KeyName, Data -AutoSize
}

Write-Host "`n=== All Connected USB Devices (Before Test) ===" -ForegroundColor Yellow
Get-PnpDevice -PresentOnly | Where-Object {
    $_.Class -eq 'DiskDrive' -or
    $_.Class -eq 'USB' -or
    $_.InstanceId -like '*USB*'
} | Select-Object FriendlyName, Class, InstanceId | Format-Table -AutoSize

Write-Host "`n=== Instructions ===" -ForegroundColor Green
Write-Host "1. Note the devices listed above"
Write-Host "2. Plug a USB device into a rear USB port"
Write-Host "3. Run the script again and compare the device lists"
Write-Host "4. The new device's InstanceId will tell you which controller it's on"
Write-Host "5. If InstanceId contains '00E3' it's likely the USB4 port (based on USB4 Host Router location)"
Write-Host ""
