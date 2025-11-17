#--------------------------------------------------------------------------------------------------
# File: /src/windows/Backup-Database.ps1
# Description: This script provides comprehensive database backup functionality for Windows.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$BackupDir = "C:\DatabaseBackups"
$LogFile = "$BackupDir\DatabaseBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$RetentionDays = 7
$CompressBackups = $true

# Create backup directory if it doesn't exist
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

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

# Function to clean old backups
function Remove-OldBackups {
    param (
        [string]$Path,
        [int]$Days
    )
    
    Write-Log "Cleaning backups older than $Days days from $Path"
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$Days)
        $oldBackups = Get-ChildItem -Path $Path -Recurse | Where-Object {
            $_.LastWriteTime -lt $cutoffDate
        }
        
        if ($oldBackups) {
            foreach ($backup in $oldBackups) {
                Remove-Item $backup.FullName -Force -Recurse
                Write-Log "Removed old backup: $($backup.Name)"
            }
            Write-Log "Removed $($oldBackups.Count) old backup(s)" "SUCCESS"
        }
        else {
            Write-Log "No old backups to remove"
        }
    }
    catch {
        Write-Log "Error cleaning old backups: $_" "ERROR"
    }
}

# Function to compress backup
function Compress-BackupFile {
    param (
        [string]$SourcePath,
        [string]$DestinationPath
    )
    
    try {
        Compress-Archive -Path $SourcePath -DestinationPath $DestinationPath -Force
        Remove-Item $SourcePath -Force
        Write-Log "Backup compressed: $DestinationPath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error compressing backup: $_" "ERROR"
        return $false
    }
}

# Function to backup SQL Server database
function Backup-SQLServerDatabase {
    Write-Log "=== Starting SQL Server Database Backup ==="
    
    $serverInstance = Read-Host "Enter SQL Server instance (e.g., localhost\SQLEXPRESS)"
    $databaseName = Read-Host "Enter database name (or 'ALL' for all databases)"
    
    try {
        # Load SQL Server SMO
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server($serverInstance)
        
        if (-not $server.Version) {
            Write-Log "Unable to connect to SQL Server instance: $serverInstance" "ERROR"
            return
        }
        
        Write-Log "Connected to SQL Server: $($server.Name) (Version: $($server.Version))"
        
        $databases = if ($databaseName -eq 'ALL') {
            $server.Databases | Where-Object { $_.Name -notin @('master', 'model', 'msdb', 'tempdb') }
        }
        else {
            $server.Databases | Where-Object { $_.Name -eq $databaseName }
        }
        
        if (-not $databases) {
            Write-Log "No databases found to backup" "WARNING"
            return
        }
        
        foreach ($db in $databases) {
            $backupFile = Join-Path $BackupDir "$($db.Name)_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
            
            Write-Log "Backing up database: $($db.Name)"
            
            $backup = New-Object Microsoft.SqlServer.Management.Smo.Backup
            $backup.Database = $db.Name
            $backup.Devices.AddDevice($backupFile, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
            $backup.BackupSetDescription = "Full backup of $($db.Name)"
            $backup.BackupSetName = "$($db.Name) Backup"
            
            $backup.SqlBackup($server)
            
            $backupSize = (Get-Item $backupFile).Length / 1MB
            Write-Log "Backup completed: $backupFile ($([math]::Round($backupSize, 2)) MB)" "SUCCESS"
            
            if ($CompressBackups) {
                $zipFile = "$backupFile.zip"
                Compress-BackupFile -SourcePath $backupFile -DestinationPath $zipFile
            }
        }
        
        Write-Log "SQL Server backup completed successfully" "SUCCESS"
    }
    catch {
        Write-Log "Error backing up SQL Server database: $_" "ERROR"
    }
}

# Function to backup MySQL database
function Backup-MySQLDatabase {
    Write-Log "=== Starting MySQL Database Backup ==="
    
    $mysqlDump = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe"
    
    if (-not (Test-Path $mysqlDump)) {
        $mysqlDump = Read-Host "Enter full path to mysqldump.exe"
        if (-not (Test-Path $mysqlDump)) {
            Write-Log "mysqldump.exe not found" "ERROR"
            return
        }
    }
    
    $host = Read-Host "Enter MySQL host (default: localhost)"
    if ([string]::IsNullOrWhiteSpace($host)) { $host = "localhost" }
    
    $user = Read-Host "Enter MySQL username"
    $password = Read-Host "Enter MySQL password" -AsSecureString
    $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    
    $databaseName = Read-Host "Enter database name (or 'ALL' for all databases)"
    
    try {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        
        if ($databaseName -eq 'ALL') {
            $backupFile = Join-Path $BackupDir "mysql_all_databases_$timestamp.sql"
            
            Write-Log "Backing up all MySQL databases"
            
            $arguments = "--host=$host --user=$user --password=$passwordPlain --all-databases --routines --triggers --single-transaction"
            & $mysqlDump $arguments.Split() | Out-File -FilePath $backupFile -Encoding UTF8
            
            if ($LASTEXITCODE -eq 0) {
                $backupSize = (Get-Item $backupFile).Length / 1MB
                Write-Log "Backup completed: $backupFile ($([math]::Round($backupSize, 2)) MB)" "SUCCESS"
                
                if ($CompressBackups) {
                    $zipFile = "$backupFile.zip"
                    Compress-BackupFile -SourcePath $backupFile -DestinationPath $zipFile
                }
            }
            else {
                Write-Log "MySQL backup failed with exit code: $LASTEXITCODE" "ERROR"
            }
        }
        else {
            $backupFile = Join-Path $BackupDir "$($databaseName)_$timestamp.sql"
            
            Write-Log "Backing up MySQL database: $databaseName"
            
            $arguments = "--host=$host --user=$user --password=$passwordPlain --databases $databaseName --routines --triggers --single-transaction"
            & $mysqlDump $arguments.Split() | Out-File -FilePath $backupFile -Encoding UTF8
            
            if ($LASTEXITCODE -eq 0) {
                $backupSize = (Get-Item $backupFile).Length / 1MB
                Write-Log "Backup completed: $backupFile ($([math]::Round($backupSize, 2)) MB)" "SUCCESS"
                
                if ($CompressBackups) {
                    $zipFile = "$backupFile.zip"
                    Compress-BackupFile -SourcePath $backupFile -DestinationPath $zipFile
                }
            }
            else {
                Write-Log "MySQL backup failed with exit code: $LASTEXITCODE" "ERROR"
            }
        }
        
        Write-Log "MySQL backup completed successfully" "SUCCESS"
    }
    catch {
        Write-Log "Error backing up MySQL database: $_" "ERROR"
    }
}

# Function to backup PostgreSQL database
function Backup-PostgreSQLDatabase {
    Write-Log "=== Starting PostgreSQL Database Backup ==="
    
    $pgDump = "C:\Program Files\PostgreSQL\15\bin\pg_dump.exe"
    
    if (-not (Test-Path $pgDump)) {
        $pgDump = Read-Host "Enter full path to pg_dump.exe"
        if (-not (Test-Path $pgDump)) {
            Write-Log "pg_dump.exe not found" "ERROR"
            return
        }
    }
    
    $host = Read-Host "Enter PostgreSQL host (default: localhost)"
    if ([string]::IsNullOrWhiteSpace($host)) { $host = "localhost" }
    
    $port = Read-Host "Enter PostgreSQL port (default: 5432)"
    if ([string]::IsNullOrWhiteSpace($port)) { $port = "5432" }
    
    $user = Read-Host "Enter PostgreSQL username"
    $databaseName = Read-Host "Enter database name"
    
    try {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupFile = Join-Path $BackupDir "$($databaseName)_$timestamp.backup"
        
        Write-Log "Backing up PostgreSQL database: $databaseName"
        
        $env:PGPASSWORD = Read-Host "Enter PostgreSQL password" -AsSecureString
        $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($env:PGPASSWORD))
        $env:PGPASSWORD = $passwordPlain
        
        & $pgDump --host=$host --port=$port --username=$user --format=custom --file=$backupFile $databaseName
        
        if ($LASTEXITCODE -eq 0) {
            $backupSize = (Get-Item $backupFile).Length / 1MB
            Write-Log "Backup completed: $backupFile ($([math]::Round($backupSize, 2)) MB)" "SUCCESS"
            
            if ($CompressBackups) {
                $zipFile = "$backupFile.zip"
                Compress-BackupFile -SourcePath $backupFile -DestinationPath $zipFile
            }
        }
        else {
            Write-Log "PostgreSQL backup failed with exit code: $LASTEXITCODE" "ERROR"
        }
        
        Remove-Item Env:\PGPASSWORD
        Write-Log "PostgreSQL backup completed successfully" "SUCCESS"
    }
    catch {
        Write-Log "Error backing up PostgreSQL database: $_" "ERROR"
    }
}

# Function to backup MongoDB database
function Backup-MongoDBDatabase {
    Write-Log "=== Starting MongoDB Database Backup ==="
    
    $mongoDump = "C:\Program Files\MongoDB\Server\6.0\bin\mongodump.exe"
    
    if (-not (Test-Path $mongoDump)) {
        $mongoDump = Read-Host "Enter full path to mongodump.exe"
        if (-not (Test-Path $mongoDump)) {
            Write-Log "mongodump.exe not found" "ERROR"
            return
        }
    }
    
    $host = Read-Host "Enter MongoDB host (default: localhost)"
    if ([string]::IsNullOrWhiteSpace($host)) { $host = "localhost" }
    
    $port = Read-Host "Enter MongoDB port (default: 27017)"
    if ([string]::IsNullOrWhiteSpace($port)) { $port = "27017" }
    
    $databaseName = Read-Host "Enter database name (or leave empty for all databases)"
    
    try {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $outputDir = Join-Path $BackupDir "mongodb_$timestamp"
        
        Write-Log "Backing up MongoDB database(s)"
        
        if ([string]::IsNullOrWhiteSpace($databaseName)) {
            & $mongoDump --host=$host --port=$port --out=$outputDir
        }
        else {
            & $mongoDump --host=$host --port=$port --db=$databaseName --out=$outputDir
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Backup completed: $outputDir" "SUCCESS"
            
            if ($CompressBackups) {
                $zipFile = "$outputDir.zip"
                Compress-Archive -Path $outputDir -DestinationPath $zipFile -Force
                Remove-Item $outputDir -Recurse -Force
                Write-Log "Backup compressed: $zipFile" "SUCCESS"
            }
        }
        else {
            Write-Log "MongoDB backup failed with exit code: $LASTEXITCODE" "ERROR"
        }
        
        Write-Log "MongoDB backup completed successfully" "SUCCESS"
    }
    catch {
        Write-Log "Error backing up MongoDB database: $_" "ERROR"
    }
}

# Main menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Database Backup Utility" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Backup SQL Server database"
    Write-Host "2. Backup MySQL database"
    Write-Host "3. Backup PostgreSQL database"
    Write-Host "4. Backup MongoDB database"
    Write-Host "5. Clean old backups"
    Write-Host "6. View backup directory"
    Write-Host "7. Configure settings"
    Write-Host "8. Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Backup Directory: $BackupDir" -ForegroundColor Yellow
    Write-Host "Retention: $RetentionDays days" -ForegroundColor Yellow
    Write-Host "Compression: $CompressBackups" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Function to configure settings
function Set-BackupSettings {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "Configure Settings" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    $newBackupDir = Read-Host "Enter backup directory (current: $BackupDir)"
    if (-not [string]::IsNullOrWhiteSpace($newBackupDir)) {
        $script:BackupDir = $newBackupDir
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }
    }
    
    $newRetention = Read-Host "Enter retention days (current: $RetentionDays)"
    if ($newRetention -match '^\d+$') {
        $script:RetentionDays = [int]$newRetention
    }
    
    $compress = Read-Host "Enable compression? (Y/N, current: $CompressBackups)"
    if ($compress -eq 'Y' -or $compress -eq 'N') {
        $script:CompressBackups = $compress -eq 'Y'
    }
    
    Write-Host "Settings updated!" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

# Main execution
try {
    Write-Log "Database Backup script started"
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-8)"
        
        switch ($choice) {
            "1" { Backup-SQLServerDatabase; Read-Host "`nPress Enter to continue" }
            "2" { Backup-MySQLDatabase; Read-Host "`nPress Enter to continue" }
            "3" { Backup-PostgreSQLDatabase; Read-Host "`nPress Enter to continue" }
            "4" { Backup-MongoDBDatabase; Read-Host "`nPress Enter to continue" }
            "5" { Remove-OldBackups -Path $BackupDir -Days $RetentionDays; Read-Host "`nPress Enter to continue" }
            "6" { Invoke-Item $BackupDir }
            "7" { Set-BackupSettings }
            "8" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                Write-Log "Database Backup script exited"
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
    Write-Error "Database backup failed: $_"
    exit 1
}
