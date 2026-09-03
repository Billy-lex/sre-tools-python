# http_check.py / http_check.sh / http_check.ps1

## Function
Check HTTP/HTTPS endpoint availability, report status code, response time, server info, and trigger warnings for error status or slow responses.

## Features
- HTTP status code check
- Response time measurement with slow warning (>2s)
- Server header and content length display
- Configurable timeout
- Auto-prepend https:// if no scheme given
- Follow redirects (shell version)
- PowerShell implementation for Windows environments

## Usage
```bash
python3 monitoring/http_check.py <url> [timeout]
python3 monitoring/http_check.py https://example.com 5
./monitoring/http_check.sh <url> [timeout]
.\monitoring\http_check.ps1 <url> [timeout]
.\monitoring\http_check.ps1 https://example.com 5
```
