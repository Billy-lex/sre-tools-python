import shutil
import logging

# Basic logging config
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

# Disk usage alert threshold
THRESHOLD = 80.0


def check_disk_usage(path: str = "/") -> None:
    """Check local disk usage and trigger warning when exceeding threshold"""
    try:
        usage = shutil.disk_usage(path)

        total_gb = usage.total / (1024 ** 3)
        used_gb = usage.used / (1024 ** 3)
        free_gb = usage.free / (1024 ** 3)
        usage_percent = usage.used / usage.total * 100

        logging.info(f"Total: {total_gb:.2f} GB")
        logging.info(f"Used:  {used_gb:.2f} GB")
        logging.info(f"Free:  {free_gb:.2f} GB")
        logging.info(f"Usage: {usage_percent:.2f}%")

        if usage_percent >= THRESHOLD:
            logging.warning(f"Disk usage over threshold {THRESHOLD}% !")

    except Exception as e:
        logging.error(f"Disk check failed: {str(e)}")


if __name__ == "__main__":
    check_disk_usage("/")
