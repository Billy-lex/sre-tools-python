# ICMP ping latency monitoring - PowerShell port of latency_monitor.sh
# Runs on both Windows PowerShell 5.1 and PowerShell 7+

param(
    [Parameter(Position = 0)]
    [string]$HostName,

    [Parameter(Position = 1)]
    [int]$Count = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WARN_THRESHOLD_MS = 100
$LOSS_THRESHOLD_PCT = 20

if (-not $HostName) {
    Write-Output "Usage: $PSCommandPath <host> [count]"
    exit 1
}

Write-Output "Monitoring latency to $HostName ($Count pings)"

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$pinger = New-Object System.Net.NetworkInformation.Ping
$successCount = 0
$rttSum = 0.0
$rttSumSq = 0.0
$minMs = 0.0
$maxMs = 0.0

# Sequential pings with a 3s per-reply timeout, like ping -c N -W 3
for ($i = 0; $i -lt $Count; $i++) {
    $reply = $null
    try {
        $reply = $pinger.Send($HostName, 3000)
    } catch {
        $reply = $null
    }
    if ($null -ne $reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
        $rtt = [double]$reply.RoundtripTime
        $successCount++
        $rttSum += $rtt
        $rttSumSq += $rtt * $rtt
        if ($successCount -eq 1 -or $rtt -lt $minMs) { $minMs = $rtt }
        if ($rtt -gt $maxMs) { $maxMs = $rtt }
    }
}

if ($Count -gt 0) {
    $lossPct = [int][math]::Round((($Count - $successCount) * 100.0) / $Count)
} else {
    $lossPct = 100
}

Write-Output "Packet loss: $($lossPct)%"

if ($successCount -gt 0) {
    $avgMs = $rttSum / $successCount
    $variance = ($rttSumSq / $successCount) - ($avgMs * $avgMs)
    if ($variance -lt 0) { $variance = 0 }
    $mdevMs = [math]::Sqrt($variance)

    $rttLine = 'rtt min/avg/max/mdev = {0}/{1}/{2}/{3} ms' -f $minMs.ToString('0.000', $inv), $avgMs.ToString('0.000', $inv), $maxMs.ToString('0.000', $inv), $mdevMs.ToString('0.000', $inv)
    Write-Output "Latency: $rttLine"

    if ($avgMs -gt $WARN_THRESHOLD_MS) {
        Write-Output "WARNING: Average latency exceeds $($WARN_THRESHOLD_MS)ms threshold"
    }
} else {
    Write-Output 'WARNING: No successful ping replies received'
}

if ($lossPct -gt $LOSS_THRESHOLD_PCT) {
    Write-Output "WARNING: Packet loss exceeds $($LOSS_THRESHOLD_PCT)% threshold"
}

exit 0
