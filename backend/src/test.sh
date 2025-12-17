#!/bin/bash

LOG_DIR="system_reports"
mkdir -p "$LOG_DIR"
INTERVAL=10

TIMESTAMP=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
REPORT_DIR="$LOG_DIR/$TIMESTAMP"
mkdir -p "$REPORT_DIR"

#thresholds
CRITICAL_MEMORY_THRESHOLD=50
CRITICAL_VIRTAUL_MEMORY_THRESHOLD=50
CRITICAL_CPU_THRESHOLD=70
CRITICAL_CPU_TEMP_THRESHOLD=50
CRITICAL_GPU_USAGE_THRESHOLD=50
CRITICAL_GPU_TEMP_THRESHOLD=50
CRITICAL_DISK_THRESHOLD=90  

# Flags
CPU_OK=0
MEMORY_OK=0
GPU_OK=0
DISK_OK=0
NETWORK_OK=0
LOAD_OK=0
SMART_OK=0


function assert_not_empty {
    local raw_value="$1"
    local name="$2"

    # Strip everything except numbers and dots (removes GB, %, °C, etc.)
    local numeric_value=$(echo "$raw_value" | sed 's/[^0-9.]//g')

    # Now test if the remaining number is empty or effectively zero
    if [ -z "$numeric_value" ]; then
        echo "ERROR: $name did not work or returned empty/zero"
        echo "$(date): ERROR: $name (Value: $raw_value) failed validation" >> "$REPORT_DIR/error.log"
        return 1
    fi
    return 0
}


function cpu
{
    if [ "$SKIP_CPU" = true ]; then
        return
    fi
    
    Cpu=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2 + $4 + $6}')

    assert_not_empty "$Cpu" "CPU use" || return

    Cputemp=$(sensors | awk '/Package id 0/ {gsub(/[+°C]/,"",$4); print $4 "°C"}')

    assert_not_empty "$Cputemp" "CPU temp" || return

    echo "CPU Usage: $Cpu%"

    Cputemp_num=$(echo "$Cputemp" | sed 's/[^0-9.]//g')

    echo "CPU Temperature: $Cputemp_num"
    # CPU Usage alert (decimal-safe using bc)
    if (( $(echo "$Cpu > $CRITICAL_CPU_THRESHOLD" | bc -l) )); then
        echo "ALERT: High CPU Usage ($Cpu%)" 
        echo "ALERT: High CPU Usage ($Cpu%)" >> "$REPORT_DIR/cpu.log"
    fi

    # CPU Temperature alert using numeric temp variable
    if (( $(echo "$Cputemp_num > $CRITICAL_CPU_TEMP_THRESHOLD" | bc -l) )); then
        echo "ALERT: High CPU TEMP ($Cputemp)" 
        echo "ALERT: High CPU TEMP ($Cputemp)" >> "$REPORT_DIR/cpu.log"
    fi

    
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: CPU Usage: $Cpu% CPU Temperature: $Cputemp" >> "$REPORT_DIR/cpu.log"

    echo "===============================" >> "$REPORT_DIR/cpu.log"
}

function memory
{
    # Get memory 
    memoryUtilAverage=$(free | awk '/Mem/ {printf("%3.1f", ($3/$2) * 100)}')

    assert_not_empty "$memoryUtilAverage" "Mem Utility Average" || return

    memoryUsed=$(free -m | awk '/Mem:/ {printf "%.2f GB\n", $3/1024}')

    assert_not_empty "$memoryUsed" "Mem Used" || return 
    
    memoryTotal=$(free -m | awk '/Mem:/ {printf "%.2f GB\n", $2/1024}')
    
    assert_not_empty "$memoryTotal" "Mem Total" || return

    echo "Memory Utilization: $memoryUtilAverage%"
    echo "Memory Used: $memoryUsed"
    echo "Memory Total: $memoryTotal"
    
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: Memory Utilization: $memoryUtilAverage Memory Used: $memoryUsed Memory Total: $memoryTotal" >> "$REPORT_DIR/memory.log"
    
    # Get virtual memory 
    VMUtilAverage=$(free | awk '/Swap/ {printf("%3.1f", ($3/$2) * 100)}')
    assert_not_empty "$VMUtilAverage" "Vram Utilization" || return

    VMUsed=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $3/1024}')
    assert_not_empty "$VMUsed" "Vram Used" || return

    
    VMTotal=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $2/1024}')
    assert_not_empty "$VMTotal" "Vram Total" || return

    
    echo "Virtual Memory Utilization: $VMUtilAverage%"
    echo "Virtual Memory Used: $VMUsed"
    echo "Virtual Memory Total: $VMTotal"
    
    # RAM usage alert
    if (( $(echo "$memoryUtilAverage > $CRITICAL_MEMORY_THRESHOLD" | bc -l) )); then
        echo "ALERT: High RAM Usage ($memoryUtilAverage%)"
        echo "ALERT: High RAM Usage ($memoryUtilAverage%)" >> "$REPORT_DIR/memory.log"
    fi

    # Virtual Memory usage alert
    if (( $(echo "$VMUtilAverage > $CRITICAL_VIRTAUL_MEMORY_THRESHOLD" | bc -l) )); then
        echo "ALERT: High Virtual Memory Usage ($VMUtilAverage%)"
        echo "ALERT: High Virtual Memory Usage ($VMUtilAverage%)" >> "$REPORT_DIR/memory.log"
    fi


    echo "$CURRENT_TIME: Virtual Memory Utilization: $VMUtilAverage Virtual Memory Used: $VMUsed Virtual Memory Total: $VMTotal" >> "$REPORT_DIR/memory.log"

    echo "===============================" >> "$REPORT_DIR/memory.log"
}

function gpu
{
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    
    if command -v nvidia-smi &> /dev/null; then
        GPU_Utilization=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2 + $4 + $6}')
        assert_not_empty "$GPU_Utilization" "GPU Util" || return
        GPU_Temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
        assert_not_empty "$GPU_Temperature" "GPU Temp" || return

        echo "GPU Usage: $GPU_Utilization%"

        echo "GPU Temperature: $GPU_Temperature"

        echo "$CURRENT_TIME: GPU Usage: $GPU_Utilization% GPU Temperature: $GPU_Temperature°C" >> "$REPORT_DIR/gpu.log"

    elif command -v rocm-smi &> /dev/null; then 
            GPU_Utilization=$(rocm-smi --showuse | awk '/GPU/ {print $2}')
            assert_not_empty "$GPU_Utilization" "GPU use" || return
            GPU_Temperature=$(rocm-smi --showtemp | awk '/GPU/ {print $2}')
            assert_not_empty "$GPU_Temperature" "GPU Temp" || return
            
            echo "GPU Usage: $GPU_Utilization%"
            echo "GPU Temperature: $GPU_Temperature°C"

            echo "$CURRENT_TIME: GPU Usage: $GPU_Utilization% GPU Temperature: $GPU_Temperature°C" >> "$REPORT_DIR/gpu.log"
    
    # elif command -v intel_gpu_top &> /dev/null; then
    #         sudo timeout 0.2s intel_gpu_top > /dev/tty
    #         sudo timeout 0.2s intel_gpu_top -o /dev/stdout >> "$REPORT_DIR/gpu.log"
    fi  

    # Clean numeric values for comparison
    GPU_Util_num=$(echo "$GPU_Utilization" | sed 's/[^0-9.]//g')
    GPU_Temp_num=$(echo "$GPU_Temperature" | sed 's/[^0-9.]//g')

    # Only compare if numeric values exist
    if [[ -n "$GPU_Util_num" ]]; then
        if (( $(echo "$GPU_Util_num > $CRITICAL_GPU_USAGE_THRESHOLD" | bc -l) )); then
            echo "ALERT: High GPU Usage ($GPU_Utilization%)" 
            echo "ALERT: High GPU Usage ($GPU_Utilization%)" >> "$REPORT_DIR/gpu.log"
        fi
    fi
    
    if [[ -n "$GPU_Temp_num" ]]; then
        if (( $(echo "$GPU_Temp_num > $CRITICAL_GPU_TEMP_THRESHOLD" | bc -l) )); then
            echo "ALERT: High GPU TEMP ($GPU_Temperature°C)" 
            echo "ALERT: High GPU TEMP ($GPU_Temperature°C)" >> "$REPORT_DIR/gpu.log"
        fi
    fi

    echo "===============================" >> "$REPORT_DIR/gpu.log"
}

function disk 
{
    # List all block devices except swap and zram
    lsblk -no NAME,SIZE,TYPE,MOUNTPOINT | while read name size type mount; do
        # Skip empty lines
        [ -z "$name" ] && continue

        # Skip swap partitions, zram, and LVM logical volumes
        if [[ "$mount" == "[SWAP]" ]] || [[ "$name" == zram* ]]; then
            continue
        fi


        # Remove └─ or ├─ from the name
        clean_name=$(echo "$name" | sed 's/^[└├─]*//')

        CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")

        # If the mountpoint exists and is not "[SWAP]", get used space
        if [ -n "$mount" ] && [[ "$type" != "crypt" ]]; then
            
            used=$(df -h "$mount" | awk 'NR==2 {print $3 " used"}')
            use_percent=$(df -h "$mount" | awk 'NR==2 {print $5}')
            
            echo -e "$CURRENT_TIME: partition: $clean_name $size $type $mount $used $use_percent"

            echo -e "$CURRENT_TIME: partition: $clean_name $size $type $mount $used $use_percent" >> "$REPORT_DIR/disk.log"

            # Get usage percent without %
            use_percent=$(df -h "$mount" | awk 'NR==2 {print $5}' | tr -d '%')
            
            # Alert if usage exceeds threshold
            if (( use_percent > CRITICAL_DISK_THRESHOLD )); then
                echo "ALERT: High Disk Usage on $clean_name ($use_percent%)"
                echo "ALERT: High Disk Usage on $clean_name ($use_percent%)" >> "$REPORT_DIR/disk.log"
            fi

        elif [[ "$type" == "disk" ]]; then
            echo -e "$CURRENT_TIME: disk: $clean_name $size"

            echo -e "$CURRENT_TIME: disk: $clean_name $size" >> "$REPORT_DIR/disk.log"
        
        elif [[ "$type" != "crypt" ]]; then
            echo -e "$CURRENT_TIME: partition : $clean_name $size $type"

            echo -e "$CURRENT_TIME: partition : $clean_name $size $type" >> "$REPORT_DIR/disk.log"
        fi
    done

    echo "===============================" >> "$REPORT_DIR/disk.log"
}

function network
{
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")

    INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n 1)

    if [ -z "$INTERFACE" ]; then
        echo "$CURRENT_TIME: No default network interface found." >> "$REPORT_DIR/network.log"
        echo "===============================" >> "$REPORT_DIR/network.log"
        return
    fi
    
    # Get the raw cumulative byte counts (Incoming and Outgoing)
    RX_BYTES=$(cat "/sys/class/net/$INTERFACE/statistics/rx_bytes" 2>/dev/null)
    assert_not_empty "$RX_BYTES" "RX_BYTES" || return
    TX_BYTES=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes" 2>/dev/null)
    assert_not_empty "$TX_BYTES" " TX_BYTES" || return

    # Format the output string
    NETWORK_DATA="Interface: $INTERFACE | Incoming_Bytes_Total: $RX_BYTES | Outgoing_Bytes_Total: $TX_BYTES"
    assert_not_empty "$NETWORK_DATA" "NETWORK_DATA" || return

    # Output to console and log
    echo "Network Traffic: $NETWORK_DATA"
    echo "$CURRENT_TIME: Network Traffic: $NETWORK_DATA" >> "$REPORT_DIR/network.log"

    echo "===============================" >> "$REPORT_DIR/network.log"
}

function smartStatus 
{
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")

    # Use 'sudo smartctl --scan' to find all devices
    sudo smartctl --scan | awk '{print $1}' | while read -r dev; do

        # Extract attributes. Use sed to clean up the output where possible.
        HEALTH=$(sudo smartctl -H "$dev" | awk '/SMART overall-health/ {print ($6=="PASSED")?1:0}')
        assert_not_empty "$HEALTH" "Smart Status (Health)" || return
        TEMP=$(sudo smartctl -A "$dev" | awk '$1==194 {print $10}')
        assert_not_empty "$TEMP" "Smart Status(Temperature)" || return
        REALLOC=$(sudo smartctl -A "$dev" | awk '$1==5 {print $10}')
        assert_not_empty "$REALLOC" "Smart Status(Reallocation)" || return
        PENDING=$(sudo smartctl -A "$dev" | awk '$1==197 {print $10}')
        assert_not_empty "$PENDING" "Smart Status(Pending)" || return
        UNCORR=$(sudo smartctl -A "$dev" | awk '$1==198 {print $10}')
        assert_not_empty "$UNCORR" "Smart Status(uncorr)" || return
        HOURS=$(sudo smartctl -A "$dev" | awk '$1==9 {print $10}')
        assert_not_empty "$HOURS" "Smart Status (Hours)" || return

        LOG_LINE="$CURRENT_TIME $dev health=$HEALTH temp=$TEMP realloc=$REALLOC pending=$PENDING uncorrect=$UNCORR hours=$HOURS"

        echo "$LOG_LINE"
        echo "$LOG_LINE" >> "$REPORT_DIR/smart.log"

    done

    echo "===============================" >> "$REPORT_DIR/smart.log"
}

function loadmatrics
{
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")

    uptime=$('uptime')
    assert_not_empty "$uptime" "Uptime" || return
    echo "$CURRENT_TIME: $uptime" >> "$REPORT_DIR/load.log"
    echo "$uptime"
    echo "===============================" >> "$REPORT_DIR/load.log"
}

function linux 
{
    # Detect Linux distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$NAME
        VERSION=$VERSION_ID
        echo "Detected Linux: $DISTRO $VERSION"
    else
        DISTRO=$(uname -s)
        VERSION=$(uname -r)
        echo "Detected Linux: $DISTRO $VERSION"
    fi

    trap 'exit' SIGINT

    while true; do
        disk
        cpu 
        memory
        gpu
        network
        #smartStatus
        loadmatrics
        sleep 4
    done
}


detect_os() {
    unameOut="$(uname -s)"
    case "$unameOut" in
        Linux*)
            # If Linux but running inside Windows (WSL), still count as Windows
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "Windows wsl"
                linux "WSL"
            else
                echo "Linux"
                linux "Native"
            fi
            ;;
        Darwin*)
            echo "macOS"
            mac
            ;;
        CYGWIN*)
            echo "Windows using CYGWIN"
            windows
            ;;
        MINGW*)
            echo "Windows using MINGW"
            windows
            ;;
        MSYS*)
            echo "Windows using MSYS"
            windows
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}




test_cpu() {
    echo "Testing cpu function..."
    output=$(cpu 2>&1)

    # Extract numeric values
    cpu_usage=$(echo "$output" | awk -F': ' '/^CPU Usage:/ {gsub(/%/, "", $2); print $2}')
    cpu_temp=$(echo "$output" | awk -F': ' '/^CPU Temperature:/ {gsub(/[^0-9.]/, "", $2); print $2}')

    # Validate numbers
    if [[ "$cpu_usage" =~ ^[0-9]+(\.[0-9]+)?$ ]] &&
       [[ "$cpu_temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        CPU_OK=1
    else
        CPU_OK=0
    fi
}



test_memory() {
    echo "Testing memory function..."
    output=$(memory 2>&1)

    # Extract values
    mem_util=$(echo "$output" | awk -F': ' '/^Memory Utilization:/ {gsub(/%/, "", $2); print $2}')
    mem_used=$(echo "$output" | awk -F': ' '/^Memory Used:/ {gsub(/[^0-9.]/, "", $2); print $2}')
    mem_total=$(echo "$output" | awk -F': ' '/^Memory Total:/ {gsub(/[^0-9.]/, "", $2); print $2}')

    swap_util=$(echo "$output" | awk -F': ' '/^Virtual Memory Utilization:/ {gsub(/%/, "", $2); print $2}')
    swap_used=$(echo "$output" | awk -F': ' '/^Virtual Memory Used:/ {gsub(/[^0-9.]/, "", $2); print $2}')
    swap_total=$(echo "$output" | awk -F': ' '/^Virtual Memory Total:/ {gsub(/[^0-9.]/, "", $2); print $2}')

    # Validate numeric values
    numeric_ok=true
    for v in "$mem_util" "$mem_used" "$mem_total" "$swap_util" "$swap_used" "$swap_total"; do
        [[ "$v" =~ ^[0-9]+(\.[0-9]+)?$ ]] || numeric_ok=false
    done

    # Range checks
    range_ok=true
    (( $(echo "$mem_util >= 0 && $mem_util <= 100" | bc -l) )) || range_ok=false
    (( $(echo "$swap_util >= 0 && $swap_util <= 100" | bc -l) )) || range_ok=false

    if [[ $numeric_ok == true && $range_ok == true ]]; then
        MEMORY_OK=1
    else
        MEMORY_OK=0
    fi
}


test_gpu() {
    echo "Testing gpu function..."
    output=$(gpu 2>&1)

    # If no GPU tools exist, gpu() prints nothing → PASS (not an error)
    if [[ -z "$output" ]]; then
        GPU_OK=1
        return
    fi

    gpu_util=$(echo "$output" | awk -F': ' '/^GPU Usage:/ {gsub(/%/, "", $2); print $2}')
    gpu_temp=$(echo "$output" | awk -F': ' '/^GPU Temperature:/ {gsub(/[^0-9.]/, "", $2); print $2}')

    numeric_ok=true

    [[ "$gpu_util" =~ ^[0-9]+(\.[0-9]+)?$ ]] || numeric_ok=false
    [[ "$gpu_temp" =~ ^[0-9]+(\.[0-9]+)?$ ]] || numeric_ok=false

    range_ok=true
    (( $(echo "$gpu_util >= 0 && $gpu_util <= 100" | bc -l) )) || range_ok=false
    (( $(echo "$gpu_temp >= 0 && $gpu_temp <= 120" | bc -l) )) || range_ok=false

    if [[ $numeric_ok == true && $range_ok == true ]]; then
        GPU_OK=1
    else
        GPU_OK=0
    fi
}


test_disk() {
    echo "Testing disk function..."
    output=$(disk 2>&1)

    # Skip empty output
    [[ -z "$output" ]] && { DISK_OK=1; return; }

    valid=true

    while read -r line; do
        # Skip separator lines
        [[ "$line" == *"===="* ]] && continue

        # Match disk lines
        if [[ "$line" =~ disk: ]]; then
            dev=$(echo "$line" | awk '{print $4}')
            [[ -n "$dev" ]] || valid=false

        # Match partition lines
        elif [[ "$line" =~ partition ]]; then
            dev=$(echo "$line" | awk '{print $4}')
            [[ -n "$dev" ]] || valid=false

            # Optional: validate numeric usage percent if present
            if [[ "$line" =~ used ]]; then
                percent=$(echo "$line" | awk '{print $NF}' | tr -d '%')
                [[ "$percent" =~ ^[0-9]+$ ]] || valid=false
            fi
        fi
    done <<< "$output"

    if [[ $valid == true ]]; then
        DISK_OK=1
    else
        DISK_OK=0
    fi
}

test_network() {
    echo "Testing network function..."
    output=$(network 2>&1)

    # No output = no network (valid state)
    if [[ -z "$output" ]]; then
        NETWORK_OK=1
        return
    fi

    interface=$(echo "$output" | awk -F'Interface: ' '/Network Traffic/ {print $2}' | awk '{print $1}')
    rx=$(echo "$output" | awk -F'Incoming_Bytes_Total: ' '{print $2}' | awk '{print $1}')
    tx=$(echo "$output" | awk -F'Outgoing_Bytes_Total: ' '{print $2}')

    numeric_ok=true
    [[ "$rx" =~ ^[0-9]+$ ]] || numeric_ok=false
    [[ "$tx" =~ ^[0-9]+$ ]] || numeric_ok=false
    [[ -n "$interface" ]] || numeric_ok=false

    if [[ $numeric_ok == true ]]; then
        NETWORK_OK=1
    else
        NETWORK_OK=0
    fi
}


test_loadmatrics() {
    echo "Testing loadmatrics function..."
    output=$(loadmatrics 2>&1)

    # No output = failure
    if [[ -z "$output" ]]; then
        LOAD_OK=0
        return
    fi

    # Extract load averages
    loads=$(echo "$output" | awk -F'load average: ' '{print $2}')

    # Must contain three values
    l1=$(echo "$loads" | awk -F',' '{print $1}' | tr -d ' ')
    l5=$(echo "$loads" | awk -F',' '{print $2}' | tr -d ' ')
    l15=$(echo "$loads" | awk -F',' '{print $3}' | tr -d ' ')

    numeric_ok=true
    [[ "$l1" =~ ^[0-9]+(\.[0-9]+)?$ ]] || numeric_ok=false
    [[ "$l5" =~ ^[0-9]+(\.[0-9]+)?$ ]] || numeric_ok=false
    [[ "$l15" =~ ^[0-9]+(\.[0-9]+)?$ ]] || numeric_ok=false

    if [[ $numeric_ok == true ]]; then
        LOAD_OK=1
    else
        LOAD_OK=0
    fi
}

test_smartStatus() {
    echo "Testing smartStatus function..."
    output=$(smartStatus 2>&1)

    # No output = no SMART devices (valid state)
    if [[ -z "$output" ]]; then
        SMART_OK=1
        return
    fi

    valid=true

    while read -r line; do
        # Skip separator lines
        [[ "$line" == *"===="* ]] && continue

        # Extract fields
        dev=$(echo "$line" | awk '{print $2}')
        health=$(echo "$line" | sed -n 's/.*health=\([01]\).*/\1/p')
        temp=$(echo "$line" | sed -n 's/.*temp=\([0-9]\+\).*/\1/p')
        realloc=$(echo "$line" | sed -n 's/.*realloc=\([0-9]\+\).*/\1/p')
        pending=$(echo "$line" | sed -n 's/.*pending=\([0-9]\+\).*/\1/p')
        uncorrect=$(echo "$line" | sed -n 's/.*uncorrect=\([0-9]\+\).*/\1/p')
        hours=$(echo "$line" | sed -n 's/.*hours=\([0-9]\+\).*/\1/p')

        [[ "$dev" =~ ^/dev/ ]] || valid=false
        [[ -n "$health" ]] || valid=false
        [[ "$temp" =~ ^[0-9]+$ ]] || valid=false
        [[ "$realloc" =~ ^[0-9]+$ ]] || valid=false
        [[ "$pending" =~ ^[0-9]+$ ]] || valid=false
        [[ "$uncorrect" =~ ^[0-9]+$ ]] || valid=false
        [[ "$hours" =~ ^[0-9]+$ ]] || valid=false

    done <<< "$output"

    if [[ $valid == true ]]; then
        SMART_OK=1
    else
        SMART_OK=0
    fi
}


run_all_tests() {
    
    if [ $CPU_OK -eq 1 ]; then
        test_cpu
    fi
    if [ $MEMORY_OK -eq 1 ]; then
        test_memory
    fi
    if [ $GPU_OK -eq 1 ]; then
        test_gpu
    fi
    if [ $DISK_OK -eq 1 ]; then
        test_disk
    fi
    if [ $NETWORK_OK -eq 1 ]; then
        test_network
    fi
    if [ $LOAD_OK -eq 1 ]; then
        test_loadmatrics
    fi
    #if [ $SMART_OK -eq 1 ]; then
        #test_smartStatus
    #fi
    echo "All tests completed."
    echo "Flags: CPU=$CPU_OK, MEMORY=$MEMORY_OK, GPU=$GPU_OK, DISK=$DISK_OK, NETWORK=$NETWORK_OK, LOAD=$LOAD_OK, SMART=$SMART_OK"
}

# Execute tests
run_all_tests
detect_os