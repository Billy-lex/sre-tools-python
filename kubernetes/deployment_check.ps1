# Check Kubernetes deployment replica readiness.
# PowerShell port of deployment_check.sh for Windows PowerShell 5.1 and PowerShell 7+.

param(
    [Parameter(Position = 0)]
    [string]$Namespace = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
    # StrictMode-safe property lookup on ConvertFrom-Json objects
    param($Object, [string]$Name, $Default)

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Invoke-Kubectl {
    # Run kubectl with stderr suppressed and report its exit code (mirrors `kubectl ... 2>/dev/null`)
    param([string[]]$Arguments)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = $null
    $exitCode = 1
    try {
        $output = & kubectl @Arguments 2> $null
        $exitCode = $LASTEXITCODE
    } catch {
        # kubectl not installed or not on PATH
        $exitCode = 1
    }
    $ErrorActionPreference = $previousPreference

    return [pscustomobject]@{ Output = $output; ExitCode = $exitCode }
}

if ($Namespace -ne '') {
    $scopeArgs = @('--namespace', $Namespace)
    $scope = $Namespace
} else {
    $scopeArgs = @('--all-namespaces')
    $scope = 'all namespaces'
}

Write-Output 'Kubernetes Deployment Check'
Write-Output '==========================='
Write-Output "Scope: $scope"
Write-Output ''

$result = Invoke-Kubectl -Arguments (@('get', 'deployments') + $scopeArgs + @('-o', 'json'))
if ($result.ExitCode -ne 0) {
    Write-Output 'ERROR: kubectl get deployments failed (is kubectl installed and the cluster reachable?)'
    exit 2
}

$data = ($result.Output -join "`n") | ConvertFrom-Json
$deployments = @(Get-PropertyValue $data 'items' @())

$checked = 0
$healthy = 0
$scaledDown = 0
$degraded = 0
$degradedList = @()

Write-Output ('{0,-25} {1,-40} {2,-12} {3}' -f 'NAMESPACE', 'DEPLOYMENT', 'READY', 'STATE')
Write-Output ('-' * 90)

foreach ($deployment in $deployments) {
    $metadata = Get-PropertyValue $deployment 'metadata' $null
    $ns = Get-PropertyValue $metadata 'namespace' ''
    $name = Get-PropertyValue $metadata 'name' ''

    if ($ns -eq '') { continue }

    $checked += 1

    # readyReplicas is absent from the API response until a replica is ready
    $desired = [int](Get-PropertyValue (Get-PropertyValue $deployment 'spec' $null) 'replicas' 0)
    $ready = [int](Get-PropertyValue (Get-PropertyValue $deployment 'status' $null) 'readyReplicas' 0)

    if ($desired -eq 0) {
        # Intentionally scaled down, not a failure
        $state = 'SCALED-DOWN'
        $scaledDown += 1
    } elseif ($ready -eq $desired) {
        $state = 'OK'
        $healthy += 1
    } else {
        $state = 'DEGRADED'
        $degraded += 1
        $degradedList += "  ${ns}/${name}: ${ready}/${desired} replicas ready"
    }

    Write-Output ('{0,-25} {1,-40} {2,-12} {3}' -f $ns, $name, "$ready/$desired", $state)
}

Write-Output ''
Write-Output 'Summary'
Write-Output '-------'
Write-Output "Checked:     $checked"
Write-Output "Healthy:     $healthy"
Write-Output "Scaled down: $scaledDown"
Write-Output "Degraded:    $degraded"

if ($degraded -gt 0) {
    Write-Output ''
    Write-Output 'Degraded deployments:'
    foreach ($line in $degradedList) {
        Write-Output $line
    }
    exit 1
}

exit 0
