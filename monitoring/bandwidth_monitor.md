# bandwidth_monitor.py / bandwidth_monitor.sh

## Function
Monitor real-time network bandwidth usage on a specified interface. Samples RX/TX throughput at configurable intervals and displays rates in human-readable format.

## Features
- Real-time RX/TX bandwidth monitoring
- Configurable sampling interval and sample count
- Human-readable rate formatting (B/s, KB/s, MB/s, GB/s)
- Interface state validation
- Read from /sys/class/net statistics (no external dependencies)

## Usage
```bash
python3 monitoring/bandwidth_monitor.py <interface> [interval] [count]
python3 monitoring/bandwidth_monitor.py eth0 5 10
./monitoring/bandwidth_monitor.sh <interface> [interval] [count]
```
