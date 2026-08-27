#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TIMEOUT=10

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <url> [timeout_seconds]"
    exit 1
fi

url="$1"
timeout="${2:-$DEFAULT_TIMEOUT}"

if [[ ! "$url" =~ ^https?:// ]]; then
    url="https://$url"
fi

echo "Checking $url ..."

start_time=$(date +%s%N)
http_code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time "$timeout" "$url" 2>/dev/null) || {
    echo "ERROR: Connection failed"
    exit 1
}
end_time=$(date +%s%N)

elapsed_ms=$(awk "BEGIN {printf \"%.2f\", ($end_time - $start_time) / 1000000}")

echo "Status:  $http_code"
echo "Time:    ${elapsed_ms} ms"

if [ "$http_code" -ge 400 ]; then
    echo "WARNING: HTTP error status: $http_code"
fi

if (( $(echo "$elapsed_ms 2000" | awk '{if ($1 > $2) print 1; else print 0}') == 1 )); then
    echo "WARNING: Response time is slow (>2s)"
fi
