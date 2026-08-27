#!/usr/bin/env bash
set -euo pipefail

TIMEOUT=3
passed=0
failed=0
failed_checks=""

echo "=== Connectivity Check ==="

echo "[1] DNS Check"
if host google.com >/dev/null 2>&1 || nslookup google.com >/dev/null 2>&1 || getent hosts google.com >/dev/null 2>&1; then
    echo "  DNS resolution: OK"
    ((passed++))
else
    echo "  DNS resolution: FAILED"
    ((failed++))
    failed_checks+="dns "
fi

echo "[2] ICMP Ping Check"
if ping -c 2 -W "$TIMEOUT" 8.8.8.8 >/dev/null 2>&1; then
    echo "  Ping 8.8.8.8: OK"
    ((passed++))
else
    echo "  Ping 8.8.8.8: FAILED"
    ((failed++))
    failed_checks+="ping "
fi

echo "[3] TCP Connectivity Check"
for target in "httpbin.org:80" "google.com:443"; do
    host="${target%%:*}"
    port="${target##*:}"
    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        echo "  TCP $host:$port: OK"
        ((passed++))
    else
        echo "  TCP $host:$port: FAILED"
        ((failed++))
        failed_checks+="tcp_$host "
    fi
done

total=$((passed + failed))
echo "=== Summary ==="
echo "Passed: $passed/$total"

if [ "$failed" -gt 0 ]; then
    echo "WARNING: Failed checks: $failed_checks"
    exit 1
else
    echo "All connectivity checks passed."
fi
