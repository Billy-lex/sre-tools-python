# HTTP endpoint availability check - PowerShell port of http_check.sh
# Runs on both Windows PowerShell 5.1 and PowerShell 7+

param(
    [Parameter(Position = 0)]
    [string]$Url,

    [Parameter(Position = 1)]
    [int]$Timeout = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Url) {
    Write-Output "Usage: $PSCommandPath <url> [timeout_seconds]"
    exit 1
}

# Normalize scheme like the shell version
if ($Url -notmatch '^https?://') {
    $Url = "https://$Url"
}

# Enable TLS 1.2 on top of whatever is already configured (older systems)
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Write-Output "Checking $Url ..."

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec $Timeout
    $httpCode = [int]$response.StatusCode
} catch {
    # Invoke-WebRequest throws for HTTP >= 400; read the status from the exception response
    $exResponse = $null
    if (@($_.Exception.PSObject.Properties.Name) -contains 'Response') {
        $exResponse = $_.Exception.Response
    }
    if ($null -eq $exResponse) {
        Write-Output 'ERROR: Connection failed'
        exit 1
    }
    $httpCode = [int]$exResponse.StatusCode
}
$stopwatch.Stop()

$elapsedMs = $stopwatch.Elapsed.TotalMilliseconds
$elapsedText = $elapsedMs.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)

Write-Output "Status:  $httpCode"
Write-Output "Time:    $elapsedText ms"

if ($httpCode -ge 400) {
    Write-Output "WARNING: HTTP error status: $httpCode"
}

if ($elapsedMs -gt 2000) {
    Write-Output 'WARNING: Response time is slow (>2s)'
}

exit 0
