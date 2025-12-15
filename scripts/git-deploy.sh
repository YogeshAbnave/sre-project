#!/bin/bash

# Git-Based SRE Agent Deployment Script
# This script handles deployment from a Git repository on EC2

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
INSTALL_DIR="/opt/sre-agent"
GIT_REPO="${GIT_REPO:-https://github.com/YogeshAbnave/sre-project.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"
DOMAIN_NAME="${DOMAIN_NAME:-}"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --repo URL          Git repository URL"
    echo "  --branch BRANCH     Git branch to deploy (default: main)"
    echo "  --domain DOMAIN     Domain name for SSL certificates"
    echo "  --update            Update existing installation"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  GIT_REPO           Git repository URL"
    echo "  GIT_BRANCH         Git branch (default: main)"
    echo "  DOMAIN_NAME        Domain name for SSL"
    echo "  PROJECT_NAME       Project name (default: sre-agent)"
    echo "  ENVIRONMENT        Environment (default: production)"
    echo ""
    echo "Examples:"
    echo "  $0 --repo https://github.com/YogeshAbnave/sre-project.git"
    echo "  $0 --repo git@github.com:YogeshAbnave/sre-project.git --branch develop"
    echo "  $0 --update"
}

# Parse command line arguments
UPDATE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            GIT_REPO="$2"
            shift 2
            ;;
        --branch)
            GIT_BRANCH="$2"
            shift 2
            ;;
        --domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        --update)
            UPDATE_MODE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check if running as correct user
check_user() {
    if [ "$EUID" -eq 0 ]; then
        log_error "This script should not be run as root. Please run as ec2-user."
        exit 1
    fi
}

# Function to install prerequisites
install_prerequisites() {
    log_info "Installing prerequisites..."
    
    # Update system
    sudo yum update -y
    
    # Install required packages
    sudo yum install -y git curl wget unzip jq python3 python3-pip docker
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -a -G docker ec2-user
    
    # Install AWS CLI v2 if not present
    if ! command -v aws &> /dev/null; then
        log_info "Installing AWS CLI v2..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    fi
    
    # Install UV package manager if not present
    if ! command -v uv &> /dev/null; then
        log_info "Installing UV package manager..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        source ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    log_success "Prerequisites installed"
}

# Function to clone or update repository
setup_repository() {
    log_info "Setting up repository..."
    
    if [ "$UPDATE_MODE" = true ]; then
        if [ -d "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR/.git" ]; then
            log_info "Updating existing repository..."
            cd "$INSTALL_DIR"
            
            # Stop service before update
            if systemctl is-active --quiet sre-agent; then
                log_info "Stopping SRE Agent service..."
                sudo systemctl stop sre-agent
            fi
            
            # Stash any local changes
            git stash push -m "Auto-stash before update $(date)"
            
            # Pull latest changes
            git fetch origin
            git checkout "$GIT_BRANCH"
            git pull origin "$GIT_BRANCH"
            
            log_success "Repository updated to latest $GIT_BRANCH"
        else
            log_error "No existing repository found for update mode"
            exit 1
        fi
    else
        if [ -z "$GIT_REPO" ]; then
            log_error "Git repository URL is required for initial deployment"
            log_error "Use --repo option or set GIT_REPO environment variable"
            exit 1
        fi
        
        # Backup existing directory if it exists
        if [ -d "$INSTALL_DIR" ]; then
            log_warning "Existing installation found. Creating backup..."
            sudo mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Create installation directory
        sudo mkdir -p "$INSTALL_DIR"
        sudo chown ec2-user:ec2-user "$INSTALL_DIR"
        
        # Clone repository
        log_info "Cloning repository: $GIT_REPO"
        git clone -b "$GIT_BRANCH" "$GIT_REPO" "$INSTALL_DIR"
        
        # Set ownership
        sudo chown -R ec2-user:ec2-user "$INSTALL_DIR"
        
        log_success "Repository cloned successfully"
    fi
    
    cd "$INSTALL_DIR"
    
    # Show current status
    log_info "Current repository status:"
    echo "  Repository: $(git remote get-url origin)"
    echo "  Branch: $(git branch --show-current)"
    echo "  Commit: $(git log --oneline -1)"
}

# Function to get AWS configuration
get_aws_config() {
    log_info "Getting AWS configuration..."
    
    # Test AWS access
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "AWS CLI is not configured or lacks permissions"
        log_error "Please configure AWS CLI or ensure IAM role is attached"
        exit 1
    fi
    
    # Get configuration from SSM if available
    export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    export AWS_REGION=$(aws configure get region || echo "us-east-1")
    
    # Try to get configuration from SSM Parameter Store
    export S3_BUCKET=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/s3_bucket" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    export USER_POOL_ID=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/user_pool_id" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    export CLIENT_ID=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/client_id" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    # Get instance metadata
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s 2>/dev/null || echo "")
    if [ -n "$TOKEN" ]; then
        export INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "")
        export PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "localhost")
        export PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
    else
        export PRIVATE_IP="localhost"
        export PUBLIC_IP=""
    fi
    
    log_success "AWS configuration retrieved"
    log_info "Account ID: ${AWS_ACCOUNT_ID}"
    log_info "Region: ${AWS_REGION}"
    log_info "Instance ID: ${INSTANCE_ID:-N/A}"
    log_info "Private IP: ${PRIVATE_IP}"
}

# Function to install Python dependencies
install_dependencies() {
    log_info "Installing Python dependencies..."
    
    cd "$INSTALL_DIR"
    
    # Create virtual environment
    uv venv --python 3.12
    source .venv/bin/activate
    
    # Install dependencies
    uv pip install -e .
    
    log_success "Dependencies installed"
}

# Function to configure environment
configure_environment() {
    log_info "Configuring environment..."
    
    cd "$INSTALL_DIR"
    
    # Create sre_agent/.env if it doesn't exist
    if [ ! -f "sre_agent/.env" ]; then
        log_info "Creating sre_agent/.env file..."
        cat > sre_agent/.env << EOF
# SRE Agent Environment Variables
# Generated by git-deploy.sh on $(date)

# User ID for memory and session tracking
USER_ID=production-admin

# LLM Provider Configuration
LLM_PROVIDER=bedrock

# AWS Configuration
AWS_DEFAULT_REGION=${AWS_REGION}

# Gateway Access Token (will be generated later)
GATEWAY_ACCESS_TOKEN=

# Optional: Debug settings
DEBUG=false
LOG_LEVEL=INFO
EOF
    else
        log_info "Using existing sre_agent/.env file"
    fi
    
    # Create gateway/.env if it doesn't exist and we have the required info
    if [ ! -f "gateway/.env" ] && [ -n "$USER_POOL_ID" ] && [ -n "$CLIENT_ID" ]; then
        log_info "Creating gateway/.env file..."
        mkdir -p gateway
        cat > gateway/.env << EOF
# Gateway Environment Variables
# Generated by git-deploy.sh on $(date)

# Cognito Configuration
COGNITO_DOMAIN=https://${PROJECT_NAME}-${ENVIRONMENT}-${AWS_ACCOUNT_ID}.auth.${AWS_REGION}.amazoncognito.com
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_USER_POOL_ID=${USER_POOL_ID}

# Backend API Key (generate a secure key)
BACKEND_API_KEY=$(openssl rand -hex 32)
EOF
    fi
    
    # Create gateway/config.yaml if it doesn't exist and we have the required info
    if [ ! -f "gateway/config.yaml" ] && [ -n "$S3_BUCKET" ] && [ -n "$USER_POOL_ID" ]; then
        log_info "Creating gateway/config.yaml file..."
        cat > gateway/config.yaml << EOF
# AgentCore Gateway Configuration
# Generated by git-deploy.sh on $(date)

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
    fi
    
    log_success "Environment configuration completed"
}

# Function to run the main deployment script
run_deployment() {
    log_info "Running main deployment script..."
    
    cd "$INSTALL_DIR"
    
    # Make deployment script executable
    chmod +x scripts/deploy-sre-agent.sh
    
    # Set environment variables for deployment script
    export PROJECT_NAME="$PROJECT_NAME"
    export ENVIRONMENT="$ENVIRONMENT"
    export DOMAIN_NAME="$DOMAIN_NAME"
    
    # Run deployment script
    ./scripts/deploy-sre-agent.sh
    
    log_success "Main deployment completed"
}

# Function to start services
start_services() {
    log_info "Starting services..."
    
    # Start and enable SRE Agent service
    if [ -f "/etc/systemd/system/sre-agent.service" ]; then
        sudo systemctl daemon-reload
        sudo systemctl enable sre-agent
        sudo systemctl start sre-agent
        
        # Wait a moment for service to start
        sleep 3
        
        if systemctl is-active --quiet sre-agent; then
            log_success "SRE Agent service started successfully"
        else
            log_warning "SRE Agent service may not have started properly"
            log_info "Check status with: sudo systemctl status sre-agent"
        fi
    else
        log_warning "Systemd service file not found. Service may need manual start."
    fi
}

# Function to run validation
run_validation() {
    log_info "Running validation tests..."
    
    cd "$INSTALL_DIR"
    
    if [ -f "scripts/validate-deployment.sh" ]; then
        chmod +x scripts/validate-deployment.sh
        ./scripts/validate-deployment.sh
    else
        log_warning "Validation script not found. Skipping validation."
    fi
}

# Function to display deployment summary
display_summary() {
    log_info "🎉 Git-based deployment completed!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "  Repository: $(cd "$INSTALL_DIR" && git remote get-url origin)"
    echo "  Branch: $(cd "$INSTALL_DIR" && git branch --show-current)"
    echo "  Commit: $(cd "$INSTALL_DIR" && git log --oneline -1)"
    echo "  Install Directory: $INSTALL_DIR"
    echo "  Private IP: $PRIVATE_IP"
    echo "  Public IP: ${PUBLIC_IP:-N/A}"
    if [ -n "$DOMAIN_NAME" ]; then
        echo "  Domain: $DOMAIN_NAME"
    fi
    echo ""
    echo "🚀 Service Management:"
    echo "  Check status: sudo systemctl status sre-agent"
    echo "  View logs: sudo journalctl -u sre-agent -f"
    echo "  Restart: sudo systemctl restart sre-agent"
    echo ""
    echo "🔄 Future Updates:"
    echo "  cd $INSTALL_DIR"
    echo "  git pull origin $GIT_BRANCH"
    echo "  $0 --update"
    echo ""
    echo "🧪 Manual Testing:"
    echo "  cd $INSTALL_DIR"
    echo "  source .venv/bin/activate"
    echo "  uv run sre-agent --prompt 'Test the system'"
}

# Main deployment function
main() {
    log_info "🚀 Starting Git-based SRE Agent Deployment"
    echo ""
    
    check_user
    install_prerequisites
    setup_repository
    get_aws_config
    install_dependencies
    configure_environment
    run_deployment
    start_services
    run_validation
    display_summary
    
    log_success "🎉 Git-based deployment completed successfully!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi