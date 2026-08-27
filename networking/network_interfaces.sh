#!/usr/bin/env bash
set -euo pipefail

format_bytes() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        awk "BEGIN {printf \"%.2f GB\", $bytes / 1073741824}"
    elif (( bytes >= 1048576 )); then
        awk "BEGIN {printf \"%.2f MB\", $bytes / 1048576}"
    elif (( bytes >= 1024 )); then
        awk "BEGIN {printf \"%.2f KB\", $bytes / 1024}"
    else
        echo "${bytes} B"
    fi
}

interfaces=$(ls /sys/class/net/ | grep -v lo)
count=$(echo "$interfaces" | wc -l)

echo "Found $count network interface(s) (excluding lo):"

for iface in $interfaces; do
    ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "N/A")
    state=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo "unknown")
    rx_bytes=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx_bytes=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)

    echo "  $iface:"
    echo "    IP:     $ip"
    echo "    State:  $state"
    echo "    RX:     $(format_bytes "$rx_bytes")"
    echo "    TX:     $(format_bytes "$tx_bytes")"
done
