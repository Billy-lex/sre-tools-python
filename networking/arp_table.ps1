Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Get-Command arp -ErrorAction SilentlyContinue) {
    # Native arp utility available, dump its output (equivalent of `arp -n`)
    arp -a
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    exit 0
}

if (Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue) {
    # Fall back to Get-NetNeighbor with /proc/net/arp-style formatting
    Write-Output 'IP Address       MAC Address          Device       Flags'
    Write-Output '----------------------------------------------'
    foreach ($entry in @(Get-NetNeighbor)) {
        if ($entry.State -eq 'Reachable') {
            $flagStr = 'complete'
        } else {
            $flagStr = $entry.State
        }
        Write-Output ('{0,-18} {1,-20} {2,-12} {3}' -f $entry.IPAddress, $entry.LinkLayerAddress, $entry.InterfaceAlias, $flagStr)
    }
    exit 0
}

Write-Output 'ERROR: Cannot read ARP table'
exit 1
