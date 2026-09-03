param(
    [Parameter(Position = 0)]
    [string]$TargetHost,

    [Parameter(Position = 1)]
    [int]$Port = 80,

    [Parameter(Position = 2)]
    [int]$Count = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TimeoutMs = 3000
$culture = [System.Globalization.CultureInfo]::InvariantCulture

if (-not $TargetHost) {
    Write-Output "Usage: $PSCommandPath <host> [port] [count]"
    exit 1
}

Write-Output "TCP PING ${TargetHost}:$Port count=$Count"

$sent = 0
$received = 0
$totalMs = 0.0
$minMs = $null
$maxMs = $null

for ($i = 1; $i -le $Count; $i++) {
    $sent++
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $client = New-Object System.Net.Sockets.TcpClient
    $connected = $false
    try {
        $task = $client.ConnectAsync($TargetHost, $Port)
        if ($task.Wait($TimeoutMs) -and $client.Connected) {
            $connected = $true
        }
    } catch {
        $connected = $false
    } finally {
        $client.Close()
    }

    if ($connected) {
        $stopwatch.Stop()
        $elapsedMs = $stopwatch.Elapsed.TotalMilliseconds
        Write-Output "Reply from ${TargetHost}:$Port seq=$i time=$($elapsedMs.ToString('0.00', $culture)) ms"
        $received++
        $totalMs += $elapsedMs
        if ($null -eq $minMs -or $elapsedMs -lt $minMs) { $minMs = $elapsedMs }
        if ($null -eq $maxMs -or $elapsedMs -gt $maxMs) { $maxMs = $elapsedMs }
    } else {
        Write-Output "Request timed out seq=$i"
    }

    if ($i -lt $Count) {
        Start-Sleep -Seconds 1
    }
}

Write-Output '--- statistics ---'
$lost = $sent - $received
$lossPct = [double]$lost / [double]$sent * 100
Write-Output "$sent packets sent, $received received, $($lossPct.ToString('0.0', $culture))% loss"

if ($received -gt 0) {
    $avgMs = $totalMs / $received
    Write-Output "min=$($minMs.ToString('0.00', $culture)) ms  avg=$($avgMs.ToString('0.00', $culture)) ms  max=$($maxMs.ToString('0.00', $culture)) ms"
}
