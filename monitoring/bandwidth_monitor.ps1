# Network bandwidth monitoring - PowerShell port of bandwidth_monitor.sh
# Runs on both Windows PowerShell 5.1 and PowerShell 7+

param(
    [Parameter(Position = 0)]
    [string]$InterfaceName,

    [Parameter(Position = 1)]
    [int]$Interval = 3,

    [Parameter(Position = 2)]
    [int]$Count = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Format bytes/sec to human-readable rate, like the shell version
function Format-Rate {
    param([double]$Bps)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Bps -ge 1073741824) {
        return '{0} GB/s' -f ($Bps / 1073741824).ToString('0.00', $inv)
    } elseif ($Bps -ge 1048576) {
        return '{0} MB/s' -f ($Bps / 1048576).ToString('0.00', $inv)
    } elseif ($Bps -ge 1024) {
        return '{0} KB/s' -f ($Bps / 1024).ToString('0.00', $inv)
    } else {
        return '{0} B/s' -f $Bps.ToString('0.00', $inv)
    }
}

function Read-InterfaceBytes {
    param([string]$Name)
    $stats = Get-NetAdapterStatistics -Name $Name
    return @{ Rx = [double]$stats.ReceivedBytes; Tx = [double]$stats.SentBytes }
}

if (-not $InterfaceName) {
    Write-Output "Usage: $PSCommandPath <interface> [interval_seconds] [count]"
    exit 1
}

$adapter = $null
try {
    $adapter = Get-NetAdapter -Name $InterfaceName -ErrorAction Stop
} catch {
    Write-Output "ERROR: Interface not found: $InterfaceName"
    exit 1
}

Write-Output "Interface $InterfaceName state: $($adapter.Status.ToString().ToLower())"
Write-Output "Monitoring bandwidth on $InterfaceName (interval=${Interval}s, count=$Count)"

$prev = Read-InterfaceBytes $InterfaceName

for ($i = 1; $i -le $Count; $i++) {
    Start-Sleep -Seconds $Interval
    $curr = Read-InterfaceBytes $InterfaceName
    $rxRate = [math]::Round(($curr.Rx - $prev.Rx) / $Interval, 2)
    $txRate = [math]::Round(($curr.Tx - $prev.Tx) / $Interval, 2)
    Write-Output "Sample ${i}/${Count}:  RX: $(Format-Rate $rxRate)  |  TX: $(Format-Rate $txRate)"
    $prev = $curr
}

exit 0
