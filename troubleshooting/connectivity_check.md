# connectivity_check.py / connectivity_check.sh

## Function
Run a series of connectivity checks (DNS, ICMP ping, TCP) against common targets to quickly diagnose network issues. Reports per-check results and a pass/fail summary.

## Features
- DNS resolution check
- ICMP ping check
- TCP connectivity check to multiple targets
- Pass/fail summary with failed check details
- Non-zero exit code on any failure (useful for scripting)
- Configurable timeout

## Usage
```bash
python3 troubleshooting/connectivity_check.py
./troubleshooting/connectivity_check.sh
```
