# health_checker.py / health_checker.sh / healthchecker.ps1

## Function

Check the health status of specified Linux systemd services and report whether each service is running, stopped, failed, or unknown.

## Features

* Check one or multiple systemd services
* Use `systemctl is-active` to determine service state
* Display service health in a human-readable format
* Generate a summary of healthy and unhealthy services
* Handle non-existent services
* Continue checking when individual services fail
* Return meaningful Linux exit codes
* Support command-line service arguments
* Python implementation for infrastructure automation
* Bash wrapper for convenient execution
* PowerShell implementation for Windows environments

## Usage

```bash
python3 system/health_checker.py sshd chronyd rsyslog
./system/health_checker.sh sshd chronyd rsyslog
.\system\healthchecker.ps1 sshd chronyd rsyslog
```

## Example

```text
Linux Service Health Check
==========================

sshd            RUNNING
chronyd         RUNNING
rsyslog         FAILED

Summary
-------
Checked:   3
Healthy:   2
Unhealthy: 1
Unknown:   0
```

## Exit Codes

```text
0   All services are healthy
1   One or more services are unhealthy or unknown
2   Invalid command-line usage or program error
```
