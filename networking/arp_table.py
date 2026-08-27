import logging
import re
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)


def read_arp_table() -> list[dict]:
    """Read the system ARP table from /proc/net/arp."""
    entries = []
    try:
        with open("/proc/net/arp") as f:
            lines = f.readlines()
    except Exception as e:
        logging.error(f"Failed to read ARP table: {e}")
        sys.exit(1)

    for line in lines[1:]:
        parts = line.split()
        if len(parts) >= 6:
            entries.append({
                "ip": parts[0],
                "hw_type": parts[1],
                "flags": parts[2],
                "mac": parts[3],
                "mask": parts[4],
                "device": parts[5],
            })
    return entries


def main() -> None:
    entries = read_arp_table()

    if not entries:
        logging.info("ARP table is empty.")
        return

    logging.info(f"ARP table ({len(entries)} entries):")
    logging.info(f"  {'IP Address':<18} {'MAC Address':<20} {'Device':<12} {'Flags'}")
    logging.info(f"  {'-'*18} {'-'*20} {'-'*12} {'-'*6}")

    for entry in entries:
        flags = "complete" if entry["flags"] == "0x2" else f"0x{entry['flags']}"
        logging.info(
            f"  {entry['ip']:<18} {entry['mac']:<20} {entry['device']:<12} {flags}"
        )


if __name__ == "__main__":
    main()
