#--------------------------------------------------------------------------------------------------
# File: /src/windows/Optimize-System.ps1
# Description: This script performs system optimization and cleanup tasks for Windows.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$LogFile = "C:\Windows\Temp\SystemOptimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Function to write log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

# Function to clean temporary files
function Clear-TemporaryFiles {
    Write-Log "=== Cleaning Temporary Files ==="
    
    $tempFolders = @(
        $env:TEMP,
        "C:\Windows\Temp",
        "C:\Windows\Prefetch"
    )
    
    foreach ($folder in $tempFolders) {
        if (Test-Path $folder) {
            try {
                $itemsBefore = (Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count
                Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                
                $itemsAfter = (Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count
                $itemsRemoved = $itemsBefore - $itemsAfter
                
                Write-Log "Cleaned $folder - Removed $itemsRemoved items"
            }
            catch {
                Write-Log "Error cleaning $folder : $_" "ERROR"
            }
        }
    }
}

# Function to clean Windows Update cache
function Clear-WindowsUpdateCache {
    Write-Log "=== Cleaning Windows Update Cache ==="
    
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
        
        $updateFolder = "C:\Windows\SoftwareDistribution\Download"
        if (Test-Path $updateFolder) {
            $sizeBefore = (Get-ChildItem -Path $updateFolder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            
            Get-ChildItem -Path $updateFolder -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            
            Write-Log "Cleaned Windows Update cache - Freed $([math]::Round($sizeBefore, 2)) MB"
        }
        
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Start-Service -Name bits -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Error cleaning Windows Update cache: $_" "ERROR"
    }
}

# Function to run Disk Cleanup
function Start-DiskCleanup {
    Write-Log "=== Running Disk Cleanup ==="
    
    try {
        $cleanmgrKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        
        # Enable all cleanup options
        $subKeys = Get-ChildItem -Path $cleanmgrKey
        foreach ($subKey in $subKeys) {
            Set-ItemProperty -Path $subKey.PSPath -Name StateFlags0001 -Value 2 -ErrorAction SilentlyContinue
        }
        
        # Run cleanup
        Start-Process -FilePath cleanmgr.exe -ArgumentList "/sagerun:1" -Wait -NoNewWindow
        
        Write-Log "Disk Cleanup completed"
    }
    catch {
        Write-Log "Error running Disk Cleanup: $_" "ERROR"
    }
}

# Function to optimize drives
function Optimize-Drives {
    Write-Log "=== Optimizing Drives ==="
    
    $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
    
    foreach ($volume in $volumes) {
        try {
            Write-Log "Optimizing drive $($volume.DriveLetter)..."
            Optimize-Volume -DriveLetter $volume.DriveLetter -Verbose
            Write-Log "Drive $($volume.DriveLetter) optimized"
        }
        catch {
            Write-Log "Error optimizing drive $($volume.DriveLetter): $_" "ERROR"
        }
    }
}

# Function to clear DNS cache
function Clear-DNSCache {
    Write-Log "=== Clearing DNS Cache ==="
    
    try {
        Clear-DnsClientCache
        Write-Log "DNS cache cleared"
    }
    catch {
        Write-Log "Error clearing DNS cache: $_" "ERROR"
    }
}

# Function to clear event logs
function Clear-EventLogs {
    Write-Log "=== Clearing Event Logs ==="
    
    $logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 }
    
    foreach ($log in $logs) {
        try {
            wevtutil cl $log.LogName 2>$null
            Write-Log "Cleared event log: $($log.LogName)"
        }
        catch {
            Write-Log "Error clearing event log $($log.LogName): $_" "WARNING"
        }
    }
}

# Function to clean Windows Error Reporting
function Clear-WindowsErrorReporting {
    Write-Log "=== Cleaning Windows Error Reporting ==="
    
    $werFolders = @(
        "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
        "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
    )
    
    foreach ($folder in $werFolders) {
        if (Test-Path $folder) {
            try {
                $sizeBefore = (Get-ChildItem -Path $folder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
                Remove-Item -Path "$folder\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Cleaned $folder - Freed $([math]::Round($sizeBefore, 2)) MB"
            }
            catch {
                Write-Log "Error cleaning $folder : $_" "ERROR"
            }
        }
    }
}

# Function to disable unnecessary services
function Disable-UnnecessaryServices {
    Write-Log "=== Checking Unnecessary Services ==="
    
    $servicesToDisable = @(
        "DiagTrack",      # Connected User Experiences and Telemetry
        "dmwappushservice", # WAP Push Message Routing Service
        "RetailDemo",     # Retail Demo Service
        "RemoteRegistry"  # Remote Registry
    )
    
    foreach ($serviceName in $servicesToDisable) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            try {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log "Disabled service: $serviceName"
            }
            catch {
                Write-Log "Error disabling service $serviceName : $_" "WARNING"
            }
        }
    }
}

# Function to update Windows Defender definitions
function Update-WindowsDefender {
    Write-Log "=== Updating Windows Defender Definitions ==="
    
    try {
        Update-MpSignature -ErrorAction SilentlyContinue
        Write-Log "Windows Defender definitions updated"
    }
    catch {
        Write-Log "Error updating Windows Defender: $_" "WARNING"
    }
}

# Function to check disk health
function Test-DiskHealth {
    Write-Log "=== Checking Disk Health ==="
    
    $disks = Get-PhysicalDisk
    
    foreach ($disk in $disks) {
        $health = $disk.HealthStatus
        $operational = $disk.OperationalStatus
        
        Write-Log "Disk $($disk.FriendlyName): Health=$health, Status=$operational"
        
        if ($health -ne 'Healthy') {
            Write-Log "WARNING: Disk $($disk.FriendlyName) health status is $health" "WARNING"
        }
    }
}

# Function to display summary
function Show-Summary {
    Write-Log "`n========================================="
    Write-Log "Optimization Summary"
    Write-Log "========================================="
    
    # Get free space on C: drive
    $drive = Get-PSDrive C
    Write-Log "C: Drive Free Space: $([math]::Round($drive.Free / 1GB, 2)) GB"
    
    # Get memory usage
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $freeMemory = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    Write-Log "Free Memory: $freeMemory GB"
    
    Write-Log "Log File: $LogFile"
    Write-Log "========================================="
}

# Main execution
try {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Windows System Optimization Script" -ForegroundColor Green
    Write-Host "Started: $(Get-Date)" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    Clear-TemporaryFiles
    Clear-WindowsUpdateCache
    Start-DiskCleanup
    Optimize-Drives
    Clear-DNSCache
    Clear-EventLogs
    Clear-WindowsErrorReporting
    Disable-UnnecessaryServices
    Update-WindowsDefender
    Test-DiskHealth
    Show-Summary
    
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "System optimization completed!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
}
catch {
    Write-Log "An error occurred: $_" "ERROR"
    Write-Error "Optimization failed: $_"
    exit 1
}
