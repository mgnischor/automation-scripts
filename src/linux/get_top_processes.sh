#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/get_top_processes.sh
# Description: This script retrieves and displays the top processes by CPU and memory usage.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Number of top processes to display
TOP_N=10

# Function to get top processes by CPU usage
get_top_cpu_processes() {
    echo "=== Top $TOP_N Processes by CPU Usage ==="
    if command -v ps &> /dev/null; then
        ps aux --sort=-%cpu | head -n $((TOP_N + 1)) | awk 'NR>1 {print "PID: " $2 ", CPU: " $3 "%, Command: " $11}'
    else
        echo "ps command not available."
    fi
}

# Function to get top processes by memory usage
get_top_memory_processes() {
    echo "=== Top $TOP_N Processes by Memory Usage ==="
    if command -v ps &> /dev/null; then
        ps aux --sort=-%mem | head -n $((TOP_N + 1)) | awk 'NR>1 {print "PID: " $2 ", Memory: " $4 "%, Command: " $11}'
    else
        echo "ps command not available."
    fi
}

# Execute the functions
get_top_cpu_processes
echo ""
get_top_memory_processes
