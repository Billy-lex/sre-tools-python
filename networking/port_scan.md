# port_scan.py / port_scan.sh

## Function
Scan TCP ports on a target host to check which ones are open. Supports scanning a default list of common ports or user-specified ports.

## Features
- Concurrent port scanning with thread pool (Python)
- Default common port list (21, 22, 80, 443, 3306, 6379, 8080, etc.)
- Custom port list via command-line argument
- Service name resolution for open ports
- Host resolution validation
- Configurable timeout

## Usage
```bash
python3 networking/port_scan.py <host>
python3 networking/port_scan.py <host> 22,80,443
./networking/port_scan.sh <host>
./networking/port_scan.sh <host> 22,80,443
```
