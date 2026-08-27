#!/usr/bin/env bash
set -euo pipefail

THRESHOLD=5
NAMESPACE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --threshold)
            THRESHOLD="${2:?--threshold requires a value}"
            shift
            ;;
        --threshold=*)
            THRESHOLD="${1#*=}"
            ;;
        *)
            NAMESPACE="$1"
            ;;
    esac
    shift
done

if [ -n "$NAMESPACE" ]; then
    scope_args=(--namespace "$NAMESPACE")
    scope="$NAMESPACE"
else
    scope_args=(--all-namespaces)
    scope="all namespaces"
fi

echo "Kubernetes Pod Restart Check"
echo "============================"
echo "Scope:     $scope"
echo "Threshold: $THRESHOLD"
echo

jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.status.containerStatuses[*].restartCount}{"\n"}{end}'

if ! pods=$(kubectl get pods "${scope_args[@]}" -o jsonpath="$jsonpath" 2>/dev/null); then
    echo "ERROR: kubectl get pods failed (is kubectl installed and the cluster reachable?)"
    exit 2
fi

checked=0
total_restarts=0
over_threshold=0

while read -r ns name counts; do
    [ -z "$ns" ] && continue

    checked=$((checked + 1))

    # Sum restart counts across all containers of the pod
    restarts=0
    for count in $counts; do
        restarts=$((restarts + count))
    done

    total_restarts=$((total_restarts + restarts))

    if [ "$restarts" -gt "$THRESHOLD" ]; then
        printf "%-25s %-45s restarts=%s  ALERT\n" "$ns" "$name" "$restarts"
        over_threshold=$((over_threshold + 1))
    elif [ "$restarts" -gt 0 ]; then
        printf "%-25s %-45s restarts=%s\n" "$ns" "$name" "$restarts"
    fi
done <<< "$pods"

echo
echo "Summary"
echo "-------"
echo "Checked:        $checked"
echo "Total restarts: $total_restarts"
echo "Over threshold: $over_threshold"

if [ "$over_threshold" -gt 0 ]; then
    exit 1
fi

exit 0
