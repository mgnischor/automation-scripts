#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/configure_firewall.sh
# Description: This script provides a menu-driven interface to configure firewall rules (iptables/ufw/firewalld).
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Detect firewall type
detect_firewall() {
    if command -v ufw &> /dev/null; then
        echo "ufw"
    elif command -v firewall-cmd &> /dev/null; then
        echo "firewalld"
    elif command -v iptables &> /dev/null; then
        echo "iptables"
    else
        echo "none"
    fi
}

FIREWALL=$(detect_firewall)

# Function to display menu
show_menu() {
    echo "========================================="
    echo "Firewall Configuration Script"
    echo "Detected Firewall: $FIREWALL"
    echo "========================================="
    echo "1. Show firewall status"
    echo "2. Enable firewall"
    echo "3. Disable firewall"
    echo "4. Allow port"
    echo "5. Deny port"
    echo "6. Allow service"
    echo "7. Deny service"
    echo "8. List all rules"
    echo "9. Reset firewall to defaults"
    echo "0. Exit"
    echo "========================================="
}

# UFW Functions
ufw_status() {
    ufw status verbose
}

ufw_enable() {
    ufw --force enable
    echo "UFW enabled."
}

ufw_disable() {
    ufw disable
    echo "UFW disabled."
}

ufw_allow_port() {
    read -p "Enter port number: " port
    read -p "Protocol (tcp/udp/both): " proto
    if [ "$proto" = "both" ]; then
        ufw allow "$port"
    else
        ufw allow "$port/$proto"
    fi
    echo "Port $port allowed."
}

ufw_deny_port() {
    read -p "Enter port number: " port
    read -p "Protocol (tcp/udp/both): " proto
    if [ "$proto" = "both" ]; then
        ufw deny "$port"
    else
        ufw deny "$port/$proto"
    fi
    echo "Port $port denied."
}

ufw_allow_service() {
    read -p "Enter service name (e.g., ssh, http, https): " service
    ufw allow "$service"
    echo "Service $service allowed."
}

ufw_deny_service() {
    read -p "Enter service name: " service
    ufw deny "$service"
    echo "Service $service denied."
}

ufw_list_rules() {
    ufw status numbered
}

ufw_reset() {
    read -p "This will reset all firewall rules. Continue? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        ufw --force reset
        echo "UFW reset to defaults."
    fi
}

# Firewalld Functions
firewalld_status() {
    firewall-cmd --state
    firewall-cmd --list-all
}

firewalld_enable() {
    systemctl enable firewalld
    systemctl start firewalld
    echo "Firewalld enabled."
}

firewalld_disable() {
    systemctl stop firewalld
    systemctl disable firewalld
    echo "Firewalld disabled."
}

firewalld_allow_port() {
    read -p "Enter port number: " port
    read -p "Protocol (tcp/udp): " proto
    firewall-cmd --permanent --add-port="$port/$proto"
    firewall-cmd --reload
    echo "Port $port/$proto allowed."
}

firewalld_deny_port() {
    read -p "Enter port number: " port
    read -p "Protocol (tcp/udp): " proto
    firewall-cmd --permanent --remove-port="$port/$proto"
    firewall-cmd --reload
    echo "Port $port/$proto denied."
}

firewalld_allow_service() {
    read -p "Enter service name (e.g., ssh, http, https): " service
    firewall-cmd --permanent --add-service="$service"
    firewall-cmd --reload
    echo "Service $service allowed."
}

firewalld_deny_service() {
    read -p "Enter service name: " service
    firewall-cmd --permanent --remove-service="$service"
    firewall-cmd --reload
    echo "Service $service denied."
}

firewalld_list_rules() {
    firewall-cmd --list-all
}

firewalld_reset() {
    read -p "This will reset all firewall rules. Continue? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        firewall-cmd --complete-reload
        echo "Firewalld reset."
    fi
}

# Main loop
if [ "$FIREWALL" = "none" ]; then
    echo "No supported firewall found. Please install ufw, firewalld, or iptables."
    exit 1
fi

while true; do
    show_menu
    read -p "Select an option: " option
    
    case $option in
        1)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_status
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_status
            fi
            ;;
        2)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_enable
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_enable
            fi
            ;;
        3)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_disable
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_disable
            fi
            ;;
        4)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_allow_port
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_allow_port
            fi
            ;;
        5)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_deny_port
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_deny_port
            fi
            ;;
        6)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_allow_service
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_allow_service
            fi
            ;;
        7)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_deny_service
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_deny_service
            fi
            ;;
        8)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_list_rules
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_list_rules
            fi
            ;;
        9)
            if [ "$FIREWALL" = "ufw" ]; then
                ufw_reset
            elif [ "$FIREWALL" = "firewalld" ]; then
                firewalld_reset
            fi
            ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done
