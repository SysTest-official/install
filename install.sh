#!/bin/bash

# --- 1. Detect Distro & Install Fastfetch ---
echo "Checking for fastfetch..."
if ! command -v fastfetch &> /dev/null; then
    echo "fastfetch not found. Attempting to install..."
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y fastfetch
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm fastfetch
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y fastfetch
    elif command -v brew &> /dev/null; then
        brew install fastfetch
    else
        echo "Could not find a supported package manager. Please install fastfetch manually."
        exit 1
    fi
fi

# --- 2. Define the systest function ---
FUNC_CONTENT='
systest() {
    local bench_output=""
    local BENCH=false

    # --- Parse flags ---
    for arg in "$@"; do
        case $arg in
            -Help|--help)
                echo "Systest v1.0 CLI Options:"
                echo "  -Benchmark      Run CPU benchmark before dashboard"
                echo "  -Help, --help   Show this help message"
                return
                ;;
            -Benchmark)
                BENCH=true
                ;;
        esac
    done

    clear

    # --- Benchmark ---
    if [[ "$BENCH" == true ]]; then
        echo -e "\n\e[1;31m[!] Benchmarking CPU... Please wait.\e[0m"
        bench_output=$( { time (dd if=/dev/zero bs=1M count=512 2>/dev/null | sha256sum > /dev/null) } 2>&1 | grep real | awk "{print \$2}")
        echo -e "\e[1;32m[+] Benchmark finished. Generating dashboard...\e[0m"
        sleep 0.5
    else
        echo -e "\e[2mSkipping benchmark...\e[0m"
        sleep 0.5
    fi

    echo
    fastfetch
    echo

    # --- User & Host ---
    echo -e "\e[1;34m== User ==\e[0m"
    echo "User: $(whoami) | Host: $(hostname)"
    echo "-----------------------------"

    # --- Uptime ---
    echo -e "\e[1;32m== Uptime ==\e[0m"
    uptime -p
    echo "-----------------------------"

    # --- Kernel / OS ---
    echo -e "\e[1;35m== Kernel ==\e[0m"
    uname -smr
    echo "-----------------------------"

    # --- Network Interfaces ---
    echo -e "\e[1;33m== Network ==\e[0m"
    ip -br a | while read -r iface state addr rest; do
        if [[ "$state" == "UP" && -n "$addr" ]]; then
            printf "\e[1;32m%-12s %-8s %-15s\e[0m\n" "$iface" "$state" "$addr"
        else
            printf "%-12s %-8s %-15s\n" "$iface" "$state" "$addr"
        fi
    done
    echo "-----------------------------"

    # --- Resources ---
    echo -e "\e[1;36m== Resources ==\e[0m"
    mem=$(free -h | awk "/Mem:/ {print \$3 \" / \" \$2}")
    cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk "{print 100 - \$1\"%\"}")
    
    disk_raw=$(df -h / | awk "NR==2 {print \$5}" | sed "s/%//")
    disk_usage_text=$(df -h / | awk "NR==2 {print \$3 \" / \" \$2 \" (\" \$5 \")\"}")
    
    if [ "$disk_raw" -ge 90 ]; then disk_color="\e[1;31m"
    elif [ "$disk_raw" -ge 70 ]; then disk_color="\e[1;33m"
    else disk_color="\e[1;32m"
    fi

    echo "Memory:    $mem"
    echo "CPU Usage: $cpu"
    echo -e "Disk (/):  ${disk_color}${disk_usage_text}\e[0m"

    if [[ -n "$bench_output" ]]; then
        echo -e "CPU Score: \e[1;32m$bench_output\e[0m (512MB Hash Time)"
    fi
    echo "-----------------------------"

    # --- Top processes (CPU) ---
    echo -e "\e[1;35m== Top Processes ==\e[0m"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6
    echo "-----------------------------"
}

# --- Aliases for convenience ---
alias systool="systest"
alias st="systest"
'

# --- 3. Determine which shell config file to use ---
if [[ "$SHELL" == */zsh ]]; then
    CONF_FILE="$HOME/.zshrc"
else
    CONF_FILE="$HOME/.bashrc"
fi

# --- 4. Append the function if not already installed ---
if grep -q "systest()" "$CONF_FILE"; then
    echo "systest is already installed in $CONF_FILE."
else
    echo "$FUNC_CONTENT" >> "$CONF_FILE"
    echo "Success! systest added to $CONF_FILE with aliases systool and st."
    echo "Please run: source $CONF_FILE"
fi
