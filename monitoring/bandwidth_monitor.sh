#!/usr/bin/env bash
set -euo pipefail

DEFAULT_INTERVAL=3
DEFAULT_COUNT=5

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <interface> [interval_seconds] [count]"
    exit 1
fi

iface="$1"
interval="${2:-$DEFAULT_INTERVAL}"
count="${3:-$DEFAULT_COUNT}"

if [ ! -d "/sys/class/net/$iface" ]; then
    echo "ERROR: Interface not found: $iface"
    exit 1
fi

state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo "unknown")
echo "Interface $iface state: $state"
echo "Monitoring bandwidth on $iface (interval=${interval}s, count=$count)"

format_rate() {
    local bps=$1
    if (( $(echo "$bps >= 1073741824" | bc -l) )); then
        awk "BEGIN {printf \"%.2f GB/s\", $bps / 1073741824}"
    elif (( $(echo "$bps >= 1048576" | bc -l) )); then
        awk "BEGIN {printf \"%.2f MB/s\", $bps / 1048576}"
    elif (( $(echo "$bps >= 1024" | bc -l) )); then
        awk "BEGIN {printf \"%.2f KB/s\", $bps / 1024}"
    else
        echo "${bps} B/s"
    fi
}

prev_rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes")
prev_tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes")

for ((i = 1; i <= count; i++)); do
    sleep "$interval"
    curr_rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes")
    curr_tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes")

    rx_rate=$(awk "BEGIN {printf \"%.2f\", ($curr_rx - $prev_rx) / $interval}")
    tx_rate=$(awk "BEGIN {printf \"%.2f\", ($curr_tx - $prev_tx) / $interval}")

    echo "Sample $i/$count:  RX: $(format_rate "$rx_rate")  |  TX: $(format_rate "$tx_rate")"

    prev_rx=$curr_rx
    prev_tx=$curr_tx
done
