import json
import subprocess
import sys


def get_nodes():
    """Fetch node list from the cluster using kubectl."""
    result = subprocess.run(
        ["kubectl", "get", "nodes", "--output=json"],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "kubectl failed")

    return json.loads(result.stdout)["items"]


def condition_status(node, condition_type):
    """Return the status of a node condition, or 'Unknown' when absent."""
    conditions = node.get("status", {}).get("conditions", [])

    for condition in conditions:
        if condition.get("type") == condition_type:
            return condition.get("status", "Unknown")

    return "Unknown"


def main():
    print("Kubernetes Node Health Check")
    print("============================")
    print()

    try:
        nodes = get_nodes()
    except Exception as e:
        print(f"ERROR: {e}")
        return 2

    unhealthy = []

    print(f"{'NODE':<35} {'READY':<8} {'MEMORY':<8} {'DISK':<8} {'PID':<8}")
    print("-" * 67)

    for node in nodes:
        name = node.get("metadata", {}).get("name", "-")

        ready = condition_status(node, "Ready")
        memory = condition_status(node, "MemoryPressure")
        disk = condition_status(node, "DiskPressure")
        pid = condition_status(node, "PIDPressure")

        print(f"{name:<35} {ready:<8} {memory:<8} {disk:<8} {pid:<8}")

        # A healthy node is Ready and reports no resource pressure
        if not (ready == "True" and memory == "False"
                and disk == "False" and pid == "False"):
            unhealthy.append(name)

    print()
    print("Summary")
    print("-------")
    print(f"Checked:   {len(nodes)}")
    print(f"Healthy:   {len(nodes) - len(unhealthy)}")
    print(f"Unhealthy: {len(unhealthy)}")

    if unhealthy:
        print()
        print("Unhealthy nodes:")

        for name in unhealthy:
            print(f"  {name}")

        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
