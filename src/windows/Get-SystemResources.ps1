#--------------------------------------------------------------------------------------------------
# File: /src/windows/Get-SystemResources.ps1
# Description: This script monitors and displays system resource usage including CPU, memory
#              and disk.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Function to get CPU usage
function Get-CPUUsage {
    Write-Host "=== CPU Usage ===" -ForegroundColor Cyan
    
    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
    $cpuUsageRounded = [math]::Round($cpuUsage, 2)
    
    Write-Host "CPU Usage: $cpuUsageRounded%" -ForegroundColor $(if ($cpuUsageRounded -gt 80) { 'Red' } elseif ($cpuUsageRounded -gt 60) { 'Yellow' } else { 'Green' })
    
    # Get top processes by CPU
    Write-Host "`nTop 5 Processes by CPU:" -ForegroundColor White
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, @{Name="CPU(%)";Expression={[math]::Round(($_.CPU / (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize) * 100, 2)}} | Format-Table -AutoSize
}

# Function to get memory usage
function Get-MemoryUsage {
    Write-Host "`n=== Memory Usage ===" -ForegroundColor Cyan
    
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemory = $os.TotalVisibleMemorySize / 1MB
    $freeMemory = $os.FreePhysicalMemory / 1MB
    $usedMemory = $totalMemory - $freeMemory
    $memoryUsagePercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
    
    [PSCustomObject]@{
        'Total Memory (GB)'     = [math]::Round($totalMemory, 2)
        'Used Memory (GB)'      = [math]::Round($usedMemory, 2)
        'Free Memory (GB)'      = [math]::Round($freeMemory, 2)
        'Memory Usage (%)'      = $memoryUsagePercent
    } | Format-List
    
    if ($memoryUsagePercent -gt 80) {
        Write-Host "WARNING: Memory usage is above 80%!" -ForegroundColor Red
    }
    
    # Get top processes by memory
    Write-Host "Top 5 Processes by Memory:" -ForegroundColor White
    Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 Name, @{Name="Memory(MB)";Expression={[math]::Round($_.WorkingSet / 1MB, 2)}} | Format-Table -AutoSize
}

# Function to get disk usage
function Get-DiskUsage {
    Write-Host "`n=== Disk Usage ===" -ForegroundColor Cyan
    
    $disks = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
    
    foreach ($disk in $disks) {
        $usedSpace = [math]::Round($disk.Used / 1GB, 2)
        $freeSpace = [math]::Round($disk.Free / 1GB, 2)
        $totalSpace = $usedSpace + $freeSpace
        $usagePercent = [math]::Round(($usedSpace / $totalSpace) * 100, 2)
        
        $color = if ($usagePercent -gt 80) { 'Red' } elseif ($usagePercent -gt 60) { 'Yellow' } else { 'Green' }
        
        Write-Host "`nDrive: $($disk.Name)" -ForegroundColor White
        [PSCustomObject]@{
            'Total Space (GB)'  = $totalSpace
            'Used Space (GB)'   = $usedSpace
            'Free Space (GB)'   = $freeSpace
            'Usage (%)'         = $usagePercent
        } | Format-List
        
        if ($usagePercent -gt 80) {
            Write-Host "WARNING: Disk $($disk.Name) usage is above 80%!" -ForegroundColor Red
        }
    }
}

# Function to get network usage
function Get-NetworkUsage {
    Write-Host "`n=== Network Usage ===" -ForegroundColor Cyan
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    
    foreach ($adapter in $adapters) {
        Write-Host "`nAdapter: $($adapter.Name)" -ForegroundColor White
        
        $stats = Get-NetAdapterStatistics -Name $adapter.Name
        
        [PSCustomObject]@{
            'Bytes Received (MB)' = [math]::Round($stats.ReceivedBytes / 1MB, 2)
            'Bytes Sent (MB)'     = [math]::Round($stats.SentBytes / 1MB, 2)
            'Link Speed'          = $adapter.LinkSpeed
            'Status'              = $adapter.Status
        } | Format-List
    }
}

# Function to get system uptime
function Get-SystemUptime {
    Write-Host "`n=== System Uptime ===" -ForegroundColor Cyan
    
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    
    [PSCustomObject]@{
        'Last Boot Time'    = $os.LastBootUpTime
        'Uptime (Days)'     = $uptime.Days
        'Uptime (Hours)'    = $uptime.Hours
        'Uptime (Minutes)'  = $uptime.Minutes
    } | Format-List
}

# Main execution
try {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Windows System Resources Monitor" -ForegroundColor Green
    Write-Host "Generated: $(Get-Date)" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    
    Get-CPUUsage
    Get-MemoryUsage
    Get-DiskUsage
    Get-NetworkUsage
    Get-SystemUptime
    
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Resource monitoring completed." -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
