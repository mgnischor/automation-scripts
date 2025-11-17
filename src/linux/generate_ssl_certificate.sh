#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/generate_ssl_certificate.sh
# Description: This script generates self-signed SSL certificates and configures Apache/Nginx for HTTPS.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Configuration
DOMAIN=""
COUNTRY="US"
STATE="California"
CITY="San Francisco"
ORG="My Organization"
OU="IT Department"
EMAIL="admin@example.com"
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
DAYS_VALID=365

# Function to collect certificate information
collect_info() {
    echo "=== SSL Certificate Information ==="
    read -p "Enter domain name (e.g., example.com): " DOMAIN
    read -p "Enter country code (default: US): " input
    COUNTRY=${input:-$COUNTRY}
    read -p "Enter state (default: California): " input
    STATE=${input:-$STATE}
    read -p "Enter city (default: San Francisco): " input
    CITY=${input:-$CITY}
    read -p "Enter organization (default: My Organization): " input
    ORG=${input:-$ORG}
    read -p "Enter organizational unit (default: IT Department): " input
    OU=${input:-$OU}
    read -p "Enter email (default: admin@example.com): " input
    EMAIL=${input:-$EMAIL}
    read -p "Enter validity period in days (default: 365): " input
    DAYS_VALID=${input:-$DAYS_VALID}
}

# Function to generate SSL certificate
generate_certificate() {
    echo "=== Generating SSL Certificate ==="
    
    # Create directories if they don't exist
    mkdir -p "$CERT_DIR"
    mkdir -p "$KEY_DIR"
    
    # Generate private key
    openssl genrsa -out "${KEY_DIR}/${DOMAIN}.key" 2048
    chmod 600 "${KEY_DIR}/${DOMAIN}.key"
    
    # Generate certificate signing request
    openssl req -new -key "${KEY_DIR}/${DOMAIN}.key" -out "${CERT_DIR}/${DOMAIN}.csr" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${DOMAIN}/emailAddress=${EMAIL}"
    
    # Generate self-signed certificate
    openssl x509 -req -days ${DAYS_VALID} -in "${CERT_DIR}/${DOMAIN}.csr" \
        -signkey "${KEY_DIR}/${DOMAIN}.key" -out "${CERT_DIR}/${DOMAIN}.crt"
    
    chmod 644 "${CERT_DIR}/${DOMAIN}.crt"
    
    echo "SSL certificate generated successfully."
    echo "Certificate: ${CERT_DIR}/${DOMAIN}.crt"
    echo "Private Key: ${KEY_DIR}/${DOMAIN}.key"
}

# Function to configure Apache
configure_apache() {
    echo "=== Configuring Apache for SSL ==="
    
    if ! command -v apache2 &> /dev/null && ! command -v httpd &> /dev/null; then
        echo "Apache not found. Skipping Apache configuration."
        return
    fi
    
    # Enable SSL module
    if command -v a2enmod &> /dev/null; then
        a2enmod ssl
        a2enmod headers
    fi
    
    # Create virtual host configuration
    VHOST_FILE="/etc/apache2/sites-available/${DOMAIN}-ssl.conf"
    if [ ! -d "/etc/apache2/sites-available" ]; then
        VHOST_FILE="/etc/httpd/conf.d/${DOMAIN}-ssl.conf"
    fi
    
    cat > "$VHOST_FILE" << EOF
<VirtualHost *:443>
    ServerName ${DOMAIN}
    DocumentRoot /var/www/html
    
    SSLEngine on
    SSLCertificateFile ${CERT_DIR}/${DOMAIN}.crt
    SSLCertificateKeyFile ${KEY_DIR}/${DOMAIN}.key
    
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}-access.log combined
</VirtualHost>
EOF
    
    # Enable site
    if command -v a2ensite &> /dev/null; then
        a2ensite "${DOMAIN}-ssl"
        systemctl reload apache2
    else
        systemctl reload httpd
    fi
    
    echo "Apache configured for SSL."
}

# Function to configure Nginx
configure_nginx() {
    echo "=== Configuring Nginx for SSL ==="
    
    if ! command -v nginx &> /dev/null; then
        echo "Nginx not found. Skipping Nginx configuration."
        return
    fi
    
    # Create server block configuration
    NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"
    if [ ! -d "/etc/nginx/sites-available" ]; then
        NGINX_CONF="/etc/nginx/conf.d/${DOMAIN}.conf"
    fi
    
    cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};
    
    ssl_certificate ${CERT_DIR}/${DOMAIN}.crt;
    ssl_certificate_key ${KEY_DIR}/${DOMAIN}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    root /var/www/html;
    index index.html index.php;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
EOF
    
    # Enable site
    if [ -d "/etc/nginx/sites-enabled" ]; then
        ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/${DOMAIN}"
    fi
    
    nginx -t && systemctl reload nginx
    
    echo "Nginx configured for SSL."
}

# Function to configure firewall
configure_firewall() {
    echo "=== Configuring Firewall for HTTPS ==="
    if command -v ufw &> /dev/null; then
        ufw allow 443/tcp
        ufw reload
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi
    echo "Firewall configured for HTTPS."
}

# Function to display certificate information
display_cert_info() {
    echo ""
    echo "========================================="
    echo "SSL Certificate Information"
    echo "========================================="
    openssl x509 -in "${CERT_DIR}/${DOMAIN}.crt" -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After"
    echo "========================================="
}

# Main execution
collect_info
generate_certificate
configure_apache
configure_nginx
configure_firewall
display_cert_info

echo ""
echo "SSL certificate setup completed successfully."
echo "Access your site at: https://${DOMAIN}"
