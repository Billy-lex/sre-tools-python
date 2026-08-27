import sys
import logging
import time
import urllib.request
import urllib.error

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

DEFAULT_TIMEOUT = 10


def http_check(url: str, timeout: int = DEFAULT_TIMEOUT) -> None:
    """Check HTTP endpoint availability and response time."""
    if not url.startswith("http"):
        url = "https://" + url

    logging.info(f"Checking {url} ...")

    start = time.time()
    try:
        req = urllib.request.Request(url, method="GET")
        req.add_header("User-Agent", "sre-http-check/1.0")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            elapsed_ms = (time.time() - start) * 1000
            status = resp.getcode()
            content_length = resp.headers.get("Content-Length", "unknown")
            server = resp.headers.get("Server", "unknown")

            logging.info(f"Status:  {status}")
            logging.info(f"Time:    {elapsed_ms:.2f} ms")
            logging.info(f"Server:  {server}")
            logging.info(f"Size:    {content_length} bytes")

            if status >= 400:
                logging.warning(f"HTTP error status: {status}")
            if elapsed_ms > 2000:
                logging.warning("Response time is slow (>2s)")

    except urllib.error.HTTPError as e:
        elapsed_ms = (time.time() - start) * 1000
        logging.error(f"HTTP Error {e.code}: {e.reason} ({elapsed_ms:.2f} ms)")
        sys.exit(1)
    except urllib.error.URLError as e:
        logging.error(f"Connection failed: {e.reason}")
        sys.exit(1)
    except Exception as e:
        logging.error(f"Check failed: {e}")
        sys.exit(1)


def main() -> None:
    if len(sys.argv) < 2:
        logging.error(f"Usage: {sys.argv[0]} <url> [timeout_seconds]")
        sys.exit(1)

    url = sys.argv[1]
    timeout = int(sys.argv[2]) if len(sys.argv) >= 3 else DEFAULT_TIMEOUT
    http_check(url, timeout)


if __name__ == "__main__":
    main()
