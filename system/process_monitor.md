# process_monitor.py / process_monitor.sh / process_monitor.ps1

## Function

Sample the running processes of a host and report the top consumers by CPU or
resident memory, roll usage up per owning user, and alert when a process crosses
a CPU or RSS threshold.

## Features

* Rank processes by sampled CPU% or by resident set size
* Per-user rollup of process count, CPU% and RSS
* Machine-wide CPU utilisation, load average, memory and swap usage
* Configurable top-N, ranking metric and sampling interval
* Per-process CPU and RSS alert thresholds
* Optional `--user` filter for a single account
* JSON output for automation and dashboards
* Return meaningful exit codes
* Python implementation for infrastructure automation
* Bash implementation for convenient execution
* PowerShell implementation for Windows environments

## Why Python

This is a case where the Python version is clearly more convenient than the Bash
one:

* **Real sampling** — Python reads `/proc/<pid>/stat` twice and converts the
  jiffies delta into an instantaneous CPU%, so a process that spiked a second ago
  is caught. `ps` only exposes the average over the whole process lifetime, so the
  Bash version cannot see short spikes.
* **Numeric data instead of text columns** — CPU and RSS stay numbers all the way
  through the aggregation. Bash has to re-parse whitespace-aligned `ps` columns
  with `awk`, then sort them back with `sort -k`, and any field containing spaces
  (the command line) has to be re-joined by hand.
* **Reliable owner resolution** — Python maps the uid from `/proc/<pid>/status`
  through `pwd`, so `systemd-resolve` is reported in full. `ps` truncates long user
  names to `systemd+`, which the Bash version cannot undo.
* **Structured output** — the per-user rollup and the JSON report fall out of dicts
  and `round()`. In Bash the same JSON has to be assembled field by field with
  manual escaping of quotes and backslashes.

## Usage

```bash
python3 system/process_monitor.py
python3 system/process_monitor.py --metric rss --top 15
python3 system/process_monitor.py --cpu-threshold 50 --rss-threshold 512 --json
./system/process_monitor.sh --metric rss --top 15
./system/process_monitor.sh --user www-data --json
```

```powershell
.\system\process_monitor.ps1
.\system\process_monitor.ps1 -Metric rss -Top 15
.\system\process_monitor.ps1 -CpuThreshold 50 -RssThreshold 512 -Json
```

## Options

```text
--metric cpu|rss          Ranking metric (default: cpu)
--top N                   Processes to list (default: 10)
--interval SECONDS        Sampling window, Python and PowerShell only (default: 1.0)
--cpu-threshold PCT       Alert at or above this CPU% (default: 80.0)
--rss-threshold MB        Alert at or above this RSS in MB (default: 1024.0)
--user NAME               Only consider processes owned by NAME
--json                    Emit JSON instead of the text report
```

PowerShell uses `-Metric`, `-Top`, `-Interval`, `-CpuThreshold`, `-RssThreshold`,
`-User` and `-Json`.

CPU% is expressed per single core, the same convention as `top` and `ps`: a
process that saturates one core reads 100%, and a multi-threaded process on an
8-core host can read up to 800%.

## Example

```text
Linux Process Monitor
=====================
Host:       node-01
CPU cores:  8
Metric:     cpu
Interval:   1.0s
Thresholds: cpu>=80.0%  rss>=1024.0MB

Top 3 by CPU%
------------------------------------------------------------------------------
PID     USER                CPU%   RSS(MB)  CMD
4821    www-data            91.4     312.7  /usr/sbin/nginx -g daemon off;  ALERT
2210    root                12.6    1580.2  /usr/bin/java -Xmx2g -jar app.jar  ALERT
5133    billy                3.9      15.8  python3 system/process_monitor.py

Per-User Summary
----------------
USER              PROCS     CPU%    RSS(MB)
www-data             12    104.3     980.4
root                 38     18.1    2140.6
billy                23      5.8    2003.0

System Summary
--------------
Load avg (1m/5m/15m): 1.82 1.44 1.10
CPU usage:  34.7%
Memory:     6.20 / 15.60 GB (39.7%)
Swap used:  0.00 / 2.00 GB
Processes:  312
Over threshold: 2
```

## Implementation Differences

```text
Python      Reads /proc directly and samples twice, so CPU% is instantaneous.
Bash        Uses ps, whose CPU% is the lifetime average; -Interval is not
            available and the header prints "n/a". Long user names are truncated
            by ps (systemd+ instead of systemd-resolve).
PowerShell  Samples TotalProcessorTime twice like Python. Windows has no load
            average, so that line is replaced by Win32_Processor LoadPercentage,
            and "Swap" is reported as commit charge.
```

## Exit Codes

```text
0   No process crosses the CPU or RSS threshold
1   One or more processes cross a threshold
2   Invalid command-line usage, or the host state could not be collected
```
