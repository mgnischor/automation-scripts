#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/get_hostname.sh
# Description: This script retrieves and prints the system's hostname.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if hostname command exists
if ! command -v hostname &> /dev/null; then
    echo "Error: hostname command not found."
    exit 1
fi

# Retrieve and print the hostname
HOSTNAME=$(hostname)
echo "System Hostname: $HOSTNAME"