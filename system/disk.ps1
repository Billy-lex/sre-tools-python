param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Disk usage alert threshold (percent)
$Threshold = 80.0

$invariant = [System.Globalization.CultureInfo]::InvariantCulture

# Check the system drive, the Windows equivalent of /
$drive = $env:SystemDrive
$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$drive'"

if ($null -eq $disk) {
    [Console]::Error.WriteLine("Disk check failed: drive $drive not found")
    exit 1
}

$totalGb = [math]::Round($disk.Size / 1GB, 2)
$usedGb = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
$freeGb = [math]::Round($disk.FreeSpace / 1GB, 2)
$usagePercent = [int][math]::Ceiling(($disk.Size - $disk.FreeSpace) / $disk.Size * 100)

Write-Output "Total: $($totalGb.ToString('F2', $invariant)) GB"
Write-Output "Used:  $($usedGb.ToString('F2', $invariant)) GB"
Write-Output "Free:  $($freeGb.ToString('F2', $invariant)) GB"
Write-Output "Usage: $usagePercent%"

if ($usagePercent -gt $Threshold) {
    Write-Output "WARNING: Disk usage over threshold $($Threshold.ToString('F1', $invariant))%"
}
