#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <service1> [service2] ..."
    exit 2
fi

echo "Linux Service Health Check"
echo "=========================="
echo

healthy=0
unhealthy=0
unknown=0

for service in "$@"; do
    state=$(systemctl is-active "$service" 2>/dev/null) || true

    case "$state" in
        active)   status="RUNNING" ;;
        inactive) status="STOPPED" ;;
        failed)   status="FAILED" ;;
        *)        status="UNKNOWN" ;;
    esac

    printf "%-15s %s\n" "$service" "$status"

    case "$status" in
        RUNNING)           ((healthy++)) || true ;;
        STOPPED|FAILED)    ((unhealthy++)) || true ;;
        *)                 ((unknown++)) || true ;;
    esac
done

total=$((healthy + unhealthy + unknown))

echo
echo "Summary"
echo "-------"
echo "Checked:   $total"
echo "Healthy:   $healthy"
echo "Unhealthy: $unhealthy"
echo "Unknown:   $unknown"

if [ "$unhealthy" -gt 0 ] || [ "$unknown" -gt 0 ]; then
    exit 1
fi

exit 0
