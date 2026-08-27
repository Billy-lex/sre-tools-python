import argparse
import subprocess
import sys

# Alert when CPU or memory usage percentage reaches this value
DEFAULT_THRESHOLD = 80


def run_kubectl_top(target, namespace=None):
    """Run kubectl top and return non-empty output lines."""
    cmd = ["kubectl", "top", target, "--no-headers"]

    if target == "pods":
        if namespace:
            cmd += ["--namespace", namespace]
        else:
            cmd += ["--all-namespaces"]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "kubectl top failed")

    return [line for line in result.stdout.splitlines() if line.strip()]


def parse_percent(field):
    """Parse a kubectl top percentage field like '42%' into an int."""
    if field.endswith("%"):
        return int(field.rstrip("%"))

    return None


def main():
    parser = argparse.ArgumentParser(
        description="Check Kubernetes CPU and memory usage via kubectl top"
    )

    parser.add_argument(
        "--pods",
        action="store_true",
        help="Check pod usage instead of node usage"
    )

    parser.add_argument(
        "namespace",
        nargs="?",
        default=None,
        help="Namespace to check in --pods mode (default: all namespaces)"
    )

    parser.add_argument(
        "--threshold",
        type=int,
        default=DEFAULT_THRESHOLD,
        help=f"Usage percentage alert threshold (default: {DEFAULT_THRESHOLD})"
    )

    args = parser.parse_args()

    target = "pods" if args.pods else "nodes"

    if args.pods:
        scope = args.namespace or "all namespaces"
    else:
        scope = "cluster nodes"

    print("Kubernetes Resource Usage Check")
    print("===============================")
    print(f"Scope:     {scope}")
    print(f"Threshold: {args.threshold}%")
    print()

    try:
        lines = run_kubectl_top(target, args.namespace)
    except Exception as e:
        print(f"ERROR: {e}")
        return 2

    exceeded = []

    for line in lines:
        fields = line.split()

        if target == "nodes":
            # Columns: NAME CPU(cores) CPU% MEMORY(bytes) MEMORY%
            identity = fields[0]
            cpu_field = fields[2] if len(fields) > 4 else "-"
            memory_field = fields[4] if len(fields) > 4 else "-"
        elif len(fields) == 6:
            # Columns: NAMESPACE NAME CPU(cores) MEMORY(bytes) CPU% MEMORY%
            identity = f"{fields[0]}/{fields[1]}"
            cpu_field = fields[4]
            memory_field = fields[5]
        else:
            # Columns: NAME CPU(cores) MEMORY(bytes) CPU% MEMORY%
            identity = fields[0]
            cpu_field = fields[3] if len(fields) > 4 else "-"
            memory_field = fields[4] if len(fields) > 4 else "-"

        cpu_percent = parse_percent(cpu_field)
        memory_percent = parse_percent(memory_field)

        over_cpu = cpu_percent is not None and cpu_percent >= args.threshold
        over_memory = (
            memory_percent is not None and memory_percent >= args.threshold
        )

        if over_cpu or over_memory:
            exceeded.append(identity)
            state = "ALERT"
        else:
            state = "OK"

        print(f"{identity:<60} cpu={cpu_field:<8} memory={memory_field:<8} {state}")

    print()
    print("Summary")
    print("-------")
    print(f"Checked:        {len(lines)}")
    print(f"Over threshold: {len(exceeded)}")

    if exceeded:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
