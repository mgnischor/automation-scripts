# Contributing to Automation Scripts

First off, thank you for considering contributing to Automation Scripts! It's people like you that make this project such a great tool for system administrators and DevOps engineers.

## Table of Contents

-   [Code of Conduct](#code-of-conduct)
-   [How Can I Contribute?](#how-can-i-contribute)
    -   [Reporting Bugs](#reporting-bugs)
    -   [Suggesting Enhancements](#suggesting-enhancements)
    -   [Your First Code Contribution](#your-first-code-contribution)
    -   [Pull Requests](#pull-requests)
-   [Style Guides](#style-guides)
    -   [Git Commit Messages](#git-commit-messages)
    -   [Bash Script Style Guide](#bash-script-style-guide)
    -   [PowerShell Script Style Guide](#powershell-script-style-guide)
    -   [Documentation Style Guide](#documentation-style-guide)
-   [Project Structure](#project-structure)
-   [Testing Guidelines](#testing-guidelines)
-   [Additional Notes](#additional-notes)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to miguel@datatower.tech.

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report. Following these guidelines helps maintainers and the community understand your report, reproduce the behavior, and find related reports.

**Before Submitting A Bug Report:**

-   Check the documentation for a list of common questions and problems
-   Perform a cursory search to see if the problem has already been reported
-   If you find a closed issue that seems like it is the same thing that you're experiencing, open a new issue and include a link to the original issue

**How Do I Submit A Good Bug Report?**

Bugs are tracked as [GitHub issues](https://github.com/mgnischor/automation-scripts/issues). Create an issue and provide the following information:

-   **Use a clear and descriptive title** for the issue to identify the problem
-   **Describe the exact steps to reproduce the problem** in as much detail as possible
-   **Provide specific examples** to demonstrate the steps
-   **Describe the behavior you observed** after following the steps
-   **Explain which behavior you expected to see instead and why**
-   **Include screenshots or logs** if possible
-   **Include your environment details:**
    -   OS version (Linux distribution or Windows version)
    -   Shell version (Bash version or PowerShell version)
    -   Script version or commit hash
    -   Any relevant system configuration

**Template for Bug Reports:**

```markdown
## Bug Description

A clear and concise description of what the bug is.

## Steps to Reproduce

1. Go to '...'
2. Run command '...'
3. See error

## Expected Behavior

A clear description of what you expected to happen.

## Actual Behavior

What actually happened.

## Environment

-   OS: [e.g., Ubuntu 22.04, Windows Server 2022]
-   Shell: [e.g., Bash 5.1, PowerShell 7.3]
-   Script: [e.g., debian_hardening.sh]
-   Version: [e.g., commit hash or tag]

## Logs
```

Paste relevant logs here

```

## Additional Context
Add any other context about the problem here.
```

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion, including completely new features and minor improvements to existing functionality.

**Before Submitting An Enhancement Suggestion:**

-   Check if there's already a script that provides that functionality
-   Check the [roadmap in README.md](README.md#roadmap) to see if it's already planned
-   Perform a cursory search to see if the enhancement has already been suggested

**How Do I Submit A Good Enhancement Suggestion?**

Enhancement suggestions are tracked as [GitHub issues](https://github.com/mgnischor/automation-scripts/issues). Create an issue and provide the following information:

-   **Use a clear and descriptive title** for the issue
-   **Provide a step-by-step description** of the suggested enhancement
-   **Provide specific examples** to demonstrate the steps
-   **Describe the current behavior** and explain which behavior you expected to see instead
-   **Explain why this enhancement would be useful** to most users
-   **List some other projects** where this enhancement exists, if applicable

**Template for Enhancement Suggestions:**

```markdown
## Enhancement Description

A clear and concise description of what you want to happen.

## Motivation

Why is this enhancement needed? What problem does it solve?

## Proposed Solution

Describe the solution you'd like.

## Alternatives Considered

Describe alternatives you've considered.

## Additional Context

Add any other context or screenshots about the enhancement here.
```

### Your First Code Contribution

Unsure where to begin contributing? You can start by looking through these `beginner` and `help-wanted` issues:

-   **Beginner issues** - issues which should only require a few lines of code
-   **Help wanted issues** - issues which should be a bit more involved than beginner issues

### Pull Requests

The process described here has several goals:

-   Maintain the project's quality
-   Fix problems that are important to users
-   Engage the community in working toward the best possible automation scripts
-   Enable a sustainable system for maintainers to review contributions

**Please follow these steps:**

1. **Fork the repository** and create your branch from `main`
2. **Follow the style guides** described below
3. **Test your changes** thoroughly
4. **Update documentation** if you're changing functionality
5. **Write clear commit messages** following our commit message conventions
6. **Submit your pull request** with a clear description

**Pull Request Template:**

```markdown
## Description

A clear description of what this PR does.

## Type of Change

-   [ ] Bug fix (non-breaking change which fixes an issue)
-   [ ] New feature (non-breaking change which adds functionality)
-   [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
-   [ ] Documentation update
-   [ ] Code refactoring
-   [ ] Performance improvement
-   [ ] Security enhancement

## Related Issue

Fixes #(issue number)

## Changes Made

-   Change 1
-   Change 2
-   Change 3

## Testing

Describe the tests you ran to verify your changes:

-   [ ] Tested on Ubuntu 22.04
-   [ ] Tested on Debian 12
-   [ ] Tested on RHEL 9
-   [ ] Tested on Windows Server 2022
-   [ ] Tested on Windows 11

## Checklist

-   [ ] My code follows the style guidelines of this project
-   [ ] I have performed a self-review of my own code
-   [ ] I have commented my code, particularly in hard-to-understand areas
-   [ ] I have made corresponding changes to the documentation
-   [ ] My changes generate no new warnings or errors
-   [ ] I have added tests that prove my fix is effective or that my feature works
-   [ ] New and existing unit tests pass locally with my changes
-   [ ] Any dependent changes have been merged and published

## Screenshots (if applicable)

Add screenshots to help explain your changes.

## Additional Notes

Any additional information that reviewers should know.
```

## Style Guides

### Git Commit Messages

-   Use the present tense ("Add feature" not "Added feature")
-   Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
-   Limit the first line to 72 characters or less
-   Reference issues and pull requests liberally after the first line
-   Consider starting the commit message with an applicable emoji:
    -   🎨 `:art:` when improving the format/structure of the code
    -   🐛 `:bug:` when fixing a bug
    -   🔥 `:fire:` when removing code or files
    -   📝 `:memo:` when writing docs
    -   🚀 `:rocket:` when improving performance
    -   🔒 `:lock:` when dealing with security
    -   ⬆️ `:arrow_up:` when upgrading dependencies
    -   ⬇️ `:arrow_down:` when downgrading dependencies
    -   ✅ `:white_check_mark:` when adding tests

**Example:**

```
:bug: Fix disk space calculation in monitor_disk_space.sh

- Corrected df command parsing
- Added handling for mounted network drives
- Updated threshold calculation logic

Fixes #123
```

### Bash Script Style Guide

All Bash scripts must follow these conventions:

#### File Header

Every script must start with this header:

```bash
#--------------------------------------------------------------------------------------------------
# File: /path/to/script.sh
# Description: Brief description of what the script does
# Author: Your Name <your.email@example.com>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------
```

#### Shebang and Options

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined variables, and pipe failures
```

#### Variables

-   Use UPPERCASE for constants and exported variables
-   Use lowercase for local variables
-   Use descriptive names
-   Quote all variable expansions

```bash
# Constants
readonly BACKUP_DIR="/var/backups"
readonly MAX_RETRIES=3

# Local variables
local current_date=$(date +%Y%m%d)
local file_count=0
```

#### Functions

-   Use lowercase with underscores for function names
-   Add function documentation
-   Check function parameters

```bash
# Function: backup_database
# Description: Creates a backup of the specified database
# Parameters:
#   $1 - Database name
#   $2 - Backup directory (optional)
# Returns: 0 on success, 1 on failure
backup_database() {
    local db_name="$1"
    local backup_dir="${2:-$DEFAULT_BACKUP_DIR}"

    if [[ -z "$db_name" ]]; then
        log_error "Database name is required"
        return 1
    fi

    # Function implementation
}
```

#### Error Handling

-   Always check return codes
-   Use meaningful error messages
-   Log errors appropriately

```bash
if ! command -v mysql &> /dev/null; then
    log_error "MySQL client is not installed"
    exit 1
fi

if ! mkdir -p "$BACKUP_DIR"; then
    log_error "Failed to create backup directory: $BACKUP_DIR"
    exit 1
fi
```

#### Logging

Use consistent logging functions:

```bash
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" | tee -a "$LOG_FILE"
}
```

#### Indentation and Formatting

-   Use 4 spaces for indentation (no tabs)
-   Keep lines under 100 characters when possible
-   Use blank lines to separate logical sections
-   Align similar elements for readability

```bash
if [[ $condition ]]; then
    do_something
    do_another_thing
else
    do_alternative
fi
```

### PowerShell Script Style Guide

All PowerShell scripts must follow these conventions:

#### File Header

```powershell
#--------------------------------------------------------------------------------------------------
# File: /path/to/Script.ps1
# Description: Brief description of what the script does
# Author: Your Name <your.email@example.com>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------
```

#### Script Requirements

```powershell
#Requires -RunAsAdministrator
#Requires -Version 5.1
```

#### Variables

-   Use PascalCase for variable names
-   Use descriptive names
-   Declare types when appropriate

```powershell
$BackupDirectory = "C:\Backups"
$MaxRetries = 3
[int]$FileCount = 0
```

#### Functions

-   Use PascalCase with Verb-Noun format
-   Include proper parameter declarations
-   Add comment-based help

```powershell
<#
.SYNOPSIS
    Creates a backup of the specified database.

.DESCRIPTION
    This function creates a full backup of the specified database
    and saves it to the backup directory with compression.

.PARAMETER DatabaseName
    The name of the database to backup.

.PARAMETER BackupDirectory
    The directory where the backup will be saved. Defaults to C:\Backups.

.EXAMPLE
    Backup-Database -DatabaseName "MyDB" -BackupDirectory "C:\DBBackups"

.OUTPUTS
    Returns $true if successful, $false otherwise.
#>
function Backup-Database {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,

        [Parameter(Mandatory = $false)]
        [string]$BackupDirectory = "C:\Backups"
    )

    # Function implementation
}
```

#### Error Handling

```powershell
try {
    $result = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Log "Service found: $($result.DisplayName)" "SUCCESS"
}
catch {
    Write-Log "Error getting service: $_" "ERROR"
    return $false
}
```

#### Logging

```powershell
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }

    Add-Content -Path $LogFile -Value $logMessage
}
```

#### Indentation and Formatting

-   Use 4 spaces for indentation
-   Place opening braces on the same line
-   Keep lines under 120 characters
-   Use blank lines to separate logical sections

```powershell
if ($condition) {
    Do-Something
    Do-AnotherThing
}
else {
    Do-Alternative
}
```

### Documentation Style Guide

#### README Updates

-   Use clear, concise language
-   Include code examples
-   Keep formatting consistent
-   Update the table of contents if adding sections

#### Inline Comments

-   Write comments that explain "why", not "what"
-   Keep comments up to date with code changes
-   Use TODO comments for temporary code

```bash
# TODO: Implement retry logic for failed backups
# FIXME: Handle edge case when disk is full
# NOTE: This section requires root privileges
```

#### Script Documentation

Every script should have:

1. **Header**: Author, description, license
2. **Prerequisites**: Required packages, permissions
3. **Configuration**: Configurable variables at the top
4. **Function documentation**: Purpose, parameters, return values
5. **Usage examples**: In comments or separate documentation

## Project Structure

```
automation-scripts/
├── src/
│   ├── linux/              # Linux bash scripts
│   │   ├── *.sh           # Individual scripts
│   │   └── common/        # Shared functions (future)
│   └── windows/           # Windows PowerShell scripts
│       ├── *.ps1          # Individual scripts
│       └── modules/       # Shared modules (future)
├── tests/                 # Test scripts (future)
│   ├── linux/
│   └── windows/
├── docs/                  # Additional documentation (future)
├── workspace/
│   └── automation-scripts.code-workspace
├── README.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── LICENSE
```

## Testing Guidelines

### Before Submitting

1. **Test in Multiple Environments**

    - Test on at least one target OS (Linux distribution or Windows version)
    - Test with different configurations
    - Test error conditions

2. **Check for Common Issues**

    - Verify proper error handling
    - Check for resource leaks
    - Ensure proper cleanup on failure
    - Test with edge cases

3. **Security Considerations**

    - Never hardcode credentials
    - Validate all user inputs
    - Use secure temporary files
    - Follow principle of least privilege
    - Check file permissions

4. **Performance Testing**
    - Test with large datasets
    - Monitor resource usage
    - Check for potential bottlenecks

### Test Script Template (Bash)

```bash
#!/bin/bash
# Test script for: script_name.sh

set -euo pipefail

test_basic_functionality() {
    echo "Testing basic functionality..."
    ./script_name.sh --option value
    echo "✓ Basic functionality test passed"
}

test_error_handling() {
    echo "Testing error handling..."
    if ./script_name.sh --invalid-option 2>/dev/null; then
        echo "✗ Error handling test failed"
        return 1
    fi
    echo "✓ Error handling test passed"
}

# Run tests
test_basic_functionality
test_error_handling

echo "All tests passed!"
```

### Test Script Template (PowerShell)

```powershell
# Test script for: Script-Name.ps1

Describe "Script-Name Tests" {
    It "Should execute basic functionality" {
        $result = .\Script-Name.ps1 -Parameter Value
        $result | Should -Not -BeNullOrEmpty
    }

    It "Should handle errors gracefully" {
        { .\Script-Name.ps1 -InvalidParameter } | Should -Throw
    }
}
```

## Additional Notes

### Issue and Pull Request Labels

-   `bug` - Something isn't working
-   `documentation` - Improvements or additions to documentation
-   `duplicate` - This issue or pull request already exists
-   `enhancement` - New feature or request
-   `good first issue` - Good for newcomers
-   `help wanted` - Extra attention is needed
-   `invalid` - This doesn't seem right
-   `question` - Further information is requested
-   `security` - Security-related issues
-   `wontfix` - This will not be worked on
-   `linux` - Linux-specific issues
-   `windows` - Windows-specific issues
-   `database` - Database-related issues

### Review Process

1. All pull requests require at least one approval
2. CI/CD checks must pass (when implemented)
3. Documentation must be updated
4. Code must follow style guides
5. Tests must be included for new features

### Release Process

1. Version numbers follow [Semantic Versioning](https://semver.org/)
2. Maintain a CHANGELOG.md
3. Tag releases in git
4. Create release notes

### Getting Help

If you need help with your contribution:

-   Check existing documentation
-   Search closed issues
-   Ask in a new issue with the `question` label
-   Contact the maintainer at miguel@datatower.tech

### Recognition

Contributors will be recognized in:

-   The project README
-   Release notes
-   A CONTRIBUTORS.md file (future)

Thank you for contributing to Automation Scripts! Your efforts help make system administration easier for everyone. 🚀
