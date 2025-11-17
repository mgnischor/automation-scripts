#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/database_backup.sh
# Description: This script automates database backups for MySQL/PostgreSQL/MongoDB with compression and rotation.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Warning: Not running as root. Some operations may fail."
fi

# Configuration
BACKUP_DIR="/var/backups/databases"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7

# MySQL Configuration
MYSQL_USER="root"
MYSQL_PASSWORD=""

# PostgreSQL Configuration
POSTGRES_USER="postgres"

# MongoDB Configuration
MONGO_USER=""
MONGO_PASSWORD=""

# Oracle Configuration
ORACLE_USER="system"
ORACLE_PASSWORD=""
ORACLE_SID="ORCL"

# MS SQL Server Configuration
MSSQL_USER="sa"
MSSQL_PASSWORD=""
MSSQL_HOST="localhost"

# Redis Configuration
REDIS_HOST="localhost"
REDIS_PORT="6379"
REDIS_PASSWORD=""

# Cassandra Configuration
CASSANDRA_USER=""
CASSANDRA_PASSWORD=""
CASSANDRA_HOST="localhost"

# Function to create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        echo "Backup directory created: $BACKUP_DIR"
    fi
}

# Function to backup MySQL databases
backup_mysql() {
    echo "=== Backing Up MySQL Databases ==="
    
    if ! command -v mysql &> /dev/null; then
        echo "MySQL not installed. Skipping MySQL backup."
        return
    fi
    
    if [ -z "$MYSQL_PASSWORD" ]; then
        read -s -p "Enter MySQL root password: " MYSQL_PASSWORD
        echo
    fi
    
    MYSQL_BACKUP_DIR="${BACKUP_DIR}/mysql_${TIMESTAMP}"
    mkdir -p "$MYSQL_BACKUP_DIR"
    
    # Get list of databases
    DATABASES=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
    
    if [ $? -ne 0 ]; then
        echo "Failed to connect to MySQL. Check credentials."
        return
    fi
    
    for db in $DATABASES; do
        echo "Backing up database: $db"
        mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --single-transaction --routines --triggers "$db" | gzip > "${MYSQL_BACKUP_DIR}/${db}.sql.gz"
        
        if [ $? -eq 0 ]; then
            echo "Successfully backed up: $db"
        else
            echo "Failed to backup: $db"
        fi
    done
    
    echo "MySQL backup completed."
}

# Function to backup PostgreSQL databases
backup_postgresql() {
    echo "=== Backing Up PostgreSQL Databases ==="
    
    if ! command -v psql &> /dev/null; then
        echo "PostgreSQL not installed. Skipping PostgreSQL backup."
        return
    fi
    
    POSTGRES_BACKUP_DIR="${BACKUP_DIR}/postgresql_${TIMESTAMP}"
    mkdir -p "$POSTGRES_BACKUP_DIR"
    
    # Get list of databases
    DATABASES=$(sudo -u "$POSTGRES_USER" psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Failed to connect to PostgreSQL."
        return
    fi
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)
        echo "Backing up database: $db"
        sudo -u "$POSTGRES_USER" pg_dump "$db" | gzip > "${POSTGRES_BACKUP_DIR}/${db}.sql.gz"
        
        if [ $? -eq 0 ]; then
            echo "Successfully backed up: $db"
        else
            echo "Failed to backup: $db"
        fi
    done
    
    # Backup all databases
    sudo -u "$POSTGRES_USER" pg_dumpall | gzip > "${POSTGRES_BACKUP_DIR}/all_databases.sql.gz"
    
    echo "PostgreSQL backup completed."
}

# Function to backup MongoDB databases
backup_mongodb() {
    echo "=== Backing Up MongoDB Databases ==="
    
    if ! command -v mongodump &> /dev/null; then
        echo "MongoDB not installed. Skipping MongoDB backup."
        return
    fi
    
    MONGO_BACKUP_DIR="${BACKUP_DIR}/mongodb_${TIMESTAMP}"
    mkdir -p "$MONGO_BACKUP_DIR"
    
    if [ ! -z "$MONGO_USER" ] && [ ! -z "$MONGO_PASSWORD" ]; then
        mongodump --username="$MONGO_USER" --password="$MONGO_PASSWORD" --out="$MONGO_BACKUP_DIR" 2>/dev/null
    else
        mongodump --out="$MONGO_BACKUP_DIR" 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        # Compress the backup
        tar -czf "${MONGO_BACKUP_DIR}.tar.gz" -C "$BACKUP_DIR" "mongodb_${TIMESTAMP}"
        rm -rf "$MONGO_BACKUP_DIR"
        echo "MongoDB backup completed."
    else
        echo "Failed to backup MongoDB."
    fi
}

# Function to backup Oracle databases
backup_oracle() {
    echo "=== Backing Up Oracle Databases ==="
    
    if ! command -v sqlplus &> /dev/null; then
        echo "Oracle not installed. Skipping Oracle backup."
        return
    fi
    
    if [ -z "$ORACLE_PASSWORD" ]; then
        read -s -p "Enter Oracle password: " ORACLE_PASSWORD
        echo
    fi
    
    ORACLE_BACKUP_DIR="${BACKUP_DIR}/oracle_${TIMESTAMP}"
    mkdir -p "$ORACLE_BACKUP_DIR"
    
    export ORACLE_SID="$ORACLE_SID"
    
    # Export full database
    echo "Exporting Oracle database: $ORACLE_SID"
    expdp "$ORACLE_USER/$ORACLE_PASSWORD" DIRECTORY=DATA_PUMP_DIR DUMPFILE="${ORACLE_SID}_${TIMESTAMP}.dmp" LOGFILE="${ORACLE_SID}_${TIMESTAMP}.log" FULL=Y 2>/dev/null
    
    # Alternative: use exp for older versions
    if [ $? -ne 0 ]; then
        exp "$ORACLE_USER/$ORACLE_PASSWORD" FILE="${ORACLE_BACKUP_DIR}/${ORACLE_SID}.dmp" LOG="${ORACLE_BACKUP_DIR}/${ORACLE_SID}.log" FULL=Y 2>/dev/null
    fi
    
    if [ $? -eq 0 ]; then
        # Compress the backup
        gzip "${ORACLE_BACKUP_DIR}"/*.dmp 2>/dev/null
        echo "Oracle backup completed."
    else
        echo "Failed to backup Oracle."
    fi
}

# Function to backup MS SQL Server databases
backup_mssql() {
    echo "=== Backing Up MS SQL Server Databases ==="
    
    if ! command -v sqlcmd &> /dev/null; then
        echo "MS SQL Server tools not installed. Skipping MS SQL backup."
        return
    fi
    
    if [ -z "$MSSQL_PASSWORD" ]; then
        read -s -p "Enter MS SQL Server password: " MSSQL_PASSWORD
        echo
    fi
    
    MSSQL_BACKUP_DIR="${BACKUP_DIR}/mssql_${TIMESTAMP}"
    mkdir -p "$MSSQL_BACKUP_DIR"
    
    # Get list of databases
    DATABASES=$(sqlcmd -S "$MSSQL_HOST" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD" -Q "SELECT name FROM sys.databases WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')" -h -1 2>/dev/null | grep -v '^$')
    
    if [ $? -ne 0 ]; then
        echo "Failed to connect to MS SQL Server. Check credentials."
        return
    fi
    
    for db in $DATABASES; do
        db=$(echo "$db" | xargs)
        echo "Backing up database: $db"
        sqlcmd -S "$MSSQL_HOST" -U "$MSSQL_USER" -P "$MSSQL_PASSWORD" -Q "BACKUP DATABASE [$db] TO DISK = '${MSSQL_BACKUP_DIR}/${db}.bak' WITH FORMAT" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            gzip "${MSSQL_BACKUP_DIR}/${db}.bak"
            echo "Successfully backed up: $db"
        else
            echo "Failed to backup: $db"
        fi
    done
    
    echo "MS SQL Server backup completed."
}

# Function to backup Redis
backup_redis() {
    echo "=== Backing Up Redis ==="
    
    if ! command -v redis-cli &> /dev/null; then
        echo "Redis not installed. Skipping Redis backup."
        return
    fi
    
    REDIS_BACKUP_DIR="${BACKUP_DIR}/redis_${TIMESTAMP}"
    mkdir -p "$REDIS_BACKUP_DIR"
    
    # Trigger Redis save
    if [ ! -z "$REDIS_PASSWORD" ]; then
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" --no-auth-warning BGSAVE 2>/dev/null
    else
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" BGSAVE 2>/dev/null
    fi
    
    # Wait for background save to complete
    sleep 5
    
    # Copy RDB file
    REDIS_DIR=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" CONFIG GET dir 2>/dev/null | tail -n 1)
    REDIS_RDB=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" CONFIG GET dbfilename 2>/dev/null | tail -n 1)
    
    if [ -f "${REDIS_DIR}/${REDIS_RDB}" ]; then
        cp "${REDIS_DIR}/${REDIS_RDB}" "${REDIS_BACKUP_DIR}/dump.rdb"
        gzip "${REDIS_BACKUP_DIR}/dump.rdb"
        echo "Redis backup completed."
    else
        echo "Failed to backup Redis. RDB file not found."
    fi
}

# Function to backup Cassandra
backup_cassandra() {
    echo "=== Backing Up Cassandra ==="
    
    if ! command -v nodetool &> /dev/null; then
        echo "Cassandra not installed. Skipping Cassandra backup."
        return
    fi
    
    CASSANDRA_BACKUP_DIR="${BACKUP_DIR}/cassandra_${TIMESTAMP}"
    mkdir -p "$CASSANDRA_BACKUP_DIR"
    
    # Create snapshot
    echo "Creating Cassandra snapshot..."
    nodetool snapshot -t "backup_${TIMESTAMP}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Find Cassandra data directory
        CASSANDRA_DATA="/var/lib/cassandra/data"
        if [ ! -d "$CASSANDRA_DATA" ]; then
            CASSANDRA_DATA="/opt/cassandra/data"
        fi
        
        # Copy snapshots
        find "$CASSANDRA_DATA" -type d -name "backup_${TIMESTAMP}" -exec cp -r {} "$CASSANDRA_BACKUP_DIR/" \;
        
        # Compress backup
        tar -czf "${CASSANDRA_BACKUP_DIR}.tar.gz" -C "$BACKUP_DIR" "cassandra_${TIMESTAMP}"
        rm -rf "$CASSANDRA_BACKUP_DIR"
        
        # Clean snapshot from Cassandra
        nodetool clearsnapshot -t "backup_${TIMESTAMP}" 2>/dev/null
        
        echo "Cassandra backup completed."
    else
        echo "Failed to backup Cassandra."
    fi
}

# Function to clean old backups
clean_old_backups() {
    echo "=== Cleaning Old Backups ==="
    
    find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
    find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null
    find "$BACKUP_DIR" -type d -empty -delete 2>/dev/null
    
    echo "Old backups (>${RETENTION_DAYS} days) removed."
}

# Function to display backup summary
display_summary() {
    echo ""
    echo "========================================="
    echo "Database Backup Summary"
    echo "========================================="
    echo "Backup Location: $BACKUP_DIR"
    echo "Timestamp: $TIMESTAMP"
    echo "Retention: $RETENTION_DAYS days"
    echo ""
    echo "Backup Files:"
    du -sh ${BACKUP_DIR}/*${TIMESTAMP}* 2>/dev/null || echo "No backups created."
    echo ""
    echo "Total Backup Size:"
    du -sh "$BACKUP_DIR"
    echo "========================================="
}

# Function to show menu
show_menu() {
    echo "========================================="
    echo "Database Backup Script"
    echo "========================================="
    echo "1. Backup MySQL"
    echo "2. Backup PostgreSQL"
    echo "3. Backup MongoDB"
    echo "4. Backup Oracle"
    echo "5. Backup MS SQL Server"
    echo "6. Backup Redis"
    echo "7. Backup Cassandra"
    echo "8. Backup All"
    echo "9. Clean Old Backups"
    echo "0. Exit"
    echo "========================================="
}

# Main execution
create_backup_dir

if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Select an option: " option
        
        case $option in
            1) backup_mysql ;;
            2) backup_postgresql ;;
            3) backup_mongodb ;;
            4) backup_oracle ;;
            5) backup_mssql ;;
            6) backup_redis ;;
            7) backup_cassandra ;;
            8) 
                backup_mysql
                backup_postgresql
                backup_mongodb
                backup_oracle
                backup_mssql
                backup_redis
                backup_cassandra
                ;;
            9) clean_old_backups ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
else
    # Non-interactive mode
    case $1 in
        mysql) backup_mysql ;;
        postgresql) backup_postgresql ;;
        mongodb) backup_mongodb ;;
        oracle) backup_oracle ;;
        mssql) backup_mssql ;;
        redis) backup_redis ;;
        cassandra) backup_cassandra ;;
        all) 
            backup_mysql
            backup_postgresql
            backup_mongodb
            backup_oracle
            backup_mssql
            backup_redis
            backup_cassandra
            ;;
        clean) clean_old_backups ;;
        *) 
            echo "Usage: $0 {mysql|postgresql|mongodb|oracle|mssql|redis|cassandra|all|clean}"
            exit 1
            ;;
    esac
fi

display_summary
echo "Database backup completed successfully."
