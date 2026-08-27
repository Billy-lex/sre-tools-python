#!/usr/bin/env bash
set -euo pipefail

echo "Kubernetes Node Health Check"
echo "============================"
echo

jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.conditions[?(@.type=="Ready")].status}{" "}{.status.conditions[?(@.type=="MemoryPressure")].status}{" "}{.status.conditions[?(@.type=="DiskPressure")].status}{" "}{.status.conditions[?(@.type=="PIDPressure")].status}{"\n"}{end}'

if ! nodes=$(kubectl get nodes -o jsonpath="$jsonpath" 2>/dev/null); then
    echo "ERROR: kubectl get nodes failed (is kubectl installed and the cluster reachable?)"
    exit 2
fi

checked=0
healthy=0
unhealthy=0
unhealthy_list=""

printf "%-35s %-8s %-8s %-8s %-8s\n" "NODE" "READY" "MEMORY" "DISK" "PID"
printf '%s\n' "-------------------------------------------------------------------"

while read -r name ready memory disk pid; do
    [ -z "$name" ] && continue

    checked=$((checked + 1))

    printf "%-35s %-8s %-8s %-8s %-8s\n" "$name" "$ready" "$memory" "$disk" "$pid"

    # A healthy node is Ready and reports no resource pressure
    if [ "$ready" = "True" ] && [ "$memory" = "False" ] && [ "$disk" = "False" ] && [ "$pid" = "False" ]; then
        healthy=$((healthy + 1))
    else
        unhealthy=$((unhealthy + 1))
        unhealthy_list="${unhealthy_list}  ${name}\n"
    fi
done <<< "$nodes"

echo
echo "Summary"
echo "-------"
echo "Checked:   $checked"
echo "Healthy:   $healthy"
echo "Unhealthy: $unhealthy"

if [ "$unhealthy" -gt 0 ]; then
    echo
    echo "Unhealthy nodes:"
    printf "%b" "$unhealthy_list"
    exit 1
fi

exit 0
