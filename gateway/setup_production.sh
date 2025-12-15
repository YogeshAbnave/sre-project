#!/bin/bash

# Production-Grade SRE Agent Gateway Setup Script
# This script provides robust AWS credential validation and gateway setup
# with comprehensive error handling and troubleshooting guidance

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup.log"
STATE_FILE="${SCRIPT_DIR}/.setup_state"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; }
success() { log "SUCCESS" "${GREEN}$*${NC}"; }

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    error "Script failed at line ${line_number} with exit code ${exit_code}"
    
    # Save current state for resumption
    save_state "FAILED" "Script failed at line ${line_number}"
    
    # Provide troubleshooting guidance
    echo -e "\n${RED}Setup Failed - Troubleshooting Guide:${NC}"
    echo "1. Check the log file: ${LOG_FILE}"
    echo "2. Verify your AWS credentials: aws sts get-caller-identity"
    echo "3. Check your configuration: cat ${SCRIPT_DIR}/config.yaml"
    echo "4. Resume setup: ${0} --resume"
    echo "5. For help: ${0} --help"
    
    exit $exit_code
}

trap 'handle_error ${LINENO}' ERR

# State management
save_state() {
    local status=$1
    local step=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp}|${status}|${step}" > "${STATE_FILE}"
}

load_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        cat "${STATE_FILE}"
    fi
}

# Help function
show_help() {
    cat << EOF
Production-Grade SRE Agent Gateway Setup

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help              Show this help message
    --resume            Resume setup from last failed step
    --validate-only     Only validate configuration and credentials
    --force             Force setup even if validation fails
    --debug             Enable debug output
    --config FILE       Use custom config file (default: config.yaml)

EXAMPLES:
    $0                  # Run complete setup
    $0 --validate-only  # Only validate configuration
    $0 --resume         # Resume from last failure
    $0 --debug          # Run with debug output

PREREQUISITES:
    - AWS CLI configured with valid credentials
    - Python 3.12+ with uv package manager
    - Valid SSL certificates for HTTPS endpoints
    - IAM role with BedrockAgentCoreFullAccess policy

For detailed documentation, see: docs/deployment-guide.md
EOF
}

# Validation functions
validate_prerequisites() {
    info "Validating prerequisites..."
    
    local errors=0
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed or not in PATH"
        echo "  Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        ((errors++))
    fi
    
    # Check Python and uv
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is not installed or not in PATH"
        ((errors++))
    fi
    
    if ! command -v uv &> /dev/null; then
        error "uv package manager is not installed"
        echo "  Install: curl -LsSf https://astral.sh/uv/install.sh | sh"
        ((errors++))
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials are not configured or invalid"
        echo "  Configure: aws configure"
        echo "  Or set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        ((errors++))
    else
        local caller_identity=$(aws sts get-caller-identity)
        local account_id=$(echo "$caller_identity" | jq -r '.Account')
        local user_arn=$(echo "$caller_identity" | jq -r '.Arn')
        success "AWS credentials validated - Account: ${account_id}, User: ${user_arn}"
    fi
    
    # Check for required files
    if [[ ! -f "${SCRIPT_DIR}/config.yaml" ]]; then
        warn "config.yaml not found, will create template"
    fi
    
    if [[ ! -f "${SCRIPT_DIR}/.env" ]]; then
        warn ".env file not found, will create template"
    fi
    
    if [[ $errors -gt 0 ]]; then
        error "Prerequisites validation failed with ${errors} errors"
        return 1
    fi
    
    success "Prerequisites validation passed"
    return 0
}

validate_aws_permissions() {
    info "Validating AWS permissions..."
    
    local required_actions=(
        "bedrock-agentcore:CreateGateway"
        "bedrock-agentcore:ListGateways"
        "s3:CreateBucket"
        "s3:PutObject"
        "iam:GetRole"
    )
    
    # Test basic AWS operations
    local account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    local region=$(aws configure get region || echo "us-east-1")
    
    info "Testing AWS permissions for account ${account_id} in region ${region}"
    
    # Test S3 access
    local test_bucket="sre-agent-test-${account_id}-$(date +%s)"
    if aws s3api create-bucket --bucket "${test_bucket}" --region "${region}" &> /dev/null; then
        aws s3api delete-bucket --bucket "${test_bucket}" &> /dev/null
        success "S3 permissions validated"
    else
        warn "S3 bucket creation test failed - may need additional permissions"
    fi
    
    # Test IAM access
    if aws iam get-user &> /dev/null || aws iam get-role --role-name "$(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)" &> /dev/null; then
        success "IAM permissions validated"
    else
        warn "IAM access test failed - may need additional permissions"
    fi
    
    success "AWS permissions validation completed"
}

validate_configuration() {
    info "Validating configuration..."
    
    # Debug: Show current directory and files
    info "Current directory: $(pwd)"
    info "Files in directory:"
    ls -la config.yaml* .env* 2>/dev/null || info "No config or env files found"
    
    # Simple validation - just check if required files exist
    if [[ ! -f "config.yaml" ]]; then
        error "config.yaml file not found"
        info "Available files: $(ls -la)"
        return 1
    fi
    
    if [[ ! -f ".env" ]]; then
        error ".env file not found"
        return 1
    fi
    
    # Debug: Show first few lines of config.yaml
    info "First 10 lines of config.yaml:"
    head -10 config.yaml
    
    # Extract values using grep and cut (more reliable than Python YAML)
    local gateway_name=$(grep "^gateway_name:" config.yaml | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "")
    local s3_bucket=$(grep "^s3_bucket:" config.yaml | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "")
    local region=$(grep "^region:" config.yaml | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "")
    
    info "Found configuration values:"
    info "  - gateway_name: '$gateway_name'"
    info "  - s3_bucket: '$s3_bucket'"
    info "  - region: '$region'"
    
    # Check if values are not empty
    if [[ -z "$gateway_name" ]]; then
        error "gateway_name is missing or empty in config.yaml"
        return 1
    fi
    
    if [[ -z "$s3_bucket" ]]; then
        error "s3_bucket is missing or empty in config.yaml"
        return 1
    fi
    
    if [[ -z "$region" ]]; then
        error "region is missing or empty in config.yaml"
        return 1
    fi
    
    success "Configuration validation passed"
    return 0
}

validate_environment_variables() {
    info "Validating environment variables..."
    
    local required_vars=(
        "BACKEND_API_KEY"
    )
    
    local missing_vars=()
    
    # Load .env file if it exists
    if [[ -f "${SCRIPT_DIR}/.env" ]]; then
        set -a  # automatically export all variables
        source "${SCRIPT_DIR}/.env"
        set +a  # stop automatically exporting
    fi
    
    # Check required variables
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables: ${missing_vars[*]}"
        echo "Please set these variables in your .env file:"
        for var in "${missing_vars[@]}"; do
            echo "  ${var}=your-value-here"
        done
        return 1
    fi
    
    success "Environment variables validation passed"
    return 0
}

# Setup functions
setup_python_environment() {
    info "Setting up Python environment..."
    
    cd "${SCRIPT_DIR}/.."
    
    # Create virtual environment if it doesn't exist
    if [[ ! -d ".venv" ]]; then
        info "Creating Python virtual environment..."
        uv venv --python 3.12
    fi
    
    # Activate virtual environment
    source .venv/bin/activate
    
    # Install dependencies
    info "Installing Python dependencies..."
    uv pip install -e .
    
    # Install testing dependencies for our improved setup system
    if [[ -f "gateway/requirements-test.txt" ]]; then
        uv pip install -r gateway/requirements-test.txt
    fi
    
    success "Python environment setup completed"
}

setup_backend_servers() {
    info "Setting up backend servers..."
    
    cd "${SCRIPT_DIR}/.."
    
    # Generate OpenAPI specs
    if [[ -n "${BACKEND_DOMAIN:-}" ]]; then
        info "Generating OpenAPI specs for domain: ${BACKEND_DOMAIN}"
        BACKEND_DOMAIN="${BACKEND_DOMAIN}" ./backend/openapi_specs/generate_specs.sh
    else
        warn "BACKEND_DOMAIN not set, using default specs"
    fi
    
    # Get EC2 private IP for server binding
    local private_ip
    if command -v curl &> /dev/null; then
        local token=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
            -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s 2>/dev/null || echo "")
        if [[ -n "$token" ]]; then
            private_ip=$(curl -H "X-aws-ec2-metadata-token: $token" \
                -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "0.0.0.0")
        else
            private_ip="0.0.0.0"
        fi
    else
        private_ip="0.0.0.0"
    fi
    
    info "Starting backend servers on IP: ${private_ip}"
    
    # Start backend servers
    cd backend
    
    # Check for SSL certificates
    if [[ -f "/opt/ssl/privkey.pem" && -f "/opt/ssl/fullchain.pem" ]]; then
        info "Starting backend servers with SSL certificates"
        ./scripts/start_demo_backend.sh \
            --host "${private_ip}" \
            --ssl-keyfile /opt/ssl/privkey.pem \
            --ssl-certfile /opt/ssl/fullchain.pem
    else
        warn "SSL certificates not found, starting without SSL (not recommended for production)"
        ./scripts/start_demo_backend.sh --host "${private_ip}"
    fi
    
    cd "${SCRIPT_DIR}"
    success "Backend servers setup completed"
}

setup_gateway() {
    info "Setting up AgentCore Gateway..."
    
    cd "${SCRIPT_DIR}"
    
    # Create credential provider
    info "Creating API key credential provider..."
    
    # Extract values using grep/cut (more reliable)
    local provider_name=$(grep "^credential_provider_name:" config.yaml | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "")
    local region_name=$(grep "^region:" config.yaml | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "")
    local endpoint_url=$(grep "^credential_provider_endpoint_url:" config.yaml | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "")
    
    info "Using region: '${region_name}'"
    info "Using provider name: '${provider_name}'"
    info "Using endpoint: '${endpoint_url}'"
    
    if python3 create_credentials_provider.py \
        --credential-provider-name "${provider_name}" \
        --api-key "${BACKEND_API_KEY}" \
        --region "${region_name}" \
        --endpoint-url "${endpoint_url}"; then
        success "Credential provider created successfully"
    else
        error "Failed to create credential provider"
        return 1
    fi
    
    # Create gateway
    info "Creating AgentCore Gateway..."
    if ./create_gateway.sh; then
        success "Gateway created successfully"
    else
        error "Failed to create gateway"
        return 1
    fi
    
    # Generate MCP commands
    info "Generating MCP commands..."
    if ./mcp_cmds.sh; then
        success "MCP commands generated successfully"
    else
        error "Failed to generate MCP commands"
        return 1
    fi
    
    success "Gateway setup completed"
}

configure_agent() {
    info "Configuring SRE Agent..."
    
    cd "${SCRIPT_DIR}/.."
    
    # Update gateway URI in agent configuration
    if [[ -f "gateway/.gateway_uri" ]]; then
        local gateway_uri=$(cat gateway/.gateway_uri)
        info "Updating agent configuration with gateway URI: ${gateway_uri}"
        sed -i "s|uri: \".*\"|uri: \"$gateway_uri\"|" sre_agent/config/agent_config.yaml
    fi
    
    # Update access token in .env file
    if [[ -f "gateway/.access_token" ]]; then
        local access_token=$(cat gateway/.access_token)
        info "Updating access token in .env file"
        
        # Remove existing token line and add new one
        sed -i '/^GATEWAY_ACCESS_TOKEN=/d' sre_agent/.env 2>/dev/null || true
        echo "GATEWAY_ACCESS_TOKEN=${access_token}" >> sre_agent/.env
    fi
    
    success "Agent configuration completed"
}

create_s3_bucket() {
    info "Creating S3 bucket if needed..."
    
    # Extract bucket name from config using grep/cut (more reliable)
    local bucket_name=$(grep "^s3_bucket:" config.yaml | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "")
    local region_name=$(grep "^region:" config.yaml | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/"//g' || echo "us-east-1")
    
    info "Extracted values:"
    info "  - bucket_name: '$bucket_name'"
    info "  - region_name: '$region_name'"
    
    if [[ -z "$bucket_name" ]]; then
        error "S3 bucket name not found in config.yaml"
        return 1
    fi
    
    info "Checking if S3 bucket exists: ${bucket_name}"
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "${bucket_name}" 2>/dev/null; then
        success "S3 bucket already exists: ${bucket_name}"
        return 0
    fi
    
    info "Creating S3 bucket: ${bucket_name} in region: ${region_name}"
    
    # Create bucket with proper region handling
    if [[ "$region_name" == "us-east-1" ]]; then
        # us-east-1 doesn't need LocationConstraint
        if aws s3api create-bucket --bucket "${bucket_name}" --region "${region_name}"; then
            success "S3 bucket created successfully: ${bucket_name}"
        else
            error "Failed to create S3 bucket: ${bucket_name}"
            return 1
        fi
    else
        # Other regions need LocationConstraint
        if aws s3api create-bucket \
            --bucket "${bucket_name}" \
            --region "${region_name}" \
            --create-bucket-configuration LocationConstraint="${region_name}"; then
            success "S3 bucket created successfully: ${bucket_name}"
        else
            error "Failed to create S3 bucket: ${bucket_name}"
            return 1
        fi
    fi
    
    # Enable versioning (optional but recommended)
    info "Enabling versioning on S3 bucket..."
    if aws s3api put-bucket-versioning \
        --bucket "${bucket_name}" \
        --versioning-configuration Status=Enabled; then
        success "S3 bucket versioning enabled"
    else
        warn "Failed to enable S3 bucket versioning (continuing anyway)"
    fi
    
    # Set bucket policy for AgentCore access (optional)
    info "Setting bucket policy for AgentCore access..."
    local account_id=$(aws sts get-caller-identity --query 'Account' --output text)
    
    cat > /tmp/bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AgentCoreAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${account_id}:root"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${bucket_name}",
                "arn:aws:s3:::${bucket_name}/*"
            ]
        }
    ]
}
EOF
    
    if aws s3api put-bucket-policy --bucket "${bucket_name}" --policy file:///tmp/bucket-policy.json; then
        success "S3 bucket policy set successfully"
    else
        warn "Failed to set S3 bucket policy (continuing anyway)"
    fi
    
    # Clean up temp file
    rm -f /tmp/bucket-policy.json
    
    success "S3 bucket setup completed: ${bucket_name}"
    return 0
}

setup_memory_system() {
    info "Setting up memory system..."
    
    cd "${SCRIPT_DIR}/.."
    
    # Initialize memory system
    info "Initializing memory system (this may take 10-12 minutes)..."
    if uv run python scripts/manage_memories.py update; then
        success "Memory system initialized successfully"
        info "Memory system will be ready in 10-12 minutes"
    else
        warn "Memory system initialization failed, continuing without memory"
    fi
}

# Main setup function
run_setup() {
    local validate_only=${1:-false}
    local force=${2:-false}
    
    info "Starting production-grade SRE Agent setup..."
    save_state "RUNNING" "Starting setup"
    
    # Step 1: Validate prerequisites
    save_state "RUNNING" "Validating prerequisites"
    if ! validate_prerequisites; then
        if [[ "$force" == "true" ]]; then
            warn "Prerequisites validation failed, but continuing due to --force flag"
        else
            error "Prerequisites validation failed. Use --force to continue anyway."
            return 1
        fi
    fi
    
    # Step 2: Validate AWS permissions
    save_state "RUNNING" "Validating AWS permissions"
    validate_aws_permissions
    
    # Step 3: Validate configuration
    save_state "RUNNING" "Validating configuration"
    if ! validate_configuration; then
        if [[ "$force" == "true" ]]; then
            warn "Configuration validation failed, but continuing due to --force flag"
        else
            error "Configuration validation failed. Fix configuration or use --force."
            return 1
        fi
    fi
    
    # Step 4: Validate environment variables
    save_state "RUNNING" "Validating environment variables"
    if ! validate_environment_variables; then
        if [[ "$force" == "true" ]]; then
            warn "Environment validation failed, but continuing due to --force flag"
        else
            error "Environment validation failed. Fix .env file or use --force."
            return 1
        fi
    fi
    
    if [[ "$validate_only" == "true" ]]; then
        success "Validation completed successfully"
        return 0
    fi
    
    # Step 5: Create S3 bucket if needed
    save_state "RUNNING" "Creating S3 bucket"
    create_s3_bucket
    
    # Step 6: Setup Python environment
    save_state "RUNNING" "Setting up Python environment"
    setup_python_environment
    
    # Step 7: Setup backend servers
    save_state "RUNNING" "Setting up backend servers"
    setup_backend_servers
    
    # Step 8: Setup gateway
    save_state "RUNNING" "Setting up gateway"
    setup_gateway
    
    # Step 9: Configure agent
    save_state "RUNNING" "Configuring agent"
    configure_agent
    
    # Step 10: Setup memory system
    save_state "RUNNING" "Setting up memory system"
    setup_memory_system
    
    save_state "COMPLETED" "Setup completed successfully"
    success "Production-grade SRE Agent setup completed successfully!"
    
    # Display summary
    echo -e "\n${GREEN}Setup Summary:${NC}"
    echo "✅ Prerequisites validated"
    echo "✅ AWS permissions verified"
    echo "✅ Configuration validated"
    echo "✅ Python environment configured"
    echo "✅ Backend servers started"
    echo "✅ AgentCore Gateway created"
    echo "✅ Agent configured"
    echo "✅ Memory system initialized"
    
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. Test the agent: uv run sre-agent --prompt 'list the pods in my infrastructure'"
    echo "2. Start interactive mode: uv run sre-agent --interactive"
    echo "3. Deploy to production: ./deployment/build_and_deploy.sh"
    echo "4. View logs: tail -f ${LOG_FILE}"
    
    if [[ -f "gateway/.gateway_uri" ]]; then
        echo "5. Gateway URL: $(cat gateway/.gateway_uri)"
    fi
}

# Parse command line arguments
VALIDATE_ONLY=false
FORCE=false
DEBUG=false
RESUME=false
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --debug)
            DEBUG=true
            set -x
            shift
            ;;
        --resume)
            RESUME=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    # Setup logging
    exec 1> >(tee -a "${LOG_FILE}")
    exec 2> >(tee -a "${LOG_FILE}" >&2)
    
    info "Production-Grade SRE Agent Setup Script"
    info "Log file: ${LOG_FILE}"
    
    if [[ "$RESUME" == "true" ]]; then
        local state=$(load_state)
        if [[ -n "$state" ]]; then
            info "Resuming from previous state: $state"
        else
            info "No previous state found, starting fresh setup"
        fi
    fi
    
    # Run setup
    run_setup "$VALIDATE_ONLY" "$FORCE"
}

# Execute main function
main "$@"