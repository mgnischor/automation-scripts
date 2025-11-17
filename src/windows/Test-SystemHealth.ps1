#--------------------------------------------------------------------------------------------------
# File: /src/windows/Test-SystemHealth.ps1
# Description: This script performs comprehensive Windows system health checks and generates a detailed report.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$ReportFile = "C:\Windows\Temp\SystemHealthReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$CPUThreshold = 80
$MemoryThreshold = 80
$DiskThreshold = 80

# Function to write to report
function Write-Report {
    param (
        [string]$Message,
        [switch]$Header
    )
    
    if ($Header) {
        $separator = "=" * 60
        $output = "`n$separator`n$Message`n$separator`n"
    }
    else {
        $output = $Message
    }
    
    Write-Host $output
    Add-Content -Path $ReportFile -Value $output
}

# Function to check system information
function Test-SystemInfo {
    Write-Report "System Information" -Header
    
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    
    $info = @"
Hostname: $($computer.Name)
OS: $($os.Caption)
Version: $($os.Version)
Build: $($os.BuildNumber)
Architecture: $($os.OSArchitecture)
Install Date: $($os.InstallDate)
Last Boot: $($os.LastBootUpTime)
Uptime: $((Get-Date) - $os.LastBootUpTime | Select-Object -ExpandProperty Days) days
"@
    
    Write-Report $info
}

# Function to check CPU status
function Test-CPUStatus {
    Write-Report "CPU Status" -Header
    
    $cpu = Get-CimInstance -ClassName Win32_Processor
    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    
    $info = @"
Processor: $($cpu.Name)
Cores: $($cpu.NumberOfCores)
Logical Processors: $($cpu.NumberOfLogicalProcessors)
Current Usage: $([math]::Round($cpuUsage, 2))%
Max Clock Speed: $($cpu.MaxClockSpeed) MHz
"@
    
    Write-Report $info
    
    if ($cpuUsage -gt $CPUThreshold) {
        Write-Report "WARNING: CPU usage is above $CPUThreshold%!" -ForegroundColor Yellow
    }
    else {
        Write-Report "Status: OK" -ForegroundColor Green
    }
}

# Function to check memory status
function Test-MemoryStatus {
    Write-Report "Memory Status" -Header
    
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemory = $os.TotalVisibleMemorySize / 1MB
    $freeMemory = $os.FreePhysicalMemory / 1MB
    $usedMemory = $totalMemory - $freeMemory
    $memoryUsagePercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
    
    $info = @"
Total Memory: $([math]::Round($totalMemory, 2)) GB
Used Memory: $([math]::Round($usedMemory, 2)) GB
Free Memory: $([math]::Round($freeMemory, 2)) GB
Usage: $memoryUsagePercent%
"@
    
    Write-Report $info
    
    if ($memoryUsagePercent -gt $MemoryThreshold) {
        Write-Report "WARNING: Memory usage is above $MemoryThreshold%!"
    }
    else {
        Write-Report "Status: OK"
    }
}

# Function to check disk status
function Test-DiskStatus {
    Write-Report "Disk Status" -Header
    
    $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
    
    foreach ($disk in $disks) {
        $usedSpace = [math]::Round($disk.Used / 1GB, 2)
        $freeSpace = [math]::Round($disk.Free / 1GB, 2)
        $totalSpace = $usedSpace + $freeSpace
        $usagePercent = [math]::Round(($usedSpace / $totalSpace) * 100, 2)
        
        $info = @"

Drive: $($disk.Name)
Total Space: $totalSpace GB
Used Space: $usedSpace GB
Free Space: $freeSpace GB
Usage: $usagePercent%
"@
        
        Write-Report $info
        
        if ($usagePercent -gt $DiskThreshold) {
            Write-Report "WARNING: Drive $($disk.Name) usage is above $DiskThreshold%!"
        }
    }
}

# Function to check network connectivity
function Test-NetworkConnectivity {
    Write-Report "Network Connectivity" -Header
    
    $tests = @(
        @{Name = "Google DNS"; Address = "8.8.8.8"},
        @{Name = "Cloudflare DNS"; Address = "1.1.1.1"},
        @{Name = "Google"; Address = "google.com"}
    )
    
    foreach ($test in $tests) {
        $result = Test-Connection -ComputerName $test.Address -Count 2 -Quiet
        $status = if ($result) { "OK" } else { "FAILED" }
        Write-Report "$($test.Name) ($($test.Address)): $status"
    }
}

# Function to check running services
function Test-CriticalServices {
    Write-Report "Critical Services Status" -Header
    
    $criticalServices = @(
        "Winmgmt",      # Windows Management Instrumentation
        "Dhcp",         # DHCP Client
        "Dnscache",     # DNS Client
        "EventLog",     # Windows Event Log
        "W32Time",      # Windows Time
        "WinDefend"     # Windows Defender
    )
    
    foreach ($serviceName in $criticalServices) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $status = $service.Status
            Write-Report "$($service.DisplayName): $status"
            
            if ($status -ne 'Running') {
                Write-Report "WARNING: Service $($service.DisplayName) is not running!"
            }
        }
    }
}

# Function to check Windows updates
function Test-WindowsUpdates {
    Write-Report "Windows Update Status" -Header
    
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
        
        $updateCount = $searchResult.Updates.Count
        Write-Report "Available Updates: $updateCount"
        
        if ($updateCount -gt 0) {
            Write-Report "WARNING: There are $updateCount pending updates!"
        }
    }
    catch {
        Write-Report "Unable to check Windows updates: $_"
    }
}

# Function to check event log errors
function Test-EventLogErrors {
    Write-Report "Recent Event Log Errors" -Header
    
    $errorLogs = Get-WinEvent -FilterHashtable @{
        LogName = 'System', 'Application'
        Level = 2  # Error level
        StartTime = (Get-Date).AddHours(-24)
    } -MaxEvents 10 -ErrorAction SilentlyContinue
    
    if ($errorLogs) {
        Write-Report "Found $($errorLogs.Count) errors in the last 24 hours"
        
        foreach ($log in $errorLogs) {
            Write-Report "`n[$($log.TimeCreated)] $($log.ProviderName)"
            Write-Report "  $($log.Message.Substring(0, [Math]::Min(100, $log.Message.Length)))..."
        }
    }
    else {
        Write-Report "No critical errors found in the last 24 hours"
    }
}

# Function to check disk health
function Test-DiskHealth {
    Write-Report "Disk Health Status" -Header
    
    $disks = Get-PhysicalDisk
    
    foreach ($disk in $disks) {
        Write-Report "`nDisk: $($disk.FriendlyName)"
        Write-Report "  Health Status: $($disk.HealthStatus)"
        Write-Report "  Operational Status: $($disk.OperationalStatus)"
        
        if ($disk.HealthStatus -ne 'Healthy') {
            Write-Report "  WARNING: Disk health is $($disk.HealthStatus)!"
        }
    }
}

# Function to check Windows Defender status
function Test-WindowsDefender {
    Write-Report "Windows Defender Status" -Header
    
    try {
        $defenderStatus = Get-MpComputerStatus
        
        $info = @"
Antivirus Enabled: $($defenderStatus.AntivirusEnabled)
Real-time Protection: $($defenderStatus.RealTimeProtectionEnabled)
Behavior Monitor: $($defenderStatus.BehaviorMonitorEnabled)
Signature Age (days): $($defenderStatus.AntivirusSignatureAge)
Last Quick Scan: $($defenderStatus.QuickScanEndTime)
Last Full Scan: $($defenderStatus.FullScanEndTime)
"@
        
        Write-Report $info
        
        if (-not $defenderStatus.RealTimeProtectionEnabled) {
            Write-Report "WARNING: Real-time protection is disabled!"
        }
        
        if ($defenderStatus.AntivirusSignatureAge -gt 7) {
            Write-Report "WARNING: Antivirus signatures are older than 7 days!"
        }
    }
    catch {
        Write-Report "Unable to check Windows Defender status: $_"
    }
}

# Function to check logged in users
function Test-LoggedInUsers {
    Write-Report "Logged In Users" -Header
    
    $users = query user 2>$null
    if ($users) {
        Write-Report ($users | Out-String)
    }
    else {
        Write-Report "No users currently logged in"
    }
}

# Function to generate summary
function Write-Summary {
    Write-Report "Health Check Summary" -Header
    
    Write-Report "Report Generated: $(Get-Date)"
    Write-Report "Report File: $ReportFile"
    Write-Report "`nReview the report above for any warnings or issues."
}

# Main execution
try {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Windows System Health Check" -ForegroundColor Green
    Write-Host "Started: $(Get-Date)" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    # Initialize report file
    "Windows System Health Check Report" | Out-File -FilePath $ReportFile -Encoding UTF8
    "Generated: $(Get-Date)" | Out-File -FilePath $ReportFile -Append -Encoding UTF8
    
    Test-SystemInfo
    Test-CPUStatus
    Test-MemoryStatus
    Test-DiskStatus
    Test-NetworkConnectivity
    Test-CriticalServices
    Test-WindowsUpdates
    Test-EventLogErrors
    Test-DiskHealth
    Test-WindowsDefender
    Test-LoggedInUsers
    Write-Summary
    
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Health check completed!" -ForegroundColor Green
    Write-Host "Report saved to: $ReportFile" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
}
catch {
    Write-Error "Health check failed: $_"
    exit 1
}
