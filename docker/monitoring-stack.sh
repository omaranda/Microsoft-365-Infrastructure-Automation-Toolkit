#!/bin/bash
################################################################################
# Copyright (c) 2025 Omar Miranda
# All rights reserved.
#
# This script is provided "as is" without warranty of any kind, express or
# implied. Use at your own risk.
#
# Author: Omar Miranda
# Created: 2025
################################################################################

# Monitoring Stack Management Script
# Manages Grafana, Prometheus, and all monitoring services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

print_header() {
    echo ""
    print_message "$BLUE" "════════════════════════════════════════════════════════════════"
    print_message "$BLUE" "  $1"
    print_message "$BLUE" "════════════════════════════════════════════════════════════════"
    echo ""
}

print_success() {
    print_message "$GREEN" "✓ $1"
}

print_error() {
    print_message "$RED" "✗ $1"
}

print_warning() {
    print_message "$YELLOW" "⚠ $1"
}

print_info() {
    print_message "$BLUE" "ℹ $1"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Install Docker from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker is installed"

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        print_info "Install Docker Compose from: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose is installed"

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_info "Start Docker Desktop or Docker daemon"
        exit 1
    fi
    print_success "Docker daemon is running"
}

# Setup environment file
setup_env() {
    if [ ! -f "$ENV_FILE" ]; then
        print_warning "Environment file not found, creating from example..."

        cat > "$ENV_FILE" << 'EOF'
# Azure AD Configuration (for Graph API proxy)
AZURE_TENANT_ID=your-tenant-id-here
AZURE_CLIENT_ID=your-client-id-here
AZURE_CLIENT_SECRET=your-client-secret-here

# Grafana Configuration
GF_SECURITY_ADMIN_PASSWORD=admin
EOF

        print_success "Created .env file at: $ENV_FILE"
        print_warning "Please edit $ENV_FILE with your Azure AD credentials"
        print_info "You can get these from: https://portal.azure.com -> Azure AD -> App registrations"
        echo ""
        read -p "Press Enter to continue after editing .env file..."
    else
        print_success "Environment file exists"
    fi
}

# Copy dashboard to Grafana folder
setup_dashboards() {
    print_header "Setting up Dashboards"

    local dashboard_source="$SCRIPT_DIR/../06-Monitoring/Azure-Monitor/grafana-dashboard-windows-servers.json"
    local dashboard_dest="$SCRIPT_DIR/grafana/dashboards/"

    if [ ! -d "$dashboard_dest" ]; then
        mkdir -p "$dashboard_dest"
        print_success "Created dashboards directory"
    fi

    if [ -f "$dashboard_source" ]; then
        cp "$dashboard_source" "$dashboard_dest/"
        print_success "Copied Windows Servers dashboard"
    else
        print_warning "Windows Servers dashboard not found at: $dashboard_source"
    fi
}

# Start the monitoring stack
start_stack() {
    print_header "Starting Monitoring Stack"

    check_prerequisites
    setup_env
    setup_dashboards

    print_info "Starting containers..."
    docker compose -f "$COMPOSE_FILE" up -d

    print_success "Monitoring stack started!"
    echo ""
    show_status
    show_urls
}

# Stop the monitoring stack
stop_stack() {
    print_header "Stopping Monitoring Stack"

    docker compose -f "$COMPOSE_FILE" down

    print_success "Monitoring stack stopped"
}

# Restart the monitoring stack
restart_stack() {
    print_header "Restarting Monitoring Stack"

    docker compose -f "$COMPOSE_FILE" restart

    print_success "Monitoring stack restarted"
    echo ""
    show_status
}

# Show stack status
show_status() {
    print_header "Stack Status"

    docker compose -f "$COMPOSE_FILE" ps

    echo ""
    print_info "Container Health:"
    docker ps --filter "name=grafana" --filter "name=prometheus" --filter "name=graph-api" \
        --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Show logs
show_logs() {
    local service=$1

    if [ -z "$service" ]; then
        print_header "All Container Logs (last 50 lines)"
        docker compose -f "$COMPOSE_FILE" logs --tail=50 --follow
    else
        print_header "Logs for: $service"
        docker compose -f "$COMPOSE_FILE" logs --tail=100 --follow "$service"
    fi
}

# Show URLs
show_urls() {
    print_header "Access URLs"

    echo ""
    print_info "Grafana:          http://localhost:3000"
    print_info "  Username:       admin"
    print_info "  Password:       admin (change on first login)"
    echo ""
    print_info "Prometheus:       http://localhost:9090"
    print_info "Node Exporter:    http://localhost:9100/metrics"
    print_info "cAdvisor:         http://localhost:8080"
    print_info "Graph API Proxy:  http://localhost:3001"
    print_info "Alertmanager:     http://localhost:9093"
    echo ""
}

# Update containers
update_stack() {
    print_header "Updating Monitoring Stack"

    print_info "Pulling latest images..."
    docker compose -f "$COMPOSE_FILE" pull

    print_info "Recreating containers..."
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate

    print_success "Stack updated successfully"
}

# Clean up (remove containers and volumes)
cleanup_stack() {
    print_header "Cleanup Monitoring Stack"

    print_warning "This will remove all containers, networks, and volumes!"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        docker compose -f "$COMPOSE_FILE" down -v
        print_success "Cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Backup Grafana data
backup_grafana() {
    print_header "Backup Grafana Data"

    local backup_dir="$SCRIPT_DIR/backups"
    local backup_file="$backup_dir/grafana-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    mkdir -p "$backup_dir"

    print_info "Creating backup..."
    docker run --rm \
        --volumes-from grafana \
        -v "$backup_dir:/backup" \
        alpine:latest \
        tar czf "/backup/$(basename $backup_file)" -C /var/lib/grafana .

    print_success "Backup created: $backup_file"
}

# Restore Grafana data
restore_grafana() {
    local backup_file=$1

    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        print_info "Usage: $0 restore <backup-file>"
        exit 1
    fi

    print_header "Restore Grafana Data"
    print_warning "This will overwrite existing Grafana data!"
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        print_info "Stopping Grafana..."
        docker compose -f "$COMPOSE_FILE" stop grafana

        print_info "Restoring backup..."
        docker run --rm \
            --volumes-from grafana \
            -v "$(dirname $backup_file):/backup" \
            alpine:latest \
            sh -c "cd /var/lib/grafana && tar xzf /backup/$(basename $backup_file)"

        print_info "Starting Grafana..."
        docker compose -f "$COMPOSE_FILE" start grafana

        print_success "Restore completed"
    else
        print_info "Restore cancelled"
    fi
}

# Add Windows server to monitoring
add_windows_server() {
    local server_ip=$1
    local server_name=$2

    if [ -z "$server_ip" ] || [ -z "$server_name" ]; then
        print_error "Missing parameters"
        print_info "Usage: $0 add-server <server-ip> <server-name>"
        exit 1
    fi

    print_header "Adding Windows Server to Monitoring"

    local prometheus_config="$SCRIPT_DIR/prometheus/prometheus.yml"

    print_info "Adding $server_name ($server_ip) to Prometheus configuration..."

    # Check if server already exists
    if grep -q "$server_ip:9182" "$prometheus_config"; then
        print_warning "Server already exists in configuration"
        exit 0
    fi

    # Add server to windows-servers job (uncomment and add)
    # This is a simplified approach - manual editing may be needed
    print_warning "Please manually add the following to $prometheus_config:"
    echo ""
    echo "          - '$server_ip:9182'  # $server_name"
    echo ""
    print_info "Then restart Prometheus: $0 restart"
}

# Show help
show_help() {
    cat << EOF
Monitoring Stack Management Script

Usage: $0 <command> [options]

Commands:
  start              Start the monitoring stack
  stop               Stop the monitoring stack
  restart            Restart the monitoring stack
  status             Show status of all containers
  logs [service]     Show logs (all or specific service)
  urls               Show access URLs
  update             Update all containers to latest versions
  cleanup            Remove containers and volumes (destructive!)
  backup             Backup Grafana data
  restore <file>     Restore Grafana data from backup
  add-server <ip> <name>  Add Windows server to monitoring
  help               Show this help message

Services:
  grafana, prometheus, node-exporter, cadvisor, graph-api-proxy, alertmanager

Examples:
  $0 start                           # Start all services
  $0 logs grafana                    # Show Grafana logs
  $0 add-server 192.168.1.10 srv01   # Add Windows server

EOF
}

# Main script logic
main() {
    local command=$1
    shift

    case "$command" in
        start)
            start_stack
            ;;
        stop)
            stop_stack
            ;;
        restart)
            restart_stack
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$@"
            ;;
        urls)
            show_urls
            ;;
        update)
            update_stack
            ;;
        cleanup)
            cleanup_stack
            ;;
        backup)
            backup_grafana
            ;;
        restore)
            restore_grafana "$@"
            ;;
        add-server)
            add_windows_server "$@"
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
