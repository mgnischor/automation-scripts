#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/cleanup_system.sh
# Description: This script performs system cleanup tasks including package cache, logs, and temporary files.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Function to clean package cache
clean_package_cache() {
    echo "=== Cleaning Package Cache ==="
    if command -v apt &> /dev/null; then
        apt autoremove -y
        apt autoclean
        apt clean
        echo "APT cache cleaned."
    elif command -v yum &> /dev/null; then
        yum autoremove -y
        yum clean all
        echo "YUM cache cleaned."
    elif command -v dnf &> /dev/null; then
        dnf autoremove -y
        dnf clean all
        echo "DNF cache cleaned."
    else
        echo "No supported package manager found."
    fi
}

# Function to clean old log files
clean_logs() {
    echo "=== Cleaning Old Log Files ==="
    # Rotate logs
    logrotate -f /etc/logrotate.conf 2>/dev/null || true
    
    # Remove old compressed logs
    find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null || true
    find /var/log -type f -name "*.old" -mtime +30 -delete 2>/dev/null || true
    find /var/log -type f -name "*.1" -mtime +30 -delete 2>/dev/null || true
    
    # Truncate large log files
    find /var/log -type f -size +100M -exec truncate -s 0 {} \; 2>/dev/null || true
    
    echo "Old log files cleaned."
}

# Function to clean temporary files
clean_temp_files() {
    echo "=== Cleaning Temporary Files ==="
    # Clean /tmp
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /tmp -type d -empty -delete 2>/dev/null || true
    
    # Clean /var/tmp
    find /var/tmp -type f -atime +30 -delete 2>/dev/null || true
    find /var/tmp -type d -empty -delete 2>/dev/null || true
    
    # Clean user cache
    find /home/*/.cache -type f -atime +30 -delete 2>/dev/null || true
    
    echo "Temporary files cleaned."
}

# Function to clean old kernels (Debian/Ubuntu)
clean_old_kernels() {
    echo "=== Cleaning Old Kernels ==="
    if command -v dpkg &> /dev/null; then
        CURRENT_KERNEL=$(uname -r)
        OLD_KERNELS=$(dpkg --list | grep linux-image | awk '{print $2}' | grep -v "$CURRENT_KERNEL")
        
        if [ ! -z "$OLD_KERNELS" ]; then
            for kernel in $OLD_KERNELS; do
                apt purge -y "$kernel" 2>/dev/null || true
            done
            echo "Old kernels removed."
        else
            echo "No old kernels to remove."
        fi
    else
        echo "Kernel cleanup only available on Debian-based systems."
    fi
}

# Function to clean journal logs
clean_journal() {
    echo "=== Cleaning Journal Logs ==="
    if command -v journalctl &> /dev/null; then
        journalctl --vacuum-time=7d
        journalctl --vacuum-size=100M
        echo "Journal logs cleaned."
    else
        echo "journalctl not available."
    fi
}

# Function to clean thumbnail cache
clean_thumbnails() {
    echo "=== Cleaning Thumbnail Cache ==="
    find /home/*/.cache/thumbnails -type f -delete 2>/dev/null || true
    find /root/.cache/thumbnails -type f -delete 2>/dev/null || true
    echo "Thumbnail cache cleaned."
}

# Function to clean orphaned packages
clean_orphaned_packages() {
    echo "=== Cleaning Orphaned Packages ==="
    if command -v deborphan &> /dev/null; then
        ORPHANS=$(deborphan)
        if [ ! -z "$ORPHANS" ]; then
            apt purge -y $(deborphan)
            echo "Orphaned packages removed."
        else
            echo "No orphaned packages found."
        fi
    else
        echo "deborphan not installed. Skipping."
    fi
}

# Function to display disk space before and after
display_disk_space() {
    echo ""
    echo "=== Disk Space Usage ==="
    df -h / | tail -n 1
}

# Main execution
echo "Starting system cleanup..."
echo ""
display_disk_space

clean_package_cache
clean_logs
clean_temp_files
clean_old_kernels
clean_journal
clean_thumbnails
clean_orphaned_packages

echo ""
echo "Cleanup completed."
display_disk_space
