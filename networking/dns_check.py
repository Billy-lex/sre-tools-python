import socket
import sys
import logging
import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)


def resolve_dns(domain: str) -> None:
    """Resolve DNS records for a domain and report latency."""
    logging.info(f"Resolving DNS for: {domain}")

    start = time.time()
    try:
        addresses = socket.getaddrinfo(domain, None, socket.AF_UNSPEC, socket.SOCK_STREAM)
        elapsed_ms = (time.time() - start) * 1000
    except socket.gaierror as e:
        logging.error(f"DNS resolution failed for {domain}: {e}")
        sys.exit(1)

    seen = set()
    unique_addrs = []
    for family, _, _, _, sockaddr in addresses:
        ip = sockaddr[0]
        family_name = "IPv4" if family == socket.AF_INET else "IPv6"
        key = (ip, family_name)
        if key not in seen:
            seen.add(key)
            unique_addrs.append(key)

    logging.info(f"Resolution time: {elapsed_ms:.2f} ms")
    logging.info(f"Found {len(unique_addrs)} record(s):")
    for ip, family_name in unique_addrs:
        logging.info(f"  {family_name}: {ip}")

    if elapsed_ms > 500:
        logging.warning("DNS resolution is slow (>500ms)")


def main() -> None:
    if len(sys.argv) < 2:
        logging.error(f"Usage: {sys.argv[0]} <domain>")
        sys.exit(1)

    resolve_dns(sys.argv[1])


if __name__ == "__main__":
    main()
