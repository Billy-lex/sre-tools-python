#!/usr/bin/env bash
set -euo pipefail

TIMEOUT=1
DEFAULT_PORTS="21 22 23 25 53 80 110 143 443 445 993 995 3306 3389 5432 6379 8080 8443"

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <host> [port1,port2,...]"
    exit 1
fi

host="$1"

if [ "$#" -ge 2 ]; then
    IFS=',' read -ra ports <<< "$2"
else
    read -ra ports <<< "$DEFAULT_PORTS"
fi

echo "Scanning $host ..."
open_count=0

for port in "${ports[@]}"; do
    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        echo "  PORT ${port}/tcp  OPEN"
        ((open_count++))
    fi
done

echo "Found ${open_count} open port(s)."
