#!/bin/bash
# syscheck.sh — Quick system health check for macOS

# ── Colors ───────────────────────────────────────
R='\033[0;31m'    # red
Y='\033[0;33m'    # yellow
G='\033[0;32m'    # green
C='\033[0;36m'    # cyan
M='\033[0;35m'    # magenta
W='\033[0;37m'    # white
D='\033[2m'       # dim
B='\033[1m'       # bold
N='\033[0m'       # reset

SHOW_ALL=0
[ "$1" = "--all" ] || [ "$1" = "-a" ] && SHOW_ALL=1

# Known macOS system ports to filter in default mode
SYSTEM_PORTS="ControlCe|rapportd|AirPlayXPCHelper|WiFiAgent|sharingd"

# ── Helper: progress bar ────────────────────────
bar() {
  local pct=$1 width=${2:-20} label="$3"
  local filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled=$width
  local empty=$((width - filled))

  local fg="$G"
  if [ "$pct" -ge 80 ] 2>/dev/null; then
    fg="$R"
  elif [ "$pct" -ge 50 ] 2>/dev/null; then
    fg="$Y"
  fi

  printf "${fg}"
  for ((i=0; i<filled; i++)); do printf "█"; done
  printf "${D}"
  for ((i=0; i<empty; i++)); do printf "░"; done
  printf "${N} ${fg}${B}%3s%%${N}" "$pct"
  [ -n "$label" ] && printf " ${D}%s${N}" "$label"
}

# ── Helper: format MB ───────────────────────────
hmb() {
  local mb=$1
  if [ "$mb" -ge 1024 ] 2>/dev/null; then
    printf "%.1fG" "$(echo "$mb / 1024" | bc -l)"
  else
    printf "%dM" "$mb"
  fi
}

# ── Gather metrics ──────────────────────────────
total_mem_bytes=$(sysctl -n hw.memsize)
total_mem_mb=$((total_mem_bytes / 1024 / 1024))
page_size=$(vm_stat | head -1 | /usr/bin/grep -oE '[0-9]+')
active=$(vm_stat | awk '/Pages active/ {gsub(/\./,"",$3); print $3}')
wired=$(vm_stat | awk '/Pages wired/ {gsub(/\./,"",$4); print $4}')
compressed=$(vm_stat | awk '/Pages occupied by compressor/ {gsub(/\./,"",$5); print $5}')
used_pages=$(( active + wired + compressed ))
used_mem_mb=$(( used_pages * page_size / 1024 / 1024 ))
mem_pct=$(( used_mem_mb * 100 / total_mem_mb ))

cpu_line=$(top -l 1 -n 0 2>/dev/null | /usr/bin/grep "CPU usage")
cpu_user=$(echo "$cpu_line" | /usr/bin/grep -oE '[0-9.]+% user' | /usr/bin/grep -oE '[0-9.]+')
cpu_sys=$(echo "$cpu_line" | /usr/bin/grep -oE '[0-9.]+% sys' | /usr/bin/grep -oE '[0-9.]+')
cpu_total=$(echo "${cpu_user:-0} ${cpu_sys:-0}" | awk '{printf "%.0f", $1+$2}')

disk_info=$(df -h / | awk 'NR==2 {print $3, $2, $5}')
disk_used=$(echo "$disk_info" | awk '{print $1}')
disk_total=$(echo "$disk_info" | awk '{print $2}')
disk_pct=$(echo "$disk_info" | awk '{gsub(/%/,""); print $3}')

load_avg=$(sysctl -n vm.loadavg | awk '{print $2}')
ncpu=$(sysctl -n hw.ncpu)

gpu_perf=$(ioreg -r -c AGXAcceleratorG17X 2>/dev/null | /usr/bin/grep "PerformanceStatistics")
[ -z "$gpu_perf" ] && gpu_perf=$(ioreg -r -c AGXAccelerator 2>/dev/null | /usr/bin/grep "PerformanceStatistics")
gpu_util=$(echo "$gpu_perf" | /usr/bin/grep -oE '"Device Utilization %"=[0-9]+' | /usr/bin/grep -oE '[0-9]+$')
gpu_render=$(echo "$gpu_perf" | /usr/bin/grep -oE '"Renderer Utilization %"=[0-9]+' | /usr/bin/grep -oE '[0-9]+$')
gpu_mem_bytes=$(echo "$gpu_perf" | /usr/bin/grep -oE '"In use system memory"=[0-9]+' | /usr/bin/grep -oE '[0-9]+$')
gpu_mem_mb=$((${gpu_mem_bytes:-0} / 1024 / 1024))

# Swap usage
swap_info=$(sysctl -n vm.swapusage 2>/dev/null)
swap_used=$(echo "$swap_info" | /usr/bin/grep -oE 'used = [0-9.]+M' | /usr/bin/grep -oE '[0-9.]+')
swap_total=$(echo "$swap_info" | /usr/bin/grep -oE 'total = [0-9.]+M' | /usr/bin/grep -oE '[0-9.]+')
swap_used_mb=${swap_used%.*}
swap_total_mb=${swap_total%.*}

# Battery
batt_info=$(pmset -g batt 2>/dev/null)
batt_pct=$(echo "$batt_info" | /usr/bin/grep -oE '[0-9]+%' | head -1 | tr -d '%')
batt_state=$(echo "$batt_info" | /usr/bin/grep -oE "discharging|charging|charged|AC Power" | head -1)

# Network throughput (bytes since boot via netstat)
net_line=$(netstat -ib 2>/dev/null | awk '/^en0/ && NF==11 {print $7, $10; exit}')
net_in_bytes=$(echo "$net_line" | awk '{print $1}')
net_out_bytes=$(echo "$net_line" | awk '{print $2}')
format_bytes() {
  local bytes=$1
  if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
    printf "%.1fG" "$(echo "$bytes / 1073741824" | bc -l)"
  elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
    printf "%.0fM" "$(echo "$bytes / 1048576" | bc -l)"
  elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
    printf "%.0fK" "$(echo "$bytes / 1024" | bc -l)"
  else
    printf "%dB" "${bytes:-0}"
  fi
}

uptime_str=$(uptime | sed 's/.*up //' | sed 's/,  *[0-9]* user.*//')
chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")

# ── Header ───────────────────────────────────────
echo ""
echo -e "  ${B}⚡ syscheck${N}  ${D}${chip} · $(date '+%b %d %H:%M') · up ${uptime_str}${N}"
echo -e "  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ── System gauges ────────────────────────────────
printf "  🧠 ${D}CPU${N}  "; bar "$cpu_total" 20 "usr:${cpu_user}% sys:${cpu_sys}%"; echo ""
printf "  💾 ${D}RAM${N}  "; bar "$mem_pct" 20 "$(hmb $used_mem_mb)/$(hmb $total_mem_mb)"; echo ""
if [ -n "$gpu_util" ]; then
  printf "  🎮 ${D}GPU${N}  "; bar "${gpu_util}" 20 "render:${gpu_render}% vram:$(hmb $gpu_mem_mb)"; echo ""
fi
printf "  💿 ${D}DSK${N}  "; bar "${disk_pct}" 20 "${disk_used}/${disk_total}"; echo ""

# Swap bar (only show if swap is in use)
if [ "${swap_used_mb:-0}" -gt 0 ] 2>/dev/null && [ "${swap_total_mb:-0}" -gt 0 ] 2>/dev/null; then
  swap_pct=$((swap_used_mb * 100 / swap_total_mb))
  printf "  🔄 ${D}SWP${N}  "; bar "$swap_pct" 20 "${swap_used_mb}M/${swap_total_mb}M"; echo ""
fi

# Load
printf "  ⚖️  ${D}LD ${N}  "
load_color="$G"
load_int=${load_avg%.*}
[ "$load_int" -ge "$ncpu" ] 2>/dev/null && load_color="$R"
[ "$load_int" -ge $((ncpu / 2)) ] 2>/dev/null && [ "$load_int" -lt "$ncpu" ] 2>/dev/null && load_color="$Y"
echo -e "${load_color}${B}${load_avg}${N} ${D}/ ${ncpu} cores${N}"

# Network + Battery on one line
net_str=""
if [ -n "$net_in_bytes" ]; then
  net_str="  🌍 ${D}NET${N}  ↓$(format_bytes $net_in_bytes) ↑$(format_bytes $net_out_bytes)"
fi

batt_str=""
if [ -n "$batt_pct" ]; then
  batt_icon="🔋"
  batt_color="$G"
  [ "$batt_pct" -le 20 ] 2>/dev/null && batt_icon="🪫" && batt_color="$R"
  [ "$batt_pct" -le 50 ] 2>/dev/null && [ "$batt_pct" -gt 20 ] 2>/dev/null && batt_color="$Y"
  state_label=""
  case "$batt_state" in
    charging)    state_label=" ⚡" ;;
    charged)     state_label=" ✓" ;;
    "AC Power")  state_label=" ⚡" ;;
  esac
  batt_str="  ${batt_icon} ${D}BAT${N}  ${batt_color}${B}${batt_pct}%${N}${state_label}"
fi

[ -n "$net_str" ] || [ -n "$batt_str" ] && echo -e "${net_str}${batt_str}"

# ── LLM Processes ───────────────────────────────
LLM_PATTERNS=(
  "cmd|ollama|Ollama"
  "cmd|LMStudio|LM Studio"
  "full|mlx_lm|MLX LM"
  "full|mlx-lm|MLX LM"
  "full|mlc_llm|MLC LLM"
  "cmd|llama-server|llama.cpp"
  "cmd|llama-cli|llama.cpp"
  "cmd|llamafile|llamafile"
  "cmd|claude|Claude"
  "cmd|openai|OpenAI CLI"
  "cmd|jan|Jan"
  "cmd|gpt4all|GPT4All"
  "cmd|koboldcpp|KoboldCpp"
  "full|text-generation-launcher|TGI"
  "full|vllm\.entrypoints|vLLM"
  "cmd|LocalAI|LocalAI"
  "cmd|msty|Msty"
)

llm_found=0
llm_lines=""
llm_total_cpu=0
llm_total_ram=0

for entry in "${LLM_PATTERNS[@]}"; do
  mode="${entry%%|*}"
  rest="${entry#*|}"
  pattern="${rest%%|*}"
  label="${rest##*|}"

  pids=""
  if [ "$mode" = "cmd" ]; then
    pids=$(ps -eo pid,comm 2>/dev/null | awk -v pat="$pattern" '$2 ~ pat {print $1}')
  else
    pids=$(pgrep -f "$pattern" 2>/dev/null)
  fi

  while IFS= read -r pid; do
    [ -z "$pid" ] && continue
    llm_found=1
    cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ')
    rss_kb=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ')
    rss_mb=$((rss_kb / 1024))
    llm_total_cpu=$(echo "$llm_total_cpu $cpu" | awk '{printf "%.1f", $1+$2}')
    llm_total_ram=$((llm_total_ram + rss_mb))

    cpu_c="$G"; cpu_int=${cpu%.*}
    [ "$cpu_int" -ge 50 ] 2>/dev/null && cpu_c="$R"
    [ "$cpu_int" -ge 20 ] 2>/dev/null && [ "$cpu_int" -lt 50 ] 2>/dev/null && cpu_c="$Y"

    ram_c="$G"
    [ "$rss_mb" -ge 2048 ] 2>/dev/null && ram_c="$R"
    [ "$rss_mb" -ge 512 ] 2>/dev/null && [ "$rss_mb" -lt 2048 ] 2>/dev/null && ram_c="$Y"

    llm_lines+="$(printf "  ${M}│${N} ${M}%-12s${N} ${D}pid:%-6s${N} cpu:${cpu_c}%6s${N}  ram:${ram_c}%s${N}\n" \
      "$label" "$pid" "$cpu%" "$(hmb $rss_mb)")"
    llm_lines+=$'\n'
  done <<< "$pids"
done

if [ $llm_found -eq 1 ]; then
  echo ""
  echo -e "  ${B}🤖 LLM${N}  ${D}total cpu:${llm_total_cpu}%  ram:$(hmb $llm_total_ram)${N}"
  echo -e "  ${D}──────────────────────────────────────────────${N}"
  printf "%s" "$llm_lines"
fi

# ── CPU hogs (>10%) ─────────────────────────────
hogs=$(ps -eo pid,%cpu,%mem,comm -r | awk 'NR>1 && $2+0 > 10.0' | head -6)
if [ -n "$hogs" ]; then
  echo ""
  echo -e "  ${B}🔥 HOT${N}"
  echo -e "  ${D}──────────────────────────────────────────────${N}"
  echo "$hogs" | while IFS= read -r line; do
    pid=$(echo "$line" | awk '{print $1}')
    cpu=$(echo "$line" | awk '{print $2}')
    mem=$(echo "$line" | awk '{print $3}')
    cmd=$(echo "$line" | awk '{print $4}' | xargs basename 2>/dev/null)
    printf "  ${R}│${N} %-18s ${D}pid:%-6s${N} cpu:${R}%6s${N}  mem:%s\n" "$cmd" "$pid" "$cpu%" "$mem%"
  done
fi

# ── Memory hogs (top N by RSS) ──────────────────
mem_limit=4
[ $SHOW_ALL -eq 1 ] && mem_limit=10
echo ""
echo -e "  ${B}📊 MEM${N}${D}$( [ $SHOW_ALL -eq 0 ] && echo "  (use --all for more)")${N}"
echo -e "  ${D}──────────────────────────────────────────────${N}"
ps -eo pid,rss,%cpu,comm -m | awk 'NR>1 && $2+0 > 512000' | head -$mem_limit | while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $1}')
  rss_kb=$(echo "$line" | awk '{print $2}')
  cpu=$(echo "$line" | awk '{print $3}')
  cmd=$(echo "$line" | awk '{print $4}' | xargs basename 2>/dev/null)
  rss_mb=$((rss_kb / 1024))
  rc="$G"
  [ "$rss_mb" -ge 2048 ] 2>/dev/null && rc="$R"
  [ "$rss_mb" -ge 512 ] 2>/dev/null && [ "$rss_mb" -lt 2048 ] 2>/dev/null && rc="$Y"
  printf "  ${Y}│${N} %-18s ${D}pid:%-6s${N} ${rc}%7s${N}  cpu:%s\n" "$cmd" "$pid" "$(hmb $rss_mb)" "$cpu%"
done

# ── Listening ports (filtered) ──────────────────
all_ports=$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR>1 {print $1, $2, $9}' | sort -u)
if [ $SHOW_ALL -eq 1 ]; then
  ports="$all_ports"
else
  ports=$(echo "$all_ports" | /usr/bin/grep -vE "^(${SYSTEM_PORTS}) ")
fi
if [ -n "$ports" ]; then
  echo ""
  echo -e "  ${B}🌐 NET${N}${D}$( [ $SHOW_ALL -eq 0 ] && echo "  (system ports hidden)")${N}"
  echo -e "  ${D}──────────────────────────────────────────────${N}"
  echo "$ports" | while read name pid addr; do
    port=$(echo "$addr" | /usr/bin/grep -oE '[0-9]+$')
    printf "  ${C}│${N} ${C}:%-5s${N}  %-16s ${D}pid:%s${N}\n" "$port" "$name" "$pid"
  done
fi

echo ""
echo -e "  ${D}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
