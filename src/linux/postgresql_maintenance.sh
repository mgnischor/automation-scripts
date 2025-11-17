#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/postgresql_maintenance.sh
# Description: This script performs comprehensive PostgreSQL maintenance including backup, log cleanup, optimization, and performance tuning.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Warning: Not running as root. Some operations may require elevated privileges."
fi

# Configuration
POSTGRES_USER="postgres"
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
BACKUP_DIR="/var/backups/postgresql"
LOG_DIR="/var/log/postgresql_maintenance"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7
PG_DATA_DIR="/var/lib/postgresql/data"
PG_LOG_DIR="/var/log/postgresql"

# Create necessary directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"
MAINTENANCE_LOG="${LOG_DIR}/maintenance_${TIMESTAMP}.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAINTENANCE_LOG"
}

# Function to check PostgreSQL connection
check_postgres_connection() {
    log_message "=== Checking PostgreSQL Connection ==="
    
    sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -c "SELECT 1;" &>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "PostgreSQL connection successful."
        return 0
    else
        log_message "ERROR: Failed to connect to PostgreSQL."
        return 1
    fi
}

# Function to backup all databases
backup_databases() {
    log_message "=== Starting Database Backup ==="
    
    BACKUP_SUBDIR="${BACKUP_DIR}/backup_${TIMESTAMP}"
    mkdir -p "$BACKUP_SUBDIR"
    
    # Get list of databases
    DATABASES=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" 2>/dev/null)
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)
        log_message "Backing up database: $db"
        
        sudo -u "$POSTGRES_USER" pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
            -Fc -b -v "$db" 2>/dev/null | gzip > "${BACKUP_SUBDIR}/${db}.dump.gz"
        
        if [ $? -eq 0 ]; then
            SIZE=$(du -h "${BACKUP_SUBDIR}/${db}.dump.gz" | cut -f1)
            log_message "Successfully backed up $db (Size: $SIZE)"
        else
            log_message "ERROR: Failed to backup $db"
        fi
    done
    
    # Full cluster backup
    log_message "Creating full cluster backup..."
    sudo -u "$POSTGRES_USER" pg_dumpall -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
        --clean --if-exists | gzip > "${BACKUP_SUBDIR}/cluster_backup.sql.gz"
    
    if [ $? -eq 0 ]; then
        SIZE=$(du -h "${BACKUP_SUBDIR}/cluster_backup.sql.gz" | cut -f1)
        log_message "Full cluster backup completed (Size: $SIZE)"
    fi
    
    log_message "Database backup completed."
}

# Function to vacuum databases
vacuum_databases() {
    log_message "=== Vacuuming Databases ==="
    
    DATABASES=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)
        log_message "Vacuuming database: $db"
        
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -d "$db" -c "VACUUM VERBOSE;" &>/dev/null
        
        if [ $? -eq 0 ]; then
            log_message "  Successfully vacuumed: $db"
        else
            log_message "  WARNING: Failed to vacuum $db"
        fi
    done
    
    log_message "Vacuum completed."
}

# Function to analyze databases
analyze_databases() {
    log_message "=== Analyzing Databases ==="
    
    DATABASES=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)
        log_message "Analyzing database: $db"
        
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -d "$db" -c "ANALYZE VERBOSE;" &>/dev/null
        
        if [ $? -eq 0 ]; then
            log_message "  Successfully analyzed: $db"
        else
            log_message "  WARNING: Failed to analyze $db"
        fi
    done
    
    log_message "Analysis completed."
}

# Function to reindex databases
reindex_databases() {
    log_message "=== Reindexing Databases ==="
    
    DATABASES=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)
        log_message "Reindexing database: $db"
        
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -d "$db" -c "REINDEX DATABASE \"$db\";" &>/dev/null
        
        if [ $? -eq 0 ]; then
            log_message "  Successfully reindexed: $db"
        else
            log_message "  WARNING: Failed to reindex $db"
        fi
    done
    
    log_message "Reindexing completed."
}

# Function to check for bloated tables
check_bloat() {
    log_message "=== Checking Table Bloat ==="
    
    BLOAT_QUERY="
    SELECT schemaname, tablename,
           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
           ROUND((CASE WHEN otta=0 THEN 0.0 ELSE sml.relpages::float/otta END)::numeric,1) AS bloat_ratio
    FROM (
        SELECT schemaname, tablename, cc.relpages, bs,
               CEIL((cc.reltuples*((datahdr+ma-(CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS otta
        FROM (
            SELECT ma,bs,schemaname,tablename,(datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
                   (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
            FROM (
                SELECT schemaname, tablename, hdr, ma, bs,
                       SUM((1-null_frac)*avg_width) AS datawidth,
                       MAX(null_frac) AS maxfracsum,
                       hdr+(SELECT 1+count(*)/8 FROM pg_stats s2 WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename) AS nullhdr
                FROM pg_stats s, (SELECT 23 AS hdr, 8 AS ma, 8192 AS bs) AS constants
                GROUP BY 1,2,3,4,5
            ) AS foo
        ) AS rs
        JOIN pg_class cc ON cc.relname = rs.tablename
        JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
    ) AS sml
    WHERE sml.relpages > 10
    ORDER BY bloat_ratio DESC
    LIMIT 10;
    "
    
    RESULT=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "$BLOAT_QUERY" 2>/dev/null)
    
    if [ ! -z "$RESULT" ]; then
        log_message "Top 10 bloated tables:"
        echo "$RESULT" | tee -a "$MAINTENANCE_LOG"
    else
        log_message "No significant bloat detected."
    fi
}

# Function to cleanup WAL archives
cleanup_wal_archives() {
    log_message "=== Cleaning Up WAL Archives ==="
    
    WAL_ARCHIVE_DIR=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SHOW archive_command;" 2>/dev/null | grep -oP "(?<=/)[^ ]+(?=/)")
    
    if [ -z "$WAL_ARCHIVE_DIR" ]; then
        log_message "WAL archiving not configured or not found."
        return
    fi
    
    if [ -d "$WAL_ARCHIVE_DIR" ]; then
        SIZE_BEFORE=$(du -sh "$WAL_ARCHIVE_DIR" 2>/dev/null | cut -f1)
        log_message "WAL archive size before cleanup: $SIZE_BEFORE"
        
        # Remove WAL files older than retention days
        find "$WAL_ARCHIVE_DIR" -name "*.backup" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
        find "$WAL_ARCHIVE_DIR" -name "*[0-9A-F]*" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
        
        SIZE_AFTER=$(du -sh "$WAL_ARCHIVE_DIR" 2>/dev/null | cut -f1)
        log_message "WAL archive size after cleanup: $SIZE_AFTER"
    fi
}

# Function to cleanup old log files
cleanup_log_files() {
    log_message "=== Cleaning Up PostgreSQL Log Files ==="
    
    if [ -d "$PG_LOG_DIR" ]; then
        SIZE_BEFORE=$(du -sh "$PG_LOG_DIR" 2>/dev/null | cut -f1)
        log_message "PostgreSQL log directory size: $SIZE_BEFORE"
        
        # Archive and compress old logs
        find "$PG_LOG_DIR" -name "*.log" -mtime +7 ! -name "*.gz" -exec gzip {} \; 2>/dev/null
        
        # Remove very old compressed logs
        find "$PG_LOG_DIR" -name "*.log.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
        
        SIZE_AFTER=$(du -sh "$PG_LOG_DIR" 2>/dev/null | cut -f1)
        log_message "PostgreSQL log directory size after cleanup: $SIZE_AFTER"
    else
        log_message "PostgreSQL log directory not found at: $PG_LOG_DIR"
    fi
}

# Function to check for long-running queries
check_long_running_queries() {
    log_message "=== Checking Long-Running Queries ==="
    
    LONG_QUERIES=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "
        SELECT pid, usename, datname, 
               NOW() - query_start AS duration,
               LEFT(query, 100) AS query
        FROM pg_stat_activity
        WHERE state = 'active'
        AND query_start < NOW() - INTERVAL '5 minutes'
        AND query NOT LIKE '%pg_stat_activity%'
        ORDER BY duration DESC;
    " 2>/dev/null)
    
    if [ ! -z "$LONG_QUERIES" ] && [ "$(echo "$LONG_QUERIES" | wc -l)" -gt 1 ]; then
        log_message "Long-running queries detected:"
        echo "$LONG_QUERIES" | tee -a "$MAINTENANCE_LOG"
    else
        log_message "No long-running queries detected."
    fi
}

# Function to check database connections
check_connections() {
    log_message "=== Checking Database Connections ==="
    
    CONN_INFO=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "
        SELECT datname, count(*) as connections
        FROM pg_stat_activity
        WHERE datname IS NOT NULL
        GROUP BY datname
        ORDER BY connections DESC;
    " 2>/dev/null)
    
    log_message "Current connections per database:"
    echo "$CONN_INFO" | tee -a "$MAINTENANCE_LOG"
    
    # Check max connections
    MAX_CONN=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SHOW max_connections;" 2>/dev/null | xargs)
    CURRENT_CONN=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)
    
    log_message "Total connections: $CURRENT_CONN / $MAX_CONN"
}

# Function to check for unused indexes
check_unused_indexes() {
    log_message "=== Checking Unused Indexes ==="
    
    UNUSED_INDEXES=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "
        SELECT schemaname, tablename, indexname,
               pg_size_pretty(pg_relation_size(indexrelid)) AS size
        FROM pg_stat_user_indexes
        WHERE idx_scan = 0
        AND schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY pg_relation_size(indexrelid) DESC
        LIMIT 10;
    " 2>/dev/null)
    
    if [ ! -z "$UNUSED_INDEXES" ]; then
        log_message "Top 10 unused indexes:"
        echo "$UNUSED_INDEXES" | tee -a "$MAINTENANCE_LOG"
    else
        log_message "No unused indexes detected."
    fi
}

# Function to check cache hit ratio
check_cache_hit_ratio() {
    log_message "=== Checking Cache Hit Ratio ==="
    
    CACHE_RATIO=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "
        SELECT 
            ROUND(sum(blks_hit)*100.0 / (sum(blks_hit) + sum(blks_read)), 2) AS cache_hit_ratio
        FROM pg_stat_database
        WHERE datname NOT IN ('template0', 'template1');
    " 2>/dev/null | xargs)
    
    log_message "Cache hit ratio: ${CACHE_RATIO}%"
    
    if (( $(echo "$CACHE_RATIO < 90" | bc -l 2>/dev/null || echo 0) )); then
        log_message "WARNING: Cache hit ratio is below 90%. Consider increasing shared_buffers."
    fi
}

# Function to update statistics
update_statistics() {
    log_message "=== Updating Statistics ==="
    
    DATABASES=$(sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -d "$db" -c "VACUUM ANALYZE;" &>/dev/null
    done
    
    log_message "Statistics updated."
}

# Function to clean old backups
clean_old_backups() {
    log_message "=== Cleaning Old Backups ==="
    
    find "$BACKUP_DIR" -type f -name "*.dump.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
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
        echo "PostgreSQL Performance Report"
        echo "Generated: $(date)"
        echo "========================================="
        echo ""
        
        echo "=== Server Version ==="
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -t -c "SELECT version();" 2>/dev/null
        echo ""
        
        echo "=== Database Sizes ==="
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -c "
            SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
            FROM pg_database
            WHERE datistemplate = false
            ORDER BY pg_database_size(datname) DESC;
        " 2>/dev/null
        echo ""
        
        echo "=== Largest Tables ==="
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -c "
            SELECT schemaname, tablename,
                   pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
                   pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
                   pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
            FROM pg_tables
            WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
            ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
            LIMIT 10;
        " 2>/dev/null
        echo ""
        
        echo "=== Activity Statistics ==="
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -c "
            SELECT datname, numbackends, xact_commit, xact_rollback,
                   blks_read, blks_hit,
                   ROUND(blks_hit*100.0/(blks_hit+blks_read), 2) AS cache_hit_ratio
            FROM pg_stat_database
            WHERE datname NOT IN ('template0', 'template1')
            ORDER BY datname;
        " 2>/dev/null
        echo ""
        
        echo "=== Configuration Parameters ==="
        sudo -u "$POSTGRES_USER" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -c "
            SELECT name, setting, unit
            FROM pg_settings
            WHERE name IN ('shared_buffers', 'effective_cache_size', 'work_mem', 'maintenance_work_mem', 'max_connections', 'max_wal_size')
            ORDER BY name;
        " 2>/dev/null
        
    } > "$REPORT_FILE"
    
    log_message "Performance report saved to: $REPORT_FILE"
}

# Function to display summary
display_summary() {
    log_message ""
    log_message "========================================="
    log_message "PostgreSQL Maintenance Summary"
    log_message "========================================="
    log_message "Start Time: $(head -n 1 "$MAINTENANCE_LOG" | awk '{print $1, $2}')"
    log_message "End Time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_message "Backup Location: $BACKUP_DIR"
    log_message "Log Location: $MAINTENANCE_LOG"
    log_message "========================================="
}

# Main execution
log_message "Starting PostgreSQL maintenance..."

if ! check_postgres_connection; then
    log_message "Exiting due to connection failure."
    exit 1
fi

backup_databases
vacuum_databases
analyze_databases
reindex_databases
check_bloat
cleanup_wal_archives
cleanup_log_files
check_long_running_queries
check_connections
check_unused_indexes
check_cache_hit_ratio
update_statistics
clean_old_backups
generate_performance_report
display_summary

log_message "PostgreSQL maintenance completed successfully."
echo ""
echo "Maintenance log: $MAINTENANCE_LOG"
