param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Require exactly one argument, like the bash version
if ($null -eq $Paths -or $Paths.Count -ne 1) {
    Write-Output "Usage: $PSCommandPath <directory>"
    exit 1
}

$path = $Paths[0]

if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    Write-Output "ERROR: Invalid directory: $path"
    exit 1
}

# Sum the size of all files under the directory, skipping unreadable entries
$totalBytes = 0
foreach ($file in (Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue)) {
    $totalBytes += $file.Length
}

$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$totalGb = [math]::Round($totalBytes / 1GB, 2).ToString('F2', $invariant)

Write-Output "Scanned Directory: $path"
Write-Output "Total Size: $totalGb GB"
