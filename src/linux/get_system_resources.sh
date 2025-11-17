#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/get_system_resources.sh
# Description: This script retrieves and displays system resource usage including CPU, memory, and disk.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Function to get CPU usage
get_cpu_usage() {
    echo "=== CPU Usage ==="
    if command -v top &> /dev/null; then
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Idle: " 100 - $1 "%"}'
    else
        echo "top command not available."
    fi
}

# Function to get memory usage
get_memory_usage() {
    echo "=== Memory Usage ==="
    if command -v free &> /dev/null; then
        free -h | grep "^Mem:" | awk '{print "Total: " $2 ", Used: " $3 ", Free: " $4}'
    else
        echo "free command not available."
    fi
}

# Function to get disk usage
get_disk_usage() {
    echo "=== Disk Usage ==="
    if command -v df &> /dev/null; then
        df -h | grep "^/dev/" | awk '{print $1 ": " $5 " used (" $3 "/" $2 ")"}'
    else
        echo "df command not available."
    fi
}

# Execute the functions
get_cpu_usage
get_memory_usage
get_disk_usage
