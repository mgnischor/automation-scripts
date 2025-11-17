#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/get_network_info.sh
# Description: This script retrieves and displays network interface information including IP
#              addresses and status.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Function to get network interfaces and their details
get_network_info() {
    echo "=== Network Interfaces ==="
    if command -v ip &> /dev/null; then
        ip addr show | grep -E "^[0-9]+: " | while read -r line; do
            iface=$(echo "$line" | awk '{print $2}' | sed 's/:$//')
            status=$(echo "$line" | grep -o "UP\|DOWN")
            echo "Interface: $iface (Status: $status)"
            ip addr show "$iface" | grep "inet " | awk '{print "  IPv4: " $2}' || echo "  No IPv4 address"
            ip addr show "$iface" | grep "inet6 " | awk '{print "  IPv6: " $2}' || echo "  No IPv6 address"
        done
    elif command -v ifconfig &> /dev/null; then
        ifconfig | grep -E "^[a-zA-Z0-9]+" | while read -r line; do
            iface=$(echo "$line" | awk '{print $1}' | sed 's/:$//')
            echo "Interface: $iface"
            ifconfig "$iface" | grep "inet " | awk '{print "  IPv4: " $2}' || echo "  No IPv4 address"
            ifconfig "$iface" | grep "inet6 " | awk '{print "  IPv6: " $2}' || echo "  No IPv6 address"
        done
    else
        echo "Neither ip nor ifconfig command available."
    fi
}

# Function to get default gateway
get_gateway() {
    echo "=== Default Gateway ==="
    if command -v ip &> /dev/null; then
        ip route | grep default | awk '{print "Gateway: " $3 " via " $5}' || echo "No default route found."
    elif command -v route &> /dev/null; then
        route -n | grep "^0.0.0.0" | awk '{print "Gateway: " $2}' || echo "No default route found."
    else
        echo "No route command available."
    fi
}

# Execute the functions
get_network_info
get_gateway
