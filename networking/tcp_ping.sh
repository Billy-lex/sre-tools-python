#!/usr/bin/env bash
set -euo pipefail

TIMEOUT=3
DEFAULT_PORT=80
DEFAULT_COUNT=4

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <host> [port] [count]"
    exit 1
fi

host="$1"
port="${2:-$DEFAULT_PORT}"
count="${3:-$DEFAULT_COUNT}"

echo "TCP PING $host:$port count=$count"

sent=0
received=0
total_ms=0
min_ms=""
max_ms=""

for ((i = 1; i <= count; i++)); do
    ((sent++))
    start_time=$(date +%s%N)

    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        end_time=$(date +%s%N)
        elapsed_ms=$(awk "BEGIN {printf \"%.2f\", ($end_time - $start_time) / 1000000}")
        echo "Reply from $host:$port seq=$i time=${elapsed_ms} ms"
        ((received++))
        total_ms=$(awk "BEGIN {printf \"%.2f\", $total_ms + $elapsed_ms}")

        if [ -z "$min_ms" ] || (( $(echo "$elapsed_ms $min_ms" | awk '{if ($1 < $2) print 1; else print 0}') == 1 )); then
            min_ms="$elapsed_ms"
        fi
        if [ -z "$max_ms" ] || (( $(echo "$elapsed_ms $max_ms" | awk '{if ($1 > $2) print 1; else print 0}') == 1 )); then
            max_ms="$elapsed_ms"
        fi
    else
        echo "Request timed out seq=$i"
    fi

    if [ "$i" -lt "$count" ]; then
        sleep 1
    fi
done

echo "--- statistics ---"
lost=$((sent - received))
loss_pct=$(awk "BEGIN {printf \"%.1f\", ($lost / $sent) * 100}")
echo "$sent packets sent, $received received, ${loss_pct}% loss"

if [ "$received" -gt 0 ]; then
    avg_ms=$(awk "BEGIN {printf \"%.2f\", $total_ms / $received}")
    echo "min=${min_ms} ms  avg=${avg_ms} ms  max=${max_ms} ms"
fi
