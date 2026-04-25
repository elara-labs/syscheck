#!/bin/bash
# syscheck.sh — Quick system health check for macOS

YELLOW='\033[0;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}System Health Check${RESET}"
echo -e "${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo ""

# ── CPU hogs (>10% CPU) ──────────────────────────
echo -e "${BOLD}CPU Hogs (>10%)${RESET}"
echo -e "${DIM}─────────────────────────────────────────────${RESET}"
ps -eo pid,%cpu,%mem,comm -r | awk 'NR==1 || (NR>1 && $2+0 > 10.0)' | head -12 | while IFS= read -r line; do
  if echo "$line" | grep -qE '^\s*PID'; then
    printf "  ${DIM}%-8s %6s %6s  %-30s${RESET}\n" "PID" "%CPU" "%MEM" "PROCESS"
  else
    pid=$(echo "$line" | awk '{print $1}')
    cpu=$(echo "$line" | awk '{print $2}')
    mem=$(echo "$line" | awk '{print $3}')
    cmd=$(echo "$line" | awk '{print $4}' | xargs basename 2>/dev/null)
    printf "  %-8s ${RED}%6s${RESET} %6s  %-30s\n" "$pid" "$cpu%" "$mem%" "$cmd"
  fi
done
echo ""

# ── Memory hogs (>200 MB RSS) ────────────────────
echo -e "${BOLD}Memory Hogs (>200 MB)${RESET}"
echo -e "${DIM}─────────────────────────────────────────────${RESET}"
printf "  ${DIM}%-8s %10s %6s  %-30s${RESET}\n" "PID" "RSS" "%CPU" "PROCESS"
ps -eo pid,rss,%cpu,comm -m | awk 'NR>1 && $2+0 > 204800' | head -12 | while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $1}')
  rss_kb=$(echo "$line" | awk '{print $2}')
  cpu=$(echo "$line" | awk '{print $3}')
  cmd=$(echo "$line" | awk '{print $4}' | xargs basename 2>/dev/null)
  rss_mb=$((rss_kb / 1024))
  printf "  %-8s ${YELLOW}%7s MB${RESET} %6s  %-30s\n" "$pid" "$rss_mb" "$cpu%" "$cmd"
done
echo ""

# ── Listening ports ──────────────────────────────
echo -e "${BOLD}Open Listening Ports${RESET}"
echo -e "${DIM}─────────────────────────────────────────────${RESET}"
lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR>1 {print $1, $2, $9}' | sort -u | while read name pid addr; do
  port=$(echo "$addr" | grep -oE '[0-9]+$')
  printf "  %-20s ${GREEN}%-8s${RESET} port %-6s\n" "$name" "PID:$pid" "$port"
done
echo ""

# ── Background Python/Node/Ruby processes ────────
echo -e "${BOLD}Background Dev Processes${RESET}"
echo -e "${DIM}─────────────────────────────────────────────${RESET}"
found=0
for lang in python python3 node ruby java; do
  pgrep -lf "$lang" 2>/dev/null | while IFS= read -r line; do
    found=1
    pid=$(echo "$line" | awk '{print $1}')
    cmd=$(echo "$line" | cut -d' ' -f2- | cut -c1-70)
    printf "  ${YELLOW}%-8s${RESET} %s\n" "$pid" "$cmd"
  done
done
if [ $found -eq 0 ] 2>/dev/null; then
  echo -e "  ${GREEN}None${RESET}"
fi
echo ""

# ── Uptime & load ────────────────────────────────
echo -e "${BOLD}System${RESET}"
echo -e "${DIM}─────────────────────────────────────────────${RESET}"
echo -e "  $(uptime | sed 's/^  */  /')"
echo ""

# ── Disk usage ───────────────────────────────────
echo -e "${BOLD}Disk Usage${RESET}"
echo -e "${DIM}─────────────────────────────────────────────${RESET}"
df -h / | awk 'NR==2 {printf "  Used: %s / %s (%s)\n", $3, $2, $5}'
echo ""
