#!/bin/bash

#--------------------------------------------------------------------------------------------------
# File: /src/linux/setup_docker.sh
# Description: This script automates Docker installation and configuration on Linux systems.
# Author: Miguel Nischor <miguel@datatower.tech>
# License: Apache License 2.0
#--------------------------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "Cannot detect OS."
        exit 1
    fi
}

# Function to install Docker on Debian/Ubuntu
install_docker_debian() {
    echo "=== Installing Docker on Debian/Ubuntu ==="
    
    # Update package index
    apt update
    
    # Install prerequisites
    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${OS}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo "Docker installed successfully."
}

# Function to install Docker on RHEL/CentOS/Rocky
install_docker_rhel() {
    echo "=== Installing Docker on RHEL/CentOS/Rocky ==="
    
    # Remove old versions
    yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    
    # Install prerequisites
    yum install -y yum-utils
    
    # Add Docker repository
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo "Docker installed successfully."
}

# Function to start and enable Docker
start_docker() {
    echo "=== Starting Docker Service ==="
    systemctl start docker
    systemctl enable docker
    echo "Docker service started and enabled."
}

# Function to configure Docker daemon
configure_docker() {
    echo "=== Configuring Docker Daemon ==="
    
    mkdir -p /etc/docker
    
    cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
    
    systemctl restart docker
    echo "Docker daemon configured."
}

# Function to add user to docker group
add_user_to_docker_group() {
    echo "=== Adding User to Docker Group ==="
    read -p "Enter username to add to docker group (or press Enter to skip): " username
    
    if [ ! -z "$username" ]; then
        if id "$username" &>/dev/null; then
            usermod -aG docker "$username"
            echo "User $username added to docker group."
            echo "User needs to log out and back in for changes to take effect."
        else
            echo "User $username does not exist."
        fi
    fi
}

# Function to install Docker Compose (standalone)
install_docker_compose_standalone() {
    echo "=== Installing Docker Compose (Standalone) ==="
    
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    chmod +x /usr/local/bin/docker-compose
    
    echo "Docker Compose installed: $(docker-compose --version)"
}

# Function to configure firewall
configure_firewall() {
    echo "=== Configuring Firewall for Docker ==="
    
    if command -v ufw &> /dev/null; then
        # UFW may interfere with Docker, add rules if needed
        echo "UFW detected. Docker manages its own iptables rules."
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --zone=trusted --add-interface=docker0
        firewall-cmd --reload
        echo "Firewalld configured for Docker."
    fi
}

# Function to verify installation
verify_installation() {
    echo ""
    echo "=== Verifying Docker Installation ==="
    
    docker --version
    docker compose version
    
    echo ""
    echo "Running test container..."
    docker run --rm hello-world
    
    if [ $? -eq 0 ]; then
        echo "Docker is working correctly!"
    else
        echo "Docker test failed."
    fi
}

# Function to display post-installation info
display_info() {
    echo ""
    echo "========================================="
    echo "Docker Installation Summary"
    echo "========================================="
    echo "Docker Version: $(docker --version)"
    echo "Docker Compose Version: $(docker compose version)"
    echo ""
    echo "Useful Commands:"
    echo "  docker ps              - List running containers"
    echo "  docker images          - List images"
    echo "  docker pull <image>    - Pull an image"
    echo "  docker run <image>     - Run a container"
    echo "  docker stop <id>       - Stop a container"
    echo "  docker rm <id>         - Remove a container"
    echo "  docker rmi <image>     - Remove an image"
    echo ""
    echo "Docker Compose Commands:"
    echo "  docker compose up      - Start services"
    echo "  docker compose down    - Stop services"
    echo "  docker compose logs    - View logs"
    echo "========================================="
}

# Main execution
detect_os

case $OS in
    ubuntu|debian)
        install_docker_debian
        ;;
    centos|rhel|rocky|almalinux)
        install_docker_rhel
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

start_docker
configure_docker
add_user_to_docker_group
configure_firewall
verify_installation
display_info

echo ""
echo "Docker installation completed successfully!"
