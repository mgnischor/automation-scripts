#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/get_distro_information.sh
# Description: This script retrieves and displays information about the Linux distribution.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Function to get distribution information
get_distro_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "Distribution Name: $NAME"
        echo "Version: $VERSION"
        echo "ID: $ID"
        echo "Pretty Name: $PRETTY_NAME"
    else
        echo "Distribution information file not found."
    fi
}

# Execute the function
get_distro_info
