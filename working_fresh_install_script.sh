#!/bin/bash
set -e

# Decidim Docker Deployment Script
# Usage: ./deploy.sh [install|diagnose|restart|logs]

DOMAIN="DOMAIN_HERE"
EMAIL="EMAIL_HERE"  # Change this to your email
INSTALL_DIR="/opt/decidim"
LOG_FILE="/var/log/decidim-deploy.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    local prereq_failed=0
    
    # Check Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "22.04" ]]; then
            log "✓ Ubuntu 22.04 detected"
        else
            error "✗ This script requires Ubuntu 22.04 (detected: $ID $VERSION_ID)"
            prereq_failed=1
        fi
    else
        warning "Cannot detect OS version"
    fi
    
    # Check DNS resolution
    log "Checking DNS resolution for $DOMAIN..."
    if host "$DOMAIN" > /dev/null 2>&1; then
        SERVER_IP=$(host "$DOMAIN" | grep "has address" | head -1 | awk '{print $4}')
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        
        if [ -n "$SERVER_IP" ]; then
            log "✓ DNS resolves to: $SERVER_IP"
            if [ "$SERVER_IP" != "$LOCAL_IP" ]; then
                warning "DNS IP ($SERVER_IP) differs from server IP ($LOCAL_IP)"
                warning "Ensure DNS A record points to this server"
            fi
        fi
    else
        error "✗ DNS resolution failed for $DOMAIN"
        error "Create A record: $DOMAIN → your server IP"
        prereq_failed=1
    fi
    
    # Check ports 80 and 443
    log "Checking if ports 80 and 443 are available..."
    if command -v netstat &> /dev/null || command -v ss &> /dev/null; then
        for port in 80 443; do
            if ss -tuln 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
                warning "Port $port is already in use"
            else
                log "✓ Port $port is available"
            fi
        done
    else
        warning "Cannot check port availability (netstat/ss not found)"
    fi
    
    # Check firewall (if UFW is active)
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        log "Checking UFW firewall rules..."
        if ! ufw status | grep -q "80.*ALLOW"; then
            warning "Port 80 may not be open in UFW firewall"
            warning "Run: ufw allow 80/tcp"
        fi
        if ! ufw status | grep -q "443.*ALLOW"; then
            warning "Port 443 may not be open in UFW firewall"
            warning "Run: ufw allow 443/tcp"
        fi
    fi
    
    if [ $prereq_failed -eq 1 ]; then
        error "Prerequisite checks failed. Please fix the issues above."
        exit 1
    fi
    
    log "All prerequisite checks passed!"
}

# Install Docker if not present
install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker already installed, skipping..."
        return 0
    fi

    log "Installing Docker..."
    apt-get update || { error "Failed to update apt"; return 1; }
    apt-get install -y ca-certificates curl gnupg lsb-release || { error "Failed to install prerequisites"; return 1; }
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || { error "Failed to add Docker GPG key"; return 1; }
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update || { error "Failed to update apt after adding Docker repo"; return 1; }
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || { error "Failed to install Docker"; return 1; }
    
    systemctl enable docker
    systemctl start docker
    log "Docker installed successfully"
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    apt-get update
    apt-get install -y nginx certbot python3-certbot-nginx git curl || { error "Failed to install packages"; return 1; }
    log "Packages installed successfully"
}

# Create directory structure
setup_directories() {
    log "Setting up directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/postgres-data"
    mkdir -p "$INSTALL_DIR/redis-data"
    mkdir -p "$INSTALL_DIR/uploads"
    chmod -R 755 "$INSTALL_DIR"
    log "Directories created"
}

# Generate secrets
generate_secrets() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        log ".env file exists, skipping secret generation..."
        return 0
    fi

    log "Generating secrets..."
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    POSTGRES_PASSWORD=$(openssl rand -hex 32)
    
    cat > "$INSTALL_DIR/.env" <<EOF
# Database configuration
POSTGRES_HOST=postgres
POSTGRES_USER=decidim
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DATABASE_URL=postgres://decidim:$POSTGRES_PASSWORD@postgres/decidim_production

# Rails configuration
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY_BASE
RAILS_SERVE_STATIC_FILES=true

# Domain configuration
DECIDIM_HOST=$DOMAIN

# Redis configuration
REDIS_URL=redis://redis:6379/0

# Email configuration (configure later)
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=your_email@example.com
SMTP_PASSWORD=your_password
SMTP_DOMAIN=$DOMAIN
EOF
    
    log "Secrets generated"
}

# Create docker-compose.yml
create_docker_compose() {
    log "Creating docker-compose.yml..."
    
    cat > "$INSTALL_DIR/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:14-alpine
    container_name: decidim_postgres
    restart: unless-stopped
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: decidim_production
    networks:
      - decidim_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U decidim"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: decidim_redis
    restart: unless-stopped
    volumes:
      - ./redis-data:/data
    networks:
      - decidim_network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  decidim:
    image: decidim/decidim:latest
    container_name: decidim_app
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    env_file:
      - .env
    volumes:
      - ./uploads:/app/public/uploads
    networks:
      - decidim_network
    ports:
      - "127.0.0.1:3000:3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    command: >
      bash -c "
        bundle exec rails db:prepare &&
        bundle exec rails db:seed &&
        bundle exec rails assets:precompile &&
        bundle exec rails server -b 0.0.0.0
      "

networks:
  decidim_network:
    driver: bridge
EOF
    
    log "docker-compose.yml created"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    # Remove default site if exists
    rm -f /etc/nginx/sites-enabled/default
    
    cat > "/etc/nginx/sites-available/$DOMAIN" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 100M;
    }
}
EOF
    
    ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"
    nginx -t || { error "Nginx configuration test failed"; return 1; }
    systemctl restart nginx
    log "Nginx configured"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    log "Setting up SSL certificate..."
    
    # Check if certificate already exists
    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        log "SSL certificate already exists, skipping..."
        return 0
    fi
    
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || {
        warning "Failed to obtain SSL certificate. You may need to configure DNS first."
        warning "Run manually later: certbot --nginx -d $DOMAIN"
        return 1
    }
    
    log "SSL certificate obtained"
}

# Start services
start_services() {
    log "Starting Decidim services..."
    cd "$INSTALL_DIR"
    docker compose down || true
    docker compose pull
    docker compose up -d || { error "Failed to start services"; return 1; }
    log "Services started"
}

# Wait for services to be ready
wait_for_services() {
    log "Waiting for services to be ready..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf http://localhost:3000/ > /dev/null 2>&1; then
            log "Decidim is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    error "Timeout waiting for Decidim to start"
    return 1
}

# Diagnose deployment
diagnose() {
    echo "=== Decidim Deployment Diagnostics ==="
    echo ""
    
    # Check Docker
    echo "Docker Status:"
    if command -v docker &> /dev/null; then
        echo "✓ Docker is installed"
        docker --version
    else
        echo "✗ Docker is NOT installed"
    fi
    echo ""
    
    # Check containers
    echo "Container Status:"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        docker compose ps
    else
        echo "✗ Installation directory not found"
    fi
    echo ""
    
    # Check Nginx
    echo "Nginx Status:"
    systemctl status nginx --no-pager | grep "Active:"
    nginx -t 2>&1 | tail -n 2
    echo ""
    
    # Check SSL
    echo "SSL Certificate:"
    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        echo "✓ SSL certificate exists"
        certbot certificates | grep "$DOMAIN" -A 3
    else
        echo "✗ SSL certificate not found"
    fi
    echo ""
    
    # Check connectivity
    echo "Service Connectivity:"
    if curl -sf http://localhost:3000/ > /dev/null 2>&1; then
        echo "✓ Decidim responds on localhost:3000"
    else
        echo "✗ Decidim not responding on localhost:3000"
    fi
    
    if curl -sf "http://$DOMAIN" > /dev/null 2>&1; then
        echo "✓ Site accessible via HTTP"
    else
        echo "✗ Site not accessible via HTTP"
    fi
    
    if curl -sf "https://$DOMAIN" > /dev/null 2>&1; then
        echo "✓ Site accessible via HTTPS"
    else
        echo "✗ Site not accessible via HTTPS"
    fi
    echo ""
    
    # Recent logs
    echo "Recent Logs (last 20 lines):"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        docker compose logs --tail=20 decidim
    fi
}

# Show logs
show_logs() {
    cd "$INSTALL_DIR"
    docker compose logs -f
}

# Restart services
restart_services() {
    log "Restarting services..."
    cd "$INSTALL_DIR"
    docker compose restart
    log "Services restarted"
}

# Main installation function
main_install() {
    log "Starting Decidim installation..."
    
    check_root
    check_prerequisites
    install_docker || error "Docker installation failed"
    install_packages || error "Package installation failed"
    setup_directories
    generate_secrets
    create_docker_compose
    configure_nginx
    start_services
    
    sleep 10
    wait_for_services || {
        error "Services failed to start properly"
        log "Check logs with: docker compose logs"
        exit 1
    }
    
    setup_ssl || warning "SSL setup incomplete, configure manually if needed"
    
    log "======================================"
    log "Decidim installation completed!"
    log "======================================"
    log "Access your site at: https://$DOMAIN"
    log ""
    log "Useful commands:"
    log "  - View logs: cd $INSTALL_DIR && docker compose logs -f"
    log "  - Restart: cd $INSTALL_DIR && docker compose restart"
    log "  - Stop: cd $INSTALL_DIR && docker compose down"
    log "  - Start: cd $INSTALL_DIR && docker compose up -d"
    log ""
    log "Edit configuration: $INSTALL_DIR/.env"
    log "Configure email settings in .env file for notifications"
}

# Main script logic
case "${1:-install}" in
    install)
        main_install
        ;;
    diagnose)
        diagnose
        ;;
    restart)
        check_root
        restart_services
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Usage: $0 {install|diagnose|restart|logs}"
        echo "  install  - Install and configure Decidim"
        echo "  diagnose - Check deployment status"
        echo "  restart  - Restart all services"
        echo "  logs     - View live logs"
        exit 1
        ;;
esac