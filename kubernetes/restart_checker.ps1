# Check Kubernetes pod restart counts and alert above a threshold.
# PowerShell port of restart_checker.sh for Windows PowerShell 5.1 and PowerShell 7+.

param(
    [Parameter(Position = 0)]
    [string]$Namespace = '',
    [int]$Threshold = 5
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

Write-Output 'Kubernetes Pod Restart Check'
Write-Output '============================'
Write-Output "Scope:     $scope"
Write-Output "Threshold: $Threshold"
Write-Output ''

$result = Invoke-Kubectl -Arguments (@('get', 'pods') + $scopeArgs + @('-o', 'json'))
if ($result.ExitCode -ne 0) {
    Write-Output 'ERROR: kubectl get pods failed (is kubectl installed and the cluster reachable?)'
    exit 2
}

$data = ($result.Output -join "`n") | ConvertFrom-Json
$pods = @(Get-PropertyValue $data 'items' @())

$checked = 0
$totalRestarts = 0
$overThreshold = 0

foreach ($pod in $pods) {
    $metadata = Get-PropertyValue $pod 'metadata' $null
    $ns = Get-PropertyValue $metadata 'namespace' ''
    $name = Get-PropertyValue $metadata 'name' ''

    if ($ns -eq '') { continue }

    $checked += 1

    # Sum restart counts across all containers of the pod
    $containerStatuses = Get-PropertyValue (Get-PropertyValue $pod 'status' $null) 'containerStatuses' @()
    $restarts = 0
    foreach ($container in @($containerStatuses)) {
        $restarts += [int](Get-PropertyValue $container 'restartCount' 0)
    }

    $totalRestarts += $restarts

    if ($restarts -gt $Threshold) {
        Write-Output ('{0,-25} {1,-45} restarts={2}  ALERT' -f $ns, $name, $restarts)
        $overThreshold += 1
    } elseif ($restarts -gt 0) {
        Write-Output ('{0,-25} {1,-45} restarts={2}' -f $ns, $name, $restarts)
    }
}

Write-Output ''
Write-Output 'Summary'
Write-Output '-------'
Write-Output "Checked:        $checked"
Write-Output "Total restarts: $totalRestarts"
Write-Output "Over threshold: $overThreshold"

if ($overThreshold -gt 0) {
    exit 1
}

exit 0
