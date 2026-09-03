# Connectivity check (DNS, ICMP ping, TCP) - PowerShell port of connectivity_check.sh
# Runs on both Windows PowerShell 5.1 and PowerShell 7+

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-TcpPort {
    param(
        [string]$TargetHost,
        [int]$Port,
        [int]$TimeoutSeconds
    )
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($TargetHost, $Port)
        return $task.Wait($TimeoutSeconds * 1000)
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

$Timeout = 3
$passed = 0
$failed = 0
$failedChecks = ''

Write-Output '=== Connectivity Check ==='

Write-Output '[1] DNS Check'
$dnsOk = $false
try {
    if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
        $null = Resolve-DnsName -Name 'google.com' -ErrorAction Stop
        $dnsOk = $true
    }
} catch {
    $dnsOk = $false
}
if (-not $dnsOk) {
    # Fallback to nslookup, mirroring the host/nslookup/getent chain in the bash script
    $null = & nslookup google.com 2>&1
    if ($LASTEXITCODE -eq 0) { $dnsOk = $true }
}
if ($dnsOk) {
    Write-Output '  DNS resolution: OK'
    $passed++
} else {
    Write-Output '  DNS resolution: FAILED'
    $failed++
    $failedChecks += 'dns '
}

Write-Output '[2] ICMP Ping Check'
$pingOk = $false
try {
    $pingOk = [bool](Test-Connection -ComputerName '8.8.8.8' -Count 2 -Quiet -ErrorAction SilentlyContinue)
} catch {
    $pingOk = $false
}
if ($pingOk) {
    Write-Output '  Ping 8.8.8.8: OK'
    $passed++
} else {
    Write-Output '  Ping 8.8.8.8: FAILED'
    $failed++
    $failedChecks += 'ping '
}

Write-Output '[3] TCP Connectivity Check'
foreach ($target in 'httpbin.org:80', 'google.com:443') {
    $tcpHost = $target.Split(':')[0]
    $tcpPort = [int]$target.Split(':')[1]
    if (Test-TcpPort -TargetHost $tcpHost -Port $tcpPort -TimeoutSeconds $Timeout) {
        Write-Output "  TCP ${tcpHost}:${tcpPort}: OK"
        $passed++
    } else {
        Write-Output "  TCP ${tcpHost}:${tcpPort}: FAILED"
        $failed++
        $failedChecks += "tcp_$tcpHost "
    }
}

$total = $passed + $failed
Write-Output '=== Summary ==='
Write-Output "Passed: $passed/$total"

if ($failed -gt 0) {
    Write-Output "WARNING: Failed checks: $failedChecks"
    exit 1
} else {
    Write-Output 'All connectivity checks passed.'
}
