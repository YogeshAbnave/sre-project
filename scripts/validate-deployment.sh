#!/bin/bash

# SRE Agent Deployment Validation Script
# This script validates that all components of the SRE Agent are properly deployed and configured

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

# Validation results
VALIDATION_RESULTS=()
FAILED_CHECKS=0
TOTAL_CHECKS=0

# Function to add validation result
add_result() {
    local status=$1
    local message=$2
    VALIDATION_RESULTS+=("$status|$message")
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ "$status" = "FAIL" ]; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Function to check command availability
check_command() {
    local cmd=$1
    local description=$2
    
    if command -v "$cmd" &> /dev/null; then
        log_success "$description is available"
        add_result "PASS" "$description available"
        return 0
    else
        log_error "$description is not available"
        add_result "FAIL" "$description not available"
        return 1
    fi
}

# Function to check service status
check_service() {
    local service=$1
    local description=$2
    
    if systemctl is-active --quiet "$service"; then
        log_success "$description is running"
        add_result "PASS" "$description running"
        return 0
    else
        log_error "$description is not running"
        add_result "FAIL" "$description not running"
        return 1
    fi
}

# Function to check file existence
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        log_success "$description exists"
        add_result "PASS" "$description exists"
        return 0
    else
        log_error "$description does not exist"
        add_result "FAIL" "$description missing"
        return 1
    fi
}

# Function to check directory existence
check_directory() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        log_success "$description exists"
        add_result "PASS" "$description exists"
        return 0
    else
        log_error "$description does not exist"
        add_result "FAIL" "$description missing"
        return 1
    fi
}

# Function to check URL accessibility
check_url() {
    local url=$1
    local description=$2
    local timeout=${3:-10}
    
    if curl -k -s --max-time "$timeout" "$url" > /dev/null; then
        log_success "$description is accessible"
        add_result "PASS" "$description accessible"
        return 0
    else
        log_warning "$description is not accessible"
        add_result "WARN" "$description not accessible"
        return 1
    fi
}

# Function to check AWS connectivity
check_aws_connectivity() {
    log_info "Checking AWS connectivity..."
    
    # Check AWS CLI
    if check_command "aws" "AWS CLI"; then
        # Check AWS credentials
        if aws sts get-caller-identity > /dev/null 2>&1; then
            log_success "AWS credentials are valid"
            add_result "PASS" "AWS credentials valid"
            
            # Get AWS account info
            ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
            REGION=$(aws configure get region || echo "us-east-1")
            log_info "AWS Account: $ACCOUNT_ID"
            log_info "AWS Region: $REGION"
        else
            log_error "AWS credentials are invalid"
            add_result "FAIL" "AWS credentials invalid"
        fi
    fi
}

# Function to check Bedrock access
check_bedrock_access() {
    log_info "Checking Amazon Bedrock access..."
    
    if aws bedrock list-foundation-models --region "${REGION:-us-east-1}" > /dev/null 2>&1; then
        log_success "Bedrock access is working"
        add_result "PASS" "Bedrock access working"
        
        # Check specific models
        local models=$(aws bedrock list-foundation-models --region "${REGION:-us-east-1}" --query 'modelSummaries[?contains(modelId, `claude`)].modelId' --output text)
        if [ -n "$models" ]; then
            log_success "Claude models are available"
            add_result "PASS" "Claude models available"
        else
            log_warning "Claude models not found"
            add_result "WARN" "Claude models not found"
        fi
    else
        log_error "Bedrock access failed"
        add_result "FAIL" "Bedrock access failed"
    fi
}

# Function to check S3 access
check_s3_access() {
    log_info "Checking S3 access..."
    
    # Try to get S3 bucket from SSM or environment
    local s3_bucket="${S3_BUCKET:-}"
    if [ -z "$s3_bucket" ]; then
        s3_bucket=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/s3_bucket" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    fi
    
    if [ -n "$s3_bucket" ]; then
        if aws s3 ls "s3://$s3_bucket" > /dev/null 2>&1; then
            log_success "S3 bucket access is working: $s3_bucket"
            add_result "PASS" "S3 bucket access working"
        else
            log_error "S3 bucket access failed: $s3_bucket"
            add_result "FAIL" "S3 bucket access failed"
        fi
    else
        log_warning "S3 bucket not configured"
        add_result "WARN" "S3 bucket not configured"
    fi
}

# Function to check Cognito access
check_cognito_access() {
    log_info "Checking Cognito access..."
    
    # Try to get user pool ID from SSM or environment
    local user_pool_id="${USER_POOL_ID:-}"
    if [ -z "$user_pool_id" ]; then
        user_pool_id=$(aws ssm get-parameter --name "/${PROJECT_NAME}/config/user_pool_id" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    fi
    
    if [ -n "$user_pool_id" ]; then
        if aws cognito-idp describe-user-pool --user-pool-id "$user_pool_id" > /dev/null 2>&1; then
            log_success "Cognito User Pool access is working: $user_pool_id"
            add_result "PASS" "Cognito access working"
        else
            log_error "Cognito User Pool access failed: $user_pool_id"
            add_result "FAIL" "Cognito access failed"
        fi
    else
        log_warning "Cognito User Pool not configured"
        add_result "WARN" "Cognito not configured"
    fi
}

# Function to check system requirements
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check required commands
    check_command "python3" "Python 3"
    check_command "pip3" "pip3"
    check_command "uv" "UV package manager"
    check_command "docker" "Docker"
    check_command "git" "Git"
    check_command "curl" "curl"
    check_command "jq" "jq"
    
    # Check Python version
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        local major_version=$(echo "$python_version" | cut -d'.' -f1)
        local minor_version=$(echo "$python_version" | cut -d'.' -f2)
        
        if [ "$major_version" -eq 3 ] && [ "$minor_version" -ge 12 ]; then
            log_success "Python version is compatible: $python_version"
            add_result "PASS" "Python version compatible"
        else
            log_error "Python version is too old: $python_version (requires 3.12+)"
            add_result "FAIL" "Python version incompatible"
        fi
    fi
    
    # Check disk space
    local available_space=$(df /opt --output=avail | tail -1)
    if [ "$available_space" -gt 5000000 ]; then  # 5GB in KB
        log_success "Sufficient disk space available"
        add_result "PASS" "Sufficient disk space"
    else
        log_warning "Low disk space available"
        add_result "WARN" "Low disk space"
    fi
    
    # Check memory
    local total_memory=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_memory" -gt 8000 ]; then  # 8GB
        log_success "Sufficient memory available: ${total_memory}MB"
        add_result "PASS" "Sufficient memory"
    else
        log_warning "Limited memory available: ${total_memory}MB"
        add_result "WARN" "Limited memory"
    fi
}

# Function to check installation files
check_installation_files() {
    log_info "Checking installation files..."
    
    # Check main directories
    check_directory "$INSTALL_DIR" "Installation directory"
    check_directory "$INSTALL_DIR/sre_agent" "SRE Agent source directory"
    check_directory "$INSTALL_DIR/gateway" "Gateway directory"
    check_directory "$INSTALL_DIR/backend" "Backend directory"
    
    # Check key files
    check_file "$INSTALL_DIR/pyproject.toml" "Project configuration file"
    check_file "$INSTALL_DIR/sre_agent/.env" "SRE Agent environment file"
    check_file "$INSTALL_DIR/gateway/config.yaml" "Gateway configuration file"
    
    # Check virtual environment
    check_directory "$INSTALL_DIR/.venv" "Python virtual environment"
    check_file "$INSTALL_DIR/.venv/bin/activate" "Virtual environment activation script"
    
    # Check if UV is working in the virtual environment
    if [ -f "$INSTALL_DIR/.venv/bin/activate" ]; then
        cd "$INSTALL_DIR"
        source .venv/bin/activate
        if command -v uv &> /dev/null; then
            log_success "UV is available in virtual environment"
            add_result "PASS" "UV in virtual environment"
        else
            log_error "UV is not available in virtual environment"
            add_result "FAIL" "UV not in virtual environment"
        fi
    fi
}

# Function to check SSL certificates
check_ssl_certificates() {
    log_info "Checking SSL certificates..."
    
    # Check for Let's Encrypt certificates
    if [ -d "/etc/letsencrypt/live" ]; then
        local cert_dirs=$(ls /etc/letsencrypt/live/ 2>/dev/null | grep -v README)
        if [ -n "$cert_dirs" ]; then
            for domain in $cert_dirs; do
                if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
                    local expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/fullchain.pem" | cut -d= -f2)
                    log_success "SSL certificate found for $domain (expires: $expiry)"
                    add_result "PASS" "SSL certificate for $domain"
                else
                    log_error "SSL certificate files missing for $domain"
                    add_result "FAIL" "SSL certificate missing for $domain"
                fi
            done
        else
            log_warning "No SSL certificates found"
            add_result "WARN" "No SSL certificates"
        fi
    else
        log_warning "Let's Encrypt directory not found"
        add_result "WARN" "Let's Encrypt not configured"
    fi
    
    # Check for custom SSL certificates
    if [ -f "/opt/ssl/fullchain.pem" ] && [ -f "/opt/ssl/privkey.pem" ]; then
        log_success "Custom SSL certificates found"
        add_result "PASS" "Custom SSL certificates"
    fi
}

# Function to check backend services
check_backend_services() {
    log_info "Checking backend services..."
    
    # Get instance private IP
    local token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s 2>/dev/null || echo "")
    local private_ip=""
    if [ -n "$token" ]; then
        private_ip=$(curl -H "X-aws-ec2-metadata-token: $token" -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "localhost")
    else
        private_ip="localhost"
    fi
    
    # Check if SSL is configured
    local protocol="http"
    if [ -f "/opt/ssl/fullchain.pem" ] || [ -d "/etc/letsencrypt/live" ]; then
        protocol="https"
    fi
    
    # Check each backend service
    local services=("8011:Kubernetes API" "8012:Logs API" "8013:Metrics API" "8014:Runbooks API")
    
    for service in "${services[@]}"; do
        local port=$(echo "$service" | cut -d: -f1)
        local name=$(echo "$service" | cut -d: -f2)
        
        # Check if process is running
        if pgrep -f "${port}" > /dev/null; then
            log_success "$name process is running on port $port"
            add_result "PASS" "$name process running"
            
            # Check if endpoint is accessible
            check_url "$protocol://$private_ip:$port/health" "$name health endpoint" 5
        else
            log_error "$name process is not running on port $port"
            add_result "FAIL" "$name process not running"
        fi
    done
}

# Function to check SRE Agent service
check_sre_agent_service() {
    log_info "Checking SRE Agent service..."
    
    # Check if systemd service exists
    if [ -f "/etc/systemd/system/sre-agent.service" ]; then
        log_success "SRE Agent systemd service file exists"
        add_result "PASS" "Systemd service file exists"
        
        # Check service status
        check_service "sre-agent" "SRE Agent service"
        
        # Check if service is enabled
        if systemctl is-enabled --quiet sre-agent; then
            log_success "SRE Agent service is enabled"
            add_result "PASS" "Service enabled"
        else
            log_warning "SRE Agent service is not enabled"
            add_result "WARN" "Service not enabled"
        fi
    else
        log_error "SRE Agent systemd service file does not exist"
        add_result "FAIL" "Systemd service file missing"
    fi
}

# Function to check network connectivity
check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    # Check internet connectivity
    if curl -s --max-time 10 https://www.google.com > /dev/null; then
        log_success "Internet connectivity is working"
        add_result "PASS" "Internet connectivity"
    else
        log_error "Internet connectivity failed"
        add_result "FAIL" "Internet connectivity failed"
    fi
    
    # Check AWS endpoints
    local region="${AWS_REGION:-us-east-1}"
    local endpoints=(
        "https://bedrock.$region.amazonaws.com:Bedrock endpoint"
        "https://s3.$region.amazonaws.com:S3 endpoint"
        "https://cognito-idp.$region.amazonaws.com:Cognito endpoint"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local url=$(echo "$endpoint" | cut -d: -f1-2)
        local name=$(echo "$endpoint" | cut -d: -f3)
        check_url "$url" "$name" 10
    done
}

# Function to check CloudWatch agent
check_cloudwatch_agent() {
    log_info "Checking CloudWatch agent..."
    
    if command -v /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl &> /dev/null; then
        log_success "CloudWatch agent is installed"
        add_result "PASS" "CloudWatch agent installed"
        
        # Check if agent is running
        if /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a query-config | grep -q "Status: running"; then
            log_success "CloudWatch agent is running"
            add_result "PASS" "CloudWatch agent running"
        else
            log_warning "CloudWatch agent is not running"
            add_result "WARN" "CloudWatch agent not running"
        fi
    else
        log_warning "CloudWatch agent is not installed"
        add_result "WARN" "CloudWatch agent not installed"
    fi
}

# Function to test SRE Agent functionality
test_sre_agent_functionality() {
    log_info "Testing SRE Agent functionality..."
    
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/.venv/bin/activate" ]; then
        cd "$INSTALL_DIR"
        source .venv/bin/activate
        
        # Test basic import
        if python3 -c "import sre_agent" 2>/dev/null; then
            log_success "SRE Agent module can be imported"
            add_result "PASS" "SRE Agent module import"
        else
            log_error "SRE Agent module cannot be imported"
            add_result "FAIL" "SRE Agent module import failed"
        fi
        
        # Test CLI availability
        if command -v sre-agent &> /dev/null; then
            log_success "SRE Agent CLI is available"
            add_result "PASS" "SRE Agent CLI available"
            
            # Test basic CLI functionality (with timeout)
            if timeout 30 uv run sre-agent --help > /dev/null 2>&1; then
                log_success "SRE Agent CLI is functional"
                add_result "PASS" "SRE Agent CLI functional"
            else
                log_warning "SRE Agent CLI test timed out or failed"
                add_result "WARN" "SRE Agent CLI test failed"
            fi
        else
            log_error "SRE Agent CLI is not available"
            add_result "FAIL" "SRE Agent CLI not available"
        fi
    else
        log_error "SRE Agent installation directory or virtual environment not found"
        add_result "FAIL" "SRE Agent installation not found"
    fi
}

# Function to generate validation report
generate_report() {
    log_info "Generating validation report..."
    
    local report_file="/tmp/sre-agent-validation-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
SRE Agent Deployment Validation Report
Generated: $(date)
Host: $(hostname)
User: $(whoami)

SUMMARY
=======
Total Checks: $TOTAL_CHECKS
Passed: $((TOTAL_CHECKS - FAILED_CHECKS))
Failed: $FAILED_CHECKS
Success Rate: $(( (TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS ))%

DETAILED RESULTS
================
EOF
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        local status=$(echo "$result" | cut -d'|' -f1)
        local message=$(echo "$result" | cut -d'|' -f2)
        printf "%-6s %s\n" "[$status]" "$message" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

RECOMMENDATIONS
===============
EOF
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        cat >> "$report_file" << EOF
❌ CRITICAL ISSUES FOUND
- Review failed checks above
- Fix critical issues before proceeding to production
- Re-run validation after fixes
EOF
    else
        cat >> "$report_file" << EOF
✅ ALL CRITICAL CHECKS PASSED
- System appears ready for production use
- Monitor logs and performance after deployment
- Set up regular health checks
EOF
    fi
    
    echo ""
    log_success "Validation report generated: $report_file"
    
    # Display summary
    echo ""
    echo "=========================================="
    echo "VALIDATION SUMMARY"
    echo "=========================================="
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Passed: $((TOTAL_CHECKS - FAILED_CHECKS))"
    echo "Failed: $FAILED_CHECKS"
    echo "Success Rate: $(( (TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS ))%"
    echo "=========================================="
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        log_success "🎉 All validation checks passed! System is ready for production."
        return 0
    else
        log_error "❌ $FAILED_CHECKS validation checks failed. Please review and fix issues."
        return 1
    fi
}

# Main validation function
main() {
    log_info "🔍 Starting SRE Agent Deployment Validation"
    echo ""
    
    check_system_requirements
    check_aws_connectivity
    check_bedrock_access
    check_s3_access
    check_cognito_access
    check_installation_files
    check_ssl_certificates
    check_backend_services
    check_sre_agent_service
    check_network_connectivity
    check_cloudwatch_agent
    test_sre_agent_functionality
    
    echo ""
    generate_report
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi