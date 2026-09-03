# deployment_check.py / deployment_check.sh / deployment_check.ps1

## Function

Check Kubernetes deployment replica readiness by comparing desired replicas with ready replicas, and alert on degraded deployments.

## Features

* Check deployments in a given namespace or across all namespaces
* Compare desired replicas with ready replicas
* Distinguish healthy, degraded and intentionally scaled-down deployments
* Print a healthy/scaled-down/degraded summary
* Continue checking when individual deployments are degraded
* Return meaningful exit codes
* Python implementation for infrastructure automation
* Bash implementation for convenient execution
* PowerShell implementation for Windows environments

## Usage

```bash
python3 kubernetes/deployment_check.py production
python3 kubernetes/deployment_check.py        # all namespaces
./kubernetes/deployment_check.sh production
```

```powershell
.\kubernetes\deployment_check.ps1 production
.\kubernetes\deployment_check.ps1             # all namespaces
```

## Example

```text
Kubernetes Deployment Check
===========================
Scope: production

NAMESPACE                 DEPLOYMENT                               READY        STATE
------------------------------------------------------------------------------------------
production                api-server                               3/3          OK
production                worker                                   1/3          DEGRADED
staging                   batch-processor                          0/0          SCALED-DOWN

Summary
-------
Checked:     3
Healthy:     1
Scaled down: 1
Degraded:    1

Degraded deployments:
  production/worker: 1/3 replicas ready
```

## Exit Codes

```text
0   All deployments are healthy (scaled-down deployments are not failures)
1   One or more deployments are degraded
2   Invalid command-line usage or kubectl error
```
