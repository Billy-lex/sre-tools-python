import socket
import sys
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

DEFAULT_PORTS = [21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 993, 995, 3306, 3389, 5432, 6379, 8080, 8443]
TIMEOUT = 1


def scan_port(host: str, port: int) -> tuple[int, bool]:
    """Scan a single port on the target host."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(TIMEOUT)
            result = sock.connect_ex((host, port))
            return (port, result == 0)
    except Exception:
        return (port, False)


def scan_ports(host: str, ports: list[int]) -> None:
    """Scan multiple ports on the target host concurrently."""
    try:
        ip = socket.gethostbyname(host)
    except socket.gaierror:
        logging.error(f"Cannot resolve host: {host}")
        sys.exit(1)

    logging.info(f"Scanning {host} ({ip})")
    open_ports = []

    with ThreadPoolExecutor(max_workers=20) as pool:
        futures = {pool.submit(scan_port, host, p): p for p in ports}
        for future in as_completed(futures):
            port, is_open = future.result()
            if is_open:
                try:
                    service = socket.getservbyport(port, "tcp")
                except OSError:
                    service = "unknown"
                open_ports.append((port, service))

    open_ports.sort()
    if open_ports:
        logging.info(f"Found {len(open_ports)} open port(s):")
        for port, service in open_ports:
            logging.info(f"  PORT {port}/tcp  OPEN  ({service})")
    else:
        logging.info("No open ports found.")


def main() -> None:
    if len(sys.argv) < 2:
        logging.error(f"Usage: {sys.argv[0]} <host> [port1,port2,...]")
        sys.exit(1)

    host = sys.argv[1]

    if len(sys.argv) >= 3:
        ports = [int(p.strip()) for p in sys.argv[2].split(",")]
    else:
        ports = DEFAULT_PORTS

    scan_ports(host, ports)


if __name__ == "__main__":
    main()
