#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

domain="$1"
echo "Resolving DNS for: $domain"

start_time=$(date +%s%N)

if command -v dig &>/dev/null; then
    result=$(dig +short "$domain" 2>&1)
elif command -v nslookup &>/dev/null; then
    result=$(nslookup "$domain" 2>&1 | grep -A1 "Name:" | grep "Address" | awk '{print $2}')
elif command -v host &>/dev/null; then
    result=$(host "$domain" 2>&1 | grep "has address" | awk '{print $NF}')
else
    result=$(getent hosts "$domain" 2>&1 | awk '{print $1}')
fi

end_time=$(date +%s%N)
elapsed_ms=$(awk "BEGIN {printf \"%.2f\", ($end_time - $start_time) / 1000000}")

if [ -z "$result" ]; then
    echo "ERROR: DNS resolution failed for $domain"
    exit 1
fi

echo "Resolution time: ${elapsed_ms} ms"
echo "Records:"
echo "$result" | while read -r line; do
    echo "  $line"
done

if (( $(echo "$elapsed_ms 500" | awk '{if ($1 > $2) print 1; else print 0}') == 1 )); then
    echo "WARNING: DNS resolution is slow (>500ms)"
fi
