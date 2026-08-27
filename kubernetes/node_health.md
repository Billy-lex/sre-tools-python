# node_health.py / node_health.sh

## Function

Check the health of Kubernetes cluster nodes, including Ready status and resource pressure conditions (`MemoryPressure`, `DiskPressure`, `PIDPressure`).

## Features

* Check the Ready condition of every cluster node
* Detect `MemoryPressure`, `DiskPressure` and `PIDPressure` conditions
* Human-readable node health table
* Healthy/unhealthy summary
* Return meaningful exit codes
* Python implementation for infrastructure automation
* Bash implementation for convenient execution

## Usage

```bash
python3 kubernetes/node_health.py
./kubernetes/node_health.sh
```

## Example

```text
Kubernetes Node Health Check
============================

NODE                                READY    MEMORY   DISK     PID
-------------------------------------------------------------------
node-1                              True     False    False    False
node-2                              True     False    False    False
node-3                              False    True     False    False

Summary
-------
Checked:   3
Healthy:   2
Unhealthy: 1

Unhealthy nodes:
  node-3
```

## Exit Codes

```text
0   All nodes are healthy
1   One or more nodes are unhealthy
2   Invalid command-line usage or kubectl error
```
