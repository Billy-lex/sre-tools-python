#!/usr/bin/env bash
set -euo pipefail

if command -v arp &>/dev/null; then
    arp_output=$(arp -n 2>/dev/null)
    echo "$arp_output"
elif [ -f /proc/net/arp ]; then
    echo "IP Address       MAC Address          Device       Flags"
    echo "----------------------------------------------"
    tail -n +2 /proc/net/arp | while read -r ip hw_type flags mac mask device; do
        if [ "$flags" = "0x2" ]; then
            flag_str="complete"
        else
            flag_str="$flags"
        fi
        printf "%-18s %-20s %-12s %s\n" "$ip" "$mac" "$device" "$flag_str"
    done
else
    echo "ERROR: Cannot read ARP table"
    exit 1
fi
