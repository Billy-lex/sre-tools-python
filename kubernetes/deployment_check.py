import argparse
import json
import subprocess
import sys


def get_deployments(namespace=None):
    """Fetch deployment list from the cluster using kubectl."""
    cmd = ["kubectl", "get", "deployments", "--output=json"]

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
        description="Check Kubernetes deployment replica readiness"
    )

    parser.add_argument(
        "namespace",
        nargs="?",
        default=None,
        help="Namespace to check (default: all namespaces)"
    )

    args = parser.parse_args()

    scope = args.namespace or "all namespaces"

    print("Kubernetes Deployment Check")
    print("===========================")
    print(f"Scope: {scope}")
    print()

    try:
        deployments = get_deployments(args.namespace)
    except Exception as e:
        print(f"ERROR: {e}")
        return 2

    degraded = []
    scaled_down = 0

    print(f"{'NAMESPACE':<25} {'DEPLOYMENT':<40} {'READY':<12} STATE")
    print("-" * 90)

    for deployment in deployments:
        metadata = deployment.get("metadata", {})
        namespace = metadata.get("namespace", "-")
        name = metadata.get("name", "-")

        desired = deployment.get("spec", {}).get("replicas", 0)
        ready = deployment.get("status", {}).get("readyReplicas") or 0

        replicas = f"{ready}/{desired}"

        if desired == 0:
            # Intentionally scaled down, not a failure
            state = "SCALED-DOWN"
            scaled_down += 1
        elif ready == desired:
            state = "OK"
        else:
            state = "DEGRADED"
            degraded.append((namespace, name, ready, desired))

        print(f"{namespace:<25} {name:<40} {replicas:<12} {state}")

    print()
    print("Summary")
    print("-------")
    print(f"Checked:     {len(deployments)}")
    print(f"Healthy:     {len(deployments) - len(degraded) - scaled_down}")
    print(f"Scaled down: {scaled_down}")
    print(f"Degraded:    {len(degraded)}")

    if degraded:
        print()
        print("Degraded deployments:")

        for namespace, name, ready, desired in degraded:
            print(f"  {namespace}/{name}: {ready}/{desired} replicas ready")

        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
