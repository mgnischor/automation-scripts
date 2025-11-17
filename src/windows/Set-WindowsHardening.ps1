#--------------------------------------------------------------------------------------------------
# File: /src/windows/Set-WindowsHardening.ps1
# Description: This script applies security hardening measures to Windows systems based on best practices.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$LogFile = "C:\Windows\Temp\WindowsHardening_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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

# Function to disable unnecessary services
function Disable-UnnecessaryServices {
    Write-Log "=== Disabling Unnecessary Services ==="
    
    $servicesToDisable = @(
        "RemoteRegistry",       # Remote Registry
        "RemoteAccess",         # Routing and Remote Access
        "TapiSrv",             # Telephony
        "DiagTrack",           # Connected User Experiences and Telemetry
        "dmwappushservice",    # WAP Push Message Routing Service
        "MapsBroker",          # Downloaded Maps Manager
        "lfsvc",               # Geolocation Service
        "RetailDemo",          # Retail Demo Service
        "XboxGipSvc",          # Xbox Accessory Management Service
        "XblAuthManager",      # Xbox Live Auth Manager
        "XblGameSave",         # Xbox Live Game Save
        "XboxNetApiSvc"        # Xbox Live Networking Service
    )
    
    foreach ($serviceName in $servicesToDisable) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            try {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log "Disabled service: $serviceName"
            }
            catch {
                Write-Log "Failed to disable service: $serviceName - $_" "WARNING"
            }
        }
    }
}

# Function to configure Windows Firewall
function Enable-WindowsFirewall {
    Write-Log "=== Configuring Windows Firewall ==="
    
    try {
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        Write-Log "Windows Firewall enabled for all profiles"
        
        # Block all inbound connections by default
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        Write-Log "Firewall default rules configured"
    }
    catch {
        Write-Log "Error configuring firewall: $_" "ERROR"
    }
}

# Function to configure Windows Defender
function Set-WindowsDefender {
    Write-Log "=== Configuring Windows Defender ==="
    
    try {
        Set-MpPreference -DisableRealtimeMonitoring $false
        Set-MpPreference -DisableBehaviorMonitoring $false
        Set-MpPreference -DisableBlockAtFirstSeen $false
        Set-MpPreference -DisableIOAVProtection $false
        Set-MpPreference -DisableScriptScanning $false
        Set-MpPreference -EnableControlledFolderAccess Enabled
        Set-MpPreference -EnableNetworkProtection Enabled
        Set-MpPreference -MAPSReporting Advanced
        Set-MpPreference -SubmitSamplesConsent SendAllSamples
        
        Write-Log "Windows Defender configured"
        
        # Update definitions
        Update-MpSignature
        Write-Log "Windows Defender definitions updated"
    }
    catch {
        Write-Log "Error configuring Windows Defender: $_" "ERROR"
    }
}

# Function to disable SMBv1
function Disable-SMBv1 {
    Write-Log "=== Disabling SMBv1 Protocol ==="
    
    try {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
        Write-Log "SMBv1 disabled"
    }
    catch {
        Write-Log "Error disabling SMBv1: $_" "ERROR"
    }
}

# Function to configure User Account Control
function Set-UACSettings {
    Write-Log "=== Configuring User Account Control ==="
    
    try {
        # Set UAC to always notify
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 2
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 1
        Write-Log "UAC configured to always notify"
    }
    catch {
        Write-Log "Error configuring UAC: $_" "ERROR"
    }
}

# Function to disable PowerShell v2
function Disable-PowerShellV2 {
    Write-Log "=== Disabling PowerShell v2 ==="
    
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart -ErrorAction SilentlyContinue
        Write-Log "PowerShell v2 disabled"
    }
    catch {
        Write-Log "Error disabling PowerShell v2: $_" "WARNING"
    }
}

# Function to configure automatic updates
function Enable-AutomaticUpdates {
    Write-Log "=== Enabling Automatic Updates ==="
    
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "AUOptions" -Value 4
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "ScheduledInstallDay" -Value 0
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name "ScheduledInstallTime" -Value 3
        Write-Log "Automatic updates enabled"
    }
    catch {
        Write-Log "Error configuring automatic updates: $_" "ERROR"
    }
}

# Function to configure password policy
function Set-PasswordPolicy {
    Write-Log "=== Configuring Password Policy ==="
    
    try {
        # Set password complexity requirements
        secedit /export /cfg C:\Windows\Temp\secpol.cfg | Out-Null
        
        $secpolContent = Get-Content C:\Windows\Temp\secpol.cfg
        $secpolContent = $secpolContent -replace "PasswordComplexity = 0", "PasswordComplexity = 1"
        $secpolContent = $secpolContent -replace "MinimumPasswordLength = \d+", "MinimumPasswordLength = 14"
        $secpolContent = $secpolContent -replace "MaximumPasswordAge = \d+", "MaximumPasswordAge = 90"
        $secpolContent = $secpolContent -replace "MinimumPasswordAge = \d+", "MinimumPasswordAge = 1"
        $secpolContent | Set-Content C:\Windows\Temp\secpol.cfg
        
        secedit /configure /db C:\Windows\security\local.sdb /cfg C:\Windows\Temp\secpol.cfg /areas SECURITYPOLICY | Out-Null
        Remove-Item C:\Windows\Temp\secpol.cfg -Force
        
        Write-Log "Password policy configured"
    }
    catch {
        Write-Log "Error configuring password policy: $_" "ERROR"
    }
}

# Function to configure audit policy
function Set-AuditPolicy {
    Write-Log "=== Configuring Audit Policy ==="
    
    try {
        auditpol /set /category:"Account Logon" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Object Access" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Policy Change" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"Privilege Use" /success:enable /failure:enable | Out-Null
        auditpol /set /category:"System" /success:enable /failure:enable | Out-Null
        
        Write-Log "Audit policy configured"
    }
    catch {
        Write-Log "Error configuring audit policy: $_" "ERROR"
    }
}

# Function to disable guest account
function Disable-GuestAccount {
    Write-Log "=== Disabling Guest Account ==="
    
    try {
        Disable-LocalUser -Name "Guest" -ErrorAction SilentlyContinue
        Write-Log "Guest account disabled"
    }
    catch {
        Write-Log "Error disabling guest account: $_" "WARNING"
    }
}

# Function to configure RDP security
function Set-RDPSecurity {
    Write-Log "=== Configuring RDP Security ==="
    
    try {
        # Require Network Level Authentication
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1
        
        # Set encryption level to high
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MinEncryptionLevel" -Value 3
        
        Write-Log "RDP security configured"
    }
    catch {
        Write-Log "Error configuring RDP security: $_" "ERROR"
    }
}

# Function to disable AutoRun
function Disable-AutoRun {
    Write-Log "=== Disabling AutoRun ==="
    
    try {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -Value 255
        Write-Log "AutoRun disabled"
    }
    catch {
        Write-Log "Error disabling AutoRun: $_" "ERROR"
    }
}

# Function to configure Windows Event Log size
function Set-EventLogSize {
    Write-Log "=== Configuring Event Log Size ==="
    
    $logs = @("Application", "Security", "System")
    
    foreach ($log in $logs) {
        try {
            Limit-EventLog -LogName $log -MaximumSize 512MB
            Write-Log "Configured $log log size to 512MB"
        }
        catch {
            Write-Log "Error configuring $log log size: $_" "WARNING"
        }
    }
}

# Function to display summary
function Show-Summary {
    Write-Log "`n========================================="
    Write-Log "Windows Hardening Summary"
    Write-Log "========================================="
    Write-Log "Hardening completed at: $(Get-Date)"
    Write-Log "Log file: $LogFile"
    Write-Log "`nPlease reboot the system for all changes to take effect."
    Write-Log "========================================="
}

# Main execution
try {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Windows Security Hardening Script" -ForegroundColor Green
    Write-Host "Started: $(Get-Date)" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    Write-Host "`nWARNING: This script will make security changes to your system." -ForegroundColor Yellow
    Write-Host "Make sure you have a backup before proceeding.`n" -ForegroundColor Yellow
    
    $confirmation = Read-Host "Do you want to continue? (Y/N)"
    if ($confirmation -ne 'Y') {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        exit 0
    }
    
    Disable-UnnecessaryServices
    Enable-WindowsFirewall
    Set-WindowsDefender
    Disable-SMBv1
    Set-UACSettings
    Disable-PowerShellV2
    Enable-AutomaticUpdates
    Set-PasswordPolicy
    Set-AuditPolicy
    Disable-GuestAccount
    Set-RDPSecurity
    Disable-AutoRun
    Set-EventLogSize
    Show-Summary
    
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Hardening completed successfully!" -ForegroundColor Green
    Write-Host "Please reboot your system." -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Green
}
catch {
    Write-Log "An error occurred: $_" "ERROR"
    Write-Error "Hardening failed: $_"
    exit 1
}
