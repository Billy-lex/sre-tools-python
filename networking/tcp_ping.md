# tcp_ping.py / tcp_ping.sh

## Function
Perform TCP ping to a target host:port, measuring connection latency over multiple rounds. Reports per-round latency and summary statistics (min/avg/max/loss).

## Features
- TCP-level connectivity check (works where ICMP ping is blocked)
- Configurable target port and probe count
- Per-round latency measurement
- Packet loss statistics
- Min/avg/max latency summary

## Usage
```bash
python3 networking/tcp_ping.py <host> [port] [count]
python3 networking/tcp_ping.py example.com 443 10
./networking/tcp_ping.sh <host> [port] [count]
```
