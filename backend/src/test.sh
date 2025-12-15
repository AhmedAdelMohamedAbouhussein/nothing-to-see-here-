#!/bin/bash

LOG_DIR="system_reports"
mkdir -p "$LOG_DIR"
INTERVAL=10

TIMESTAMP=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
REPORT_DIR="$LOG_DIR/$TIMESTAMP"
mkdir -p "$REPORT_DIR"

    CRITICAL_MEMORY_THRESHOLD=50
    CRITICAL_VIRTAUL_MEMORY_THRESHOLD=50
    CRITICAL_CPU_THRESHOLD=70
    CRITICAL_CPU_TEMP_THRESHOLD=50
    CRITICAL_GPU_USAGE_THRESHOLD=50
    CRITICAL_GPU_TEMP_THRESHOLD=50
    CRITICAL_DISK_THRESHOLD=90  


function cpu
{
    Cpu=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2 + $4 + $6}')
    echo "CPU Usage: $Cpu%"
    Cputemp=$(sensors | awk '/Package id 0/ {gsub(/[+°C]/,"",$4); print $4 "°C"}')
    echo "CPU Temperature: $Cputemp"

    # Create a numeric-only temp variable for bc comparison
    Cputemp_num=$(echo "$Cputemp" | sed 's/[^0-9.]//g')

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
    echo "Memory Utilization: $memoryUtilAverage%"
    memoryUsed=$(free -m | awk '/Mem:/ {printf "%.2f GB\n", $3/1024}')
    echo "Memory Used: $memoryUsed"
    mermoryTotal=$(free -m | awk '/Mem:/ {printf "%.2f GB\n", $2/1024}')
    echo "Memory Total: $mermoryTotal"
    
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: Memory Utilization: $memoryUtilAverage Memory Used: $memoryUsed Memory Total: $mermoryTotal" >> "$REPORT_DIR/memory.log"
    
    # Get virtual memory 
    VMUtilAverage=$(free | awk '/Swap/ {printf("%3.1f", ($3/$2) * 100)}')
    echo "Virtual Memory Utilization: $VMUtilAverage%"
    VMUsed=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $3/1024}')
    echo "Virtual Memory Used: $VMUsed"
    VMTotal=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $2/1024}')
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
        GPU_Utilization=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
        echo "GPU Usage: $GPU_Utilization%"
        GPU_Temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)

        echo "GPU Temperature: $GPU_Temperature°C"

        echo "$CURRENT_TIME: GPU Usage: $GPU_Utilization% GPU Temperature: $GPU_Temperature°C" >> "$REPORT_DIR/gpu.log"

    elif command -v rocm-smi &> /dev/null; then #TODO
            GPU_Utilization=$(rocm-smi --showuse | awk '/GPU/ {print $3}')
            echo "GPU Usage: $GPU_Utilization%"
            GPU_Temperature=$(rocm-smi --showtemp | awk '/GPU/ {print $3}')
            echo "GPU Temperature: $GPU_Temperature°C"

            echo "$CURRENT_TIME: GPU Usage: $GPU_Utilization% GPU Temperature: $GPU_Temperature°C" >> "$REPORT_DIR/gpu.log"
    
    # elif command -v intel_gpu_top &> /dev/null; then
    #         sudo timeout 0.2s intel_gpu_top > /dev/tty
    #         sudo timeout 0.2s intel_gpu_top -o /dev/stdout >> "$REPORT_DIR/gpu.log"
    fi  

    # Clean numeric values for comparison
    GPU_Util_num=$(echo "$GPU_Utilization" | sed 's/[^0-9.]//g')
    GPU_Temp_num=$(echo "$GPU_Temperature" | sed 's/[^0-9.]//g')

    # GPU usage alert
    if (( $(echo "$GPU_Util_num > $CRITICAL_GPU_USAGE_THRESHOLD" | bc -l) )); then
        echo "ALERT: High GPU Usage ($GPU_Utilization%)" 
        echo "ALERT: High GPU Usage ($GPU_Utilization%)" >> "$REPORT_DIR/gpu.log"
    fi

    # GPU temperature alert
    if (( $(echo "$GPU_Temp_num > $CRITICAL_GPU_TEMP_THRESHOLD" | bc -l) )); then
        echo "ALERT: High GPU TEMP ($GPU_Temperature°C)" 
        echo "ALERT: High GPU TEMP ($GPU_Temperature°C)" >> "$REPORT_DIR/gpu.log"
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
    TX_BYTES=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes" 2>/dev/null)

    # Format the output string
    NETWORK_DATA="Interface: $INTERFACE | Incoming_Bytes_Total: $RX_BYTES | Outgoing_Bytes_Total: $TX_BYTES"

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
        TEMP=$(sudo smartctl -A "$dev" | awk '$1==194 {print $10}')
        REALLOC=$(sudo smartctl -A "$dev" | awk '$1==5 {print $10}')
        PENDING=$(sudo smartctl -A "$dev" | awk '$1==197 {print $10}')
        UNCORR=$(sudo smartctl -A "$dev" | awk '$1==198 {print $10}')
        HOURS=$(sudo smartctl -A "$dev" | awk '$1==9 {print $10}')

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
detect_os