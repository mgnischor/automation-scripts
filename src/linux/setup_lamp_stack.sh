#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/setup_lamp_stack.sh
# Description: This script automates the installation and configuration of LAMP stack (Linux, Apache, MySQL, PHP).
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Configuration
MYSQL_ROOT_PASSWORD=""
WEB_ROOT="/var/www/html"

# Function to detect package manager
detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    else
        echo "none"
    fi
}

PKG_MGR=$(detect_package_manager)

# Function to install Apache
install_apache() {
    echo "=== Installing Apache Web Server ==="
    if [ "$PKG_MGR" = "apt" ]; then
        apt update
        apt install -y apache2
        systemctl enable apache2
        systemctl start apache2
    elif [ "$PKG_MGR" = "yum" ] || [ "$PKG_MGR" = "dnf" ]; then
        $PKG_MGR install -y httpd
        systemctl enable httpd
        systemctl start httpd
    fi
    echo "Apache installed and started."
}

# Function to install MySQL
install_mysql() {
    echo "=== Installing MySQL Database Server ==="
    if [ "$PKG_MGR" = "apt" ]; then
        apt install -y mysql-server
        systemctl enable mysql
        systemctl start mysql
    elif [ "$PKG_MGR" = "yum" ] || [ "$PKG_MGR" = "dnf" ]; then
        $PKG_MGR install -y mariadb-server mariadb
        systemctl enable mariadb
        systemctl start mariadb
    fi
    echo "MySQL/MariaDB installed and started."
}

# Function to secure MySQL installation
secure_mysql() {
    echo "=== Securing MySQL Installation ==="
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
        echo
    fi
    
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';" 2>/dev/null || \
    mysql -e "UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';" 2>/dev/null || \
    mysqladmin -u root password "${MYSQL_ROOT_PASSWORD}" 2>/dev/null
    
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    echo "MySQL secured."
}

# Function to install PHP
install_php() {
    echo "=== Installing PHP ==="
    if [ "$PKG_MGR" = "apt" ]; then
        apt install -y php libapache2-mod-php php-mysql php-cli php-curl php-gd php-mbstring php-xml php-zip
    elif [ "$PKG_MGR" = "yum" ] || [ "$PKG_MGR" = "dnf" ]; then
        $PKG_MGR install -y php php-mysqlnd php-cli php-curl php-gd php-mbstring php-xml php-zip
    fi
    echo "PHP installed."
}

# Function to configure Apache for PHP
configure_apache_php() {
    echo "=== Configuring Apache for PHP ==="
    if [ "$PKG_MGR" = "apt" ]; then
        systemctl restart apache2
    elif [ "$PKG_MGR" = "yum" ] || [ "$PKG_MGR" = "dnf" ]; then
        systemctl restart httpd
    fi
}

# Function to create test PHP file
create_test_page() {
    echo "=== Creating Test PHP Page ==="
    cat > "${WEB_ROOT}/info.php" << 'EOF'
<?php
phpinfo();
?>
EOF
    chmod 644 "${WEB_ROOT}/info.php"
    echo "Test page created at ${WEB_ROOT}/info.php"
}

# Function to configure firewall
configure_firewall() {
    echo "=== Configuring Firewall ==="
    if command -v ufw &> /dev/null; then
        ufw allow 'Apache Full'
        ufw reload
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi
    echo "Firewall configured for HTTP/HTTPS."
}

# Function to display installation summary
display_summary() {
    echo ""
    echo "========================================="
    echo "LAMP Stack Installation Summary"
    echo "========================================="
    echo "Apache Status: $(systemctl is-active apache2 httpd 2>/dev/null | head -n1)"
    echo "MySQL Status: $(systemctl is-active mysql mariadb 2>/dev/null | head -n1)"
    echo "PHP Version: $(php -v | head -n1)"
    echo ""
    echo "Web Root: ${WEB_ROOT}"
    echo "Test Page: http://$(hostname -I | awk '{print $1}')/info.php"
    echo ""
    echo "MySQL Root Password: ${MYSQL_ROOT_PASSWORD}"
    echo "========================================="
    echo "WARNING: Remove info.php after testing!"
    echo "========================================="
}

# Execute installation
if [ "$PKG_MGR" = "none" ]; then
    echo "No supported package manager found."
    exit 1
fi

install_apache
install_mysql
secure_mysql
install_php
configure_apache_php
create_test_page
configure_firewall
display_summary

echo "LAMP stack installation completed successfully."
