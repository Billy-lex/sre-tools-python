# resource_usage.py / resource_usage.sh / resource_usage.ps1

## Function

Check Kubernetes CPU and memory usage via `kubectl top` and alert when usage percentage reaches a threshold.

## Features

* Check node usage (default) or pod usage with `--pods`
* Optional namespace filter in pod mode
* Configurable usage percentage alert threshold (default: 80%)
* Requires metrics-server to be installed in the cluster
* Print a checked/over-threshold summary
* Return meaningful exit codes
* Python implementation for infrastructure automation
* Bash implementation for convenient execution
* PowerShell implementation for Windows environments

## Usage

```bash
python3 kubernetes/resource_usage.py
python3 kubernetes/resource_usage.py --pods production
python3 kubernetes/resource_usage.py --threshold 90
./kubernetes/resource_usage.sh --pods --threshold 90
```

```powershell
.\kubernetes\resource_usage.ps1
.\kubernetes\resource_usage.ps1 -pods production
.\kubernetes\resource_usage.ps1 -pods -threshold 90
```

## Example

```text
Kubernetes Resource Usage Check
===============================
Scope:     cluster nodes
Threshold: 80%

node-1                                                       cpu=12%      memory=45%     OK
node-2                                                       cpu=38%      memory=84%     ALERT
node-3                                                       cpu=21%      memory=52%     OK

Summary
-------
Checked:        3
Over threshold: 1
```

## Exit Codes

```text
0   No node/pod exceeds the usage threshold
1   One or more nodes/pods exceed the usage threshold
2   Invalid command-line usage, kubectl error or metrics-server unavailable
```
