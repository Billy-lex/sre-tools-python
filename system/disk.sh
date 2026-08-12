#!/bin/bash

# Disk usage alert threshold
THRESHOLD=80

# Check disk usage
df_output=$(df -P / | tail -n 1)

# Extract values
total_kb=$(echo "$df_output" | awk '{print $2}')
used_kb=$(echo "$df_output" | awk '{print $3}')
free_kb=$(echo "$df_output" | awk '{print $4}')
usage_percent=$(echo "$df_output" | awk '{print $5}' | tr -d '%')

# Convert KB to GB
total_gb=$(awk "BEGIN {printf \"%.2f\", $total_kb / 1024 / 1024}")
used_gb=$(awk "BEGIN {printf \"%.2f\", $used_kb / 1024 / 1024}")
free_gb=$(awk "BEGIN {printf \"%.2f\", $free_kb / 1024 / 1024}")

echo "Total: ${total_gb} GB"
echo "Used:  ${used_gb} GB"
echo "Free:  ${free_gb} GB"
echo "Usage: ${usage_percent}%"

if [ "$usage_percent" -ge "$THRESHOLD" ]; then
    echo "WARNING: Disk usage over threshold ${THRESHOLD}%!"
fi