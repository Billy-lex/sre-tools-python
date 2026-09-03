Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Format a byte count as a human-readable string (same buckets as the shell script)
function Format-Bytes {
    param([long]$Bytes)

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Bytes -ge 1073741824) {
        '{0} GB' -f ($Bytes / 1073741824.0).ToString('0.00', $culture)
    } elseif ($Bytes -ge 1048576) {
        '{0} MB' -f ($Bytes / 1048576.0).ToString('0.00', $culture)
    } elseif ($Bytes -ge 1024) {
        '{0} KB' -f ($Bytes / 1024.0).ToString('0.00', $culture)
    } else {
        "$Bytes B"
    }
}

$adapters = @(Get-NetAdapter)
Write-Output "Found $($adapters.Count) network interface(s) (excluding lo):"

foreach ($adapter in $adapters) {
    $ip = 'N/A'
    $address = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($address) {
        $ip = $address.IPAddress
    }

    $rxBytes = 0
    $txBytes = 0
    try {
        $stats = Get-NetAdapterStatistics -Name $adapter.Name -ErrorAction Stop
        $rxBytes = $stats.ReceivedBytes
        $txBytes = $stats.SentBytes
    } catch {
        # Statistics unavailable, report 0 like the shell script
    }

    Write-Output "  $($adapter.Name):"
    Write-Output "    IP:     $ip"
    Write-Output "    State:  $($adapter.Status)"
    Write-Output "    RX:     $(Format-Bytes $rxBytes)"
    Write-Output "    TX:     $(Format-Bytes $txBytes)"
}
