#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/debian_hardening.sh
# Description: This script applies basic hardening measures specific to Debian-based systems.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Function to generate a random SSH port
generate_random_port() {
    RANDOM_PORT=$(od -An -N2 -tu2 /dev/urandom | awk '{print ($1 % 64512) + 1024}')
    echo "Generated random SSH port: $RANDOM_PORT"
}

# Generate the random port
generate_random_port

# Function to update and upgrade the system
update_system() {
    echo "=== Updating System Packages ==="
    apt update && apt upgrade -y && apt autoremove -y && apt autoclean
    if [ $? -eq 0 ]; then
        echo "System updated successfully."
    else
        echo "Failed to update system."
    fi
}

# Function to install essential security packages
install_security_packages() {
    echo "=== Installing Security Packages ==="
    apt install -y ufw fail2ban unattended-upgrades apt-listchanges auditd apparmor aide libpam-pwquality libpam-tmpdir
    if [ $? -eq 0 ]; then
        echo "Security packages installed."
    else
        echo "Failed to install security packages."
    fi
}

# Function to configure UFW firewall
configure_firewall() {
    echo "=== Configuring Firewall (UFW) ==="
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow $RANDOM_PORT/tcp
    ufw reload
    echo "Firewall configured. SSH allowed on port $RANDOM_PORT."
}

# Function to harden SSH configuration
harden_ssh() {
    echo "=== Hardening SSH Configuration ==="
    SSH_CONFIG="/etc/ssh/sshd_config"
    if [ -f "$SSH_CONFIG" ]; then
        # Backup original config
        cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"
        # Disable root login
        sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' "$SSH_CONFIG"
        sed -i 's/PermitRootLogin yes/PermitRootLogin no/' "$SSH_CONFIG"
        # Disable password authentication
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' "$SSH_CONFIG"
        sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' "$SSH_CONFIG"
        # Change default port to random port
        sed -i "s/#Port 22/Port $RANDOM_PORT/" "$SSH_CONFIG"
        # Disable empty passwords
        sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' "$SSH_CONFIG"
        sed -i 's/PermitEmptyPasswords yes/PermitEmptyPasswords no/' "$SSH_CONFIG"
        # Disable X11 forwarding
        sed -i 's/#X11Forwarding yes/X11Forwarding no/' "$SSH_CONFIG"
        sed -i 's/X11Forwarding yes/X11Forwarding no/' "$SSH_CONFIG"
        # Set max authentication attempts
        sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' "$SSH_CONFIG"
        # Set login grace time
        sed -i 's/#LoginGraceTime 2m/LoginGraceTime 30s/' "$SSH_CONFIG"
        # Use only SSH protocol 2
        echo "Protocol 2" >> "$SSH_CONFIG"
        # Set stronger ciphers
        echo "Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> "$SSH_CONFIG"
        echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256" >> "$SSH_CONFIG"
        systemctl restart sshd
        echo "SSH hardened. Restarted SSH service on port $RANDOM_PORT."
    else
        echo "SSH config file not found."
    fi
}

# Function to enable unattended upgrades
enable_unattended_upgrades() {
    echo "=== Enabling Unattended Upgrades ==="
    dpkg-reconfigure --priority=low unattended-upgrades
    echo "Unattended upgrades enabled."
}

# Function to configure kernel hardening parameters
harden_kernel() {
    echo "=== Configuring Kernel Hardening ==="
    SYSCTL_CONF="/etc/sysctl.d/99-hardening.conf"
    cat > "$SYSCTL_CONF" << EOF
# IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Restrict kernel pointer access
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict kernel profiling
kernel.perf_event_paranoid = 3

# Enable ASLR
kernel.randomize_va_space = 2
EOF
    sysctl -p "$SYSCTL_CONF"
    echo "Kernel hardening configured."
}

# Function to configure audit logging
configure_audit() {
    echo "=== Configuring Audit Logging ==="
    if command -v auditctl &> /dev/null; then
        # Monitor authentication files
        auditctl -w /etc/passwd -p wa -k passwd_changes
        auditctl -w /etc/group -p wa -k group_changes
        auditctl -w /etc/shadow -p wa -k shadow_changes
        auditctl -w /etc/sudoers -p wa -k sudoers_changes
        # Monitor network configuration
        auditctl -w /etc/network/ -p wa -k network_changes
        # Monitor SSH configuration
        auditctl -w /etc/ssh/sshd_config -p wa -k sshd_config_changes
        # Monitor login/logout events
        auditctl -w /var/log/lastlog -p wa -k logins
        auditctl -w /var/log/faillog -p wa -k logins
        # Monitor file deletion
        auditctl -a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete
        # Persist rules
        auditctl -R /etc/audit/rules.d/audit.rules 2>/dev/null || true
        systemctl enable auditd
        systemctl restart auditd
        echo "Audit logging configured."
    else
        echo "auditd not installed."
    fi
}

# Function to harden file permissions
harden_file_permissions() {
    echo "=== Hardening File Permissions ==="
    # Secure sensitive files
    chmod 600 /etc/shadow
    chmod 600 /etc/gshadow
    chmod 644 /etc/passwd
    chmod 644 /etc/group
    chmod 600 /boot/grub/grub.cfg 2>/dev/null || chmod 600 /boot/grub2/grub.cfg 2>/dev/null || true
    # Secure log files
    chmod 640 /var/log/auth.log 2>/dev/null || true
    chmod 640 /var/log/syslog 2>/dev/null || true
    # Disable core dumps
    echo "* hard core 0" >> /etc/security/limits.conf
    echo "fs.suid_dumpable = 0" >> /etc/sysctl.d/99-hardening.conf
    sysctl -w fs.suid_dumpable=0
    echo "File permissions hardened."
}

# Function to configure password policies
configure_password_policy() {
    echo "=== Configuring Password Policies ==="
    PAM_PWD="/etc/pam.d/common-password"
    if [ -f "$PAM_PWD" ]; then
        # Backup original
        cp "$PAM_PWD" "${PAM_PWD}.bak"
        # Set password complexity requirements
        sed -i 's/pam_pwquality.so.*/pam_pwquality.so retry=3 minlen=14 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 maxrepeat=3 gecoscheck=1/' "$PAM_PWD"
    fi
    # Set password aging
    sed -i 's/PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
    sed -i 's/PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' /etc/login.defs
    sed -i 's/PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
    echo "Password policies configured."
}

# Function to configure fail2ban
configure_fail2ban() {
    echo "=== Configuring Fail2Ban ==="
    FAIL2BAN_CONF="/etc/fail2ban/jail.local"
    cat > "$FAIL2BAN_CONF" << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $RANDOM_PORT
logpath = /var/log/auth.log
maxretry = 3
EOF
    systemctl enable fail2ban
    systemctl restart fail2ban
    echo "Fail2Ban configured."
}

# Function to disable unnecessary services
disable_unnecessary_services() {
    echo "=== Disabling Unnecessary Services ==="
    SERVICES=("telnet" "rsh" "rlogin" "vsftpd" "httpd" "apache2" "cups" "avahi-daemon" "bluetooth")
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service"
            systemctl disable "$service"
            echo "$service disabled."
        fi
    done
}

# Function to enable AppArmor
enable_apparmor() {
    echo "=== Enabling AppArmor ==="
    if command -v aa-enforce &> /dev/null; then
        systemctl enable apparmor
        systemctl start apparmor
        aa-enforce /etc/apparmor.d/* 2>/dev/null || true
        echo "AppArmor enabled."
    else
        echo "AppArmor not installed."
    fi
}

# Execute the hardening functions
update_system
install_security_packages
harden_kernel
configure_audit
harden_file_permissions
configure_password_policy
configure_firewall
configure_fail2ban
harden_ssh
enable_apparmor
disable_unnecessary_services
enable_unattended_upgrades

echo ""
echo "========================================="
echo "Debian hardening script completed."
echo "SSH Port: $RANDOM_PORT (UPDATE YOUR FIREWALL AND CLIENT CONFIG!)"
echo "Please review changes and reboot the system."
echo "========================================="
