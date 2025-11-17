#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/monitor_services.sh
# Description: This script monitors critical system services and restarts them if they are down.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Configuration
SERVICES=("sshd" "nginx" "apache2" "mysql" "postgresql" "docker")
LOG_FILE="/var/log/service_monitor.log"
EMAIL=""

# Function to check service status
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

# Function to restart service
restart_service() {
    local service=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempting to restart $service" | tee -a "$LOG_FILE"
    systemctl restart "$service"
    sleep 5
    
    if check_service "$service"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully restarted $service" | tee -a "$LOG_FILE"
        send_notification "$service" "restarted"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to restart $service" | tee -a "$LOG_FILE"
        send_notification "$service" "failed"
    fi
}

# Function to send notification
send_notification() {
    local service=$1
    local status=$2
    
    if [ ! -z "$EMAIL" ]; then
        if [ "$status" = "restarted" ]; then
            echo "Service $service was down and has been restarted." | mail -s "Service Alert: $service Restarted" "$EMAIL" 2>/dev/null || true
        else
            echo "Service $service is down and failed to restart. Manual intervention required." | mail -s "CRITICAL: Service Alert - $service" "$EMAIL" 2>/dev/null || true
        fi
    fi
}

# Function to monitor all services
monitor_services() {
    echo "=== Monitoring Services at $(date '+%Y-%m-%d %H:%M:%S') ==="
    for service in "${SERVICES[@]}"; do
        # Check if service exists
        if systemctl list-unit-files | grep -q "^$service.service"; then
            if check_service "$service"; then
                echo "OK: $service is running"
            else
                echo "ALERT: $service is not running"
                restart_service "$service"
            fi
        fi
    done
}

# Function to display service summary
display_summary() {
    echo ""
    echo "=== Service Status Summary ==="
    for service in "${SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^$service.service"; then
            status=$(systemctl is-active "$service" 2>/dev/null)
            echo "$service: $status"
        fi
    done
}

# Execute monitoring
monitor_services
display_summary

echo ""
echo "Service monitoring completed."
