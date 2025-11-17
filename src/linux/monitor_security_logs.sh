#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/monitor_security_logs.sh
# Description: This script monitors security logs for suspicious activities and generates alerts.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Configuration
AUTH_LOG="/var/log/auth.log"
SECURE_LOG="/var/log/secure"
REPORT_FILE="/var/log/security_report_$(date +%Y%m%d).log"
EMAIL=""
FAILED_LOGIN_THRESHOLD=5

# Detect which log file to use
if [ -f "$AUTH_LOG" ]; then
    LOG_FILE="$AUTH_LOG"
elif [ -f "$SECURE_LOG" ]; then
    LOG_FILE="$SECURE_LOG"
else
    echo "No authentication log file found."
    exit 1
fi

# Function to check failed login attempts
check_failed_logins() {
    echo "=== Checking Failed Login Attempts ===" | tee -a "$REPORT_FILE"
    
    FAILED_LOGINS=$(grep "Failed password" "$LOG_FILE" | tail -n 100)
    
    if [ ! -z "$FAILED_LOGINS" ]; then
        echo "$FAILED_LOGINS" | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | while read count ip; do
            if [ "$count" -ge "$FAILED_LOGIN_THRESHOLD" ]; then
                echo "ALERT: $count failed login attempts from IP: $ip" | tee -a "$REPORT_FILE"
            fi
        done
    else
        echo "No failed login attempts found." | tee -a "$REPORT_FILE"
    fi
}

# Function to check successful logins
check_successful_logins() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== Recent Successful Logins ===" | tee -a "$REPORT_FILE"
    
    grep "Accepted password\|Accepted publickey" "$LOG_FILE" | tail -n 20 | tee -a "$REPORT_FILE"
}

# Function to check sudo usage
check_sudo_usage() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== Recent Sudo Usage ===" | tee -a "$REPORT_FILE"
    
    grep "sudo:" "$LOG_FILE" | tail -n 20 | tee -a "$REPORT_FILE"
}

# Function to check user additions/deletions
check_user_changes() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== User Account Changes ===" | tee -a "$REPORT_FILE"
    
    grep -E "useradd|userdel|usermod" "$LOG_FILE" | tail -n 20 | tee -a "$REPORT_FILE"
}

# Function to check for root login attempts
check_root_logins() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== Root Login Attempts ===" | tee -a "$REPORT_FILE"
    
    ROOT_ATTEMPTS=$(grep "Failed password for root" "$LOG_FILE" | tail -n 20)
    
    if [ ! -z "$ROOT_ATTEMPTS" ]; then
        echo "WARNING: Root login attempts detected!" | tee -a "$REPORT_FILE"
        echo "$ROOT_ATTEMPTS" | tee -a "$REPORT_FILE"
    else
        echo "No root login attempts found." | tee -a "$REPORT_FILE"
    fi
}

# Function to check for SSH brute force attempts
check_ssh_bruteforce() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== Potential SSH Brute Force Attacks ===" | tee -a "$REPORT_FILE"
    
    grep "Failed password" "$LOG_FILE" | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -n 10 | while read count ip; do
        if [ "$count" -ge 10 ]; then
            echo "CRITICAL: Possible brute force attack from $ip with $count attempts" | tee -a "$REPORT_FILE"
        fi
    done
}

# Function to check for privilege escalation attempts
check_privilege_escalation() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== Privilege Escalation Attempts ===" | tee -a "$REPORT_FILE"
    
    grep -E "sudo.*COMMAND|su\[" "$LOG_FILE" | tail -n 20 | tee -a "$REPORT_FILE"
}

# Function to check for invalid users
check_invalid_users() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== Invalid User Login Attempts ===" | tee -a "$REPORT_FILE"
    
    INVALID_USERS=$(grep "Invalid user" "$LOG_FILE" | tail -n 20)
    
    if [ ! -z "$INVALID_USERS" ]; then
        echo "WARNING: Invalid user login attempts detected!" | tee -a "$REPORT_FILE"
        echo "$INVALID_USERS" | tee -a "$REPORT_FILE"
    else
        echo "No invalid user attempts found." | tee -a "$REPORT_FILE"
    fi
}

# Function to check firewall logs
check_firewall_logs() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=== Firewall Blocked Connections ===" | tee -a "$REPORT_FILE"
    
    if [ -f "/var/log/ufw.log" ]; then
        grep "BLOCK" /var/log/ufw.log | tail -n 20 | tee -a "$REPORT_FILE"
    elif command -v journalctl &> /dev/null; then
        journalctl -u firewalld --since today | grep -i "REJECT\|DROP" | tail -n 20 | tee -a "$REPORT_FILE"
    else
        echo "No firewall logs found." | tee -a "$REPORT_FILE"
    fi
}

# Function to send email report
send_email_report() {
    if [ ! -z "$EMAIL" ]; then
        mail -s "Security Log Report - $(date +%Y-%m-%d)" "$EMAIL" < "$REPORT_FILE" 2>/dev/null || true
        echo "Report sent to $EMAIL"
    fi
}

# Function to display summary
display_summary() {
    echo "" | tee -a "$REPORT_FILE"
    echo "=========================================" | tee -a "$REPORT_FILE"
    echo "Security Monitoring Report" | tee -a "$REPORT_FILE"
    echo "Date: $(date)" | tee -a "$REPORT_FILE"
    echo "Log File: $LOG_FILE" | tee -a "$REPORT_FILE"
    echo "Report File: $REPORT_FILE" | tee -a "$REPORT_FILE"
    echo "=========================================" | tee -a "$REPORT_FILE"
}

# Main execution
echo "Starting security log monitoring..." > "$REPORT_FILE"
display_summary
check_failed_logins
check_successful_logins
check_sudo_usage
check_user_changes
check_root_logins
check_ssh_bruteforce
check_privilege_escalation
check_invalid_users
check_firewall_logs
send_email_report

echo ""
echo "Security monitoring completed. Report saved to: $REPORT_FILE"
