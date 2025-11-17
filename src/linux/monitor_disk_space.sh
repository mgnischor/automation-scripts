#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/monitor_disk_space.sh
# Description: This script monitors disk space usage and sends alerts when thresholds are exceeded.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Configuration
THRESHOLD=80
EMAIL=""
LOG_FILE="/var/log/disk_monitor.log"

# Function to check disk usage
check_disk_usage() {
    echo "=== Checking Disk Usage ==="
    df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 " " $6 }' | while read output; do
        usage=$(echo "$output" | awk '{print $1}' | sed 's/%//g')
        partition=$(echo "$output" | awk '{print $2}')
        mount_point=$(echo "$output" | awk '{print $3}')
        
        if [ "$usage" -ge "$THRESHOLD" ]; then
            echo "WARNING: Disk usage on $partition ($mount_point) is at ${usage}%" | tee -a "$LOG_FILE"
            send_alert "$partition" "$mount_point" "$usage"
        else
            echo "OK: Disk usage on $partition ($mount_point) is at ${usage}%"
        fi
    done
}

# Function to send alert
send_alert() {
    local partition=$1
    local mount_point=$2
    local usage=$3
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT: ${partition} (${mount_point}) at ${usage}%" >> "$LOG_FILE"
    
    if [ ! -z "$EMAIL" ]; then
        echo "Disk usage on ${partition} (${mount_point}) has reached ${usage}%" | mail -s "Disk Space Alert" "$EMAIL" 2>/dev/null || true
    fi
}

# Function to find large files
find_large_files() {
    echo ""
    echo "=== Top 10 Largest Files ==="
    find / -type f -exec du -h {} + 2>/dev/null | sort -rh | head -n 10
}

# Function to find large directories
find_large_directories() {
    echo ""
    echo "=== Top 10 Largest Directories ==="
    du -h --max-depth=2 / 2>/dev/null | sort -rh | head -n 10
}

# Function to display inode usage
check_inode_usage() {
    echo ""
    echo "=== Inode Usage ==="
    df -i | grep -vE '^Filesystem|tmpfs|cdrom'
}

# Execute monitoring functions
check_disk_usage
find_large_files
find_large_directories
check_inode_usage

echo ""
echo "Disk monitoring completed."
