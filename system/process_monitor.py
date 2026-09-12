import argparse
import json
import os
import pwd
import socket
import sys
import time

# Sampling window used to turn /proc CPU counters into a percentage
DEFAULT_INTERVAL = 1.0

# Number of processes listed in the top table
DEFAULT_TOP = 10

# Alert thresholds: CPU% is per single core (like top/ps), RSS is in MB
DEFAULT_CPU_THRESHOLD = 80.0
DEFAULT_RSS_THRESHOLD_MB = 1024.0

# Unit conversions read from the kernel so the tool is correct on any arch
CLK_TCK = os.sysconf("SC_CLK_TCK")
PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")


def read_proc(path: str):
    """Read a /proc text file, returning None when the entry is unreadable.

    Processes exit while we walk /proc, so a missing entry is normal and
    must not abort the whole scan.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except (FileNotFoundError, ProcessLookupError, PermissionError, OSError):
        return None


def cpu_ticks() -> tuple:
    """Return (total, idle) jiffies aggregated over all cores from /proc/stat."""
    content = read_proc("/proc/stat")
    if content is None:
        raise RuntimeError("/proc/stat is not readable")

    fields = content.splitlines()[0].split()[1:]
    values = [int(field) for field in fields]

    # fields: user nice system idle iowait irq softirq steal ...
    idle = values[3] + (values[4] if len(values) > 4 else 0)
    return sum(values), idle


def owner_name(uid: int, cache: dict) -> str:
    """Resolve a uid to a user name, caching lookups and tolerating unknown uids."""
    if uid not in cache:
        try:
            cache[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            cache[uid] = str(uid)
    return cache[uid]


def sample_processes(uid_cache: dict) -> dict:
    """Snapshot every process: CPU jiffies, RSS bytes, owner and command line."""
    samples = {}

    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue

        pid = int(entry)
        stat = read_proc(f"/proc/{pid}/stat")
        if stat is None:
            continue

        # comm is wrapped in parentheses and may contain spaces, so the
        # remaining fields are split from the last ')' onwards
        close = stat.rfind(")")
        fields = stat[close + 2:].split()
        if len(fields) < 22:
            continue

        comm = stat[stat.find("(") + 1:close]

        status = read_proc(f"/proc/{pid}/status")
        uid = -1
        if status is not None:
            for line in status.splitlines():
                if line.startswith("Uid:"):
                    uid = int(line.split()[1])
                    break

        cmdline = read_proc(f"/proc/{pid}/cmdline")
        if cmdline:
            command = " ".join(part for part in cmdline.split("\0") if part)
        else:
            command = f"[{comm}]"

        samples[pid] = {
            "pid": pid,
            "user": owner_name(uid, uid_cache),
            "command": command.strip() or f"[{comm}]",
            "cpu_ticks": int(fields[11]) + int(fields[12]),
            "rss_bytes": int(fields[21]) * PAGE_SIZE,
        }

    return samples


def memory_info() -> dict:
    """Read MemTotal/MemAvailable/SwapTotal/SwapFree from /proc/meminfo in bytes."""
    content = read_proc("/proc/meminfo")
    values = {}

    if content:
        for line in content.splitlines():
            key, _, rest = line.partition(":")
            values[key.strip()] = int(rest.split()[0]) * 1024

    return {
        "total_bytes": values.get("MemTotal", 0),
        "available_bytes": values.get("MemAvailable", 0),
        "swap_total_bytes": values.get("SwapTotal", 0),
        "swap_free_bytes": values.get("SwapFree", 0),
    }


def load_average() -> list:
    """Return the 1/5/15 minute load averages from /proc/loadavg."""
    content = read_proc("/proc/loadavg")
    if content is None:
        return [0.0, 0.0, 0.0]
    return [float(value) for value in content.split()[:3]]


def collect(interval: float) -> dict:
    """Take two samples `interval` seconds apart and derive CPU percentages."""
    uid_cache = {}

    before_procs = sample_processes(uid_cache)
    before_total, before_idle = cpu_ticks()

    time.sleep(interval)

    after_procs = sample_processes(uid_cache)
    after_total, after_idle = cpu_ticks()

    cpu_cores = os.cpu_count() or 1
    total_delta = max(after_total - before_total, 1)
    idle_delta = max(after_idle - before_idle, 0)

    processes = []
    for pid, after in after_procs.items():
        before = before_procs.get(pid)
        ticks_delta = after["cpu_ticks"] - before["cpu_ticks"] if before else 0

        # Scale by the core count so 100% means one fully busy core
        cpu_percent = ticks_delta / total_delta * 100 * cpu_cores

        processes.append({
            "pid": pid,
            "user": after["user"],
            "command": after["command"],
            "cpu_percent": round(cpu_percent, 1),
            "rss_mb": round(after["rss_bytes"] / (1024 ** 2), 1),
        })

    memory = memory_info()
    used_bytes = memory["total_bytes"] - memory["available_bytes"]

    return {
        "host": socket.gethostname(),
        "cpu_cores": cpu_cores,
        "interval_seconds": interval,
        "cpu_usage_percent": round((1 - idle_delta / total_delta) * 100, 1),
        "load_average": load_average(),
        "memory": {
            "total_gb": round(memory["total_bytes"] / (1024 ** 3), 2),
            "used_gb": round(used_bytes / (1024 ** 3), 2),
            "used_percent": round(used_bytes / memory["total_bytes"] * 100, 1)
            if memory["total_bytes"] else 0.0,
            "swap_total_gb": round(memory["swap_total_bytes"] / (1024 ** 3), 2),
            "swap_used_gb": round(
                (memory["swap_total_bytes"] - memory["swap_free_bytes"]) / (1024 ** 3), 2
            ),
        },
        "process_count": len(processes),
        "processes": processes,
    }


def summarize_by_user(processes: list) -> list:
    """Roll CPU% and RSS up per owning user."""
    users = {}

    for process in processes:
        entry = users.setdefault(
            process["user"], {"user": process["user"], "processes": 0, "cpu_percent": 0.0, "rss_mb": 0.0}
        )
        entry["processes"] += 1
        entry["cpu_percent"] += process["cpu_percent"]
        entry["rss_mb"] += process["rss_mb"]

    for entry in users.values():
        entry["cpu_percent"] = round(entry["cpu_percent"], 1)
        entry["rss_mb"] = round(entry["rss_mb"], 1)

    return list(users.values())


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sample /proc and report top processes by CPU or memory"
    )

    parser.add_argument(
        "--metric",
        choices=("cpu", "rss"),
        default="cpu",
        help="Ranking metric (default: cpu)"
    )

    parser.add_argument(
        "--top",
        type=int,
        default=DEFAULT_TOP,
        help=f"Number of processes to list (default: {DEFAULT_TOP})"
    )

    parser.add_argument(
        "--interval",
        type=float,
        default=DEFAULT_INTERVAL,
        help=f"Sampling window in seconds (default: {DEFAULT_INTERVAL})"
    )

    parser.add_argument(
        "--cpu-threshold",
        type=float,
        default=DEFAULT_CPU_THRESHOLD,
        help=f"Alert when a process uses at least this CPU%% (default: {DEFAULT_CPU_THRESHOLD})"
    )

    parser.add_argument(
        "--rss-threshold",
        type=float,
        default=DEFAULT_RSS_THRESHOLD_MB,
        help=f"Alert when a process holds at least this many MB of RSS (default: {DEFAULT_RSS_THRESHOLD_MB})"
    )

    parser.add_argument(
        "--user",
        default=None,
        help="Only consider processes owned by this user"
    )

    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON instead of the text report"
    )

    args = parser.parse_args()

    if args.top < 1:
        print("ERROR: --top must be at least 1")
        return 2

    if args.interval <= 0:
        print("ERROR: --interval must be greater than 0")
        return 2

    if not os.path.isdir("/proc"):
        print("ERROR: /proc not found (this tool requires a Linux kernel)")
        return 2

    try:
        report = collect(args.interval)
    except (RuntimeError, ValueError, OSError) as e:
        print(f"ERROR: {e}")
        return 2

    processes = report["processes"]
    if args.user:
        processes = [p for p in processes if p["user"] == args.user]

    key = "cpu_percent" if args.metric == "cpu" else "rss_mb"
    processes.sort(key=lambda p: p[key], reverse=True)

    exceeded = [
        p for p in processes
        if p["cpu_percent"] >= args.cpu_threshold or p["rss_mb"] >= args.rss_threshold
    ]
    exceeded_pids = {p["pid"] for p in exceeded}

    users = summarize_by_user(processes)
    users.sort(key=lambda u: u[key], reverse=True)

    report["metric"] = args.metric
    report["thresholds"] = {
        "cpu_percent": args.cpu_threshold,
        "rss_mb": args.rss_threshold,
    }
    report["processes"] = processes[:args.top]
    report["users"] = users[:args.top]
    report["over_threshold"] = len(exceeded)

    if args.json:
        print(json.dumps(report, indent=2))
        return 1 if exceeded else 0

    print("Linux Process Monitor")
    print("=====================")
    print(f"Host:       {report['host']}")
    print(f"CPU cores:  {report['cpu_cores']}")
    print(f"Metric:     {args.metric}")
    print(f"Interval:   {args.interval}s")
    print(f"Thresholds: cpu>={args.cpu_threshold}%  rss>={args.rss_threshold}MB")
    print()

    label = "CPU%" if args.metric == "cpu" else "RSS(MB)"
    print(f"Top {len(report['processes'])} by {label}")
    print("-" * 78)
    print(f"{'PID':<8}{'USER':<16}{'CPU%':>8}{'RSS(MB)':>10}  CMD")

    for process in report["processes"]:
        command = process["command"][:44]
        flag = "  ALERT" if process["pid"] in exceeded_pids else ""
        print(
            f"{process['pid']:<8}{process['user']:<16}"
            f"{process['cpu_percent']:>8.1f}{process['rss_mb']:>10.1f}  {command}{flag}"
        )

    print()
    print("Per-User Summary")
    print("----------------")
    print(f"{'USER':<16}{'PROCS':>7}{'CPU%':>9}{'RSS(MB)':>11}")

    for user in report["users"]:
        print(
            f"{user['user']:<16}{user['processes']:>7}"
            f"{user['cpu_percent']:>9.1f}{user['rss_mb']:>11.1f}"
        )

    memory = report["memory"]
    load = report["load_average"]

    print()
    print("System Summary")
    print("--------------")
    print(f"Load avg (1m/5m/15m): {load[0]:.2f} {load[1]:.2f} {load[2]:.2f}")
    print(f"CPU usage:  {report['cpu_usage_percent']:.1f}%")
    print(
        f"Memory:     {memory['used_gb']:.2f} / {memory['total_gb']:.2f} GB "
        f"({memory['used_percent']:.1f}%)"
    )
    print(f"Swap used:  {memory['swap_used_gb']:.2f} / {memory['swap_total_gb']:.2f} GB")
    print(f"Processes:  {report['process_count']}")
    print(f"Over threshold: {len(exceeded)}")

    if exceeded:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
