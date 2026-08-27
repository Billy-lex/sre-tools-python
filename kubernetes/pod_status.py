import argparse
import json
import subprocess
import sys

# Pod phases that are considered healthy
HEALTHY_PHASES = {"Running", "Succeeded", "Completed"}

# Waiting reasons that indicate a broken pod
UNHEALTHY_WAITING_REASONS = {
    "CrashLoopBackOff",
    "ImagePullBackOff",
    "ErrImagePull",
    "CreateContainerConfigError",
    "CreateContainerError",
    "InvalidImageName",
}


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


def pod_state(pod):
    """Derive a human-readable state for a pod."""
    status = pod.get("status", {})
    phase = status.get("phase", "Unknown")

    for container in status.get("containerStatuses", []):
        waiting = container.get("state", {}).get("waiting") or {}

        if waiting.get("reason") in UNHEALTHY_WAITING_REASONS:
            return waiting["reason"]

        terminated = container.get("state", {}).get("terminated") or {}

        if terminated.get("reason") == "OOMKilled":
            return "OOMKilled"

    return phase


def main():
    parser = argparse.ArgumentParser(
        description="Check Kubernetes pod status and alert on unhealthy pods"
    )

    parser.add_argument(
        "namespace",
        nargs="?",
        default=None,
        help="Namespace to check (default: all namespaces)"
    )

    args = parser.parse_args()

    scope = args.namespace or "all namespaces"

    print("Kubernetes Pod Status Check")
    print("===========================")
    print(f"Scope: {scope}")
    print()

    try:
        pods = get_pods(args.namespace)
    except Exception as e:
        print(f"ERROR: {e}")
        return 2

    unhealthy = []

    for pod in pods:
        metadata = pod.get("metadata", {})
        namespace = metadata.get("namespace", "-")
        name = metadata.get("name", "-")
        state = pod_state(pod)

        restarts = sum(
            container.get("restartCount", 0)
            for container in pod.get("status", {}).get("containerStatuses", [])
        )

        if state not in HEALTHY_PHASES:
            unhealthy.append((namespace, name, state))

        print(f"{namespace:<25} {name:<45} {state:<25} restarts={restarts}")

    print()
    print("Summary")
    print("-------")
    print(f"Checked:   {len(pods)}")
    print(f"Healthy:   {len(pods) - len(unhealthy)}")
    print(f"Unhealthy: {len(unhealthy)}")

    if unhealthy:
        print()
        print("Unhealthy pods:")

        for namespace, name, state in unhealthy:
            print(f"  {namespace}/{name}: {state}")

        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
