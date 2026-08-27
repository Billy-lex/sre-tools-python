import socket
import fcntl
import struct
import logging
import subprocess
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)


def get_interfaces() -> list[str]:
    """List all network interface names from /proc/net/dev."""
    interfaces = []
    try:
        with open("/proc/net/dev") as f:
            for line in f:
                if ":" in line:
                    name = line.split(":")[0].strip()
                    if name != "lo":
                        interfaces.append(name)
    except Exception as e:
        logging.error(f"Failed to read interfaces: {e}")
        sys.exit(1)
    return interfaces


def get_ip_address(ifname: str) -> str:
    """Get the IPv4 address of a network interface."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        return socket.inet_ntoa(fcntl.ioctl(
            sock.fileno(),
            0x8915,
            struct.pack('256s', ifname.encode()[:15])
        ))
    except Exception:
        return "N/A"


def get_interface_stats(ifname: str) -> dict:
    """Get RX/TX byte counters for an interface."""
    try:
        with open(f"/sys/class/net/{ifname}/statistics/rx_bytes") as f:
            rx_bytes = int(f.read().strip())
        with open(f"/sys/class/net/{ifname}/statistics/tx_bytes") as f:
            tx_bytes = int(f.read().strip())
        with open(f"/sys/class/net/{ifname}/operstate") as f:
            state = f.read().strip()
        return {"rx_bytes": rx_bytes, "tx_bytes": tx_bytes, "state": state}
    except Exception:
        return {"rx_bytes": 0, "tx_bytes": 0, "state": "unknown"}


def format_bytes(n: int) -> str:
    """Format bytes to human-readable string."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if n < 1024:
            return f"{n:.2f} {unit}"
        n /= 1024
    return f"{n:.2f} PB"


def main() -> None:
    interfaces = get_interfaces()
    logging.info(f"Found {len(interfaces)} network interface(s) (excluding lo):")

    for iface in interfaces:
        ip = get_ip_address(iface)
        stats = get_interface_stats(iface)
        logging.info(f"  {iface}:")
        logging.info(f"    IP:     {ip}")
        logging.info(f"    State:  {stats['state']}")
        logging.info(f"    RX:     {format_bytes(stats['rx_bytes'])}")
        logging.info(f"    TX:     {format_bytes(stats['tx_bytes'])}")


if __name__ == "__main__":
    main()
