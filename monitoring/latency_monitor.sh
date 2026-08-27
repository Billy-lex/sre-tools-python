#!/usr/bin/env bash
set -euo pipefail

DEFAULT_COUNT=10
WARN_THRESHOLD_MS=100
LOSS_THRESHOLD_PCT=20

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <host> [count]"
    exit 1
fi

host="$1"
count="${2:-$DEFAULT_COUNT}"

echo "Monitoring latency to $host ($count pings)"

ping_output=$(ping -c "$count" -W 3 "$host" 2>&1) || true

loss=$(echo "$ping_output" | grep -oP '\d+(?=% packet loss)' || echo "100")
echo "Packet loss: ${loss}%"

rtt_line=$(echo "$ping_output" | grep "rtt min" || true)
if [ -n "$rtt_line" ]; then
    rtt_values=$(echo "$rtt_line" | grep -oP '[\d.]+/[\d.]+/[\d.]+/[\d.]+')
    echo "Latency: $rtt_line"

    avg_ms=$(echo "$rtt_values" | cut -d/ -f2)
    if (( $(echo "$avg_ms $WARN_THRESHOLD_MS" | awk '{if ($1 > $2) print 1; else print 0}') == 1 )); then
        echo "WARNING: Average latency exceeds ${WARN_THRESHOLD_MS}ms threshold"
    fi
else
    echo "WARNING: No successful ping replies received"
fi

if (( $(echo "$loss $LOSS_THRESHOLD_PCT" | awk '{if ($1 > $2) print 1; else print 0}') == 1 )); then
    echo "WARNING: Packet loss exceeds ${LOSS_THRESHOLD_PCT}% threshold"
fi
