#--------------------------------------------------------------------------------------------------
# File: /src/windows/Watch-ServiceMonitor.ps1
# Description: This script monitors critical Windows services and automatically restarts them
#              if stopped.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$LogFile = "C:\Windows\Temp\ServiceMonitor_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$CheckInterval = 60  # seconds
$EmailAlert = $false  # Set to $true to enable email alerts
$EmailTo = "admin@example.com"
$EmailFrom = "monitor@example.com"
$SMTPServer = "smtp.example.com"

# Services to monitor (add or remove as needed)
$ServicesToMonitor = @(
    "Winmgmt",      # Windows Management Instrumentation
    "EventLog",     # Windows Event Log
    "Dhcp",         # DHCP Client
    "Dnscache",     # DNS Client
    "W32Time",      # Windows Time
    "WinDefend",    # Windows Defender Antivirus Service
    "MSSQLSERVER",  # SQL Server (if installed)
    "W3SVC",        # IIS (if installed)
    "IISADMIN"      # IIS Admin (if installed)
)

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

# Function to send email alert
function Send-EmailAlert {
    param (
        [string]$Subject,
        [string]$Body
    )
    
    if (-not $EmailAlert) {
        return
    }
    
    try {
        $mailParams = @{
            To = $EmailTo
            From = $EmailFrom
            Subject = $Subject
            Body = $Body
            SmtpServer = $SMTPServer
        }
        
        Send-MailMessage @mailParams
        Write-Log "Email alert sent: $Subject"
    }
    catch {
        Write-Log "Failed to send email alert: $_" "ERROR"
    }
}

# Function to check service status
function Test-ServiceStatus {
    param (
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        
        if (-not $service) {
            Write-Log "Service not found: $ServiceName" "WARNING"
            return $null
        }
        
        return $service
    }
    catch {
        Write-Log "Error checking service $ServiceName: $_" "ERROR"
        return $null
    }
}

# Function to restart service
function Restart-MonitoredService {
    param (
        [string]$ServiceName
    )
    
    try {
        Write-Log "Attempting to restart service: $ServiceName" "WARNING"
        
        Start-Service -Name $ServiceName -ErrorAction Stop
        Start-Sleep -Seconds 5
        
        $service = Get-Service -Name $ServiceName
        
        if ($service.Status -eq 'Running') {
            Write-Log "Service successfully restarted: $ServiceName" "SUCCESS"
            
            $alertSubject = "Service Restarted: $ServiceName"
            $alertBody = @"
Service Name: $ServiceName
Display Name: $($service.DisplayName)
Status: $($service.Status)
Restart Time: $(Get-Date)
Host: $env:COMPUTERNAME
"@
            Send-EmailAlert -Subject $alertSubject -Body $alertBody
            
            return $true
        }
        else {
            Write-Log "Service restart failed: $ServiceName (Status: $($service.Status))" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error restarting service $ServiceName: $_" "ERROR"
        
        $alertSubject = "Service Restart Failed: $ServiceName"
        $alertBody = @"
Service Name: $ServiceName
Error: $_
Time: $(Get-Date)
Host: $env:COMPUTERNAME
"@
        Send-EmailAlert -Subject $alertSubject -Body $alertBody
        
        return $false
    }
}

# Function to get service dependencies
function Get-ServiceDependencies {
    param (
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName
        $dependencies = $service.DependentServices | Where-Object { $_.Status -eq 'Running' }
        
        if ($dependencies) {
            Write-Log "Service $ServiceName has $($dependencies.Count) dependent services running"
            foreach ($dep in $dependencies) {
                Write-Log "  - $($dep.Name) ($($dep.DisplayName))"
            }
        }
    }
    catch {
        Write-Log "Error getting dependencies for $ServiceName: $_" "WARNING"
    }
}

# Function to monitor all services
function Start-ServiceMonitoring {
    Write-Log "========================================="
    Write-Log "Starting Service Monitoring"
    Write-Log "========================================="
    Write-Log "Monitoring $($ServicesToMonitor.Count) services"
    Write-Log "Check interval: $CheckInterval seconds"
    Write-Log "Press Ctrl+C to stop monitoring"
    Write-Log "========================================="
    
    $cycleCount = 0
    
    while ($true) {
        $cycleCount++
        Write-Log "`n--- Monitoring Cycle #$cycleCount ---"
        
        $stoppedServices = @()
        
        foreach ($serviceName in $ServicesToMonitor) {
            $service = Test-ServiceStatus -ServiceName $serviceName
            
            if ($null -eq $service) {
                continue
            }
            
            if ($service.Status -ne 'Running') {
                Write-Log "Service is NOT running: $($service.DisplayName) (Status: $($service.Status))" "WARNING"
                $stoppedServices += $service
                
                # Get dependencies before restarting
                Get-ServiceDependencies -ServiceName $serviceName
                
                # Attempt to restart
                $restarted = Restart-MonitoredService -ServiceName $serviceName
                
                if (-not $restarted) {
                    Write-Log "Failed to restart service: $serviceName - Manual intervention required!" "ERROR"
                }
            }
            else {
                Write-Log "Service is running: $($service.DisplayName)" "SUCCESS"
            }
        }
        
        # Summary for this cycle
        if ($stoppedServices.Count -eq 0) {
            Write-Log "All monitored services are running" "SUCCESS"
        }
        else {
            Write-Log "$($stoppedServices.Count) service(s) required attention" "WARNING"
        }
        
        Write-Log "Next check in $CheckInterval seconds..."
        Start-Sleep -Seconds $CheckInterval
    }
}

# Function to display service status report
function Show-ServiceReport {
    Write-Log "`n========================================="
    Write-Log "Service Status Report"
    Write-Log "========================================="
    
    $report = @()
    
    foreach ($serviceName in $ServicesToMonitor) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
        if ($service) {
            $report += [PSCustomObject]@{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = $service.Status
                StartType = $service.StartType
            }
        }
    }
    
    $report | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Log $_ }
    Write-Log "========================================="
}

# Function to test email configuration
function Test-EmailConfiguration {
    Write-Host "`nTesting email configuration..." -ForegroundColor Cyan
    
    if (-not $EmailAlert) {
        Write-Host "Email alerts are disabled." -ForegroundColor Yellow
        return
    }
    
    try {
        $testSubject = "Service Monitor - Test Email"
        $testBody = @"
This is a test email from the Service Monitor script.

Configuration:
- From: $EmailFrom
- To: $EmailTo
- SMTP Server: $SMTPServer
- Host: $env:COMPUTERNAME
- Time: $(Get-Date)

If you received this email, the configuration is working correctly.
"@
        
        Send-EmailAlert -Subject $testSubject -Body $testBody
        Write-Host "Test email sent successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to send test email: $_" -ForegroundColor Red
    }
}

# Main menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Windows Service Monitor" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Start monitoring services"
    Write-Host "2. Show current service status"
    Write-Host "3. Test email configuration"
    Write-Host "4. Edit monitored services list"
    Write-Host "5. Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Function to edit monitored services
function Edit-MonitoredServices {
    Write-Host "`nCurrent monitored services:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $ServicesToMonitor.Count; $i++) {
        Write-Host "$($i+1). $($ServicesToMonitor[$i])"
    }
    
    Write-Host "`nOptions:" -ForegroundColor Cyan
    Write-Host "A - Add a service"
    Write-Host "R - Remove a service"
    Write-Host "Q - Return to main menu"
    
    $choice = Read-Host "`nEnter your choice"
    
    switch ($choice.ToUpper()) {
        "A" {
            $serviceName = Read-Host "Enter service name to add"
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                $script:ServicesToMonitor += $serviceName
                Write-Host "Service added: $serviceName" -ForegroundColor Green
            }
            else {
                Write-Host "Service not found: $serviceName" -ForegroundColor Red
            }
            Start-Sleep -Seconds 2
        }
        "R" {
            $index = Read-Host "Enter service number to remove"
            if ($index -match '^\d+$' -and $index -gt 0 -and $index -le $ServicesToMonitor.Count) {
                $removed = $ServicesToMonitor[$index - 1]
                $script:ServicesToMonitor = $ServicesToMonitor | Where-Object { $_ -ne $removed }
                Write-Host "Service removed: $removed" -ForegroundColor Green
            }
            else {
                Write-Host "Invalid selection" -ForegroundColor Red
            }
            Start-Sleep -Seconds 2
        }
    }
}

# Main execution
try {
    while ($true) {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-5)"
        
        switch ($choice) {
            "1" {
                Start-ServiceMonitoring
            }
            "2" {
                Show-ServiceReport
                Read-Host "`nPress Enter to continue"
            }
            "3" {
                Test-EmailConfiguration
                Read-Host "`nPress Enter to continue"
            }
            "4" {
                Edit-MonitoredServices
            }
            "5" {
                Write-Host "Exiting..." -ForegroundColor Yellow
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
    Write-Error "Service monitoring failed: $_"
    exit 1
}
