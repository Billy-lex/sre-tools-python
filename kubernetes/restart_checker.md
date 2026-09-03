# restart_checker.py / restart_checker.sh / restart_checker.ps1

## Function

Check Kubernetes pod restart counts and alert on pods whose total restart count exceeds a threshold, helping to spot crash-looping workloads.

## Features

* Check pods in a given namespace or across all namespaces
* Sum restart counts across all containers of each pod
* Configurable alert threshold (default: 5 restarts)
* Report cluster-wide total restart count
* Print a checked/total/over-threshold summary
* Return meaningful exit codes
* Python implementation for infrastructure automation
* Bash implementation for convenient execution
* PowerShell implementation for Windows environments

## Usage

```bash
python3 kubernetes/restart_checker.py kube-system
python3 kubernetes/restart_checker.py --threshold 10
./kubernetes/restart_checker.sh kube-system --threshold 10
```

```powershell
.\kubernetes\restart_checker.ps1 kube-system
.\kubernetes\restart_checker.ps1 kube-system -threshold 10
```

## Example

```text
Kubernetes Pod Restart Check
============================
Scope:     kube-system
Threshold: 5

kube-system               broken-app-6f9b8d4c5-xyz12                restarts=12  ALERT
kube-system               coredns-5d78c9869d-abcde                  restarts=2

Summary
-------
Checked:        2
Total restarts: 14
Over threshold: 1
```

## Exit Codes

```text
0   No pod exceeds the restart threshold
1   One or more pods exceed the restart threshold
2   Invalid command-line usage or kubectl error
```
