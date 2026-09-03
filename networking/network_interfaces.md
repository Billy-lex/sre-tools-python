# network_interfaces.py / network_interfaces.sh / network_interfaces.ps1

## Function
List all network interfaces (excluding loopback), showing IP address, operational state, and cumulative RX/TX traffic for each.

## Features
- Enumerate interfaces via /sys/class/net
- Display IPv4 address per interface
- Show operational state (up/down)
- Cumulative RX/TX bytes in human-readable format
- No external dependencies (Python uses /proc and ioctl)
- PowerShell implementation for Windows environments

## Usage
```bash
python3 networking/network_interfaces.py
./networking/network_interfaces.sh
```

```powershell
.\networking\network_interfaces.ps1
```
