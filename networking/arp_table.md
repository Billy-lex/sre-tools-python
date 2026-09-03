# arp_table.py / arp_table.sh / arp_table.ps1

## Function
Read and display the system ARP (Address Resolution Protocol) table, showing IP-to-MAC address mappings for all known neighbors on the local network.

## Features
- Read ARP table from /proc/net/arp
- Display IP, MAC address, network device, and entry flags
- Formatted tabular output
- Fallback to `arp -n` command in shell script
- PowerShell implementation for Windows environments

## Usage
```bash
python3 networking/arp_table.py
./networking/arp_table.sh
```

```powershell
.\networking\arp_table.ps1
```
