#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/mysql_maintenance.sh
# Description: This script performs comprehensive MySQL maintenance including backup,
#              log cleanup, optimization, and performance tuning.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Warning: Not running as root. Some operations may require elevated privileges."
fi

# Configuration
MYSQL_USER="root"
MYSQL_PASSWORD=""
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
BACKUP_DIR="/var/backups/mysql"
LOG_DIR="/var/log/mysql_maintenance"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7
SLOW_QUERY_LOG="/var/log/mysql/mysql-slow.log"
ERROR_LOG="/var/log/mysql/error.log"
BINARY_LOG_DIR="/var/lib/mysql"

# Create necessary directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"
MAINTENANCE_LOG="${LOG_DIR}/maintenance_${TIMESTAMP}.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAINTENANCE_LOG"
}

# Function to check MySQL connection
check_mysql_connection() {
    log_message "=== Checking MySQL Connection ==="
    
    if [ -z "$MYSQL_PASSWORD" ]; then
        read -s -p "Enter MySQL root password: " MYSQL_PASSWORD
        echo
    fi
    
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT 1;" &>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "MySQL connection successful."
        return 0
    else
        log_message "ERROR: Failed to connect to MySQL. Check credentials."
        return 1
    fi
}

# Function to backup all databases
backup_databases() {
    log_message "=== Starting Database Backup ==="
    
    BACKUP_SUBDIR="${BACKUP_DIR}/backup_${TIMESTAMP}"
    mkdir -p "$BACKUP_SUBDIR"
    
    # Get list of databases
    DATABASES=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
    
    for db in $DATABASES; do
        log_message "Backing up database: $db"
        mysqldump -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
            --single-transaction --routines --triggers --events \
            --opt --compress "$db" | gzip > "${BACKUP_SUBDIR}/${db}.sql.gz"
        
        if [ $? -eq 0 ]; then
            SIZE=$(du -h "${BACKUP_SUBDIR}/${db}.sql.gz" | cut -f1)
            log_message "Successfully backed up $db (Size: $SIZE)"
        else
            log_message "ERROR: Failed to backup $db"
        fi
    done
    
    # Full backup with all databases
    log_message "Creating full backup (all databases)..."
    mysqldump -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
        --all-databases --single-transaction --routines --triggers --events \
        --opt --compress | gzip > "${BACKUP_SUBDIR}/all_databases.sql.gz"
    
    log_message "Database backup completed."
}

# Function to optimize tables
optimize_tables() {
    log_message "=== Optimizing Tables ==="
    
    DATABASES=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
    
    for db in $DATABASES; do
        log_message "Optimizing database: $db"
        
        # Get tables in database
        TABLES=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D"$db" -e "SHOW TABLES;" 2>/dev/null | tail -n +2)
        
        for table in $TABLES; do
            log_message "  Optimizing table: $db.$table"
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D"$db" -e "OPTIMIZE TABLE \`$table\`;" &>/dev/null
            
            if [ $? -eq 0 ]; then
                log_message "    OK: $db.$table optimized"
            else
                log_message "    WARNING: Failed to optimize $db.$table"
            fi
        done
    done
    
    log_message "Table optimization completed."
}

# Function to analyze and repair tables
analyze_repair_tables() {
    log_message "=== Analyzing and Repairing Tables ==="
    
    DATABASES=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
    
    for db in $DATABASES; do
        log_message "Analyzing database: $db"
        
        TABLES=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D"$db" -e "SHOW TABLES;" 2>/dev/null | tail -n +2)
        
        for table in $TABLES; do
            # Analyze table
            mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D"$db" -e "ANALYZE TABLE \`$table\`;" &>/dev/null
            
            # Check table
            RESULT=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D"$db" -e "CHECK TABLE \`$table\`;" 2>/dev/null | grep -i "error\|corrupt")
            
            if [ ! -z "$RESULT" ]; then
                log_message "  WARNING: $db.$table needs repair"
                mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D"$db" -e "REPAIR TABLE \`$table\`;" &>/dev/null
                log_message "  Repair attempted on $db.$table"
            fi
        done
    done
    
    log_message "Table analysis and repair completed."
}

# Function to clean up binary logs
cleanup_binary_logs() {
    log_message "=== Cleaning Up Binary Logs ==="
    
    # Check if binary logging is enabled
    BINLOG_ENABLED=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW VARIABLES LIKE 'log_bin';" 2>/dev/null | grep ON)
    
    if [ -z "$BINLOG_ENABLED" ]; then
        log_message "Binary logging is not enabled. Skipping."
        return
    fi
    
    # Get current binary logs size
    BINLOG_SIZE=$(du -sh "$BINARY_LOG_DIR" 2>/dev/null | cut -f1)
    log_message "Current binary logs size: $BINLOG_SIZE"
    
    # Purge binary logs older than retention days
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL $RETENTION_DAYS DAY);" &>/dev/null
    
    if [ $? -eq 0 ]; then
        NEW_SIZE=$(du -sh "$BINARY_LOG_DIR" 2>/dev/null | cut -f1)
        log_message "Binary logs cleaned. New size: $NEW_SIZE"
    else
        log_message "WARNING: Failed to clean binary logs"
    fi
}

# Function to clean up slow query log
cleanup_slow_query_log() {
    log_message "=== Cleaning Up Slow Query Log ==="
    
    if [ -f "$SLOW_QUERY_LOG" ]; then
        SIZE=$(du -h "$SLOW_QUERY_LOG" | cut -f1)
        log_message "Slow query log size: $SIZE"
        
        # Archive and rotate
        if [ -s "$SLOW_QUERY_LOG" ]; then
            cp "$SLOW_QUERY_LOG" "${LOG_DIR}/slow_query_${TIMESTAMP}.log"
            > "$SLOW_QUERY_LOG"
            log_message "Slow query log archived and rotated."
        fi
    else
        log_message "Slow query log not found or disabled."
    fi
}

# Function to analyze slow queries
analyze_slow_queries() {
    log_message "=== Analyzing Slow Queries ==="
    
    if [ ! -f "$SLOW_QUERY_LOG" ] || [ ! -s "$SLOW_QUERY_LOG" ]; then
        log_message "No slow queries to analyze."
        return
    fi
    
    if command -v pt-query-digest &> /dev/null; then
        log_message "Running pt-query-digest on slow query log..."
        pt-query-digest "$SLOW_QUERY_LOG" > "${LOG_DIR}/slow_query_analysis_${TIMESTAMP}.txt"
        log_message "Slow query analysis saved to: ${LOG_DIR}/slow_query_analysis_${TIMESTAMP}.txt"
    elif command -v mysqldumpslow &> /dev/null; then
        log_message "Running mysqldumpslow on slow query log..."
        mysqldumpslow -s t -t 10 "$SLOW_QUERY_LOG" > "${LOG_DIR}/slow_query_summary_${TIMESTAMP}.txt"
        log_message "Top 10 slow queries saved to: ${LOG_DIR}/slow_query_summary_${TIMESTAMP}.txt"
    else
        log_message "No slow query analysis tools available (pt-query-digest or mysqldumpslow)."
    fi
}

# Function to update table statistics
update_statistics() {
    log_message "=== Updating Table Statistics ==="
    
    DATABASES=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
    
    for db in $DATABASES; do
        log_message "Updating statistics for database: $db"
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -D"$db" -e "ANALYZE TABLE;" &>/dev/null
    done
    
    log_message "Statistics update completed."
}

# Function to check and optimize InnoDB
optimize_innodb() {
    log_message "=== Optimizing InnoDB ==="
    
    # Check InnoDB buffer pool usage
    BUFFER_POOL=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" 2>/dev/null | tail -n 1 | awk '{print $2}')
    log_message "InnoDB buffer pool size: $(numfmt --to=iec $BUFFER_POOL 2>/dev/null || echo $BUFFER_POOL)"
    
    # Flush InnoDB logs
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SET GLOBAL innodb_fast_shutdown=0;" &>/dev/null
    
    log_message "InnoDB optimization completed."
}

# Function to check for fragmented tables
check_fragmentation() {
    log_message "=== Checking Table Fragmentation ==="
    
    FRAGMENTED=$(mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
        SELECT TABLE_SCHEMA, TABLE_NAME, 
               ROUND(DATA_FREE/1024/1024, 2) AS DATA_FREE_MB
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
        AND DATA_FREE > 0
        ORDER BY DATA_FREE DESC
        LIMIT 10;
    " 2>/dev/null)
    
    if [ ! -z "$FRAGMENTED" ]; then
        log_message "Top 10 fragmented tables:"
        echo "$FRAGMENTED" | tee -a "$MAINTENANCE_LOG"
    else
        log_message "No significant fragmentation detected."
    fi
}

# Function to clean old backups
clean_old_backups() {
    log_message "=== Cleaning Old Backups ==="
    
    find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
    find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null
    
    log_message "Old backups (>${RETENTION_DAYS} days) removed."
}

# Function to generate performance report
generate_performance_report() {
    log_message "=== Generating Performance Report ==="
    
    REPORT_FILE="${LOG_DIR}/performance_report_${TIMESTAMP}.txt"
    
    {
        echo "========================================="
        echo "MySQL Performance Report"
        echo "Generated: $(date)"
        echo "========================================="
        echo ""
        
        echo "=== Server Status ==="
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW STATUS WHERE Variable_name IN ('Uptime', 'Threads_connected', 'Threads_running', 'Questions', 'Slow_queries', 'Com_select', 'Com_insert', 'Com_update', 'Com_delete');" 2>/dev/null
        echo ""
        
        echo "=== Database Sizes ==="
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
            SELECT TABLE_SCHEMA, 
                   ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS SIZE_MB
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
            GROUP BY TABLE_SCHEMA
            ORDER BY SIZE_MB DESC;
        " 2>/dev/null
        echo ""
        
        echo "=== Largest Tables ==="
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
            SELECT TABLE_SCHEMA, TABLE_NAME,
                   ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS SIZE_MB
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
            ORDER BY SIZE_MB DESC
            LIMIT 10;
        " 2>/dev/null
        echo ""
        
        echo "=== InnoDB Status ==="
        mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW ENGINE INNODB STATUS\G" 2>/dev/null | grep -A 20 "BUFFER POOL AND MEMORY"
        
    } > "$REPORT_FILE"
    
    log_message "Performance report saved to: $REPORT_FILE"
}

# Function to display summary
display_summary() {
    log_message ""
    log_message "========================================="
    log_message "MySQL Maintenance Summary"
    log_message "========================================="
    log_message "Start Time: $(head -n 1 "$MAINTENANCE_LOG" | awk '{print $1, $2}')"
    log_message "End Time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_message "Backup Location: $BACKUP_DIR"
    log_message "Log Location: $MAINTENANCE_LOG"
    log_message "========================================="
}

# Main execution
log_message "Starting MySQL maintenance..."

if ! check_mysql_connection; then
    log_message "Exiting due to connection failure."
    exit 1
fi

backup_databases
optimize_tables
analyze_repair_tables
cleanup_binary_logs
cleanup_slow_query_log
analyze_slow_queries
update_statistics
optimize_innodb
check_fragmentation
clean_old_backups
generate_performance_report
display_summary

log_message "MySQL maintenance completed successfully."
echo ""
echo "Maintenance log: $MAINTENANCE_LOG"
