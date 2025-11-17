#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/system_health_check.sh
# Description: This script performs comprehensive system health checks and generates a detailed report.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Configuration
REPORT_FILE="/tmp/system_health_$(date +%Y%m%d_%H%M%S).txt"
EMAIL=""
CPU_THRESHOLD=80
MEMORY_THRESHOLD=80
DISK_THRESHOLD=80

# Function to print header
print_header() {
    echo "=========================================" | tee -a "$REPORT_FILE"
    echo "$1" | tee -a "$REPORT_FILE"
    echo "=========================================" | tee -a "$REPORT_FILE"
}

# Function to check system information
check_system_info() {
    print_header "System Information"
    echo "Hostname: $(hostname)" | tee -a "$REPORT_FILE"
    echo "Kernel: $(uname -r)" | tee -a "$REPORT_FILE"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)" | tee -a "$REPORT_FILE"
    echo "Uptime: $(uptime -p)" | tee -a "$REPORT_FILE"
    echo "Current Time: $(date)" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check CPU usage
check_cpu() {
    print_header "CPU Status"
    
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}')
    
    echo "CPU Usage: ${CPU_USAGE}%" | tee -a "$REPORT_FILE"
    echo "Load Average:${CPU_LOAD}" | tee -a "$REPORT_FILE"
    echo "CPU Cores: $(nproc)" | tee -a "$REPORT_FILE"
    
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
        echo "WARNING: CPU usage above threshold (${CPU_THRESHOLD}%)!" | tee -a "$REPORT_FILE"
    else
        echo "Status: OK" | tee -a "$REPORT_FILE"
    fi
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check memory usage
check_memory() {
    print_header "Memory Status"
    
    free -h | tee -a "$REPORT_FILE"
    
    MEMORY_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
    
    echo "" | tee -a "$REPORT_FILE"
    echo "Memory Usage: $(printf "%.2f" $MEMORY_USAGE)%" | tee -a "$REPORT_FILE"
    
    if (( $(echo "$MEMORY_USAGE > $MEMORY_THRESHOLD" | bc -l) )); then
        echo "WARNING: Memory usage above threshold (${MEMORY_THRESHOLD}%)!" | tee -a "$REPORT_FILE"
    else
        echo "Status: OK" | tee -a "$REPORT_FILE"
    fi
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check disk usage
check_disk() {
    print_header "Disk Usage"
    
    df -h | grep -vE '^Filesystem|tmpfs|cdrom' | tee -a "$REPORT_FILE"
    
    echo "" | tee -a "$REPORT_FILE"
    
    df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{print $5 " " $1 " " $6}' | while read output; do
        usage=$(echo "$output" | awk '{print $1}' | sed 's/%//g')
        partition=$(echo "$output" | awk '{print $2}')
        mount=$(echo "$output" | awk '{print $3}')
        
        if [ "$usage" -ge "$DISK_THRESHOLD" ]; then
            echo "WARNING: Disk usage on $partition ($mount) is at ${usage}%!" | tee -a "$REPORT_FILE"
        fi
    done
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check network connectivity
check_network() {
    print_header "Network Status"
    
    echo "Network Interfaces:" | tee -a "$REPORT_FILE"
    ip -br addr | tee -a "$REPORT_FILE"
    
    echo "" | tee -a "$REPORT_FILE"
    echo "Testing Connectivity:" | tee -a "$REPORT_FILE"
    
    if ping -c 3 8.8.8.8 &>/dev/null; then
        echo "Internet: OK (8.8.8.8 reachable)" | tee -a "$REPORT_FILE"
    else
        echo "Internet: FAILED (Cannot reach 8.8.8.8)" | tee -a "$REPORT_FILE"
    fi
    
    if ping -c 3 google.com &>/dev/null; then
        echo "DNS: OK (google.com reachable)" | tee -a "$REPORT_FILE"
    else
        echo "DNS: FAILED (Cannot resolve google.com)" | tee -a "$REPORT_FILE"
    fi
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check running services
check_services() {
    print_header "Critical Services Status"
    
    SERVICES=("sshd" "nginx" "apache2" "httpd" "mysql" "mariadb" "postgresql" "docker")
    
    for service in "${SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^$service.service"; then
            status=$(systemctl is-active "$service" 2>/dev/null)
            echo "$service: $status" | tee -a "$REPORT_FILE"
        fi
    done
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check for failed services
check_failed_services() {
    print_header "Failed Services"
    
    FAILED=$(systemctl list-units --state=failed --no-pager --no-legend)
    
    if [ -z "$FAILED" ]; then
        echo "No failed services." | tee -a "$REPORT_FILE"
    else
        echo "$FAILED" | tee -a "$REPORT_FILE"
    fi
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check system updates
check_updates() {
    print_header "System Updates"
    
    if command -v apt &> /dev/null; then
        apt update &>/dev/null
        UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
        echo "Available updates: $UPDATES" | tee -a "$REPORT_FILE"
    elif command -v yum &> /dev/null; then
        UPDATES=$(yum check-update --quiet | wc -l)
        echo "Available updates: $UPDATES" | tee -a "$REPORT_FILE"
    fi
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check logged in users
check_users() {
    print_header "Logged In Users"
    
    who | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check last reboots
check_reboots() {
    print_header "Last Reboots"
    
    last reboot | head -n 5 | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

# Function to check zombie processes
check_zombies() {
    print_header "Zombie Processes"
    
    ZOMBIES=$(ps aux | awk '{if ($8=="Z") print $0}')
    
    if [ -z "$ZOMBIES" ]; then
        echo "No zombie processes." | tee -a "$REPORT_FILE"
    else
        echo "$ZOMBIES" | tee -a "$REPORT_FILE"
    fi
    echo "" | tee -a "$REPORT_FILE"
}

# Function to send email report
send_email() {
    if [ ! -z "$EMAIL" ]; then
        mail -s "System Health Report - $(hostname)" "$EMAIL" < "$REPORT_FILE" 2>/dev/null || true
        echo "Report sent to $EMAIL"
    fi
}

# Function to display summary
display_summary() {
    print_header "Health Check Summary"
    echo "Report generated at: $(date)" | tee -a "$REPORT_FILE"
    echo "Report file: $REPORT_FILE" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

# Main execution
echo "Starting system health check..." > "$REPORT_FILE"
echo ""

check_system_info
check_cpu
check_memory
check_disk
check_network
check_services
check_failed_services
check_updates
check_users
check_reboots
check_zombies
display_summary

echo "System health check completed!"
echo "Report saved to: $REPORT_FILE"

send_email
