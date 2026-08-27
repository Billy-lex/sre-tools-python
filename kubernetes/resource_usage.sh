#!/usr/bin/env bash
set -euo pipefail

THRESHOLD=80
TARGET="nodes"
NAMESPACE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --pods)
            TARGET="pods"
            ;;
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

if [ "$TARGET" = "pods" ]; then
    if [ -n "$NAMESPACE" ]; then
        scope="pods in namespace $NAMESPACE"
    else
        scope="pods in all namespaces"
    fi
else
    scope="cluster nodes"
fi

echo "Kubernetes Resource Usage Check"
echo "==============================="
echo "Scope:     $scope"
echo "Threshold: ${THRESHOLD}%"
echo

if [ "$TARGET" = "pods" ] && [ -n "$NAMESPACE" ]; then
    top_output=$(kubectl top pods --namespace "$NAMESPACE" --no-headers 2>/dev/null) || {
        echo "ERROR: kubectl top failed (is metrics-server installed and the cluster reachable?)"
        exit 2
    }
elif [ "$TARGET" = "pods" ]; then
    top_output=$(kubectl top pods --all-namespaces --no-headers 2>/dev/null) || {
        echo "ERROR: kubectl top failed (is metrics-server installed and the cluster reachable?)"
        exit 2
    }
else
    top_output=$(kubectl top nodes --no-headers 2>/dev/null) || {
        echo "ERROR: kubectl top failed (is metrics-server installed and the cluster reachable?)"
        exit 2
    }
fi

report=$(printf '%s\n' "$top_output" | awk -v threshold="$THRESHOLD" -v target="$TARGET" '
    function pct(field) {
        if (field ~ /%$/) {
            sub(/%$/, "", field)
            return field + 0
        }
        return -1
    }

    NF == 0 { next }

    {
        if (target == "nodes") {
            # Columns: NAME CPU(cores) CPU% MEMORY(bytes) MEMORY%
            identity = $1; cpuraw = $3; memraw = $5
        } else if (NF == 6) {
            # Columns: NAMESPACE NAME CPU(cores) MEMORY(bytes) CPU% MEMORY%
            identity = $1 "/" $2; cpuraw = $5; memraw = $6
        } else {
            # Columns: NAME CPU(cores) MEMORY(bytes) CPU% MEMORY%
            identity = $1; cpuraw = $4; memraw = $5
        }

        cpu = pct(cpuraw)
        mem = pct(memraw)

        alert = (cpu >= threshold && cpu >= 0) || (mem >= threshold && mem >= 0)

        printf "%-60s cpu=%-8s memory=%-8s %s\n", identity, cpuraw, memraw, (alert ? "ALERT" : "OK")

        total++
        if (alert) alerted++
    }

    END {
        print ""
        print "Summary"
        print "-------"
        printf "Checked:        %d\n", total
        printf "Over threshold: %d\n", alerted
        if (alerted > 0) exit 1
    }
') || {
    printf '%s\n' "$report"
    exit 1
}

printf '%s\n' "$report"
exit 0
