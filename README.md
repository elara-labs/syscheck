# syscheck

Quick system health check for macOS. One script, zero dependencies.

## What it checks

- **CPU hogs** processes using >10% CPU
- **Memory hogs** processes using >200 MB RSS
- **Open listening ports** via `lsof`
- **Background dev processes** (Python, Node, Ruby, Java)
- **System uptime and load**
- **Disk usage**

## Install

```bash
curl -o syscheck.sh https://raw.githubusercontent.com/elara-labs/syscheck/main/syscheck.sh
chmod +x syscheck.sh
```

## Usage

```bash
./syscheck.sh
```

Output is color coded: red for CPU hogs, yellow for memory hogs, green for ports and clean states.

## Requirements

- macOS (uses `ps`, `lsof`, `df`, `pgrep`)
- Bash

## License

MIT
