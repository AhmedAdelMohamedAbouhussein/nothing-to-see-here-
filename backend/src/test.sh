#!/bin/bash

LOG_DIR="system_reports"
mkdir -p "$LOG_DIR"
INTERVAL=10

TIMESTAMP=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
REPORT_DIR="$LOG_DIR/$TIMESTAMP"
mkdir -p "$REPORT_DIR"

# CRITICAL_MEMORY_THRESHOLD=50
# CRITICAL_VIRTAUL_MEMORY_THRESHOLD=50  
# CRITICAL_CPU_THRESHOLD=0     
# CRITICAL_CPU_TEMP_THRESHOLD=50 
# CRITICAL_GPU_USAGE_THRESHOLD=50  
# CRITICAL_GPU_TEMP_THRESHOLD=50
# CRITICAL_DISK_THRESHOLD=90  


function cpu
{
    Cpu=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2 + $4 + $6}')
    echo "CPU Usage: $Cpu%"
    Cputemp=$(sensors | awk '/Package id 0/ {gsub(/[+°C]/,"",$4); print $4 "°C"}')
    echo "CPU Temperature: $Cputemp"
  
    # if [ "$Cpu" -gt "$CRITICAL_CPU_THRESHOLD" ]; then
    # echo "ALERT: High CPU Usage ($Cpu%)"
    # fi
    # if [ "$Cputemp" -gt "$CRITICAL_CPU_TEMP_THRESHOLD" ]; then
    # echo "ALERT: High CPU TEMP ($Cputemp%)"
    # fi

    
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

    #if [ "$memoryUtilAverage" -gt "$CRITICAL_MEMORY_THRESHOLD" ]; then
    #echo "ALERT: High memory Usage ($memoryUtilAverage%)"
    #fi
    
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: Memory Utilization: $memoryUtilAverage Memory Used: $memoryUsed Memory Total: $mermoryTotal" >> "$REPORT_DIR/memory.log"
    
    # Get virtual memory 
    VMUtilAverage=$(free | awk '/Swap/ {printf("%3.1f", ($3/$2) * 100)}')
    echo "Virtual Memory Utilization: $VMUtilAverage%"
    VMUsed=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $3/1024}')
    echo "Virtual Memory Used: $VMUsed"
    VMTotal=$(free -m | awk '/Swap:/ {printf "%.2f GB\n", $2/1024}')
    echo "Virtual Memory Total: $VMTotal"

   # if [ "$VMUtilAverage" -gt "$CRITICAL_VIRTAUL_MEMORY_THRESHOLD" ]; then
   # echo "ALERT: High VIRTUAL MEMORY Usage ($VMUtilAverage%)"
   # fi

    echo "$CURRENT_TIME: Virtual Memory Utilization: $VMUtilAverage Virtual Memory Used: $VMUsed Virtual Memory Total: $VMTotal" >> "$REPORT_DIR/memory.log"

    echo "===============================" >> "$REPORT_DIR/memory.log"
}

function gpu
{
    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    
    if command -v nvidia-smi &> /dev/null; then
        GPU_Utilization=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader)
        echo "GPU Utilization: $GPU_Utilization"
        GPU_Temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)
        echo "GPU Temperature: $GPU_Temperature"

        

        echo "$CURRENT_TIME: GPU Utilization: $GPU_Utilization GPU Temperature: $GPU_Temperature" >> "$REPORT_DIR/gpu.log"

    elif command -v rocm-smi &> /dev/null; then #TODO
            GPU_Utilization=$(rocm-smi --showuse | awk '/GPU/ {print $3}')
            echo "GPU Utilization: $GPU_Utilization"
            GPU_Temperature=$(rocm-smi --showtemp | awk '/GPU/ {print $3}')
            echo "GPU Temperature: $GPU_Temperature"

            echo "$CURRENT_TIME: GPU Utilization: $GPU_Utilization GPU Temperature: $GPU_Temperature" >> "$REPORT_DIR/gpu.log"
    
    elif command -v intel_gpu_top &> /dev/null; then
            sudo timeout 0.2s intel_gpu_top > /dev/tty
            sudo timeout 0.2s intel_gpu_top -o /dev/stdout >> "$REPORT_DIR/gpu.log"
    fi  
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
            
            echo -e "partition : $clean_name $size $type $mount $used $use_percent"

            echo -e "$CURRENT_TIME: partition : $clean_name $size $type $mount $used $use_percent" >> "$REPORT_DIR/disk.log"

        elif [[ "$type" == "disk" ]]; then
            echo -e "disk : $clean_name $size"

            echo -e "$CURRENT_TIME: disk : $clean_name $size" >> "$REPORT_DIR/disk.log"
        
        elif [[ "$type" != "crypt" ]]; then
            echo -e "partition : $clean_name $size $mount"

            echo -e "$CURRENT_TIME: partition : $clean_name $size $mount" >> "$REPORT_DIR/disk.log"
        fi
    done

    echo "===============================" >> "$REPORT_DIR/disk.log"
}

function network
{
    network_usage=$(netstat -i)
    echo "Network Usage: $network_usage"

    CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    echo "$CURRENT_TIME: NetworkUsage=$network_usage" >> "$REPORT_DIR/network.log"

    echo "===============================" >> "$REPORT_DIR/network.log"
}

function smartStatus 
{
    sudo smartctl --scan | awk '{print $1}' | while read -r dev; do
    echo "===== SMART info for $dev ====="
    sudo smartctl -T permissive -a "$dev"
    done


    #smart_info=$(smartctl -T permissive )
   # echo "SMART Info: $smart_info"

    #CURRENT_TIME=$(date "+%Y-%m-%d-%Hh-%Mmin-%Ssec")
    #echo "$CURRENT_TIME: SMARTInfo=$smart_info" >> "$REPORT_DIR/smart.log"

    echo "===============================" >> "$REPORT_DIR/smart.log"

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
        #gpu
        #network
        #smartStatus

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

