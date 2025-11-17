#--------------------------------------------------------------------------------------------------
# File: /src/windows/Manage-LocalUsers.ps1
# Description: This script provides an interactive menu for managing Windows local users
#              and groups.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$LogFile = "C:\Windows\Temp\UserManagement_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Function to write log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
    
    Add-Content -Path $LogFile -Value $logMessage
}

# Function to list all local users
function Show-LocalUsers {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Local Users" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    try {
        $users = Get-LocalUser | Select-Object Name, Enabled, LastLogon, PasswordLastSet, Description
        $users | Format-Table -AutoSize
        
        Write-Log "Listed all local users"
    }
    catch {
        Write-Log "Error listing users: $_" "ERROR"
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to create a new user
function New-UserAccount {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Create New User" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $username = Read-Host "Enter username"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Username cannot be empty" -ForegroundColor Red
        return
    }
    
    # Check if user already exists
    $existingUser = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "User already exists: $username" -ForegroundColor Red
        return
    }
    
    $fullName = Read-Host "Enter full name (optional)"
    $description = Read-Host "Enter description (optional)"
    
    # Secure password input
    $password = Read-Host "Enter password" -AsSecureString
    $confirmPassword = Read-Host "Confirm password" -AsSecureString
    
    # Convert SecureString to plain text for comparison
    $pwd1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    $pwd2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
    
    if ($pwd1 -ne $pwd2) {
        Write-Host "Passwords do not match" -ForegroundColor Red
        return
    }
    
    try {
        $userParams = @{
            Name = $username
            Password = $password
            PasswordNeverExpires = $false
            UserMayNotChangePassword = $false
            AccountNeverExpires = $true
        }
        
        if (-not [string]::IsNullOrWhiteSpace($fullName)) {
            $userParams.FullName = $fullName
        }
        
        if (-not [string]::IsNullOrWhiteSpace($description)) {
            $userParams.Description = $description
        }
        
        New-LocalUser @userParams
        Write-Log "User created successfully: $username" "SUCCESS"
        Write-Host "User created successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error creating user: $_" "ERROR"
        Write-Host "Error creating user: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to delete a user
function Remove-UserAccount {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Delete User" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $username = Read-Host "Enter username to delete"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Username cannot be empty" -ForegroundColor Red
        return
    }
    
    # Check if user exists
    $user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Host "User not found: $username" -ForegroundColor Red
        return
    }
    
    Write-Host "`nUser: $username" -ForegroundColor Yellow
    Write-Host "Full Name: $($user.FullName)"
    Write-Host "Description: $($user.Description)"
    Write-Host "Last Logon: $($user.LastLogon)"
    
    $confirm = Read-Host "`nAre you sure you want to delete this user? (Y/N)"
    if ($confirm -ne 'Y') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        return
    }
    
    try {
        Remove-LocalUser -Name $username
        Write-Log "User deleted successfully: $username" "SUCCESS"
        Write-Host "User deleted successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error deleting user: $_" "ERROR"
        Write-Host "Error deleting user: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to modify user properties
function Edit-UserAccount {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Modify User" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $username = Read-Host "Enter username to modify"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Username cannot be empty" -ForegroundColor Red
        return
    }
    
    # Check if user exists
    $user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Host "User not found: $username" -ForegroundColor Red
        return
    }
    
    Write-Host "`nCurrent user details:"
    Write-Host "Name: $($user.Name)"
    Write-Host "Full Name: $($user.FullName)"
    Write-Host "Description: $($user.Description)"
    Write-Host "Enabled: $($user.Enabled)"
    Write-Host "Password Expires: $($user.PasswordExpires)"
    
    Write-Host "`nWhat would you like to modify?"
    Write-Host "1. Enable/Disable account"
    Write-Host "2. Change description"
    Write-Host "3. Reset password"
    Write-Host "4. Change full name"
    Write-Host "5. Return to main menu"
    
    $choice = Read-Host "Enter your choice (1-5)"
    
    switch ($choice) {
        "1" {
            $enable = Read-Host "Enable account? (Y/N)"
            try {
                if ($enable -eq 'Y') {
                    Enable-LocalUser -Name $username
                    Write-Log "User enabled: $username" "SUCCESS"
                    Write-Host "User enabled successfully!" -ForegroundColor Green
                }
                else {
                    Disable-LocalUser -Name $username
                    Write-Log "User disabled: $username" "SUCCESS"
                    Write-Host "User disabled successfully!" -ForegroundColor Green
                }
            }
            catch {
                Write-Log "Error modifying user: $_" "ERROR"
                Write-Host "Error: $_" -ForegroundColor Red
            }
        }
        "2" {
            $description = Read-Host "Enter new description"
            try {
                Set-LocalUser -Name $username -Description $description
                Write-Log "User description updated: $username" "SUCCESS"
                Write-Host "Description updated successfully!" -ForegroundColor Green
            }
            catch {
                Write-Log "Error updating description: $_" "ERROR"
                Write-Host "Error: $_" -ForegroundColor Red
            }
        }
        "3" {
            $password = Read-Host "Enter new password" -AsSecureString
            $confirmPassword = Read-Host "Confirm password" -AsSecureString
            
            $pwd1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
            $pwd2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword))
            
            if ($pwd1 -ne $pwd2) {
                Write-Host "Passwords do not match" -ForegroundColor Red
                return
            }
            
            try {
                Set-LocalUser -Name $username -Password $password
                Write-Log "Password reset for user: $username" "SUCCESS"
                Write-Host "Password reset successfully!" -ForegroundColor Green
            }
            catch {
                Write-Log "Error resetting password: $_" "ERROR"
                Write-Host "Error: $_" -ForegroundColor Red
            }
        }
        "4" {
            $fullName = Read-Host "Enter new full name"
            try {
                Set-LocalUser -Name $username -FullName $fullName
                Write-Log "Full name updated for user: $username" "SUCCESS"
                Write-Host "Full name updated successfully!" -ForegroundColor Green
            }
            catch {
                Write-Log "Error updating full name: $_" "ERROR"
                Write-Host "Error: $_" -ForegroundColor Red
            }
        }
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to manage group membership
function Manage-GroupMembership {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Manage Group Membership" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $username = Read-Host "Enter username"
    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-Host "Username cannot be empty" -ForegroundColor Red
        return
    }
    
    # Check if user exists
    $user = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Host "User not found: $username" -ForegroundColor Red
        return
    }
    
    Write-Host "`nCurrent group memberships:"
    try {
        $groups = Get-LocalGroup | Where-Object {
            (Get-LocalGroupMember -Group $_.Name -ErrorAction SilentlyContinue).Name -contains "$env:COMPUTERNAME\$username"
        }
        
        if ($groups) {
            $groups | Format-Table Name, Description -AutoSize
        }
        else {
            Write-Host "User is not a member of any groups" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Log "Error getting group memberships: $_" "ERROR"
    }
    
    Write-Host "`n1. Add to group"
    Write-Host "2. Remove from group"
    Write-Host "3. Return to main menu"
    
    $choice = Read-Host "Enter your choice (1-3)"
    
    switch ($choice) {
        "1" {
            Write-Host "`nAvailable groups:"
            Get-LocalGroup | Format-Table Name, Description -AutoSize
            
            $groupName = Read-Host "Enter group name"
            try {
                Add-LocalGroupMember -Group $groupName -Member $username
                Write-Log "Added user $username to group $groupName" "SUCCESS"
                Write-Host "User added to group successfully!" -ForegroundColor Green
            }
            catch {
                Write-Log "Error adding user to group: $_" "ERROR"
                Write-Host "Error: $_" -ForegroundColor Red
            }
        }
        "2" {
            $groupName = Read-Host "Enter group name to remove from"
            try {
                Remove-LocalGroupMember -Group $groupName -Member $username
                Write-Log "Removed user $username from group $groupName" "SUCCESS"
                Write-Host "User removed from group successfully!" -ForegroundColor Green
            }
            catch {
                Write-Log "Error removing user from group: $_" "ERROR"
                Write-Host "Error: $_" -ForegroundColor Red
            }
        }
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to show user logon history
function Show-UserLogonHistory {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "User Logon History" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $username = Read-Host "Enter username (leave empty for all users)"
    
    try {
        $logonEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4624  # Successful logon
        } -MaxEvents 50 -ErrorAction SilentlyContinue
        
        if ($logonEvents) {
            $logons = $logonEvents | ForEach-Object {
                $xml = [xml]$_.ToXml()
                $targetUser = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
                $logonType = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' } | Select-Object -ExpandProperty '#text'
                
                if ([string]::IsNullOrWhiteSpace($username) -or $targetUser -eq $username) {
                    [PSCustomObject]@{
                        Time = $_.TimeCreated
                        User = $targetUser
                        LogonType = $logonType
                        Computer = $env:COMPUTERNAME
                    }
                }
            }
            
            if ($logons) {
                $logons | Format-Table -AutoSize
            }
            else {
                Write-Host "No logon events found for the specified user" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "No logon events found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Log "Error retrieving logon history: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Main menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Windows User Management" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. List all local users"
    Write-Host "2. Create new user"
    Write-Host "3. Delete user"
    Write-Host "4. Modify user"
    Write-Host "5. Manage group membership"
    Write-Host "6. Show user logon history"
    Write-Host "7. Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Main execution
try {
    Write-Log "User Management script started"
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-7)"
        
        switch ($choice) {
            "1" { Show-LocalUsers }
            "2" { New-UserAccount }
            "3" { Remove-UserAccount }
            "4" { Edit-UserAccount }
            "5" { Manage-GroupMembership }
            "6" { Show-UserLogonHistory }
            "7" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                Write-Log "User Management script exited"
                exit 0
            }
            default {
                Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}
catch {
    Write-Log "An error occurred: $_" "ERROR"
    Write-Error "User management failed: $_"
    exit 1
}
