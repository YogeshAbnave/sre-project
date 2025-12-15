#!/bin/bash

# SRE Agent Production Deployment Script
# This script deploys the SRE Agent to a production EC2 instance with full AWS integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
PROJECT_NAME="${PROJECT_NAME:-sre-agent}"
ENVIRONMENT="${ENVIRONMENT:-production}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/YogeshAbnave/sre-project.git}"
BRANCH="${BRANCH:-main}"

# Directories
INSTALL_DIR="/opt/sre-agent"
LOG_DIR="/var/log/sre-agent"
SSL_DIR="/opt/ssl"

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "This script should not be run as root. Please run as ec2-user."
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check if UV is available
    if ! command -v uv &> /dev/null; then
        log_info "Installing UV package manager..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        source ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        log_warning "User is not in docker group. Adding user to docker group..."
        sudo usermod -a -G docker $USER
        log_warning "Please log out and log back in for docker group changes to take effect"
    fi
    
    log_success "Prerequisites check completed"
}

# Function to get AWS configuration from SSM
get_aws_config() {
    log_info "Retrieving AWS configuration from SSM Parameter Store..."
    
    export AWS_ACCOUNT_ID=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/account_id" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    export AWS_REGION=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/region" --query 'Parameter.Value' --output text 2>/dev/null || aws configure get region)
    export S3_BUCKET=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/s3_bucket" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    export USER_POOL_ID=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/user_pool_id" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    export CLIENT_ID=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/client_id" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    # Get instance metadata
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
    export INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
    export PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
    export PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    log_success "AWS configuration retrieved"
    log_info "Account ID: ${AWS_ACCOUNT_ID}"
    log_info "Region: ${AWS_REGION}"
    log_info "S3 Bucket: ${S3_BUCKET}"
    log_info "Instance ID: ${INSTANCE_ID}"
    log_info "Private IP: ${PRIVATE_IP}"
    log_info "Public IP: ${PUBLIC_IP}"
}

# Function to clone and setup repository
setup_repository() {
    log_info "Setting up SRE Agent repository..."
    
    if [ -d "$INSTALL_DIR" ]; then
        log_warning "Installation directory exists. Backing up..."
        sudo mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Clone repository
    log_info "Cloning repository from $GITHUB_REPO..."
    git clone -b "$BRANCH" "$GITHUB_REPO" /tmp/sre-agent-repo
    
    # Move to installation directory
    sudo mkdir -p "$INSTALL_DIR"
    sudo cp -r /tmp/sre-agent-repo/* "$INSTALL_DIR/"
    sudo chown -R ec2-user:ec2-user "$INSTALL_DIR"
    
    # Cleanup
    rm -rf /tmp/sre-agent-repo
    
    cd "$INSTALL_DIR"
    log_success "Repository setup completed"
}

# Function to setup SSL certificates
setup_ssl_certificates() {
    log_info "Setting up SSL certificates..."
    
    if [ -z "$DOMAIN_NAME" ]; then
        log_warning "No domain name provided. SSL setup will be skipped."
        log_warning "You can set up SSL later by running: sudo certbot certonly --standalone -d your-domain.com"
        return
    fi
    
    # Check if certificates already exist
    if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
        log_info "SSL certificates already exist for $DOMAIN_NAME"
        sudo ln -sf "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" "$SSL_DIR/fullchain.pem"
        sudo ln -sf "/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem" "$SSL_DIR/privkey.pem"
    else
        log_info "Obtaining SSL certificate for $DOMAIN_NAME..."
        
        # Stop any services that might be using port 80
        sudo systemctl stop nginx 2>/dev/null || true
        sudo systemctl stop apache2 2>/dev/null || true
        
        # Obtain certificate
        sudo certbot certonly --standalone --non-interactive --agree-tos --email admin@$DOMAIN_NAME -d "$DOMAIN_NAME"
        
        # Create symlinks
        sudo mkdir -p "$SSL_DIR"
        sudo ln -sf "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" "$SSL_DIR/fullchain.pem"
        sudo ln -sf "/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem" "$SSL_DIR/privkey.pem"
        
        # Set up auto-renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
    fi
    
    log_success "SSL certificates configured"
}

# Function to install Python dependencies
install_dependencies() {
    log_info "Installing Python dependencies..."
    
    cd "$INSTALL_DIR"
    
    # Create virtual environment and install dependencies
    uv venv --python 3.12
    source .venv/bin/activate
    uv pip install -e .
    
    log_success "Dependencies installed"
}

# Function to configure environment
configure_environment() {
    log_info "Configuring environment variables..."
    
    cd "$INSTALL_DIR"
    
    # Create sre_agent/.env file
    cat > sre_agent/.env << EOF
# SRE Agent Environment Variables
# Generated by deploy-sre-agent.sh on $(date)

# User ID for memory and session tracking
USER_ID=production-admin

# LLM Provider Configuration
LLM_PROVIDER=bedrock

# AWS Configuration
AWS_DEFAULT_REGION=${AWS_REGION}

# Gateway Access Token (will be generated later)
GATEWAY_ACCESS_TOKEN=

# Optional: Debug settings for production
DEBUG=false
LOG_LEVEL=INFO
EOF
    
    # Create gateway/.env file
    mkdir -p gateway
    cat > gateway/.env << EOF
# Gateway Environment Variables
# Generated by deploy-sre-agent.sh on $(date)

# Cognito Configuration
COGNITO_DOMAIN=https://${PROJECT_NAME}-${ENVIRONMENT}-${AWS_ACCOUNT_ID}.auth.${AWS_REGION}.amazoncognito.com
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_USER_POOL_ID=${USER_POOL_ID}

# Backend API Key (generate a secure key)
BACKEND_API_KEY=$(openssl rand -hex 32)
EOF
    
    # Create gateway/config.yaml
    cat > gateway/config.yaml << EOF
# AgentCore Gateway Configuration
# Generated by deploy-sre-agent.sh on $(date)

# AWS Configuration
account_id: "${AWS_ACCOUNT_ID}"
region: "${AWS_REGION}"
role_name: "${PROJECT_NAME}-${ENVIRONMENT}-ec2-role"
endpoint_url: "https://bedrock-agentcore-control.${AWS_REGION}.amazonaws.com"
credential_provider_endpoint_url: "https://${AWS_REGION}.prod.agent-credential-provider.cognito.aws.dev"

# Cognito Configuration
user_pool_id: "${USER_POOL_ID}"
client_id: "${CLIENT_ID}"

# S3 Configuration
s3_bucket: "${S3_BUCKET}"
s3_path_prefix: "devops-multiagent-demo"

# Provider Configuration
credential_provider_name: "${PROJECT_NAME}-api-key-credential-provider"
provider_arn: "arn:aws:bedrock-agentcore:${AWS_REGION}:${AWS_ACCOUNT_ID}:token-vault/default/apikeycredentialprovider/${PROJECT_NAME}-api-key-credential-provider"

# Gateway Configuration
gateway_name: "${PROJECT_NAME^}Gateway"
gateway_description: "AgentCore Gateway for ${PROJECT_NAME^} API Integration"

# Target Configuration
target_description: "S3 target for OpenAPI schema"
EOF
    
    log_success "Environment configuration completed"
}

# Function to generate OpenAPI specifications
generate_openapi_specs() {
    log_info "Generating OpenAPI specifications..."
    
    cd "$INSTALL_DIR"
    
    # Set backend domain
    if [ -n "$DOMAIN_NAME" ]; then
        export BACKEND_DOMAIN="$DOMAIN_NAME"
    else
        export BACKEND_DOMAIN="$PUBLIC_IP"
    fi
    
    # Generate specs
    cd backend/openapi_specs
    ./generate_specs.sh
    
    log_success "OpenAPI specifications generated for domain: $BACKEND_DOMAIN"
}

# Function to setup and start backend services
setup_backend_services() {
    log_info "Setting up backend services..."
    
    cd "$INSTALL_DIR"
    
    # Create logs directory
    mkdir -p "$LOG_DIR"
    
    # Determine SSL arguments
    SSL_ARGS=""
    if [ -f "$SSL_DIR/fullchain.pem" ] && [ -f "$SSL_DIR/privkey.pem" ]; then
        SSL_ARGS="--ssl-keyfile $SSL_DIR/privkey.pem --ssl-certfile $SSL_DIR/fullchain.pem"
        log_info "Starting backend services with SSL"
    else
        log_warning "Starting backend services without SSL"
    fi
    
    # Start backend services
    cd backend
    ./scripts/start_demo_backend.sh --host "$PRIVATE_IP" $SSL_ARGS
    
    # Wait for services to start
    sleep 5
    
    # Verify services are running
    if pgrep -f "k8s_server.py" > /dev/null; then
        log_success "Backend services started successfully"
    else
        log_error "Failed to start backend services"
        exit 1
    fi
}

# Function to setup AgentCore Gateway
setup_agentcore_gateway() {
    log_info "Setting up AgentCore Gateway..."
    
    cd "$INSTALL_DIR/gateway"
    
    # Create and configure the gateway
    ./create_gateway.sh
    
    # Run MCP commands
    ./mcp_cmds.sh
    
    # Update agent configuration with gateway URI
    if [ -f ".gateway_uri" ]; then
        GATEWAY_URI=$(cat .gateway_uri)
        sed -i "s|uri: \".*\"|uri: \"$GATEWAY_URI\"|" ../sre_agent/config/agent_config.yaml
        log_success "Gateway URI updated in agent configuration"
    fi
    
    # Update access token in environment
    if [ -f ".access_token" ]; then
        ACCESS_TOKEN=$(cat .access_token)
        sed -i "s|GATEWAY_ACCESS_TOKEN=.*|GATEWAY_ACCESS_TOKEN=$ACCESS_TOKEN|" ../sre_agent/.env
        log_success "Gateway access token updated"
    fi
    
    log_success "AgentCore Gateway setup completed"
}

# Function to setup memory system
setup_memory_system() {
    log_info "Setting up memory system..."
    
    cd "$INSTALL_DIR"
    source .venv/bin/activate
    
    # Initialize memory system
    uv run python scripts/manage_memories.py update
    
    log_success "Memory system initialized"
    log_warning "Memory system takes 10-12 minutes to be fully ready"
}

# Function to create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    # Create service file
    sudo tee /etc/systemd/system/sre-agent.service > /dev/null << EOF
[Unit]
Description=SRE Agent Service
After=network.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=$INSTALL_DIR
Environment=PATH=/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=/etc/environment
ExecStart=/home/ec2-user/.local/bin/uv run sre-agent --interactive
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable sre-agent
    
    log_success "Systemd service created and enabled"
}

# Function to run validation tests
run_validation_tests() {
    log_info "Running validation tests..."
    
    cd "$INSTALL_DIR"
    source .venv/bin/activate
    
    # Test AWS connectivity
    log_info "Testing AWS connectivity..."
    aws sts get-caller-identity > /dev/null && log_success "AWS CLI working" || log_error "AWS CLI failed"
    
    # Test S3 access
    log_info "Testing S3 access..."
    aws s3 ls "s3://$S3_BUCKET" > /dev/null && log_success "S3 access working" || log_error "S3 access failed"
    
    # Test Bedrock access
    log_info "Testing Bedrock access..."
    aws bedrock list-foundation-models --region "$AWS_REGION" > /dev/null && log_success "Bedrock access working" || log_error "Bedrock access failed"
    
    # Test backend services
    log_info "Testing backend services..."
    PROTOCOL="http"
    if [ -f "$SSL_DIR/fullchain.pem" ]; then
        PROTOCOL="https"
    fi
    
    for port in 8011 8012 8013 8014; do
        if curl -k -s "$PROTOCOL://$PRIVATE_IP:$port/health" > /dev/null; then
            log_success "Backend service on port $port is responding"
        else
            log_warning "Backend service on port $port is not responding"
        fi
    done
    
    log_success "Validation tests completed"
}

# Function to display deployment summary
display_summary() {
    log_info "🎉 SRE Agent deployment completed successfully!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "  Project: $PROJECT_NAME"
    echo "  Environment: $ENVIRONMENT"
    echo "  Instance ID: $INSTANCE_ID"
    echo "  Private IP: $PRIVATE_IP"
    echo "  Public IP: $PUBLIC_IP"
    if [ -n "$DOMAIN_NAME" ]; then
        echo "  Domain: $DOMAIN_NAME"
        echo "  SSL: Enabled"
    else
        echo "  SSL: Disabled (no domain configured)"
    fi
    echo ""
    echo "📁 Installation Directory: $INSTALL_DIR"
    echo "📊 Log Directory: $LOG_DIR"
    echo ""
    echo "🚀 Service Management:"
    echo "  Start service: sudo systemctl start sre-agent"
    echo "  Stop service: sudo systemctl stop sre-agent"
    echo "  View logs: sudo journalctl -u sre-agent -f"
    echo ""
    echo "🔧 Manual Testing:"
    echo "  cd $INSTALL_DIR"
    echo "  source .venv/bin/activate"
    echo "  uv run sre-agent --prompt 'Test the system'"
    echo ""
    if [ -n "$DOMAIN_NAME" ]; then
        echo "🌐 Access URLs:"
        echo "  Main Application: https://$DOMAIN_NAME"
        echo "  Backend APIs: https://$DOMAIN_NAME:8011-8014"
    else
        echo "🌐 Access URLs (HTTP only):"
        echo "  Main Application: http://$PUBLIC_IP"
        echo "  Backend APIs: http://$PUBLIC_IP:8011-8014"
    fi
    echo ""
    echo "⚠️  Important Notes:"
    echo "  - Memory system takes 10-12 minutes to be fully ready"
    echo "  - Gateway access token expires every 24 hours"
    echo "  - Run './scripts/configure_gateway.sh' to refresh token"
    echo "  - Check service status: sudo systemctl status sre-agent"
}

# Main deployment function
main() {
    log_info "🚀 Starting SRE Agent Production Deployment"
    echo ""
    
    check_root
    check_prerequisites
    get_aws_config
    setup_repository
    setup_ssl_certificates
    install_dependencies
    configure_environment
    generate_openapi_specs
    setup_backend_services
    setup_agentcore_gateway
    setup_memory_system
    create_systemd_service
    run_validation_tests
    display_summary
    
    log_success "🎉 Deployment completed successfully!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi