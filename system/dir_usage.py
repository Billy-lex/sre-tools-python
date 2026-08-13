import os
import sys
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

def get_dir_size(path: str) -> int:
    """Calculate the total size of all files under a directory."""
    total_size = 0
    for root, _, files in os.walk(path):
        for file in files:
            file_path = os.path.join(root, file)
            total_size += os.path.getsize(file_path)
    return total_size

def main() -> None:
    if len(sys.argv) == 2:
        path = sys.argv[1]
    else:
        logging.error(f"Usage: {sys.argv[0]} [optional directory]")
        sys.exit(1)

    if not os.path.isdir(path):
        logging.error("Invalid directory: %s", path)
        sys.exit(1)

    total_bytes = get_dir_size(path)
    total_gb = total_bytes / (1024 ** 3)

    logging.info(f"Scanned Directory: {path}")
    logging.info(f"Total Size: {total_gb:.2f} GB")

if __name__ == "__main__":
    main()