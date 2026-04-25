<p align="center">
  <img src="assets/logo.svg" alt="syscheck logo" width="140"/>
</p>

<h1 align="center">syscheck</h1>

<p align="center">
  <strong>One command. Full system pulse. Zero dependencies.</strong>
</p>

<p align="center">
  <a href="#install"><img src="https://img.shields.io/badge/platform-macOS-blue?style=flat-square&logo=apple" alt="macOS"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License"/></a>
  <a href="syscheck.sh"><img src="https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash"/></a>
  <a href="syscheck.sh"><img src="https://img.shields.io/github/size/elara-labs/syscheck/syscheck.sh?style=flat-square&label=size" alt="Script size"/></a>
</p>

<br/>

<p align="center">
  <img src="assets/screenshot.svg" alt="syscheck output" width="680"/>
</p>

<br/>

## Why

You open your laptop. The fans spin up. Something is eating CPU. Something else grabbed a port you need. You don't want to run five different commands to figure it out.

`syscheck` gives you the full picture in one shot.

## What it checks

| Check | What you see |
|---|---|
| **CPU hogs** | Processes using >10% CPU, sorted by usage |
| **Memory hogs** | Processes using >200 MB RSS |
| **Listening ports** | Every open TCP port and which process owns it |
| **Dev processes** | Background Python, Node, Ruby, and Java processes |
| **System load** | Uptime and load averages |
| **Disk usage** | How full your main drive is |

All output is color coded. Red for CPU hogs, yellow for memory warnings, green for ports and clean states.

## Install

**Quick (curl)**

```bash
curl -fsSL https://raw.githubusercontent.com/elara-labs/syscheck/main/syscheck.sh -o /usr/local/bin/syscheck
chmod +x /usr/local/bin/syscheck
```

**Or clone**

```bash
git clone https://github.com/elara-labs/syscheck.git
cd syscheck
chmod +x syscheck.sh
```

**Or just copy the script.** It's a single file with no dependencies.

## Usage

```bash
syscheck        # if installed to PATH
./syscheck.sh   # if running locally
```

That's it. No flags, no config, no setup.

## Add to your shell

Drop this in your `.zshrc` or `.bashrc` to run it every time you open a terminal:

```bash
syscheck
```

Or alias it:

```bash
alias sc="syscheck"
```

## How it works

It composes standard macOS tools (`ps`, `lsof`, `df`, `pgrep`, `uptime`) into a single formatted report. No `sudo` required, no background daemons, no temp files. Runs in under a second.

## Requirements

- macOS
- Bash

## License

[MIT](LICENSE)
