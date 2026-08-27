import subprocess
import sys
import logging
import re

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

DEFAULT_COUNT = 10
WARN_THRESHOLD_MS = 100
LOSS_THRESHOLD_PCT = 20


def ping(host: str, count: int) -> dict | None:
    """Run ping and parse latency statistics."""
    try:
        result = subprocess.run(
            ["ping", "-c", str(count), "-W", "3", host],
            capture_output=True, text=True, timeout=count * 5 + 10
        )
    except subprocess.TimeoutExpired:
        logging.error(f"Ping timed out for {host}")
        return None

    output = result.stdout

    loss_match = re.search(r"(\d+)% packet loss", output)
    rtt_match = re.search(r"rtt min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+)", output)

    if not loss_match:
        logging.error(f"Failed to parse ping output for {host}")
        return None

    stats = {
        "loss_pct": float(loss_match.group(1)),
    }

    if rtt_match:
        stats["min_ms"] = float(rtt_match.group(1))
        stats["avg_ms"] = float(rtt_match.group(2))
        stats["max_ms"] = float(rtt_match.group(3))
        stats["mdev_ms"] = float(rtt_match.group(4))

    return stats


def main() -> None:
    if len(sys.argv) < 2:
        logging.error(f"Usage: {sys.argv[0]} <host> [count]")
        sys.exit(1)

    host = sys.argv[1]
    count = int(sys.argv[2]) if len(sys.argv) >= 3 else DEFAULT_COUNT

    logging.info(f"Monitoring latency to {host} ({count} pings)")

    stats = ping(host, count)
    if stats is None:
        sys.exit(1)

    logging.info(f"Packet loss: {stats['loss_pct']}%")

    if "avg_ms" in stats:
        logging.info(f"Latency: min={stats['min_ms']} ms  avg={stats['avg_ms']} ms  max={stats['max_ms']} ms  mdev={stats['mdev_ms']} ms")

        if stats["avg_ms"] > WARN_THRESHOLD_MS:
            logging.warning(f"Average latency exceeds {WARN_THRESHOLD_MS}ms threshold")
    else:
        logging.warning("No successful ping replies received")

    if stats["loss_pct"] > LOSS_THRESHOLD_PCT:
        logging.warning(f"Packet loss exceeds {LOSS_THRESHOLD_PCT}% threshold")


if __name__ == "__main__":
    main()
