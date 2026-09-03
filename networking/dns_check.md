# dns_check.py / dns_check.sh / dns_check.ps1

## Function
Resolve DNS records for a given domain, display all A/AAAA records, and report resolution latency. Warns when resolution is slow.

## Features
- Resolve both IPv4 and IPv6 addresses
- Measure DNS resolution latency
- Slow query warning (>500ms)
- Multiple resolver backends (dig, nslookup, host, getent) for shell script
- Deduplication of results
- PowerShell implementation for Windows environments

## Usage
```bash
python3 networking/dns_check.py <domain>
./networking/dns_check.sh <domain>
```

```powershell
.\networking\dns_check.ps1 example.com
```
