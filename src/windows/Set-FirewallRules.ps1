#--------------------------------------------------------------------------------------------------
# File: /src/windows/Set-FirewallRules.ps1
# Description: This script provides an interactive menu for managing Windows Firewall rules.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$LogFile = "C:\Windows\Temp\FirewallManagement_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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

# Function to show firewall status
function Show-FirewallStatus {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Windows Firewall Status" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    try {
        $profiles = Get-NetFirewallProfile
        
        foreach ($profile in $profiles) {
            Write-Host "`nProfile: $($profile.Name)" -ForegroundColor Yellow
            Write-Host "Enabled: $($profile.Enabled)"
            Write-Host "Default Inbound Action: $($profile.DefaultInboundAction)"
            Write-Host "Default Outbound Action: $($profile.DefaultOutboundAction)"
            Write-Host "Log File Path: $($profile.LogFileName)"
            Write-Host "Log Max Size: $($profile.LogMaxSizeKilobytes) KB"
        }
        
        Write-Log "Displayed firewall status"
    }
    catch {
        Write-Log "Error getting firewall status: $_" "ERROR"
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to enable/disable firewall
function Set-FirewallState {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Enable/Disable Firewall" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    Write-Host "Select profile:"
    Write-Host "1. Domain"
    Write-Host "2. Private"
    Write-Host "3. Public"
    Write-Host "4. All profiles"
    
    $profileChoice = Read-Host "Enter your choice (1-4)"
    
    $profile = switch ($profileChoice) {
        "1" { "Domain" }
        "2" { "Private" }
        "3" { "Public" }
        "4" { "Domain", "Private", "Public" }
        default { Write-Host "Invalid choice" -ForegroundColor Red; return }
    }
    
    $action = Read-Host "Enable or Disable? (E/D)"
    $enabled = $action -eq 'E'
    
    try {
        Set-NetFirewallProfile -Profile $profile -Enabled $enabled
        $status = if ($enabled) { "enabled" } else { "disabled" }
        Write-Log "Firewall $status for profile(s): $($profile -join ', ')" "SUCCESS"
        Write-Host "Firewall $status successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error changing firewall state: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to list firewall rules
function Show-FirewallRules {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Firewall Rules" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    Write-Host "Filter by:"
    Write-Host "1. All rules"
    Write-Host "2. Enabled rules only"
    Write-Host "3. Disabled rules only"
    Write-Host "4. Inbound rules"
    Write-Host "5. Outbound rules"
    Write-Host "6. Search by name"
    
    $filterChoice = Read-Host "Enter your choice (1-6)"
    
    try {
        $rules = switch ($filterChoice) {
            "1" { Get-NetFirewallRule }
            "2" { Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'True' } }
            "3" { Get-NetFirewallRule | Where-Object { $_.Enabled -eq 'False' } }
            "4" { Get-NetFirewallRule -Direction Inbound }
            "5" { Get-NetFirewallRule -Direction Outbound }
            "6" {
                $searchTerm = Read-Host "Enter search term"
                Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*$searchTerm*" }
            }
            default { Write-Host "Invalid choice" -ForegroundColor Red; return }
        }
        
        if ($rules) {
            $rules | Select-Object DisplayName, Enabled, Direction, Action, Profile | 
                Format-Table -AutoSize | Out-Host
            Write-Host "`nTotal rules: $($rules.Count)" -ForegroundColor Cyan
        }
        else {
            Write-Host "No rules found" -ForegroundColor Yellow
        }
        
        Write-Log "Listed firewall rules (filter: $filterChoice)"
    }
    catch {
        Write-Log "Error listing firewall rules: $_" "ERROR"
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to create new firewall rule
function New-FirewallRule {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Create New Firewall Rule" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $displayName = Read-Host "Enter rule name"
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        Write-Host "Rule name cannot be empty" -ForegroundColor Red
        return
    }
    
    Write-Host "`nDirection:"
    Write-Host "1. Inbound"
    Write-Host "2. Outbound"
    $dirChoice = Read-Host "Enter choice (1-2)"
    $direction = if ($dirChoice -eq "1") { "Inbound" } else { "Outbound" }
    
    Write-Host "`nAction:"
    Write-Host "1. Allow"
    Write-Host "2. Block"
    $actionChoice = Read-Host "Enter choice (1-2)"
    $action = if ($actionChoice -eq "1") { "Allow" } else { "Block" }
    
    Write-Host "`nProtocol:"
    Write-Host "1. TCP"
    Write-Host "2. UDP"
    Write-Host "3. Any"
    $protocolChoice = Read-Host "Enter choice (1-3)"
    $protocol = switch ($protocolChoice) {
        "1" { "TCP" }
        "2" { "UDP" }
        "3" { "Any" }
        default { "TCP" }
    }
    
    $localPort = Read-Host "Enter local port (or press Enter to skip)"
    $remotePort = Read-Host "Enter remote port (or press Enter to skip)"
    $remoteAddress = Read-Host "Enter remote IP address (or press Enter for any)"
    
    Write-Host "`nProfile:"
    Write-Host "1. Domain"
    Write-Host "2. Private"
    Write-Host "3. Public"
    Write-Host "4. Any"
    $profileChoice = Read-Host "Enter choice (1-4)"
    $profile = switch ($profileChoice) {
        "1" { "Domain" }
        "2" { "Private" }
        "3" { "Public" }
        "4" { "Any" }
        default { "Any" }
    }
    
    try {
        $ruleParams = @{
            DisplayName = $displayName
            Direction = $direction
            Action = $action
            Protocol = $protocol
            Profile = $profile
            Enabled = 'True'
        }
        
        if (-not [string]::IsNullOrWhiteSpace($localPort)) {
            $ruleParams.LocalPort = $localPort
        }
        
        if (-not [string]::IsNullOrWhiteSpace($remotePort)) {
            $ruleParams.RemotePort = $remotePort
        }
        
        if (-not [string]::IsNullOrWhiteSpace($remoteAddress)) {
            $ruleParams.RemoteAddress = $remoteAddress
        }
        
        New-NetFirewallRule @ruleParams
        Write-Log "Firewall rule created: $displayName" "SUCCESS"
        Write-Host "Firewall rule created successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error creating firewall rule: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to delete firewall rule
function Remove-FirewallRule {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Delete Firewall Rule" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $searchTerm = Read-Host "Enter rule name or search term"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) {
        Write-Host "Search term cannot be empty" -ForegroundColor Red
        return
    }
    
    try {
        $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*$searchTerm*" }
        
        if (-not $rules) {
            Write-Host "No rules found matching: $searchTerm" -ForegroundColor Yellow
            return
        }
        
        Write-Host "`nFound rules:"
        $rules | Select-Object DisplayName, Direction, Action, Enabled | Format-Table -AutoSize
        
        $confirm = Read-Host "`nDelete all matching rules? (Y/N)"
        if ($confirm -ne 'Y') {
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            return
        }
        
        foreach ($rule in $rules) {
            Remove-NetFirewallRule -Name $rule.Name
            Write-Log "Deleted firewall rule: $($rule.DisplayName)" "SUCCESS"
        }
        
        Write-Host "Rules deleted successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error deleting firewall rule: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to enable/disable firewall rule
function Set-FirewallRuleState {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Enable/Disable Firewall Rule" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $searchTerm = Read-Host "Enter rule name or search term"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) {
        Write-Host "Search term cannot be empty" -ForegroundColor Red
        return
    }
    
    try {
        $rules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*$searchTerm*" }
        
        if (-not $rules) {
            Write-Host "No rules found matching: $searchTerm" -ForegroundColor Yellow
            return
        }
        
        Write-Host "`nFound rules:"
        $rules | Select-Object DisplayName, Direction, Action, Enabled | Format-Table -AutoSize
        
        $action = Read-Host "`nEnable or Disable these rules? (E/D)"
        $enabled = $action -eq 'E'
        
        foreach ($rule in $rules) {
            Set-NetFirewallRule -Name $rule.Name -Enabled $enabled
            $status = if ($enabled) { "enabled" } else { "disabled" }
            Write-Log "Firewall rule $status: $($rule.DisplayName)" "SUCCESS"
        }
        
        $status = if ($enabled) { "enabled" } else { "disabled" }
        Write-Host "Rules $status successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error changing firewall rule state: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to block IP address
function Block-IPAddress {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Block IP Address" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $ipAddress = Read-Host "Enter IP address to block"
    if ([string]::IsNullOrWhiteSpace($ipAddress)) {
        Write-Host "IP address cannot be empty" -ForegroundColor Red
        return
    }
    
    $ruleName = "Block_$ipAddress"
    
    try {
        # Create inbound block rule
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Block -RemoteAddress $ipAddress -Enabled True
        Write-Log "Created firewall rule to block IP: $ipAddress" "SUCCESS"
        Write-Host "IP address blocked successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error blocking IP address: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to allow program through firewall
function Add-ProgramRule {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Allow Program Through Firewall" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $programPath = Read-Host "Enter full path to program"
    if ([string]::IsNullOrWhiteSpace($programPath)) {
        Write-Host "Program path cannot be empty" -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path $programPath)) {
        Write-Host "Program not found at specified path" -ForegroundColor Red
        return
    }
    
    $programName = Split-Path $programPath -Leaf
    $ruleName = "Allow_$programName"
    
    try {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Program $programPath -Action Allow -Enabled True
        Write-Log "Created firewall rule to allow program: $programName" "SUCCESS"
        Write-Host "Program allowed through firewall successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error creating program rule: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to export firewall rules
function Export-FirewallRules {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Export Firewall Rules" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $exportPath = Read-Host "Enter export file path (e.g., C:\firewall_rules.wfw)"
    if ([string]::IsNullOrWhiteSpace($exportPath)) {
        $exportPath = "C:\Windows\Temp\firewall_rules_$(Get-Date -Format 'yyyyMMdd_HHmmss').wfw"
    }
    
    try {
        netsh advfirewall export $exportPath | Out-Null
        Write-Log "Firewall rules exported to: $exportPath" "SUCCESS"
        Write-Host "Firewall rules exported successfully to: $exportPath" -ForegroundColor Green
    }
    catch {
        Write-Log "Error exporting firewall rules: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Function to import firewall rules
function Import-FirewallRules {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Import Firewall Rules" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $importPath = Read-Host "Enter import file path"
    if ([string]::IsNullOrWhiteSpace($importPath)) {
        Write-Host "Import path cannot be empty" -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path $importPath)) {
        Write-Host "File not found at specified path" -ForegroundColor Red
        return
    }
    
    Write-Host "WARNING: This will overwrite current firewall rules!" -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to continue? (Y/N)"
    if ($confirm -ne 'Y') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        return
    }
    
    try {
        netsh advfirewall import $importPath | Out-Null
        Write-Log "Firewall rules imported from: $importPath" "SUCCESS"
        Write-Host "Firewall rules imported successfully!" -ForegroundColor Green
    }
    catch {
        Write-Log "Error importing firewall rules: $_" "ERROR"
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter to continue"
}

# Main menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Windows Firewall Management" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Show firewall status"
    Write-Host "2. Enable/Disable firewall"
    Write-Host "3. List firewall rules"
    Write-Host "4. Create new rule"
    Write-Host "5. Delete rule"
    Write-Host "6. Enable/Disable rule"
    Write-Host "7. Block IP address"
    Write-Host "8. Allow program through firewall"
    Write-Host "9. Export firewall rules"
    Write-Host "10. Import firewall rules"
    Write-Host "11. Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Main execution
try {
    Write-Log "Firewall Management script started"
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-11)"
        
        switch ($choice) {
            "1" { Show-FirewallStatus }
            "2" { Set-FirewallState }
            "3" { Show-FirewallRules }
            "4" { New-FirewallRule }
            "5" { Remove-FirewallRule }
            "6" { Set-FirewallRuleState }
            "7" { Block-IPAddress }
            "8" { Add-ProgramRule }
            "9" { Export-FirewallRules }
            "10" { Import-FirewallRules }
            "11" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                Write-Log "Firewall Management script exited"
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
    Write-Error "Firewall management failed: $_"
    exit 1
}
