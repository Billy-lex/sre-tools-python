# connectivity_check.py / connectivity_check.sh / connectivity_check.ps1

## Function
Run a series of connectivity checks (DNS, ICMP ping, TCP) against common targets to quickly diagnose network issues. Reports per-check results and a pass/fail summary.

## Features
- DNS resolution check
- ICMP ping check
- TCP connectivity check to multiple targets
- Pass/fail summary with failed check details
- Non-zero exit code on any failure (useful for scripting)
- Configurable timeout
- PowerShell implementation for Windows environments

## Usage
```bash
python3 troubleshooting/connectivity_check.py
./troubleshooting/connectivity_check.sh
.\troubleshooting\connectivity_check.ps1
```
