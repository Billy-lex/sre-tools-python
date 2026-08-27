import socket
import sys
import logging
import subprocess

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

DEFAULT_TARGETS = [
    ("dns", "8.8.8.8", 53),
    ("http", "httpbin.org", 80),
    ("https", "google.com", 443),
]

TIMEOUT = 3


def check_dns() -> bool:
    """Check DNS resolution."""
    try:
        socket.getaddrinfo("google.com", 443)
        logging.info("  DNS resolution: OK")
        return True
    except socket.gaierror:
        logging.error("  DNS resolution: FAILED")
        return False


def check_ping(host: str) -> bool:
    """Check ICMP connectivity to a host."""
    try:
        result = subprocess.run(
            ["ping", "-c", "2", "-W", str(TIMEOUT), host],
            capture_output=True, text=True, timeout=TIMEOUT * 3 + 5
        )
        if result.returncode == 0:
            logging.info(f"  Ping {host}: OK")
            return True
        else:
            logging.error(f"  Ping {host}: FAILED")
            return False
    except Exception:
        logging.error(f"  Ping {host}: FAILED (timeout)")
        return False


def check_tcp(host: str, port: int) -> bool:
    """Check TCP connectivity to a host:port."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(TIMEOUT)
            sock.connect((host, port))
            logging.info(f"  TCP {host}:{port}: OK")
            return True
    except Exception:
        logging.error(f"  TCP {host}:{port}: FAILED")
        return False


def main() -> None:
    logging.info("=== Connectivity Check ===")

    results = {}

    logging.info("[1] DNS Check")
    results["dns"] = check_dns()

    logging.info("[2] ICMP Ping Check")
    results["ping"] = check_ping("8.8.8.8")

    logging.info("[3] TCP Connectivity Check")
    for name, host, port in DEFAULT_TARGETS:
        results[f"tcp_{name}"] = check_tcp(host, port)

    logging.info("=== Summary ===")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    logging.info(f"Passed: {passed}/{total}")

    if passed < total:
        failed = [k for k, v in results.items() if not v]
        logging.warning(f"Failed checks: {', '.join(failed)}")
        sys.exit(1)
    else:
        logging.info("All connectivity checks passed.")


if __name__ == "__main__":
    main()
