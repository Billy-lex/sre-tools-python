# network_interfaces.py / network_interfaces.sh

## Function
List all network interfaces (excluding loopback), showing IP address, operational state, and cumulative RX/TX traffic for each.

## Features
- Enumerate interfaces via /sys/class/net
- Display IPv4 address per interface
- Show operational state (up/down)
- Cumulative RX/TX bytes in human-readable format
- No external dependencies (Python uses /proc and ioctl)

## Usage
```bash
python3 networking/network_interfaces.py
./networking/network_interfaces.sh
```
