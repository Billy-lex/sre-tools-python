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

echo "Kubernetes Pod Status Check"
echo "==========================="
echo "Scope: $scope"
echo

if ! pods=$(kubectl get pods "${scope_args[@]}" --no-headers 2>/dev/null); then
    echo "ERROR: kubectl get pods failed (is kubectl installed and the cluster reachable?)"
    exit 2
fi

checked=0
healthy=0
unhealthy=0
unhealthy_list=""

while read -r col1 col2 col3 col4 _rest; do
    [ -z "$col1" ] && continue

    # With --all-namespaces the output has a leading NAMESPACE column
    if [ -n "$NAMESPACE" ]; then
        ns="$NAMESPACE"
        name="$col1"
        status="$col3"
    else
        ns="$col1"
        name="$col2"
        status="$col4"
    fi

    checked=$((checked + 1))

    case "$status" in
        Running|Completed|Succeeded)
            healthy=$((healthy + 1))
            ;;
        *)
            unhealthy=$((unhealthy + 1))
            unhealthy_list="${unhealthy_list}  ${ns}/${name}: ${status}\n"
            ;;
    esac

    printf "%-25s %-45s %s\n" "$ns" "$name" "$status"
done <<< "$pods"

echo
echo "Summary"
echo "-------"
echo "Checked:   $checked"
echo "Healthy:   $healthy"
echo "Unhealthy: $unhealthy"

if [ "$unhealthy" -gt 0 ]; then
    echo
    echo "Unhealthy pods:"
    printf "%b" "$unhealthy_list"
    exit 1
fi

exit 0
