# latency_monitor.py / latency_monitor.sh

## Function
Monitor network latency to a target host using ICMP ping. Reports min/avg/max/mdev latency and packet loss, with configurable warning thresholds.

## Features
- ICMP ping-based latency measurement
- Min/avg/max/mdev latency statistics
- Packet loss percentage
- Warning on high average latency (>100ms, configurable)
- Warning on high packet loss (>20%, configurable)
- Parse ping output for structured reporting

## Usage
```bash
python3 monitoring/latency_monitor.py <host> [count]
python3 monitoring/latency_monitor.py 8.8.8.8 20
./monitoring/latency_monitor.sh <host> [count]
```
