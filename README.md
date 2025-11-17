# Automation Scripts

A comprehensive collection of automation scripts for system administration, maintenance, and operations across multiple platforms.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-lightgrey.svg)]()
[![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20PowerShell-green.svg)]()

## 📋 Overview

This repository contains production-ready automation scripts designed to streamline system administration tasks, improve operational efficiency, and maintain system health across Linux and Windows environments. All scripts follow consistent coding standards with comprehensive documentation and error handling.

## 🚀 Features

-   **Cross-Platform Support**: Scripts for both Linux (Bash) and Windows (PowerShell)
-   **Security Hardening**: Automated security configurations based on industry best practices (MITRE ATT&CK)
-   **Database Management**: Backup, maintenance, and optimization for MySQL, PostgreSQL, MongoDB, Oracle, MS SQL Server, Redis, and Cassandra
-   **System Monitoring**: Real-time monitoring of resources, services, security logs, and disk space
-   **Network Operations**: Firewall configuration, SSL certificate generation, and network diagnostics
-   **User Management**: Comprehensive user and group administration tools
-   **Backup Solutions**: Automated backup systems with compression and retention policies
-   **Performance Tuning**: Database optimization, system cleanup, and health checks

## 📁 Repository Structure

```
automation-scripts/
├── src/
│   ├── linux/           # Bash scripts for Linux systems
│   │   ├── get_distro_information.sh
│   │   ├── get_hostname.sh
│   │   ├── get_network_info.sh
│   │   ├── get_system_resources.sh
│   │   ├── get_top_processes.sh
│   │   ├── debian_hardening.sh
│   │   ├── red_hat_hardening.sh
│   │   ├── backup_system.sh
│   │   ├── cleanup_system.sh
│   │   ├── configure_firewall.sh
│   │   ├── database_backup.sh
│   │   ├── generate_ssl_certificate.sh
│   │   ├── manage_users.sh
│   │   ├── monitor_disk_space.sh
│   │   ├── monitor_security_logs.sh
│   │   ├── monitor_services.sh
│   │   ├── mysql_maintenance.sh
│   │   ├── postgresql_maintenance.sh
│   │   ├── setup_docker.sh
│   │   ├── setup_lamp_stack.sh
│   │   └── system_health_check.sh
│   └── windows/         # PowerShell scripts for Windows systems
│       ├── Get-SystemInformation.ps1
│       ├── Get-SystemResources.ps1
│       ├── Get-NetworkDiagnostics.ps1
│       ├── Test-SystemHealth.ps1
│       ├── Set-WindowsHardening.ps1
│       ├── Set-FirewallRules.ps1
│       ├── Backup-System.ps1
│       ├── Backup-Database.ps1
│       ├── Optimize-System.ps1
│       ├── Manage-LocalUsers.ps1
│       ├── Watch-ServiceMonitor.ps1
│       └── Watch-SecurityLogs.ps1
├── workspace/
│   └── automation-scripts.code-workspace
└── README.md
```

## 🐧 Linux Scripts

### System Information & Monitoring

| Script                      | Description                                            |
| --------------------------- | ------------------------------------------------------ |
| `get_distro_information.sh` | Retrieves Linux distribution details                   |
| `get_hostname.sh`           | Displays system hostname                               |
| `get_network_info.sh`       | Shows network interface configuration and connectivity |
| `get_system_resources.sh`   | Monitors CPU, memory, and disk usage                   |
| `get_top_processes.sh`      | Lists top processes by CPU and memory consumption      |
| `monitor_disk_space.sh`     | Monitors disk usage with threshold alerts              |
| `monitor_services.sh`       | Monitors critical services and auto-restarts if down   |
| `monitor_security_logs.sh`  | Analyzes security logs for suspicious activities       |
| `system_health_check.sh`    | Comprehensive system health assessment with reporting  |

### Security & Hardening

| Script                        | Description                                                     |
| ----------------------------- | --------------------------------------------------------------- |
| `debian_hardening.sh`         | Security hardening for Debian-based systems (Ubuntu, Debian)    |
| `red_hat_hardening.sh`        | Security hardening for RHEL-based systems (CentOS, Rocky, Alma) |
| `configure_firewall.sh`       | Interactive firewall configuration (UFW/firewalld/iptables)     |
| `generate_ssl_certificate.sh` | Generates self-signed SSL certificates for Apache/Nginx         |

#### Hardening Features:

-   Automatic security updates
-   SSH hardening with random port assignment
-   Kernel parameter tuning
-   Audit logging configuration
-   Firewall setup (UFW/firewalld)
-   Fail2Ban integration
-   File permission hardening
-   Password policy enforcement
-   SELinux/AppArmor configuration
-   Service disabling (unnecessary/insecure)

### Database Operations

| Script                      | Description                                                                                   |
| --------------------------- | --------------------------------------------------------------------------------------------- |
| `database_backup.sh`        | Multi-database backup solution (MySQL, PostgreSQL, MongoDB, Oracle, MS SQL, Redis, Cassandra) |
| `mysql_maintenance.sh`      | Comprehensive MySQL maintenance and optimization                                              |
| `postgresql_maintenance.sh` | Comprehensive PostgreSQL maintenance and optimization                                         |

#### Database Maintenance Features:

-   Automated backups with compression
-   Table optimization and defragmentation
-   Index analysis and rebuilding
-   Query performance analysis
-   Log rotation and cleanup
-   WAL/Binary log management
-   Statistics updates
-   Bloat detection
-   Performance reporting

### System Maintenance

| Script              | Description                                                         |
| ------------------- | ------------------------------------------------------------------- |
| `backup_system.sh`  | System-wide backup (configs, packages, cron jobs, home directories) |
| `cleanup_system.sh` | System cleanup (cache, logs, temp files, old kernels)               |
| `manage_users.sh`   | Interactive user management tool                                    |

### Infrastructure Setup

| Script                | Description                                               |
| --------------------- | --------------------------------------------------------- |
| `setup_lamp_stack.sh` | Automated LAMP stack installation (Apache, MySQL, PHP)    |
| `setup_docker.sh`     | Docker and Docker Compose installation with configuration |

## 🪟 Windows Scripts

### System Information & Monitoring

| Script                       | Description                                                   |
| ---------------------------- | ------------------------------------------------------------- |
| `Get-SystemInformation.ps1`  | Retrieves comprehensive Windows system information            |
| `Get-SystemResources.ps1`    | Monitors CPU, memory, disk, and network usage with thresholds |
| `Test-SystemHealth.ps1`      | Comprehensive system health check with detailed reporting     |
| `Watch-ServiceMonitor.ps1`   | Monitors critical services and auto-restarts if stopped       |
| `Watch-SecurityLogs.ps1`     | Monitors security logs for suspicious activities and threats  |
| `Get-NetworkDiagnostics.ps1` | Comprehensive network diagnostics and troubleshooting         |

### Security & Administration

| Script                     | Description                                                           |
| -------------------------- | --------------------------------------------------------------------- |
| `Set-WindowsHardening.ps1` | Security hardening based on best practices (UAC, Firewall, Defender)  |
| `Set-FirewallRules.ps1`    | Interactive Windows Firewall management with rule creation/management |
| `Manage-LocalUsers.ps1`    | Comprehensive local user and group management                         |

#### Windows Hardening Features:

-   Windows Firewall configuration (all profiles)
-   Windows Defender configuration
-   SMBv1 protocol disabling
-   UAC (User Account Control) configuration
-   PowerShell v2 disabling
-   Automatic updates enabling
-   Password policy enforcement
-   Audit policy configuration
-   Guest account disabling
-   RDP security configuration
-   AutoRun disabling
-   Event log size configuration
-   Unnecessary service disabling

### System Maintenance & Optimization

| Script                | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| `Backup-System.ps1`   | Comprehensive system backup (registry, tasks, logs, configurations)    |
| `Optimize-System.ps1` | System optimization and cleanup (temp files, cache, disk optimization) |
| `Backup-Database.ps1` | Multi-database backup (SQL Server, MySQL, PostgreSQL, MongoDB)         |

#### Backup Features:

-   System information backup
-   Installed programs list
-   Windows features
-   Scheduled tasks
-   Network configuration
-   Registry keys (selective)
-   Event logs (Application, System, Security)
-   User profile listings
-   Compression and retention management

#### Database Support:

-   SQL Server (native backup)
-   MySQL (mysqldump)
-   PostgreSQL (pg_dump)
-   MongoDB (mongodump)
-   Automated compression
-   Retention policy management

## 🔧 Installation

### Prerequisites

**For Linux:**

-   Bash shell (version 4.0+)
-   Root/sudo access for system-level operations
-   Required packages vary by script (scripts will check and notify)

**For Windows:**

-   PowerShell 5.1 or later
-   Administrator privileges for system-level operations

### Quick Start

1. Clone the repository:

```bash
git clone https://github.com/mgnischor/automation-scripts.git
cd automation-scripts
```

2. For Linux - Make scripts executable:

```bash
chmod +x src/linux/*.sh
```

3. Run a Linux script:

```bash
sudo ./src/linux/system_health_check.sh
```

4. For Windows - Run PowerShell as Administrator and execute:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\src\windows\Test-SystemHealth.ps1
```

## 📖 Usage Examples

### Linux Examples

#### System Health Check

```bash
sudo ./src/linux/system_health_check.sh
```

#### Security Hardening (Debian/Ubuntu)

```bash
sudo ./src/linux/debian_hardening.sh
```

#### Database Backup (All Databases)

```bash
sudo ./src/linux/database_backup.sh all
```

#### MySQL Maintenance

```bash
sudo ./src/linux/mysql_maintenance.sh
```

#### Interactive User Management

```bash
sudo ./src/linux/manage_users.sh
```

#### Monitor Disk Space

```bash
sudo ./src/linux/monitor_disk_space.sh
```

### Windows Examples

#### System Health Check

```powershell
.\src\windows\Test-SystemHealth.ps1
```

#### Windows Security Hardening

```powershell
.\src\windows\Set-WindowsHardening.ps1
```

#### Database Backup

```powershell
.\src\windows\Backup-Database.ps1
```

#### Service Monitoring

```powershell
.\src\windows\Watch-ServiceMonitor.ps1
```

#### User Management

```powershell
.\src\windows\Manage-LocalUsers.ps1
```

#### Network Diagnostics

```powershell
.\src\windows\Get-NetworkDiagnostics.ps1
```

## ⚙️ Configuration

Most scripts include configurable variables at the top of the file:

```bash
# Example configuration section
BACKUP_DIR="/var/backups"
RETENTION_DAYS=7
EMAIL="admin@example.com"
THRESHOLD=80
```

Edit these variables according to your environment before running the scripts.

## 🔒 Security Considerations

-   **Credentials**: Scripts prompt for passwords when needed. Never hardcode sensitive information.
-   **Permissions**: Scripts check for root/sudo access and will warn if insufficient privileges.
-   **Logging**: All operations are logged with timestamps for audit purposes.
-   **Backups**: Always create backups before making system changes.
-   **Testing**: Test scripts in a non-production environment first.

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Follow the existing code style and documentation standards
4. Add appropriate comments and logging
5. Test thoroughly
6. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
7. Push to the branch (`git push origin feature/AmazingFeature`)
8. Open a Pull Request

### Coding Standards

-   Use consistent indentation (4 spaces)
-   Include header comments with file information
-   Add function documentation
-   Implement error handling
-   Provide meaningful log messages
-   Follow the existing naming conventions

## 📝 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Miguel Nischor**

-   Email: miguel@datatower.tech
-   GitHub: [@mgnischor](https://github.com/mgnischor)

## 🙏 Acknowledgments

-   Security hardening based on MITRE ATT&CK framework
-   Best practices from industry-standard security benchmarks (CIS, NIST)
-   Community feedback and contributions

## 📊 Project Status

**Current Version**: 1.0.0  
**Status**: Active Development

### Roadmap

-   [x] Linux system administration scripts
-   [x] Database backup and maintenance
-   [x] Security hardening automation
-   [x] System monitoring and health checks
-   [x] Windows PowerShell scripts
-   [ ] Advanced database maintenance for Windows (Oracle, Redis, Cassandra)
-   [ ] Kubernetes/Docker orchestration scripts
-   [ ] Cloud provider integration (AWS, Azure, GCP)
-   [ ] Ansible playbook alternatives
-   [ ] Web-based dashboard for monitoring
-   [ ] Automated testing and CI/CD integration

## 🐛 Bug Reports & Feature Requests

Please use the [GitHub Issues](https://github.com/mgnischor/automation-scripts/issues) page to report bugs or request features.

## 📞 Support

For questions or support, please open an issue or contact the author directly.

---

**⚠️ Disclaimer**: These scripts are provided as-is without warranty. Always test in a non-production environment before deploying to production systems. The author is not responsible for any damage or data loss resulting from the use of these scripts.
