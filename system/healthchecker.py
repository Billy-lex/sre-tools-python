import argparse
import subprocess
import sys


def check_service(service_name):
    """Check the current state of a systemd service."""

    result = subprocess.run(
        ["systemctl", "is-active", service_name],
        capture_output=True,
        text=True
    )

    state = result.stdout.strip()

    if result.returncode == 0 and state == "active":
        return "RUNNING"

    elif state == "inactive":
        return "STOPPED"

    elif state == "failed":
        return "FAILED"

    elif state == "unknown":
        return "UNKNOWN"

    return "UNKNOWN"


def main():
    parser = argparse.ArgumentParser(
        description="Check Linux systemd service health"
    )

    parser.add_argument(
        "services",
        nargs="+",
        help="Systemd services to check"
    )

    args = parser.parse_args()

    print("Linux Service Health Check")
    print("==========================")
    print()

    results = []

    for service in args.services:
        state = check_service(service)

        results.append((service, state))

        print(f"{service:<15} {state}")

    print()
    print("Summary")
    print("-------")

    healthy = sum(1 for _, state in results if state == "RUNNING")
    unhealthy = sum(
        1 for _, state in results
        if state == "STOPPED" or state == "FAILED"
    )
    unknown = sum(1 for _, state in results if state == "UNKNOWN")

    print(f"Checked:   {len(results)}")
    print(f"Healthy:   {healthy}")
    print(f"Unhealthy: {unhealthy}")
    print(f"Unknown:   {unknown}")

    if unhealthy > 0 or unknown > 0:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())