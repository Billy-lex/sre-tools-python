# AGENTS.md

本仓库是 SRE / 基础设施运维脚本集合，按领域分目录：`system/`、`networking/`、`monitoring/`、
`troubleshooting/`、`kubernetes/`。

## 核心约定

- **只用 Python 标准库**，禁止引入第三方依赖（`json`、`argparse`、`logging`、`re`、`hashlib`、
  `subprocess`、`concurrent.futures` 等即可）。
- **每个工具四件套**：`<name>.py` / `<name>.sh` / `<name>.ps1` / `<name>.md`，四者功能对等。
- **`.sh` 是独立完整实现，不是调 `.py` 的壳**。三种实现的行为差异必须在 `.md` 里写清楚。
- 退出码统一：`0` 正常 / `1` 发现异常（有告警项）/ `2` 用法错误或采集失败。
- 破坏性操作默认关闭，必须显式参数才执行（README 的 safe-by-default 原则）。

## Python

- 模块级 `UPPER_CASE` 常量放文件顶部，配一行注释说明用途。
- 函数带 docstring 和类型标注；入口统一 `if __name__ == "__main__": sys.exit(main())`。
- 多参数工具用 `argparse`，需要机器可读输出时提供 `--json`。

## Bash

- 首行 `#!/usr/bin/env bash`，紧跟 `set -euo pipefail`。
- 文件权限 `755`（`git update-index` 里应记为 `100755`）。
- 参数解析用 `while [ "$#" -gt 0 ] + case`，同时支持 `--flag value` 和 `--flag=value`。
- **优先 bash 内建 + coreutils**（`timeout`、`date`、`sort`、`awk`、`sed`），不要引入 `nc`、`jq`、
  `ncat` 等非 POSIX 保证的外部命令；JSON 用 `printf` 手工拼。取舍是宁可慢一点也要能在
  minimal 镜像和容器里直接跑。
- `set -e` 陷阱：`((count++))` 在 count 为 0 时返回退出码 1 会直接终止脚本，计数一律用
  `count=$((count + 1))`。
- 管道尾部避免 `head`（`sort | head` 可能触发 SIGPIPE + `pipefail` 失败），用 `awk 'NR<=n'` 代替；
  `tail` 读完整输入，安全。

## PowerShell

- 同时兼容 Windows PowerShell 5.1 和 pwsh 7+。
- 文件开头一行注释说明用途，然后 `param()`，再 `Set-StrictMode -Version Latest` 与
  `$ErrorActionPreference = 'Stop'`。
- StrictMode 下读 CIM/JSON 对象属性要用安全 helper（参考 `kubernetes/restart_checker.ps1` 的
  `Get-PropertyValue`），不要直接 `$obj.MissingProp`。
- 数字输出一律用 `[System.Globalization.CultureInfo]::InvariantCulture` 格式化，避免区域设置
  把小数点变成逗号。
- 找不到 Linux 概念的等价物时用 Windows 原生 API 替代，并在 `.md` 注明（例如无 load average →
  `Win32_Processor.LoadPercentage`；无 swap → commit charge）。

## Markdown 文档

章节顺序固定：

```
# <name>.py / <name>.sh / <name>.ps1
## Function
## Features          （要点列表，含三种实现的说明）
## Usage             （```bash 块 + ```powershell 块）
## Example           （真实输出样例，```text 块）
## Exit Codes        （```text 块，列出 0/1/2 含义）
```

存在实现差异时另加 `## Implementation Differences` 一节说明。

## 提交规范

Conventional Commits，subject 小写，需要时补一段 body 解释「为什么」。历史提交里
`Co-authored-by` trailer 不是主流（12 条里仅 1 条），默认不加。

远端有 `github` 和 `gitlab` 两个，**不要自动 push**，等明确指令。
