param(
    [Parameter(Position = 0)]
    [string]$TargetHost,

    [Parameter(Position = 1)]
    [string]$PortSpec
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TimeoutMs = 1000
$DefaultPorts = '21 22 23 25 53 80 110 143 443 445 993 995 3306 3389 5432 6379 8080 8443'

if (-not $TargetHost) {
    Write-Output "Usage: $PSCommandPath <host> [port1,port2,...]"
    exit 1
}

if ($PortSpec) {
    $ports = $PortSpec -split ','
} else {
    $ports = $DefaultPorts -split ' '
}

Write-Output "Scanning $TargetHost ..."
$openCount = 0

foreach ($port in $ports) {
    try {
        $portNumber = [int]$port
    } catch {
        # Invalid port entry, treat as closed like the shell script
        continue
    }

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($TargetHost, $portNumber)
        if ($task.Wait($TimeoutMs) -and $client.Connected) {
            Write-Output "  PORT $port/tcp  OPEN"
            $openCount++
        }
    } catch {
        # Connection refused or failed, treat as closed
    } finally {
        $client.Close()
    }
}

Write-Output "Found $openCount open port(s)."
