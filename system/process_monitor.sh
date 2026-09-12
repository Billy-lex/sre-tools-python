#!/usr/bin/env bash
set -euo pipefail

METRIC="cpu"
TOP=10
CPU_THRESHOLD=80.0
RSS_THRESHOLD=1024.0
USER_FILTER=""
JSON=0

usage() {
    cat <<EOF
Usage: $0 [--metric cpu|rss] [--top N] [--cpu-threshold PCT] [--rss-threshold MB] [--user NAME] [--json]

Note: per-process CPU% comes from ps and is the average over the whole
lifetime of the process, not a sampled instantaneous value.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --metric) METRIC="${2:?--metric requires a value}"; shift ;;
        --metric=*) METRIC="${1#*=}" ;;
        --top) TOP="${2:?--top requires a value}"; shift ;;
        --top=*) TOP="${1#*=}" ;;
        --cpu-threshold) CPU_THRESHOLD="${2:?--cpu-threshold requires a value}"; shift ;;
        --cpu-threshold=*) CPU_THRESHOLD="${1#*=}" ;;
        --rss-threshold) RSS_THRESHOLD="${2:?--rss-threshold requires a value}"; shift ;;
        --rss-threshold=*) RSS_THRESHOLD="${1#*=}" ;;
        --user) USER_FILTER="${2:?--user requires a value}"; shift ;;
        --user=*) USER_FILTER="${1#*=}" ;;
        --json) JSON=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [ "$METRIC" != "cpu" ] && [ "$METRIC" != "rss" ]; then
    echo "ERROR: --metric must be cpu or rss" >&2
    exit 2
fi

if ! [ "$TOP" -ge 1 ] 2>/dev/null; then
    echo "ERROR: --top must be at least 1" >&2
    exit 2
fi

if [ ! -r /proc/stat ] || [ ! -r /proc/meminfo ]; then
    echo "ERROR: /proc not readable (this tool requires a Linux kernel)" >&2
    exit 2
fi

cpu_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
host=$(hostname)

# Snapshot every process as tab separated rows:
# pid, user, cpu%, rss(MB), command
tsv=$(ps -ww -eo pid=,user=,pcpu=,rss=,args= | awk -v filter="$USER_FILTER" '
    {
        pid = $1; user = $2; cpu = $3; rss_mb = $4 / 1024
        cmd = ""
        for (i = 5; i <= NF; i++) { cmd = cmd (i > 5 ? " " : "") $i }
        if (cmd == "") { cmd = "[" pid "]" }
        if (filter != "" && user != filter) { next }
        printf "%s\t%s\t%.1f\t%.1f\t%s\n", pid, user, cpu, rss_mb, cmd
    }
')

# Column holding the selected metric inside the TSV rows
if [ "$METRIC" = "cpu" ]; then sort_key=3; else sort_key=4; fi

top_rows=$(printf '%s\n' "$tsv" | sort -t "$(printf '\t')" -k "${sort_key},${sort_key}" -nr | awk -v n="$TOP" 'NF && NR <= n')

user_rows=$(printf '%s\n' "$tsv" | awk -F '\t' '
    NF { procs[$2]++; cpu[$2] += $3; rss[$2] += $4 }
    END { for (u in procs) printf "%s\t%d\t%.1f\t%.1f\n", u, procs[u], cpu[u], rss[u] }
' | sort -t "$(printf '\t')" -k "$((sort_key + 1)),$((sort_key + 1))" -nr | awk -v n="$TOP" 'NR <= n')

exceeded=$(printf '%s\n' "$tsv" | awk -F '\t' -v c="$CPU_THRESHOLD" -v r="$RSS_THRESHOLD" '
    NF && ($3 + 0 >= c + 0 || $4 + 0 >= r + 0) { n++ } END { print n + 0 }
')

process_count=$(ps -e --no-headers | wc -l | tr -d ' ')
read -r load1 load5 load15 _ < /proc/loadavg

# Sample /proc/stat twice to derive machine-wide CPU utilisation
read -r total_before idle_before < <(awk '/^cpu /{idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print total, idle; exit}' /proc/stat)
sleep 0.5
read -r total_after idle_after < <(awk '/^cpu /{idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; print total, idle; exit}' /proc/stat)
cpu_usage=$(awk -v tb="$total_before" -v ib="$idle_before" -v ta="$total_after" -v ia="$idle_after" '
    BEGIN { dt = ta - tb; di = ia - ib; if (dt <= 0) { printf "0.0" } else { printf "%.1f", (1 - di / dt) * 100 } }
')

mem_total_gb=$(awk '/^MemTotal:/{printf "%.2f", $2 / 1024 / 1024}' /proc/meminfo)
mem_avail_gb=$(awk '/^MemAvailable:/{printf "%.2f", $2 / 1024 / 1024}' /proc/meminfo)
mem_used_pct=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{if(t>0) printf "%.1f", (t-a)/t*100; else print "0.0"}' /proc/meminfo)
swap_total_gb=$(awk '/^SwapTotal:/{printf "%.2f", $2 / 1024 / 1024}' /proc/meminfo)
swap_free_gb=$(awk '/^SwapFree:/{printf "%.2f", $2 / 1024 / 1024}' /proc/meminfo)

if [ "$JSON" -eq 1 ]; then
    json_escape() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g'; }

    echo "{"
    echo "  \"host\": \"$(printf '%s' "$host" | json_escape)\","
    echo "  \"cpu_cores\": $cpu_cores,"
    echo "  \"metric\": \"$METRIC\","
    echo "  \"cpu_usage_percent\": $cpu_usage,"
    echo "  \"load_average\": [$load1, $load5, $load15],"
    echo "  \"memory\": {"
    echo "    \"total_gb\": $mem_total_gb,"
    echo "    \"available_gb\": $mem_avail_gb,"
    echo "    \"used_percent\": $mem_used_pct,"
    echo "    \"swap_total_gb\": $swap_total_gb,"
    echo "    \"swap_free_gb\": $swap_free_gb"
    echo "  },"
    echo "  \"thresholds\": { \"cpu_percent\": $CPU_THRESHOLD, \"rss_mb\": $RSS_THRESHOLD },"
    echo "  \"process_count\": $process_count,"
    echo "  \"over_threshold\": $exceeded,"

    echo "  \"processes\": ["
    first=1
    while IFS="$(printf '\t')" read -r pid user cpu rss cmd; do
        [ -z "${pid:-}" ] && continue
        [ "$first" -eq 1 ] || echo ","
        first=0
        printf '    { "pid": %s, "user": "%s", "cpu_percent": %s, "rss_mb": %s, "command": "%s" }' \
            "$pid" "$(printf '%s' "$user" | json_escape)" "$cpu" "$rss" "$(printf '%s' "$cmd" | json_escape)"
    done <<< "$top_rows"
    [ "$first" -eq 1 ] || echo ""
    echo "  ],"

    echo "  \"users\": ["
    first=1
    while IFS="$(printf '\t')" read -r user procs cpu rss; do
        [ -z "${user:-}" ] && continue
        [ "$first" -eq 1 ] || echo ","
        first=0
        printf '    { "user": "%s", "processes": %s, "cpu_percent": %s, "rss_mb": %s }' \
            "$(printf '%s' "$user" | json_escape)" "$procs" "$cpu" "$rss"
    done <<< "$user_rows"
    [ "$first" -eq 1 ] || echo ""
    echo "  ]"
    echo "}"

    if [ "$exceeded" -gt 0 ]; then exit 1; fi
    exit 0
fi

echo "Linux Process Monitor"
echo "====================="
echo "Host:       $host"
echo "CPU cores:  $cpu_cores"
echo "Metric:     $METRIC"
echo "Interval:   n/a (ps lifetime average)"
echo "Thresholds: cpu>=${CPU_THRESHOLD}%  rss>=${RSS_THRESHOLD}MB"
echo

if [ "$METRIC" = "cpu" ]; then label="CPU%"; else label="RSS(MB)"; fi

echo "Top $(printf '%s\n' "$top_rows" | grep -c . || true) by $label"
echo "------------------------------------------------------------------------------"
printf "%-8s%-16s%8s%10s  %s\n" "PID" "USER" "CPU%" "RSS(MB)" "CMD"

while IFS="$(printf '\t')" read -r pid user cpu rss cmd; do
    [ -z "${pid:-}" ] && continue
    flag=$(awk -v c="$cpu" -v r="$rss" -v ct="$CPU_THRESHOLD" -v rt="$RSS_THRESHOLD" '
        BEGIN { print (c + 0 >= ct + 0 || r + 0 >= rt + 0) ? "  ALERT" : "" }')
    printf "%-8s%-16s%8.1f%10.1f  %s%s\n" "$pid" "$user" "$cpu" "$rss" "${cmd:0:44}" "$flag"
done <<< "$top_rows"

echo
echo "Per-User Summary"
echo "----------------"
printf "%-16s%7s%9s%11s\n" "USER" "PROCS" "CPU%" "RSS(MB)"

while IFS="$(printf '\t')" read -r user procs cpu rss; do
    [ -z "${user:-}" ] && continue
    printf "%-16s%7s%9.1f%11.1f\n" "$user" "$procs" "$cpu" "$rss"
done <<< "$user_rows"

echo
echo "System Summary"
echo "--------------"
printf "Load avg (1m/5m/15m): %.2f %.2f %.2f\n" "$load1" "$load5" "$load15"
echo "CPU usage:  ${cpu_usage}%"
echo "Memory:     ${mem_total_gb} GB total, ${mem_avail_gb} GB available (${mem_used_pct}% used)"
echo "Swap:       ${swap_total_gb} GB total, ${swap_free_gb} GB free"
echo "Processes:  $process_count"
echo "Over threshold: $exceeded"

if [ "$exceeded" -gt 0 ]; then
    exit 1
fi

exit 0
