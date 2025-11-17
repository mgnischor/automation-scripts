#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/backup_system.sh
# Description: This script creates compressed backups of critical system directories and files.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Configuration
BACKUP_DIR="/var/backups/system"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="system_backup_${TIMESTAMP}.tar.gz"

# Function to create backup directory
create_backup_dir() {
    echo "=== Creating Backup Directory ==="
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        echo "Backup directory created: $BACKUP_DIR"
    else
        echo "Backup directory exists: $BACKUP_DIR"
    fi
}

# Function to backup system configuration files
backup_system_configs() {
    echo "=== Backing Up System Configuration Files ==="
    CONFIGS=(
        "/etc/fstab"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/resolv.conf"
        "/etc/network/"
        "/etc/sysconfig/"
        "/etc/ssh/sshd_config"
        "/etc/sudoers"
        "/etc/passwd"
        "/etc/group"
        "/etc/shadow"
        "/etc/gshadow"
    )
    
    TEMP_DIR=$(mktemp -d)
    for config in "${CONFIGS[@]}"; do
        if [ -e "$config" ]; then
            cp -rp "$config" "$TEMP_DIR/" 2>/dev/null || true
        fi
    done
    
    tar -czf "${BACKUP_DIR}/configs_${TIMESTAMP}.tar.gz" -C "$TEMP_DIR" . 2>/dev/null
    rm -rf "$TEMP_DIR"
    echo "System configuration backup completed."
}

# Function to backup installed packages list
backup_packages_list() {
    echo "=== Backing Up Installed Packages List ==="
    if command -v dpkg &> /dev/null; then
        dpkg --get-selections > "${BACKUP_DIR}/packages_${TIMESTAMP}.txt"
    elif command -v rpm &> /dev/null; then
        rpm -qa > "${BACKUP_DIR}/packages_${TIMESTAMP}.txt"
    fi
    echo "Packages list backup completed."
}

# Function to backup cron jobs
backup_cron_jobs() {
    echo "=== Backing Up Cron Jobs ==="
    CRON_BACKUP="${BACKUP_DIR}/cron_${TIMESTAMP}"
    mkdir -p "$CRON_BACKUP"
    
    # System crontabs
    cp -rp /etc/cron* "$CRON_BACKUP/" 2>/dev/null || true
    
    # User crontabs
    for user in $(cut -f1 -d: /etc/passwd); do
        crontab -u "$user" -l > "${CRON_BACKUP}/${user}_crontab" 2>/dev/null || true
    done
    
    tar -czf "${BACKUP_DIR}/cron_${TIMESTAMP}.tar.gz" -C "${BACKUP_DIR}" "cron_${TIMESTAMP}" 2>/dev/null
    rm -rf "$CRON_BACKUP"
    echo "Cron jobs backup completed."
}

# Function to backup home directories
backup_home_directories() {
    echo "=== Backing Up Home Directories ==="
    tar -czf "${BACKUP_DIR}/home_${TIMESTAMP}.tar.gz" -C /home . 2>/dev/null || true
    echo "Home directories backup completed."
}

# Function to clean old backups (keep last 7 days)
clean_old_backups() {
    echo "=== Cleaning Old Backups ==="
    find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +7 -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "*.txt" -type f -mtime +7 -delete 2>/dev/null || true
    echo "Old backups cleaned."
}

# Function to display backup summary
display_summary() {
    echo ""
    echo "========================================="
    echo "Backup Summary"
    echo "========================================="
    echo "Backup Location: $BACKUP_DIR"
    echo "Timestamp: $TIMESTAMP"
    echo ""
    echo "Backup Files:"
    ls -lh "$BACKUP_DIR" | grep "$TIMESTAMP"
    echo "========================================="
}

# Execute backup functions
create_backup_dir
backup_system_configs
backup_packages_list
backup_cron_jobs
backup_home_directories
clean_old_backups
display_summary

echo "System backup completed successfully."
