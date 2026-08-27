import socket
import sys
import time
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

DEFAULT_COUNT = 4
DEFAULT_PORT = 80
TIMEOUT = 3


def tcp_ping(host: str, port: int, seq: int) -> float | None:
    """Send a TCP ping to host:port and return latency in ms, or None on failure."""
    try:
        start = time.time()
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(TIMEOUT)
            sock.connect((host, port))
        elapsed_ms = (time.time() - start) * 1000
        logging.info(f"Reply from {host}:{port} seq={seq} time={elapsed_ms:.2f} ms")
        return elapsed_ms
    except socket.timeout:
        logging.warning(f"Request timed out seq={seq}")
        return None
    except Exception as e:
        logging.error(f"Error seq={seq}: {e}")
        return None


def main() -> None:
    if len(sys.argv) < 2:
        logging.error(f"Usage: {sys.argv[0]} <host> [port] [count]")
        sys.exit(1)

    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) >= 3 else DEFAULT_PORT
    count = int(sys.argv[3]) if len(sys.argv) >= 4 else DEFAULT_COUNT

    logging.info(f"TCP PING {host}:{port} count={count}")

    latencies = []
    lost = 0

    for i in range(1, count + 1):
        result = tcp_ping(host, port, i)
        if result is not None:
            latencies.append(result)
        else:
            lost += 1
        if i < count:
            time.sleep(1)

    logging.info("--- statistics ---")
    sent = count
    received = len(latencies)
    loss_pct = (lost / sent) * 100
    logging.info(f"{sent} packets sent, {received} received, {loss_pct:.1f}% loss")

    if latencies:
        logging.info(f"min={min(latencies):.2f} ms  avg={sum(latencies)/len(latencies):.2f} ms  max={max(latencies):.2f} ms")


if __name__ == "__main__":
    main()
