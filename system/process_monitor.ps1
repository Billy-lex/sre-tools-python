# Sample running processes and report the top consumers by CPU or memory.
# PowerShell port of process_monitor.py / process_monitor.sh for Windows PowerShell 5.1 and PowerShell 7+.

param(
    [Parameter(Position = 0)]
    [string]$Metric = 'cpu',
    [int]$Top = 10,
    [double]$Interval = 1.0,
    [double]$CpuThreshold = 80.0,
    [double]$RssThreshold = 1024.0,
    [string]$User = '',
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$invariant = [System.Globalization.CultureInfo]::InvariantCulture

function Get-PropertyValue {
    # StrictMode-safe property lookup on CIM objects
    param($Object, [string]$Name, $Default)

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Format-Number {
    param([double]$Value, [string]$Format = 'F1')

    return $Value.ToString($Format, $invariant)
}

if ($Metric -ne 'cpu' -and $Metric -ne 'rss') {
    [Console]::Error.WriteLine('ERROR: -Metric must be cpu or rss')
    exit 2
}

if ($Top -lt 1) {
    [Console]::Error.WriteLine('ERROR: -Top must be at least 1')
    exit 2
}

if ($Interval -le 0) {
    [Console]::Error.WriteLine('ERROR: -Interval must be greater than 0')
    exit 2
}

# --- first sample: total processor time per process -------------------------
$before = @{}
foreach ($proc in (Get-Process -ErrorAction SilentlyContinue)) {
    try {
        $before[$proc.Id] = $proc.TotalProcessorTime.TotalMilliseconds
    } catch {
        # Process exited, or its timing data is not readable (Idle, System)
    }
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Start-Sleep -Seconds $Interval
$stopwatch.Stop()
$elapsedMs = [math]::Max($stopwatch.Elapsed.TotalMilliseconds, 1)

# --- metadata: command line and owner come from WMI -------------------------
$commandLines = @{}
$owners = @{}
foreach ($item in (Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue)) {
    $procId = [int](Get-PropertyValue $item 'ProcessId' -1)
    if ($procId -lt 0) { continue }

    $commandLine = Get-PropertyValue $item 'CommandLine' ''
    if ($commandLine) { $commandLines[$procId] = $commandLine }

    try {
        $owner = Invoke-CimMethod -InputObject $item -MethodName GetOwner -ErrorAction Stop
        $ownerName = Get-PropertyValue $owner 'User' ''
        $ownerDomain = Get-PropertyValue $owner 'Domain' ''
        if ($ownerName -ne '') {
            if ($ownerDomain -ne '') { $owners[$procId] = "$ownerDomain\$ownerName" }
            else { $owners[$procId] = $ownerName }
        }
    } catch {
        # Owner is not exposed for processes owned by other accounts
    }
}

# --- second sample: derive CPU% and working set ----------------------------
$rows = New-Object System.Collections.Generic.List[object]
$processCount = 0

foreach ($proc in (Get-Process -ErrorAction SilentlyContinue)) {
    $processCount += 1

    if (-not $before.ContainsKey($proc.Id)) { continue }

    try {
        $deltaMs = $proc.TotalProcessorTime.TotalMilliseconds - $before[$proc.Id]
    } catch {
        continue
    }

    # Percentage of a single core, so a process saturating one core reads 100%
    $cpuPercent = [math]::Round($deltaMs / $elapsedMs * 100, 1)
    $rssMb = [math]::Round($proc.WorkingSet64 / 1MB, 1)

    if ($owners.ContainsKey($proc.Id)) { $ownerName = $owners[$proc.Id] } else { $ownerName = 'N/A' }
    if ($commandLines.ContainsKey($proc.Id)) { $command = $commandLines[$proc.Id] } else { $command = $proc.ProcessName }

    $rows.Add([pscustomobject]@{
        pid         = $proc.Id
        user        = $ownerName
        cpu_percent = $cpuPercent
        rss_mb      = $rssMb
        command     = $command
    })
}

if ($User -ne '') {
    $rows = @($rows | Where-Object { $_.user -eq $User })
}

if ($Metric -eq 'cpu') { $sortProperty = 'cpu_percent' } else { $sortProperty = 'rss_mb' }

$sorted = @($rows | Sort-Object -Property $sortProperty -Descending)
$topRows = @($sorted | Select-Object -First $Top)
$exceeded = @($sorted | Where-Object { $_.cpu_percent -ge $CpuThreshold -or $_.rss_mb -ge $RssThreshold })
$exceededIds = @{}
foreach ($item in $exceeded) { $exceededIds[$item.pid] = $true }

$userRows = @($rows |
    Group-Object -Property user |
    ForEach-Object {
        [pscustomobject]@{
            user        = $_.Name
            processes   = $_.Count
            cpu_percent = [math]::Round(($_.Group | Measure-Object -Property cpu_percent -Sum).Sum, 1)
            rss_mb      = [math]::Round(($_.Group | Measure-Object -Property rss_mb -Sum).Sum, 1)
        }
    } |
    Sort-Object -Property $sortProperty -Descending |
    Select-Object -First $Top)

# --- system wide figures ----------------------------------------------------
$cpuCores = [Environment]::ProcessorCount

$loadValues = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue |
    ForEach-Object { [double](Get-PropertyValue $_ 'LoadPercentage' 0) })
if ($loadValues.Count -gt 0) {
    $cpuUsage = [math]::Round(($loadValues | Measure-Object -Average).Average, 1)
} else {
    $cpuUsage = 0.0
}

$os = Get-CimInstance -ClassName Win32_OperatingSystem
$totalGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$availableGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedGb = [math]::Round($totalGb - $availableGb, 2)
if ($totalGb -gt 0) { $usedPercent = [math]::Round($usedGb / $totalGb * 100, 1) } else { $usedPercent = 0.0 }

$commitTotalGb = [math]::Round($os.TotalVirtualMemorySize / 1MB, 2)
$commitFreeGb = [math]::Round($os.FreeVirtualMemory / 1MB, 2)

$report = [pscustomobject]@{
    host                = $env:COMPUTERNAME
    cpu_cores           = $cpuCores
    metric              = $Metric
    interval_seconds    = $Interval
    cpu_usage_percent   = $cpuUsage
    memory              = [pscustomobject]@{
        total_gb     = $totalGb
        used_gb      = $usedGb
        used_percent = $usedPercent
        commit_total_gb = $commitTotalGb
        commit_free_gb  = $commitFreeGb
    }
    thresholds          = [pscustomobject]@{
        cpu_percent = $CpuThreshold
        rss_mb      = $RssThreshold
    }
    process_count       = $processCount
    over_threshold      = $exceeded.Count
    processes           = $topRows
    users               = $userRows
}

if ($Json) {
    Write-Output ($report | ConvertTo-Json -Depth 5)
    if ($exceeded.Count -gt 0) { exit 1 }
    exit 0
}

Write-Output 'Windows Process Monitor'
Write-Output '======================='
Write-Output "Host:       $($report.host)"
Write-Output "CPU cores:  $cpuCores"
Write-Output "Metric:     $Metric"
Write-Output "Interval:   $(Format-Number $Interval)s"
Write-Output "Thresholds: cpu>=$(Format-Number $CpuThreshold)%  rss>=$(Format-Number $RssThreshold 'F0')MB"
Write-Output ''

if ($Metric -eq 'cpu') { $label = 'CPU%' } else { $label = 'RSS(MB)' }
Write-Output "Top $($topRows.Count) by $label"
Write-Output '------------------------------------------------------------------------------'
Write-Output ('{0,-8}{1,-16}{2,8}{3,10}  {4}' -f 'PID', 'USER', 'CPU%', 'RSS(MB)', 'CMD')

foreach ($item in $topRows) {
    $flag = ''
    if ($exceededIds.ContainsKey($item.pid)) { $flag = '  ALERT' }
    $command = $item.command
    if ($command.Length -gt 44) { $command = $command.Substring(0, 44) }
    Write-Output ('{0,-8}{1,-16}{2,8}{3,10}  {4}{5}' -f `
        $item.pid, $item.user, (Format-Number $item.cpu_percent), (Format-Number $item.rss_mb), $command, $flag)
}

Write-Output ''
Write-Output 'Per-User Summary'
Write-Output '----------------'
Write-Output ('{0,-16}{1,7}{2,9}{3,11}' -f 'USER', 'PROCS', 'CPU%', 'RSS(MB)')

foreach ($item in $userRows) {
    Write-Output ('{0,-16}{1,7}{2,9}{3,11}' -f `
        $item.user, $item.processes, (Format-Number $item.cpu_percent), (Format-Number $item.rss_mb))
}

Write-Output ''
Write-Output 'System Summary'
Write-Output '--------------'
Write-Output "CPU usage:  $(Format-Number $cpuUsage)%"
Write-Output "Memory:     $(Format-Number $usedGb 'F2') / $(Format-Number $totalGb 'F2') GB ($(Format-Number $usedPercent)%)"
Write-Output "Commit:     $(Format-Number $commitFreeGb 'F2') / $(Format-Number $commitTotalGb 'F2') GB free"
Write-Output "Processes:  $processCount"
Write-Output "Over threshold: $($exceeded.Count)"

if ($exceeded.Count -gt 0) {
    exit 1
}

exit 0
