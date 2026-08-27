# ssl_cert_check.py / ssl_cert_check.sh

## Function
Check SSL/TLS certificate expiration for a given host. Reports subject, issuer, expiry date, and days remaining. Warns when the certificate is close to expiration or already expired.

## Features
- SSL certificate expiry check
- Display subject, issuer, and expiry date
- Days-remaining calculation
- Warning when certificate expires within 30 days (configurable)
- Error on expired certificates
- SNI support for virtual hosts

## Usage
```bash
python3 monitoring/ssl_cert_check.py <host> [port]
python3 monitoring/ssl_cert_check.py example.com 443
./monitoring/ssl_cert_check.sh <host> [port]
```
