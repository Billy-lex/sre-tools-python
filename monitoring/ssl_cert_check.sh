#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PORT=443
WARN_DAYS=30

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <host> [port]"
    exit 1
fi

host="$1"
port="${2:-$DEFAULT_PORT}"

echo "Checking SSL certificate for $host:$port"

cert_end_date=$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

if [ -z "$cert_end_date" ]; then
    echo "ERROR: Failed to retrieve SSL certificate"
    exit 1
fi

subject=$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
issuer=$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')

expiry_epoch=$(date -d "$cert_end_date" +%s 2>/dev/null)
now_epoch=$(date +%s)
days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

echo "Subject:  $subject"
echo "Issuer:   $issuer"
echo "Expiry:   $cert_end_date"
echo "Days left: $days_left"

if [ "$days_left" -lt 0 ]; then
    echo "ERROR: Certificate has EXPIRED!"
elif [ "$days_left" -le "$WARN_DAYS" ]; then
    echo "WARNING: Certificate expires within $WARN_DAYS days!"
else
    echo "Certificate is valid."
fi
