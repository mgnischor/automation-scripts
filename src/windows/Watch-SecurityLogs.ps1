#--------------------------------------------------------------------------------------------------
# File: /src/windows/Watch-SecurityLogs.ps1
# Description: This script monitors Windows security logs for suspicious activities and generates alerts.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$LogFile = "C:\Windows\Temp\SecurityMonitor_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ReportFile = "C:\Windows\Temp\SecurityReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$CheckInterval = 300  # 5 minutes
$MaxFailedLogins = 5
$TimeWindowMinutes = 30

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
        "ALERT" { Write-Host $logMessage -ForegroundColor Red -BackgroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
    
    Add-Content -Path $LogFile -Value $logMessage
}

# Function to write to report
function Write-Report {
    param (
        [string]$Message
    )
    
    Add-Content -Path $ReportFile -Value $Message
    Write-Host $Message
}

# Function to check failed login attempts
function Test-FailedLogins {
    Write-Log "Checking for failed login attempts"
    
    try {
        $startTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
        
        $failedLogins = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4625  # Failed logon
            StartTime = $startTime
        } -ErrorAction SilentlyContinue
        
        if ($failedLogins) {
            $groupedLogins = $failedLogins | Group-Object -Property {
                $xml = [xml]$_.ToXml()
                $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
            }
            
            foreach ($group in $groupedLogins) {
                if ($group.Count -ge $MaxFailedLogins) {
                    Write-Log "ALERT: Multiple failed login attempts detected for user: $($group.Name) ($($group.Count) attempts)" "ALERT"
                    
                    Write-Report "`n[ALERT] Multiple Failed Login Attempts"
                    Write-Report "User: $($group.Name)"
                    Write-Report "Attempts: $($group.Count)"
                    Write-Report "Time Window: Last $TimeWindowMinutes minutes"
                    Write-Report "Times:"
                    
                    foreach ($event in $group.Group | Select-Object -First 5) {
                        Write-Report "  - $($event.TimeCreated)"
                    }
                }
            }
        }
        else {
            Write-Log "No failed login attempts in the last $TimeWindowMinutes minutes"
        }
    }
    catch {
        Write-Log "Error checking failed logins: $_" "ERROR"
    }
}

# Function to check account lockouts
function Test-AccountLockouts {
    Write-Log "Checking for account lockouts"
    
    try {
        $startTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
        
        $lockouts = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4740  # Account lockout
            StartTime = $startTime
        } -ErrorAction SilentlyContinue
        
        if ($lockouts) {
            Write-Log "ALERT: $($lockouts.Count) account lockout(s) detected" "ALERT"
            
            Write-Report "`n[ALERT] Account Lockouts Detected"
            Write-Report "Count: $($lockouts.Count)"
            
            foreach ($lockout in $lockouts) {
                $xml = [xml]$lockout.ToXml()
                $targetUser = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' } | Select-Object -ExpandProperty '#text'
                
                Write-Report "`nUser: $targetUser"
                Write-Report "Time: $($lockout.TimeCreated)"
            }
        }
        else {
            Write-Log "No account lockouts in the last $TimeWindowMinutes minutes"
        }
    }
    catch {
        Write-Log "Error checking account lockouts: $_" "ERROR"
    }
}

# Function to check privilege escalation
function Test-PrivilegeEscalation {
    Write-Log "Checking for privilege escalation attempts"
    
    try {
        $startTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
        
        $privilegeUse = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4672  # Special privileges assigned to new logon
            StartTime = $startTime
        } -ErrorAction SilentlyContinue
        
        if ($privilegeUse) {
            Write-Log "Found $($privilegeUse.Count) privilege escalation event(s)"
            
            $suspiciousPrivileges = $privilegeUse | Where-Object {
                $xml = [xml]$_.ToXml()
                $privileges = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'PrivilegeList' } | Select-Object -ExpandProperty '#text'
                $privileges -match 'SeDebugPrivilege|SeTcbPrivilege|SeBackupPrivilege'
            }
            
            if ($suspiciousPrivileges) {
                Write-Log "ALERT: Suspicious privilege escalation detected" "ALERT"
                
                Write-Report "`n[ALERT] Suspicious Privilege Escalation"
                Write-Report "Count: $($suspiciousPrivileges.Count)"
                
                foreach ($event in $suspiciousPrivileges | Select-Object -First 5) {
                    $xml = [xml]$event.ToXml()
                    $user = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'SubjectUserName' } | Select-Object -ExpandProperty '#text'
                    
                    Write-Report "`nUser: $user"
                    Write-Report "Time: $($event.TimeCreated)"
                }
            }
        }
        else {
            Write-Log "No privilege escalation events in the last $TimeWindowMinutes minutes"
        }
    }
    catch {
        Write-Log "Error checking privilege escalation: $_" "ERROR"
    }
}

# Function to check user/group changes
function Test-AccountChanges {
    Write-Log "Checking for user/group changes"
    
    try {
        $startTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
        
        $accountChanges = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4720, 4722, 4724, 4726, 4728, 4732, 4756  # User/group changes
            StartTime = $startTime
        } -ErrorAction SilentlyContinue
        
        if ($accountChanges) {
            Write-Log "Found $($accountChanges.Count) account change(s)"
            
            Write-Report "`n[INFO] Account Changes Detected"
            Write-Report "Count: $($accountChanges.Count)"
            
            foreach ($event in $accountChanges) {
                $eventName = switch ($event.Id) {
                    4720 { "User Account Created" }
                    4722 { "User Account Enabled" }
                    4724 { "Password Reset Attempted" }
                    4726 { "User Account Deleted" }
                    4728 { "Member Added to Security-Enabled Global Group" }
                    4732 { "Member Added to Security-Enabled Local Group" }
                    4756 { "Member Added to Security-Enabled Universal Group" }
                }
                
                Write-Report "`nEvent: $eventName"
                Write-Report "Time: $($event.TimeCreated)"
            }
        }
        else {
            Write-Log "No account changes in the last $TimeWindowMinutes minutes"
        }
    }
    catch {
        Write-Log "Error checking account changes: $_" "ERROR"
    }
}

# Function to check system events
function Test-SystemEvents {
    Write-Log "Checking for critical system events"
    
    try {
        $startTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
        
        $systemEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Level = 1, 2  # Critical and Error
            StartTime = $startTime
        } -MaxEvents 20 -ErrorAction SilentlyContinue
        
        if ($systemEvents) {
            Write-Log "Found $($systemEvents.Count) critical system event(s)" "WARNING"
            
            Write-Report "`n[WARNING] Critical System Events"
            Write-Report "Count: $($systemEvents.Count)"
            
            foreach ($event in $systemEvents | Select-Object -First 10) {
                Write-Report "`nSource: $($event.ProviderName)"
                Write-Report "Level: $($event.LevelDisplayName)"
                Write-Report "Time: $($event.TimeCreated)"
                Write-Report "Message: $($event.Message.Substring(0, [Math]::Min(100, $event.Message.Length)))..."
            }
        }
        else {
            Write-Log "No critical system events in the last $TimeWindowMinutes minutes"
        }
    }
    catch {
        Write-Log "Error checking system events: $_" "ERROR"
    }
}

# Function to check firewall events
function Test-FirewallEvents {
    Write-Log "Checking for firewall events"
    
    try {
        $startTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
        
        $firewallEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Windows Firewall With Advanced Security/Firewall'
            StartTime = $startTime
        } -MaxEvents 50 -ErrorAction SilentlyContinue
        
        if ($firewallEvents) {
            $blockedConnections = $firewallEvents | Where-Object { $_.Id -eq 5157 }
            
            if ($blockedConnections) {
                Write-Log "Found $($blockedConnections.Count) blocked connection(s)" "WARNING"
                
                Write-Report "`n[INFO] Firewall Blocked Connections"
                Write-Report "Count: $($blockedConnections.Count)"
                
                $groupedByIP = $blockedConnections | Group-Object -Property {
                    $_.Properties[5].Value  # Source address
                } | Sort-Object Count -Descending | Select-Object -First 5
                
                Write-Report "`nTop Blocked IP Addresses:"
                foreach ($group in $groupedByIP) {
                    Write-Report "  $($group.Name): $($group.Count) attempts"
                }
            }
        }
        else {
            Write-Log "No firewall events in the last $TimeWindowMinutes minutes"
        }
    }
    catch {
        Write-Log "Error checking firewall events: $_" "ERROR"
    }
}

# Function to check Windows Defender events
function Test-DefenderEvents {
    Write-Log "Checking Windows Defender events"
    
    try {
        $startTime = (Get-Date).AddMinutes(-$TimeWindowMinutes)
        
        $defenderEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Windows Defender/Operational'
            StartTime = $startTime
        } -MaxEvents 50 -ErrorAction SilentlyContinue
        
        if ($defenderEvents) {
            $threats = $defenderEvents | Where-Object { $_.Id -in @(1116, 1117) }  # Malware detected
            
            if ($threats) {
                Write-Log "ALERT: Windows Defender detected $($threats.Count) threat(s)" "ALERT"
                
                Write-Report "`n[ALERT] Malware Detected by Windows Defender"
                Write-Report "Count: $($threats.Count)"
                
                foreach ($threat in $threats) {
                    Write-Report "`nTime: $($threat.TimeCreated)"
                    Write-Report "Event ID: $($threat.Id)"
                    Write-Report "Message: $($threat.Message.Substring(0, [Math]::Min(200, $threat.Message.Length)))..."
                }
            }
        }
        else {
            Write-Log "No Windows Defender events in the last $TimeWindowMinutes minutes"
        }
    }
    catch {
        Write-Log "Error checking Windows Defender events: $_" "ERROR"
    }
}

# Function to generate summary report
function New-SummaryReport {
    Write-Report "`n========================================="
    Write-Report "Security Monitoring Summary"
    Write-Report "========================================="
    Write-Report "Report Generated: $(Get-Date)"
    Write-Report "Monitoring Window: Last $TimeWindowMinutes minutes"
    Write-Report "Computer: $env:COMPUTERNAME"
    Write-Report "`nLog File: $LogFile"
    Write-Report "Report File: $ReportFile"
    Write-Report "========================================="
}

# Function to run all checks
function Start-SecurityMonitoring {
    Write-Log "========================================="
    Write-Log "Starting Security Monitoring"
    Write-Log "========================================="
    Write-Log "Check interval: $CheckInterval seconds"
    Write-Log "Press Ctrl+C to stop monitoring"
    Write-Log "========================================="
    
    $cycleCount = 0
    
    while ($true) {
        $cycleCount++
        Write-Log "`n--- Monitoring Cycle #$cycleCount ---"
        
        # Initialize new report
        "Windows Security Monitoring Report" | Out-File -FilePath $ReportFile -Encoding UTF8
        "Generated: $(Get-Date)" | Out-File -FilePath $ReportFile -Append -Encoding UTF8
        "=" * 60 | Out-File -FilePath $ReportFile -Append -Encoding UTF8
        
        Test-FailedLogins
        Test-AccountLockouts
        Test-PrivilegeEscalation
        Test-AccountChanges
        Test-SystemEvents
        Test-FirewallEvents
        Test-DefenderEvents
        New-SummaryReport
        
        Write-Log "Monitoring cycle completed. Next check in $CheckInterval seconds..."
        Start-Sleep -Seconds $CheckInterval
    }
}

# Function to run one-time check
function Start-OneTimeCheck {
    Write-Log "========================================="
    Write-Log "Running One-Time Security Check"
    Write-Log "========================================="
    
    # Initialize report
    "Windows Security Monitoring Report" | Out-File -FilePath $ReportFile -Encoding UTF8
    "Generated: $(Get-Date)" | Out-File -FilePath $ReportFile -Append -Encoding UTF8
    "=" * 60 | Out-File -FilePath $ReportFile -Append -Encoding UTF8
    
    Test-FailedLogins
    Test-AccountLockouts
    Test-PrivilegeEscalation
    Test-AccountChanges
    Test-SystemEvents
    Test-FirewallEvents
    Test-DefenderEvents
    New-SummaryReport
    
    Write-Log "========================================="
    Write-Log "Security check completed!"
    Write-Log "Report saved to: $ReportFile"
    Write-Log "========================================="
}

# Main menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Windows Security Log Monitor" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Start continuous monitoring"
    Write-Host "2. Run one-time check"
    Write-Host "3. Configure settings"
    Write-Host "4. View last report"
    Write-Host "5. Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Time Window: $TimeWindowMinutes minutes" -ForegroundColor Yellow
    Write-Host "Check Interval: $CheckInterval seconds" -ForegroundColor Yellow
    Write-Host "Failed Login Threshold: $MaxFailedLogins" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Function to configure settings
function Set-MonitoringSettings {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Configure Settings" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $newWindow = Read-Host "Enter time window in minutes (current: $TimeWindowMinutes)"
    if ($newWindow -match '^\d+$') {
        $script:TimeWindowMinutes = [int]$newWindow
    }
    
    $newInterval = Read-Host "Enter check interval in seconds (current: $CheckInterval)"
    if ($newInterval -match '^\d+$') {
        $script:CheckInterval = [int]$newInterval
    }
    
    $newThreshold = Read-Host "Enter failed login threshold (current: $MaxFailedLogins)"
    if ($newThreshold -match '^\d+$') {
        $script:MaxFailedLogins = [int]$newThreshold
    }
    
    Write-Host "Settings updated!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# Main execution
try {
    Write-Log "Security Monitoring script started"
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-5)"
        
        switch ($choice) {
            "1" { Start-SecurityMonitoring }
            "2" { Start-OneTimeCheck; Read-Host "`nPress Enter to continue" }
            "3" { Set-MonitoringSettings }
            "4" { 
                if (Test-Path $ReportFile) {
                    Get-Content $ReportFile | Out-Host
                }
                else {
                    Write-Host "No report found. Run a check first." -ForegroundColor Yellow
                }
                Read-Host "`nPress Enter to continue"
            }
            "5" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                Write-Log "Security Monitoring script exited"
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
    Write-Error "Security monitoring failed: $_"
    exit 1
}
