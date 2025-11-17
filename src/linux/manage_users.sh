#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/manage_users.sh
# Description: This script provides user management operations including creation, deletion, and modification.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Function to display menu
show_menu() {
    echo "========================================="
    echo "User Management Script"
    echo "========================================="
    echo "1. List all users"
    echo "2. Create new user"
    echo "3. Delete user"
    echo "4. Lock user account"
    echo "5. Unlock user account"
    echo "6. Change user password"
    echo "7. Add user to group"
    echo "8. Remove user from group"
    echo "9. List user groups"
    echo "0. Exit"
    echo "========================================="
}

# Function to list all users
list_users() {
    echo "=== System Users ==="
    cut -d: -f1,3,6 /etc/passwd | awk -F: '$2 >= 1000 {print "User: " $1 ", UID: " $2 ", Home: " $3}'
}

# Function to create new user
create_user() {
    read -p "Enter username: " username
    if id "$username" &>/dev/null; then
        echo "User $username already exists."
        return 1
    fi
    
    read -p "Enter full name (optional): " fullname
    read -s -p "Enter password: " password
    echo
    read -s -p "Confirm password: " password_confirm
    echo
    
    if [ "$password" != "$password_confirm" ]; then
        echo "Passwords do not match."
        return 1
    fi
    
    useradd -m -c "$fullname" "$username"
    echo "$username:$password" | chpasswd
    
    echo "User $username created successfully."
}

# Function to delete user
delete_user() {
    read -p "Enter username to delete: " username
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist."
        return 1
    fi
    
    read -p "Remove home directory? (y/n): " remove_home
    if [ "$remove_home" = "y" ]; then
        userdel -r "$username"
    else
        userdel "$username"
    fi
    
    echo "User $username deleted successfully."
}

# Function to lock user account
lock_user() {
    read -p "Enter username to lock: " username
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist."
        return 1
    fi
    
    passwd -l "$username"
    echo "User $username locked successfully."
}

# Function to unlock user account
unlock_user() {
    read -p "Enter username to unlock: " username
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist."
        return 1
    fi
    
    passwd -u "$username"
    echo "User $username unlocked successfully."
}

# Function to change user password
change_password() {
    read -p "Enter username: " username
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist."
        return 1
    fi
    
    passwd "$username"
}

# Function to add user to group
add_to_group() {
    read -p "Enter username: " username
    read -p "Enter group name: " groupname
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist."
        return 1
    fi
    
    if ! getent group "$groupname" &>/dev/null; then
        echo "Group $groupname does not exist."
        return 1
    fi
    
    usermod -aG "$groupname" "$username"
    echo "User $username added to group $groupname."
}

# Function to remove user from group
remove_from_group() {
    read -p "Enter username: " username
    read -p "Enter group name: " groupname
    
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist."
        return 1
    fi
    
    gpasswd -d "$username" "$groupname"
    echo "User $username removed from group $groupname."
}

# Function to list user groups
list_user_groups() {
    read -p "Enter username: " username
    if ! id "$username" &>/dev/null; then
        echo "User $username does not exist."
        return 1
    fi
    
    echo "Groups for user $username:"
    groups "$username"
}

# Main loop
while true; do
    show_menu
    read -p "Select an option: " option
    
    case $option in
        1) list_users ;;
        2) create_user ;;
        3) delete_user ;;
        4) lock_user ;;
        5) unlock_user ;;
        6) change_password ;;
        7) add_to_group ;;
        8) remove_from_group ;;
        9) list_user_groups ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done
