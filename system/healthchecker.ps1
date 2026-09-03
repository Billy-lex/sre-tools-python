param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Services
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($null -eq $Services -or $Services.Count -eq 0) {
    Write-Output "Usage: $PSCommandPath <service1> [service2] ..."
    exit 2
}

Write-Output "Linux Service Health Check"
Write-Output "=========================="
Write-Output ""

$healthy = 0
$unhealthy = 0
$unknown = 0

foreach ($service in $Services) {
    try {
        $svc = Get-Service -Name $service -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            $status = 'RUNNING'
        }
        elseif ($svc.Status -eq 'Stopped') {
            $status = 'STOPPED'
        }
        else {
            $status = 'UNKNOWN'
        }
    }
    catch {
        # Missing or inaccessible service
        $status = 'UNKNOWN'
    }

    Write-Output ("{0,-15} {1}" -f $service, $status)

    if ($status -eq 'RUNNING') {
        $healthy++
    }
    elseif ($status -eq 'STOPPED' -or $status -eq 'FAILED') {
        $unhealthy++
    }
    else {
        $unknown++
    }
}

$total = $healthy + $unhealthy + $unknown

Write-Output ""
Write-Output "Summary"
Write-Output "-------"
Write-Output "Checked:   $total"
Write-Output "Healthy:   $healthy"
Write-Output "Unhealthy: $unhealthy"
Write-Output "Unknown:   $unknown"

if ($unhealthy -gt 0 -or $unknown -gt 0) {
    exit 1
}

exit 0
