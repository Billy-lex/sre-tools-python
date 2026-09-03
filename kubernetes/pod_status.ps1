# Check the status of Kubernetes pods and alert on unhealthy pods.
# PowerShell port of pod_status.sh for Windows PowerShell 5.1 and PowerShell 7+.

param(
    [Parameter(Position = 0)]
    [string]$Namespace = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

# Pod states that are considered healthy
$healthyStates = @('Running', 'Completed', 'Succeeded')

if ($Namespace -ne '') {
    $scopeArgs = @('--namespace', $Namespace)
    $scope = $Namespace
} else {
    $scopeArgs = @('--all-namespaces')
    $scope = 'all namespaces'
}

Write-Output 'Kubernetes Pod Status Check'
Write-Output '==========================='
Write-Output "Scope: $scope"
Write-Output ''

$result = Invoke-Kubectl -Arguments (@('get', 'pods') + $scopeArgs + @('--no-headers'))
if ($result.ExitCode -ne 0) {
    Write-Output 'ERROR: kubectl get pods failed (is kubectl installed and the cluster reachable?)'
    exit 2
}

$checked = 0
$healthy = 0
$unhealthy = 0
$unhealthyList = @()

foreach ($line in @($result.Output)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $fields = ([string]$line).Trim() -split '\s+'

    # With --all-namespaces the output has a leading NAMESPACE column
    if ($Namespace -ne '') {
        $ns = $Namespace
        $name = $fields[0]
        $status = $fields[2]
    } else {
        $ns = $fields[0]
        $name = $fields[1]
        $status = $fields[3]
    }

    $checked += 1

    if ($healthyStates -contains $status) {
        $healthy += 1
    } else {
        $unhealthy += 1
        $unhealthyList += "  ${ns}/${name}: ${status}"
    }

    Write-Output ('{0,-25} {1,-45} {2}' -f $ns, $name, $status)
}

Write-Output ''
Write-Output 'Summary'
Write-Output '-------'
Write-Output "Checked:   $checked"
Write-Output "Healthy:   $healthy"
Write-Output "Unhealthy: $unhealthy"

if ($unhealthy -gt 0) {
    Write-Output ''
    Write-Output 'Unhealthy pods:'
    foreach ($line in $unhealthyList) {
        Write-Output $line
    }
    exit 1
}

exit 0
