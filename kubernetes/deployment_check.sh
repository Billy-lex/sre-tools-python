#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-}"

if [ -n "$NAMESPACE" ]; then
    scope_args=(--namespace "$NAMESPACE")
    scope="$NAMESPACE"
else
    scope_args=(--all-namespaces)
    scope="all namespaces"
fi

echo "Kubernetes Deployment Check"
echo "==========================="
echo "Scope: $scope"
echo

jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.replicas}{" "}{.status.readyReplicas}{"\n"}{end}'

if ! deployments=$(kubectl get deployments "${scope_args[@]}" -o jsonpath="$jsonpath" 2>/dev/null); then
    echo "ERROR: kubectl get deployments failed (is kubectl installed and the cluster reachable?)"
    exit 2
fi

checked=0
healthy=0
scaled_down=0
degraded=0
degraded_list=""

printf "%-25s %-40s %-12s %s\n" "NAMESPACE" "DEPLOYMENT" "READY" "STATE"
printf '%s\n' "------------------------------------------------------------------------------------------"

while read -r ns name desired ready; do
    [ -z "$ns" ] && continue

    checked=$((checked + 1))

    # readyReplicas is absent from the API response until a replica is ready
    [ -z "$desired" ] && desired=0
    [ -z "$ready" ] && ready=0

    if [ "$desired" -eq 0 ]; then
        # Intentionally scaled down, not a failure
        state="SCALED-DOWN"
        scaled_down=$((scaled_down + 1))
    elif [ "$ready" -eq "$desired" ]; then
        state="OK"
        healthy=$((healthy + 1))
    else
        state="DEGRADED"
        degraded=$((degraded + 1))
        degraded_list="${degraded_list}  ${ns}/${name}: ${ready}/${desired} replicas ready\n"
    fi

    printf "%-25s %-40s %-12s %s\n" "$ns" "$name" "${ready}/${desired}" "$state"
done <<< "$deployments"

echo
echo "Summary"
echo "-------"
echo "Checked:     $checked"
echo "Healthy:     $healthy"
echo "Scaled down: $scaled_down"
echo "Degraded:    $degraded"

if [ "$degraded" -gt 0 ]; then
    echo
    echo "Degraded deployments:"
    printf "%b" "$degraded_list"
    exit 1
fi

exit 0
