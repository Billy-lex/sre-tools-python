import time
import sys
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

DEFAULT_INTERVAL = 3
DEFAULT_COUNT = 5


def read_bytes(iface: str) -> tuple[int, int]:
    """Read RX and TX bytes for a network interface."""
    with open(f"/sys/class/net/{iface}/statistics/rx_bytes") as f:
        rx = int(f.read().strip())
    with open(f"/sys/class/net/{iface}/statistics/tx_bytes") as f:
        tx = int(f.read().strip())
    return rx, tx


def format_rate(bytes_per_sec: float) -> str:
    """Format bytes/sec to human-readable rate."""
    for unit in ["B/s", "KB/s", "MB/s", "GB/s"]:
        if bytes_per_sec < 1024:
            return f"{bytes_per_sec:.2f} {unit}"
        bytes_per_sec /= 1024
    return f"{bytes_per_sec:.2f} TB/s"


def monitor_bandwidth(iface: str, interval: int, count: int) -> None:
    """Monitor network bandwidth usage on an interface."""
    logging.info(f"Monitoring bandwidth on {iface} (interval={interval}s, count={count})")

    prev_rx, prev_tx = read_bytes(iface)

    for i in range(1, count + 1):
        time.sleep(interval)
        curr_rx, curr_tx = read_bytes(iface)

        rx_rate = (curr_rx - prev_rx) / interval
        tx_rate = (curr_tx - prev_tx) / interval

        logging.info(
            f"Sample {i}/{count}:  RX: {format_rate(rx_rate)}  |  TX: {format_rate(tx_rate)}"
        )

        prev_rx, prev_tx = curr_rx, curr_tx


def main() -> None:
    if len(sys.argv) < 2:
        logging.error(f"Usage: {sys.argv[0]} <interface> [interval_seconds] [count]")
        sys.exit(1)

    iface = sys.argv[1]
    interval = int(sys.argv[2]) if len(sys.argv) >= 3 else DEFAULT_INTERVAL
    count = int(sys.argv[3]) if len(sys.argv) >= 4 else DEFAULT_COUNT

    try:
        with open(f"/sys/class/net/{iface}/operstate") as f:
            state = f.read().strip()
        logging.info(f"Interface {iface} state: {state}")
    except FileNotFoundError:
        logging.error(f"Interface not found: {iface}")
        sys.exit(1)

    monitor_bandwidth(iface, interval, count)


if __name__ == "__main__":
    main()
