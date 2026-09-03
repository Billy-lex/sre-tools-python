# SSL/TLS certificate expiration check - PowerShell port of ssl_cert_check.sh
# Runs on both Windows PowerShell 5.1 and PowerShell 7+

param(
    [Parameter(Position = 0)]
    [string]$HostName,

    [Parameter(Position = 1)]
    [int]$Port = 443
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$WARN_DAYS = 30

if (-not $HostName) {
    Write-Output "Usage: $PSCommandPath <host> [port]"
    exit 1
}

Write-Output "Checking SSL certificate for ${HostName}:${Port}"

$tcpClient = $null
$sslStream = $null
$cert = $null

try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect($HostName, $Port)
    # Accept any certificate chain, like openssl s_client without verification
    $acceptAll = [System.Net.Security.RemoteCertificateValidationCallback]{ $true }
    $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, $acceptAll)
    $sslStream.AuthenticateAsClient($HostName)
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($sslStream.RemoteCertificate)
} catch {
    Write-Output 'ERROR: Failed to retrieve SSL certificate'
    exit 1
} finally {
    if ($null -ne $sslStream) { $sslStream.Dispose() }
    if ($null -ne $tcpClient) { $tcpClient.Dispose() }
}

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$expiryUtc = $cert.NotAfter.ToUniversalTime()
$daysLeft = [math]::Truncate(($expiryUtc - [datetime]::UtcNow).TotalDays)
$expiryText = '{0} {1} {2} {3} GMT' -f $expiryUtc.ToString('MMM', $inv), $expiryUtc.Day.ToString().PadLeft(2), $expiryUtc.ToString('HH:mm:ss', $inv), $expiryUtc.Year

Write-Output "Subject:  $($cert.Subject)"
Write-Output "Issuer:   $($cert.Issuer)"
Write-Output "Expiry:   $expiryText"
Write-Output "Days left: $daysLeft"

if ($daysLeft -lt 0) {
    Write-Output 'ERROR: Certificate has EXPIRED!'
} elseif ($daysLeft -le $WARN_DAYS) {
    Write-Output "WARNING: Certificate expires within $WARN_DAYS days!"
} else {
    Write-Output 'Certificate is valid.'
}

exit 0
