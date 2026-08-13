#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

path="$1"

if [ ! -d "$path" ]; then
    echo "ERROR: Invalid directory: $path"
    exit 1
fi

total_kb=$(du -sk "$path" | awk '{print $1}')
total_gb=$(awk "BEGIN {printf \"%.2f\", $total_kb / 1024 / 1024}")

echo "Scanned Directory: $path"
echo "Total Size: $total_gb GB"