# dir_usage.py / dir_usage.sh / dir_usage.ps1

## Function

Check disk space consumed by a specified directory and its subdirectories, and report the total usage in a human-readable format.

## Features

- Recursively calculate directory size
- Include files under all subdirectories
- Display total directory usage in GB
- Validate the target directory
- Handle permission and missing-file errors
- Support command-line directory arguments
- Bash wrapper for convenient execution
- PowerShell implementation for Windows environments

## Usage

```bash
python3 system/dir_usage.py /path
./system/dir_usage.sh /path
.\system\dir_usage.ps1 C:\path