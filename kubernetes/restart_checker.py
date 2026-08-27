import argparse
import json
import subprocess
import sys

# Alert when a pod's total restart count exceeds this value
DEFAULT_THRESHOLD = 5


def get_pods(namespace=None):
    """Fetch pod list from the cluster using kubectl."""
    cmd = ["kubectl", "get", "pods", "--output=json"]

    if namespace:
        cmd += ["--namespace", namespace]
    else:
        cmd += ["--all-namespaces"]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "kubectl failed")

    return json.loads(result.stdout)["items"]


def main():
    parser = argparse.ArgumentParser(
        description="Check Kubernetes pod restart counts and alert above threshold"
    )

    parser.add_argument(
        "namespace",
        nargs="?",
        default=None,
        help="Namespace to check (default: all namespaces)"
    )

    parser.add_argument(
        "--threshold",
        type=int,
        default=DEFAULT_THRESHOLD,
        help=f"Restart count alert threshold (default: {DEFAULT_THRESHOLD})"
    )

    args = parser.parse_args()

    scope = args.namespace or "all namespaces"

    print("Kubernetes Pod Restart Check")
    print("============================")
    print(f"Scope:     {scope}")
    print(f"Threshold: {args.threshold}")
    print()

    try:
        pods = get_pods(args.namespace)
    except Exception as e:
        print(f"ERROR: {e}")
        return 2

    exceeded = []
    total_restarts = 0

    for pod in pods:
        metadata = pod.get("metadata", {})
        namespace = metadata.get("namespace", "-")
        name = metadata.get("name", "-")

        container_statuses = pod.get("status", {}).get("containerStatuses", [])

        restarts = sum(
            container.get("restartCount", 0)
            for container in container_statuses
        )

        total_restarts += restarts

        if restarts > args.threshold:
            exceeded.append((namespace, name, restarts))
            print(f"{namespace:<25} {name:<45} restarts={restarts}  ALERT")
        elif restarts > 0:
            print(f"{namespace:<25} {name:<45} restarts={restarts}")

    print()
    print("Summary")
    print("-------")
    print(f"Checked:        {len(pods)}")
    print(f"Total restarts: {total_restarts}")
    print(f"Over threshold: {len(exceeded)}")

    if exceeded:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
