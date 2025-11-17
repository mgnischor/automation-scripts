#--------------------------------------------------------------------------------------------------
# File: /src/windows/Get-SystemInformation.ps1
# Description: This script retrieves and displays comprehensive Windows system information.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Function to get operating system information
function Get-OperatingSystemInfo {
    Write-Host "=== Operating System Information ===" -ForegroundColor Cyan
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    
    [PSCustomObject]@{
        'OS Name'           = $os.Caption
        'Version'           = $os.Version
        'Build Number'      = $os.BuildNumber
        'Architecture'      = $os.OSArchitecture
        'Install Date'      = $os.InstallDate
        'Last Boot Time'    = $os.LastBootUpTime
        'System Directory'  = $os.SystemDirectory
        'Serial Number'     = $os.SerialNumber
    } | Format-List
}

# Function to get computer system information
function Get-ComputerInfo {
    Write-Host "`n=== Computer System Information ===" -ForegroundColor Cyan
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    
    [PSCustomObject]@{
        'Computer Name'     = $computer.Name
        'Domain'            = $computer.Domain
        'Manufacturer'      = $computer.Manufacturer
        'Model'             = $computer.Model
        'Total RAM (GB)'    = [math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
        'Number of Processors' = $computer.NumberOfProcessors
        'Number of Logical Processors' = $computer.NumberOfLogicalProcessors
    } | Format-List
}

# Function to get processor information
function Get-ProcessorInfo {
    Write-Host "`n=== Processor Information ===" -ForegroundColor Cyan
    $processors = Get-CimInstance -ClassName Win32_Processor
    
    foreach ($processor in $processors) {
        [PSCustomObject]@{
            'Name'              = $processor.Name
            'Manufacturer'      = $processor.Manufacturer
            'Cores'             = $processor.NumberOfCores
            'Logical Processors' = $processor.NumberOfLogicalProcessors
            'Max Clock Speed'   = "$($processor.MaxClockSpeed) MHz"
            'Current Voltage'   = $processor.CurrentVoltage
        } | Format-List
    }
}

# Function to get BIOS information
function Get-BIOSInfo {
    Write-Host "`n=== BIOS Information ===" -ForegroundColor Cyan
    $bios = Get-CimInstance -ClassName Win32_BIOS
    
    [PSCustomObject]@{
        'Manufacturer'      = $bios.Manufacturer
        'Version'           = $bios.SMBIOSBIOSVersion
        'Release Date'      = $bios.ReleaseDate
        'Serial Number'     = $bios.SerialNumber
    } | Format-List
}

# Function to get network adapter information
function Get-NetworkInfo {
    Write-Host "`n=== Network Adapters ===" -ForegroundColor Cyan
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    
    foreach ($adapter in $adapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        
        [PSCustomObject]@{
            'Name'          = $adapter.Name
            'Description'   = $adapter.InterfaceDescription
            'Status'        = $adapter.Status
            'MAC Address'   = $adapter.MacAddress
            'Link Speed'    = $adapter.LinkSpeed
            'IPv4 Address'  = $ipConfig.IPAddress -join ', '
        } | Format-List
        Write-Host "---"
    }
}

# Function to get disk information
function Get-DiskInfo {
    Write-Host "`n=== Disk Information ===" -ForegroundColor Cyan
    $disks = Get-Disk
    
    foreach ($disk in $disks) {
        [PSCustomObject]@{
            'Number'            = $disk.Number
            'Friendly Name'     = $disk.FriendlyName
            'Size (GB)'         = [math]::Round($disk.Size / 1GB, 2)
            'Partition Style'   = $disk.PartitionStyle
            'Health Status'     = $disk.HealthStatus
            'Operational Status' = $disk.OperationalStatus
        } | Format-List
        Write-Host "---"
    }
}

# Main execution
try {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Windows System Information Report" -ForegroundColor Green
    Write-Host "Generated: $(Get-Date)" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    Get-OperatingSystemInfo
    Get-ComputerInfo
    Get-ProcessorInfo
    Get-BIOSInfo
    Get-NetworkInfo
    Get-DiskInfo
    
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "System information retrieval completed." -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
