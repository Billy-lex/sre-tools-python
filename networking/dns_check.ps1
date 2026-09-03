param(
    [Parameter(Position = 0)]
    [string]$Domain
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Domain) {
    Write-Output "Usage: $PSCommandPath <domain>"
    exit 1
}

Write-Output "Resolving DNS for: $Domain"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    # Keep only A/AAAA address records
    $records = @(Resolve-DnsName -Name $Domain -ErrorAction Stop | Where-Object { $_.Type -eq 'A' -or $_.Type -eq 'AAAA' })
} catch {
    $records = @()
}
$stopwatch.Stop()

if ($records.Count -eq 0) {
    Write-Output "ERROR: DNS resolution failed for $Domain"
    exit 1
}

$elapsedMs = $stopwatch.Elapsed.TotalMilliseconds
Write-Output "Resolution time: $($elapsedMs.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)) ms"
Write-Output 'Records:'
foreach ($record in $records) {
    Write-Output "  $($record.IPAddress)"
}

if ($elapsedMs -gt 500) {
    Write-Output 'WARNING: DNS resolution is slow (>500ms)'
}
