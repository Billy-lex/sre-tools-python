# Check the health of Kubernetes cluster nodes.
# PowerShell port of node_health.sh for Windows PowerShell 5.1 and PowerShell 7+.

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

function Get-ConditionStatus {
    # Return the status of a node condition, or '' when the condition is absent
    param($Node, [string]$Type)

    $conditions = Get-PropertyValue (Get-PropertyValue $Node 'status' $null) 'conditions' @()
    foreach ($condition in @($conditions)) {
        if ((Get-PropertyValue $condition 'type' '') -eq $Type) {
            return (Get-PropertyValue $condition 'status' '')
        }
    }
    return ''
}

Write-Output 'Kubernetes Node Health Check'
Write-Output '============================'
Write-Output ''

$result = Invoke-Kubectl -Arguments @('get', 'nodes', '-o', 'json')
if ($result.ExitCode -ne 0) {
    Write-Output 'ERROR: kubectl get nodes failed (is kubectl installed and the cluster reachable?)'
    exit 2
}

$data = ($result.Output -join "`n") | ConvertFrom-Json
$nodes = @(Get-PropertyValue $data 'items' @())

$checked = 0
$healthy = 0
$unhealthy = 0
$unhealthyList = @()

Write-Output ('{0,-35} {1,-8} {2,-8} {3,-8} {4,-8}' -f 'NODE', 'READY', 'MEMORY', 'DISK', 'PID')
Write-Output ('-' * 67)

foreach ($node in $nodes) {
    $name = Get-PropertyValue (Get-PropertyValue $node 'metadata' $null) 'name' ''

    if ($name -eq '') { continue }

    $checked += 1

    $ready = Get-ConditionStatus $node 'Ready'
    $memory = Get-ConditionStatus $node 'MemoryPressure'
    $disk = Get-ConditionStatus $node 'DiskPressure'
    $pidPressure = Get-ConditionStatus $node 'PIDPressure'

    Write-Output ('{0,-35} {1,-8} {2,-8} {3,-8} {4,-8}' -f $name, $ready, $memory, $disk, $pidPressure)

    # A healthy node is Ready and reports no resource pressure
    if ($ready -eq 'True' -and $memory -eq 'False' -and $disk -eq 'False' -and $pidPressure -eq 'False') {
        $healthy += 1
    } else {
        $unhealthy += 1
        $unhealthyList += "  $name"
    }
}

Write-Output ''
Write-Output 'Summary'
Write-Output '-------'
Write-Output "Checked:   $checked"
Write-Output "Healthy:   $healthy"
Write-Output "Unhealthy: $unhealthy"

if ($unhealthy -gt 0) {
    Write-Output ''
    Write-Output 'Unhealthy nodes:'
    foreach ($line in $unhealthyList) {
        Write-Output $line
    }
    exit 1
}

exit 0
