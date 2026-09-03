# Check Kubernetes CPU and memory usage via kubectl top.
# PowerShell port of resource_usage.sh for Windows PowerShell 5.1 and PowerShell 7+.

param(
    [switch]$Pods,
    [int]$Threshold = 80,
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

function Get-Percent {
    # Parse a kubectl top percentage field like '42%' into a number, -1 otherwise
    param($Field)

    if ($null -ne $Field -and ([string]$Field).EndsWith('%')) {
        return [double]([string]$Field).TrimEnd('%')
    }
    return -1
}

function Get-Field {
    # Return the field at Index, or '' when the line has fewer fields
    param([string[]]$Fields, [int]$Index)

    if ($Index -lt $Fields.Count) { return $Fields[$Index] }
    return ''
}

if ($Pods) {
    if ($Namespace -ne '') {
        $scope = "pods in namespace $Namespace"
    } else {
        $scope = 'pods in all namespaces'
    }
} else {
    $scope = 'cluster nodes'
}

Write-Output 'Kubernetes Resource Usage Check'
Write-Output '==============================='
Write-Output "Scope:     $scope"
Write-Output "Threshold: $Threshold%"
Write-Output ''

if ($Pods) {
    if ($Namespace -ne '') {
        $topArgs = @('top', 'pods', '--namespace', $Namespace, '--no-headers')
    } else {
        $topArgs = @('top', 'pods', '--all-namespaces', '--no-headers')
    }
} else {
    $topArgs = @('top', 'nodes', '--no-headers')
}

$result = Invoke-Kubectl -Arguments $topArgs
if ($result.ExitCode -ne 0) {
    Write-Output 'ERROR: kubectl top failed (is metrics-server installed and the cluster reachable?)'
    exit 2
}

$total = 0
$alerted = 0

foreach ($line in @($result.Output)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }

    $fields = ([string]$line).Trim() -split '\s+'

    if ($Pods) {
        if ($fields.Count -eq 6) {
            # Columns: NAMESPACE NAME CPU(cores) MEMORY(bytes) CPU% MEMORY%
            $identity = "$($fields[0])/$($fields[1])"
            $cpuRaw = Get-Field $fields 4
            $memRaw = Get-Field $fields 5
        } else {
            # Columns: NAME CPU(cores) MEMORY(bytes) CPU% MEMORY%
            $identity = Get-Field $fields 0
            $cpuRaw = Get-Field $fields 3
            $memRaw = Get-Field $fields 4
        }
    } else {
        # Columns: NAME CPU(cores) CPU% MEMORY(bytes) MEMORY%
        $identity = Get-Field $fields 0
        $cpuRaw = Get-Field $fields 2
        $memRaw = Get-Field $fields 4
    }

    $cpu = Get-Percent $cpuRaw
    $mem = Get-Percent $memRaw

    $alert = (($cpu -ge $Threshold) -and ($cpu -ge 0)) -or (($mem -ge $Threshold) -and ($mem -ge 0))

    if ($alert) {
        $state = 'ALERT'
        $alerted += 1
    } else {
        $state = 'OK'
    }

    Write-Output ('{0,-60} cpu={1,-8} memory={2,-8} {3}' -f $identity, $cpuRaw, $memRaw, $state)

    $total += 1
}

Write-Output ''
Write-Output 'Summary'
Write-Output '-------'
Write-Output "Checked:        $total"
Write-Output "Over threshold: $alerted"

if ($alerted -gt 0) {
    exit 1
}

exit 0
