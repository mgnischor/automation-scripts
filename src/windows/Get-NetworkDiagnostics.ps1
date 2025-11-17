#--------------------------------------------------------------------------------------------------
# File: /src/windows/Get-NetworkDiagnostics.ps1
# Description: This script performs comprehensive network diagnostics and troubleshooting.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Requires Administrator privileges
#Requires -RunAsAdministrator

$LogFile = "C:\Windows\Temp\NetworkDiagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ReportFile = "C:\Windows\Temp\NetworkReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

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

# Function to get network adapters
function Get-NetworkAdapters {
    Write-Report "Network Adapters" -Header
    
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        
        foreach ($adapter in $adapters) {
            Write-Report "`nAdapter: $($adapter.Name)"
            Write-Report "  Description: $($adapter.InterfaceDescription)"
            Write-Report "  Status: $($adapter.Status)"
            Write-Report "  Link Speed: $($adapter.LinkSpeed)"
            Write-Report "  MAC Address: $($adapter.MacAddress)"
            
            # Get IP configuration
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
            if ($ipConfig) {
                Write-Report "  IP Addresses:"
                foreach ($ip in $ipConfig) {
                    Write-Report "    $($ip.IPAddress) ($($ip.AddressFamily))"
                }
            }
        }
        
        Write-Log "Retrieved network adapter information"
    }
    catch {
        Write-Log "Error getting network adapters: $_" "ERROR"
    }
}

# Function to get routing table
function Get-RoutingTable {
    Write-Report "Routing Table" -Header
    
    try {
        $routes = Get-NetRoute | Where-Object { $_.DestinationPrefix -ne '::1/128' } | 
            Select-Object -First 20 | Sort-Object -Property RouteMetric
        
        foreach ($route in $routes) {
            Write-Report "`nDestination: $($route.DestinationPrefix)"
            Write-Report "  Next Hop: $($route.NextHop)"
            Write-Report "  Interface: $($route.InterfaceAlias)"
            Write-Report "  Metric: $($route.RouteMetric)"
        }
        
        Write-Log "Retrieved routing table"
    }
    catch {
        Write-Log "Error getting routing table: $_" "ERROR"
    }
}

# Function to test DNS resolution
function Test-DNSResolution {
    Write-Report "DNS Resolution Test" -Header
    
    $testDomains = @("google.com", "microsoft.com", "github.com")
    
    try {
        $dnsServers = Get-DnsClientServerAddress | Where-Object { $_.ServerAddresses.Count -gt 0 }
        
        Write-Report "Configured DNS Servers:"
        foreach ($server in $dnsServers) {
            Write-Report "  Interface: $($server.InterfaceAlias)"
            foreach ($addr in $server.ServerAddresses) {
                Write-Report "    $addr"
            }
        }
        
        Write-Report "`nDNS Resolution Tests:"
        foreach ($domain in $testDomains) {
            try {
                $result = Resolve-DnsName -Name $domain -ErrorAction Stop
                $ipAddresses = $result | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress
                Write-Report "`n$domain : SUCCESS"
                Write-Report "  Resolved to: $($ipAddresses -join ', ')"
            }
            catch {
                Write-Report "`n$domain : FAILED"
                Write-Report "  Error: $_"
            }
        }
        
        Write-Log "Completed DNS resolution tests"
    }
    catch {
        Write-Log "Error testing DNS resolution: $_" "ERROR"
    }
}

# Function to test connectivity
function Test-NetworkConnectivity {
    Write-Report "Network Connectivity Test" -Header
    
    $testHosts = @(
        @{Name = "Google DNS"; Address = "8.8.8.8"},
        @{Name = "Cloudflare DNS"; Address = "1.1.1.1"},
        @{Name = "Google"; Address = "google.com"},
        @{Name = "Microsoft"; Address = "microsoft.com"}
    )
    
    foreach ($host in $testHosts) {
        try {
            Write-Report "`nTesting: $($host.Name) ($($host.Address))"
            
            $ping = Test-Connection -ComputerName $host.Address -Count 4 -ErrorAction Stop
            $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
            $packetLoss = (($ping.Count - ($ping | Where-Object { $_.StatusCode -eq 0 }).Count) / $ping.Count) * 100
            
            Write-Report "  Status: SUCCESS"
            Write-Report "  Average Latency: $([math]::Round($avgLatency, 2)) ms"
            Write-Report "  Packet Loss: $packetLoss%"
        }
        catch {
            Write-Report "  Status: FAILED"
            Write-Report "  Error: $_"
        }
    }
    
    Write-Log "Completed connectivity tests"
}

# Function to test port connectivity
function Test-PortConnectivity {
    Write-Report "Port Connectivity Test" -Header
    
    $host = Read-Host "Enter hostname or IP address"
    $ports = Read-Host "Enter port(s) to test (comma-separated)"
    
    $portList = $ports -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($port in $portList) {
        try {
            Write-Report "`nTesting: $host`:$port"
            
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($host, $port, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)
            
            if ($wait) {
                try {
                    $tcpClient.EndConnect($connect)
                    Write-Report "  Status: OPEN"
                }
                catch {
                    Write-Report "  Status: CLOSED"
                }
            }
            else {
                Write-Report "  Status: TIMEOUT"
            }
            
            $tcpClient.Close()
        }
        catch {
            Write-Report "  Status: ERROR - $_"
        }
    }
    
    Write-Log "Completed port connectivity tests"
}

# Function to get active connections
function Get-ActiveConnections {
    Write-Report "Active Network Connections" -Header
    
    try {
        $connections = Get-NetTCPConnection | Where-Object { $_.State -eq 'Established' } | 
            Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess | 
            Sort-Object -Property RemoteAddress
        
        Write-Report "`nTotal Established Connections: $($connections.Count)"
        Write-Report "`nTop Connections:"
        
        foreach ($conn in $connections | Select-Object -First 20) {
            $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            $processName = if ($process) { $process.Name } else { "Unknown" }
            
            Write-Report "`n$($conn.LocalAddress):$($conn.LocalPort) -> $($conn.RemoteAddress):$($conn.RemotePort)"
            Write-Report "  State: $($conn.State)"
            Write-Report "  Process: $processName (PID: $($conn.OwningProcess))"
        }
        
        Write-Log "Retrieved active connections"
    }
    catch {
        Write-Log "Error getting active connections: $_" "ERROR"
    }
}

# Function to get listening ports
function Get-ListeningPorts {
    Write-Report "Listening Ports" -Header
    
    try {
        $listeners = Get-NetTCPConnection | Where-Object { $_.State -eq 'Listen' } | 
            Select-Object LocalAddress, LocalPort, OwningProcess | 
            Sort-Object -Property LocalPort
        
        Write-Report "`nTotal Listening Ports: $($listeners.Count)"
        
        foreach ($listener in $listeners) {
            $process = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
            $processName = if ($process) { $process.Name } else { "Unknown" }
            
            Write-Report "`nPort: $($listener.LocalPort) ($($listener.LocalAddress))"
            Write-Report "  Process: $processName (PID: $($listener.OwningProcess))"
        }
        
        Write-Log "Retrieved listening ports"
    }
    catch {
        Write-Log "Error getting listening ports: $_" "ERROR"
    }
}

# Function to get network statistics
function Get-NetworkStatistics {
    Write-Report "Network Statistics" -Header
    
    try {
        $stats = netstat -s
        
        Write-Report ($stats | Out-String)
        
        Write-Log "Retrieved network statistics"
    }
    catch {
        Write-Log "Error getting network statistics: $_" "ERROR"
    }
}

# Function to trace route
function Start-TraceRoute {
    Write-Report "Trace Route" -Header
    
    $destination = Read-Host "Enter destination hostname or IP address"
    
    try {
        Write-Report "`nTracing route to $destination..."
        
        $trace = Test-NetConnection -ComputerName $destination -TraceRoute
        
        Write-Report "`nHops:"
        $hopNumber = 1
        foreach ($hop in $trace.TraceRoute) {
            Write-Report "  $hopNumber. $hop"
            $hopNumber++
        }
        
        Write-Report "`nDestination: $($trace.ComputerName)"
        Write-Report "IP Address: $($trace.RemoteAddress)"
        Write-Report "Ping Success: $($trace.PingSucceeded)"
        
        if ($trace.TcpTestSucceeded) {
            Write-Report "TCP Test: Success (Port $($trace.RemotePort))"
        }
        
        Write-Log "Completed trace route to $destination"
    }
    catch {
        Write-Log "Error tracing route: $_" "ERROR"
    }
}

# Function to flush DNS cache
function Clear-DNSCache {
    Write-Log "Flushing DNS cache"
    
    try {
        Clear-DnsClientCache
        Write-Report "DNS cache cleared successfully" "SUCCESS"
        Write-Log "DNS cache cleared" "SUCCESS"
    }
    catch {
        Write-Log "Error clearing DNS cache: $_" "ERROR"
    }
}

# Function to reset network adapters
function Reset-NetworkAdapters {
    Write-Log "Resetting network adapters"
    
    Write-Host "`nWARNING: This will restart all network adapters and may interrupt connectivity." -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to continue? (Y/N)"
    
    if ($confirm -ne 'Y') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        return
    }
    
    try {
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        
        foreach ($adapter in $adapters) {
            Write-Log "Restarting adapter: $($adapter.Name)"
            Restart-NetAdapter -Name $adapter.Name -Confirm:$false
        }
        
        Write-Report "Network adapters reset successfully" "SUCCESS"
        Write-Log "Network adapters reset completed" "SUCCESS"
    }
    catch {
        Write-Log "Error resetting network adapters: $_" "ERROR"
    }
}

# Function to generate summary
function New-SummaryReport {
    Write-Report "Network Diagnostics Summary" -Header
    Write-Report "Report Generated: $(Get-Date)"
    Write-Report "Computer: $env:COMPUTERNAME"
    Write-Report "`nLog File: $LogFile"
    Write-Report "Report File: $ReportFile"
}

# Function to run full diagnostics
function Start-FullDiagnostics {
    Clear-Host
    Write-Host "Running full network diagnostics..." -ForegroundColor Cyan
    
    # Initialize report file
    "Windows Network Diagnostics Report" | Out-File -FilePath $ReportFile -Encoding UTF8
    "Generated: $(Get-Date)" | Out-File -FilePath $ReportFile -Append -Encoding UTF8
    
    Get-NetworkAdapters
    Get-RoutingTable
    Test-DNSResolution
    Test-NetworkConnectivity
    Get-ActiveConnections
    Get-ListeningPorts
    Get-NetworkStatistics
    New-SummaryReport
    
    Write-Host "`n=========================================" -ForegroundColor Green
    Write-Host "Full diagnostics completed!" -ForegroundColor Green
    Write-Host "Report saved to: $ReportFile" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
}

# Main menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Network Diagnostics & Troubleshooting" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Run full diagnostics"
    Write-Host "2. Show network adapters"
    Write-Host "3. Test connectivity"
    Write-Host "4. Test port connectivity"
    Write-Host "5. Show active connections"
    Write-Host "6. Show listening ports"
    Write-Host "7. Trace route"
    Write-Host "8. DNS resolution test"
    Write-Host "9. Flush DNS cache"
    Write-Host "10. Reset network adapters"
    Write-Host "11. Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

# Main execution
try {
    Write-Log "Network Diagnostics script started"
    
    while ($true) {
        Show-Menu
        $choice = Read-Host "Enter your choice (1-11)"
        
        # Initialize report for single operations
        if ($choice -ne "1" -and $choice -ne "11") {
            "Windows Network Diagnostics Report" | Out-File -FilePath $ReportFile -Encoding UTF8
            "Generated: $(Get-Date)" | Out-File -FilePath $ReportFile -Append -Encoding UTF8
        }
        
        switch ($choice) {
            "1" { Start-FullDiagnostics; Read-Host "`nPress Enter to continue" }
            "2" { Get-NetworkAdapters; Read-Host "`nPress Enter to continue" }
            "3" { Test-NetworkConnectivity; Read-Host "`nPress Enter to continue" }
            "4" { Test-PortConnectivity; Read-Host "`nPress Enter to continue" }
            "5" { Get-ActiveConnections; Read-Host "`nPress Enter to continue" }
            "6" { Get-ListeningPorts; Read-Host "`nPress Enter to continue" }
            "7" { Start-TraceRoute; Read-Host "`nPress Enter to continue" }
            "8" { Test-DNSResolution; Read-Host "`nPress Enter to continue" }
            "9" { Clear-DNSCache; Read-Host "`nPress Enter to continue" }
            "10" { Reset-NetworkAdapters; Read-Host "`nPress Enter to continue" }
            "11" {
                Write-Host "Exiting..." -ForegroundColor Yellow
                Write-Log "Network Diagnostics script exited"
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
    Write-Error "Network diagnostics failed: $_"
    exit 1
}
