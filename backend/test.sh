#!/bin/bash

LOG_DIR="../system_reports"
mkdir -p "$LOG_DIR"
INTERVAL=10

TIMESTAMP=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
REPORT_DIR="$LOG_DIR/$TIMESTAMP"
mkdir -p "$REPORT_DIR"


function cpu
{
    Cpu=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2 + $4 + $6}')
    echo "CPU Usage: $Cpu%"
    Cputemp=$(sensors | awk '/Package id 0/ {gsub(/[+°C]/,"",$4); print $4 "°C"}')
    echo "CPU Temperature: $Cputemp"

    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: CPU=$Cpu CPU_TEMP=$Cputemp" >> "$REPORT_DIR/cpu_$TIMESTAMP.log"

    echo "===============================" >> "$REPORT_DIR/cpu_$TIMESTAMP.log"
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
    echo "$CURRENT_TIME: memoryUtilAverage=$memoryUtilAverage MemoryUsed=$memoryUsed MemoryTotal=$mermoryTotal" >> "$REPORT_DIR/memory_$TIMESTAMP.log"

    # Get virtual memory 
    VMUtilAverage=$(free | awk '/Swap/ {printf("%3.1f", ($3/$2) * 100)}')
    echo "Virtual Memory Utilization: $VMUtilAverage%"
    VMUsed=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $3/1024}')
    echo "Virtual Memory Used: $VMUsed"
    VMTotal=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $2/1024}')
    echo "Virtual Memory Total: $VMTotal"
    
    echo "$CURRENT_TIME: VMUtilAverage=$VMUtilAverage VMUsed=$VMUsed VMTotal=$VMTotal" >> "$REPORT_DIR/memory_$TIMESTAMP.log"

    echo "===============================" >> "$REPORT_DIR/memory_$TIMESTAMP.log"
}

function gpu
{
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    
    if command -v nvidia-smi &> /dev/null; then
        GPU_Utilization=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader)
        echo "GPU Utilization: $GPU_Utilization"
        GPU_Temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)
        echo "GPU Temperature: $GPU_Temperature"

        echo "$CURRENT_TIME: GPU_Utilization=$GPU_Utilization GPU_Temperature=$GPU_Temperature" >> "$REPORT_DIR/gpu_$TIMESTAMP.log"

    elif command -v rocm-smi &> /dev/null; then #TODO
        GPU_Utilization=$(rocm-smi --showuse | awk '/GPU/ {print $3}')
        echo "GPU Utilization: $GPU_Utilization"
        GPU_Temperature=$(rocm-smi --showtemp | awk '/GPU/ {print $3}')
        echo "GPU Temperature: $GPU_Temperature"

        echo "$CURRENT_TIME: GPU_Utilization=$GPU_Utilization GPU_Temperature=$GPU_Temperature" >> "$REPORT_DIR/gpu_$TIMESTAMP.log"
    
    elif command -v intel_gpu_top &> /dev/null; then #TODO
        GPU_Utilization=$(sudo timout 20s intel_gpu_top)
        echo "GPU Utilization: $GPU_Utilization"

        echo "$CURRENT_TIME: GPU_Utilization=$GPU_Utilization" >> "$REPORT_DIR/gpu_$TIMESTAMP.log"
    fi

    echo "===============================" >> "$REPORT_DIR/gpu_$TIMESTAMP.log"
}


function disk 
{
    # List all block devices except swap and zram
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | while read name size type mount; do
        # Skip empty lines
        [ -z "$name" ] && continue

        # Skip swap partitions and zram devices
        if [[ "$type" == "swap" ]] || [[ "$name" == zram* ]]; then
            continue
        fi

        # If the mountpoint exists and is not "[SWAP]", get used space
        if [ -n "$mount" ] && [[ "$mount" != "[SWAP]" ]]; then
            used=$(df -h "$mount" | awk 'NR==2 {print $3 " used"}')
            echo -e "$name\t$size\t$type\t$mount\t$used"

            echo -e "$name\t$size\t$type\t$mount\t$used" >> "$REPORT_DIR/disk_$TIMESTAMP.log"

        else
            echo -e "$name\t$size\t$type\t$mount"

            echo -e "$name\t$size\t$type\t$mount" >> "$REPORT_DIR/disk_$TIMESTAMP.log"
        fi
    done

    echo "===============================" >> "$REPORT_DIR/disk_$TIMESTAMP.log"
}

function network
{
    network_usage=$(netstat -i)
    echo "Network Usage: $network_usage"

    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: NetworkUsage=$network_usage" >> "$REPORT_DIR/network_$TIMESTAMP.log"

    echo "===============================" >> "$REPORT_DIR/network_$TIMESTAMP.log"
}

function smartStatus 
{
    smart_info=$(smartctl -T permissive )
    echo "SMART Info: $smart_info"

    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: SMARTInfo=$smart_info" >> "$REPORT_DIR/smart_$TIMESTAMP.log"

    echo "===============================" >> "$REPORT_DIR/smart_$TIMESTAMP.log"

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

        #disk
        cpu 
        memory
        gpu
        network
        smartStatus

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