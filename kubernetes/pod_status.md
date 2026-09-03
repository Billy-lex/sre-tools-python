# pod_status.py / pod_status.sh / pod_status.ps1

## Function

Check the status of Kubernetes pods in one or all namespaces and alert on pods that are not in a healthy state.

## Features

* Check pods in a given namespace or across all namespaces
* Detect unhealthy states such as `Pending`, `Failed`, `Unknown`, `CrashLoopBackOff`, `ImagePullBackOff`, `ErrImagePull` and `OOMKilled`
* Report pod restart counts
* Print a healthy/unhealthy summary
* Continue checking when individual pods are unhealthy
* Return meaningful exit codes
* Python implementation for infrastructure automation
* Bash implementation for convenient execution
* PowerShell implementation for Windows environments

## Usage

```bash
python3 kubernetes/pod_status.py kube-system
python3 kubernetes/pod_status.py              # all namespaces
./kubernetes/pod_status.sh kube-system
```

```powershell
.\kubernetes\pod_status.ps1 kube-system
.\kubernetes\pod_status.ps1                   # all namespaces
```

## Example

```text
Kubernetes Pod Status Check
===========================
Scope: kube-system

kube-system               coredns-5d78c9869d-abcde                  Running                   restarts=0
kube-system               etcd-node-1                               Running                   restarts=0
kube-system               broken-app-6f9b8d4c5-xyz12                CrashLoopBackOff          restarts=12

Summary
-------
Checked:   3
Healthy:   2
Unhealthy: 1

Unhealthy pods:
  kube-system/broken-app-6f9b8d4c5-xyz12: CrashLoopBackOff
```

## Exit Codes

```text
0   All pods are healthy
1   One or more pods are unhealthy
2   Invalid command-line usage or kubectl error
```
