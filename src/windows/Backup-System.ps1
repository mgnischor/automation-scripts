#--------------------------------------------------------------------------------------------------
# File: /src/windows/Backup-System.ps1
# Description: This script creates compressed backups of critical system files and configurations.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Configuration
$BackupDir = "C:\Backups\System"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupName = "SystemBackup_$Timestamp"
$LogFile = "$BackupDir\Logs\Backup_$Timestamp.log"

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

# Function to create backup directories
function New-BackupDirectories {
    Write-Log "Creating backup directories..."
    
    $directories = @(
        $BackupDir,
        "$BackupDir\Logs",
        "$BackupDir\$BackupName"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Log "Created directory: $dir"
        }
    }
}

# Function to backup system information
function Backup-SystemInfo {
    Write-Log "=== Backing Up System Information ==="
    
    $infoPath = "$BackupDir\$BackupName\SystemInfo.txt"
    
    systeminfo | Out-File -FilePath $infoPath -Encoding UTF8
    Get-ComputerInfo | Out-File -FilePath $infoPath -Append -Encoding UTF8
    
    Write-Log "System information backed up to: $infoPath"
}

# Function to backup installed programs
function Backup-InstalledPrograms {
    Write-Log "=== Backing Up Installed Programs List ==="
    
    $programsPath = "$BackupDir\$BackupName\InstalledPrograms.csv"
    
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Export-Csv -Path $programsPath -NoTypeInformation -Encoding UTF8
    
    Write-Log "Installed programs list backed up to: $programsPath"
}

# Function to backup Windows features
function Backup-WindowsFeatures {
    Write-Log "=== Backing Up Windows Features ==="
    
    $featuresPath = "$BackupDir\$BackupName\WindowsFeatures.csv"
    
    Get-WindowsOptionalFeature -Online |
        Select-Object FeatureName, State |
        Export-Csv -Path $featuresPath -NoTypeInformation -Encoding UTF8
    
    Write-Log "Windows features backed up to: $featuresPath"
}

# Function to backup scheduled tasks
function Backup-ScheduledTasks {
    Write-Log "=== Backing Up Scheduled Tasks ==="
    
    $tasksDir = "$BackupDir\$BackupName\ScheduledTasks"
    New-Item -Path $tasksDir -ItemType Directory -Force | Out-Null
    
    $tasks = Get-ScheduledTask
    
    foreach ($task in $tasks) {
        $taskXml = Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath
        $fileName = $task.TaskName -replace '[\\/:*?"<>|]', '_'
        $filePath = "$tasksDir\$fileName.xml"
        
        $taskXml | Out-File -FilePath $filePath -Encoding UTF8
    }
    
    Write-Log "Scheduled tasks backed up to: $tasksDir"
}

# Function to backup network configuration
function Backup-NetworkConfig {
    Write-Log "=== Backing Up Network Configuration ==="
    
    $networkPath = "$BackupDir\$BackupName\NetworkConfig.txt"
    
    @"
=== IP Configuration ===
$(ipconfig /all)

=== Network Adapters ===
$(Get-NetAdapter | Format-Table -AutoSize | Out-String)

=== Routing Table ===
$(route print)

=== DNS Configuration ===
$(Get-DnsClientServerAddress | Format-Table -AutoSize | Out-String)
"@ | Out-File -FilePath $networkPath -Encoding UTF8
    
    Write-Log "Network configuration backed up to: $networkPath"
}

# Function to backup registry keys
function Backup-RegistryKeys {
    Write-Log "=== Backing Up Registry Keys ==="
    
    $regDir = "$BackupDir\$BackupName\Registry"
    New-Item -Path $regDir -ItemType Directory -Force | Out-Null
    
    $keys = @{
        "HKLM_Software" = "HKLM:\SOFTWARE"
        "HKLM_System" = "HKLM:\SYSTEM\CurrentControlSet\Services"
        "HKCU" = "HKCU:\"
    }
    
    foreach ($key in $keys.GetEnumerator()) {
        $exportPath = "$regDir\$($key.Key).reg"
        
        try {
            reg export $key.Value $exportPath /y | Out-Null
            Write-Log "Exported registry key: $($key.Value)"
        }
        catch {
            Write-Log "Failed to export registry key: $($key.Value)" "ERROR"
        }
    }
    
    Write-Log "Registry keys backed up to: $regDir"
}

# Function to backup event logs
function Backup-EventLogs {
    Write-Log "=== Backing Up Event Logs ==="
    
    $logsDir = "$BackupDir\$BackupName\EventLogs"
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    
    $logs = @("System", "Application", "Security")
    
    foreach ($log in $logs) {
        $exportPath = "$logsDir\$log.evtx"
        
        try {
            wevtutil epl $log $exportPath
            Write-Log "Exported event log: $log"
        }
        catch {
            Write-Log "Failed to export event log: $log" "ERROR"
        }
    }
    
    Write-Log "Event logs backed up to: $logsDir"
}

# Function to backup user profiles
function Backup-UserProfiles {
    Write-Log "=== Backing Up User Profiles Information ==="
    
    $profilesPath = "$BackupDir\$BackupName\UserProfiles.csv"
    
    Get-CimInstance -ClassName Win32_UserProfile |
        Where-Object { -not $_.Special } |
        Select-Object LocalPath, LastUseTime, Loaded |
        Export-Csv -Path $profilesPath -NoTypeInformation -Encoding UTF8
    
    Write-Log "User profiles information backed up to: $profilesPath"
}

# Function to compress backup
function Compress-Backup {
    Write-Log "=== Compressing Backup ==="
    
    $zipPath = "$BackupDir\$BackupName.zip"
    
    Compress-Archive -Path "$BackupDir\$BackupName" -DestinationPath $zipPath -Force
    
    if (Test-Path $zipPath) {
        $size = (Get-Item $zipPath).Length / 1MB
        Write-Log "Backup compressed to: $zipPath (Size: $([math]::Round($size, 2)) MB)"
        
        # Remove uncompressed backup folder
        Remove-Item -Path "$BackupDir\$BackupName" -Recurse -Force
        Write-Log "Removed uncompressed backup folder"
    }
}

# Function to clean old backups
function Remove-OldBackups {
    param (
        [int]$RetentionDays = 7
    )
    
    Write-Log "=== Cleaning Old Backups ==="
    
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $oldBackups = Get-ChildItem -Path $BackupDir -Filter "SystemBackup_*.zip" |
        Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    foreach ($backup in $oldBackups) {
        Remove-Item -Path $backup.FullName -Force
        Write-Log "Removed old backup: $($backup.Name)"
    }
    
    Write-Log "Old backups (>$RetentionDays days) removed"
}

# Function to display summary
function Show-Summary {
    Write-Log "`n========================================="
    Write-Log "Backup Summary"
    Write-Log "========================================="
    Write-Log "Backup Location: $BackupDir"
    Write-Log "Backup Name: $BackupName.zip"
    Write-Log "Log File: $LogFile"
    
    $backupFile = Get-Item "$BackupDir\$BackupName.zip" -ErrorAction SilentlyContinue
    if ($backupFile) {
        Write-Log "Backup Size: $([math]::Round($backupFile.Length / 1MB, 2)) MB"
    }
    
    Write-Log "========================================="
}

# Main execution
try {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Windows System Backup Script" -ForegroundColor Green
    Write-Host "Started: $(Get-Date)" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    New-BackupDirectories
    Backup-SystemInfo
    Backup-InstalledPrograms
    Backup-WindowsFeatures
    Backup-ScheduledTasks
    Backup-NetworkConfig
    Backup-RegistryKeys
    Backup-EventLogs
    Backup-UserProfiles
    Compress-Backup
    Remove-OldBackups -RetentionDays 7
    Show-Summary
    
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Backup completed successfully!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
}
catch {
    Write-Log "An error occurred: $_" "ERROR"
    Write-Error "Backup failed: $_"
    exit 1
}
