# Production-Grade SRE Agent Setup Guide

This guide will help you deploy the SRE Agent as a production-grade application on your EC2 instance, addressing the AWS credential issues and providing robust error handling.

## Quick Start for EC2 Instance

### 1. Prerequisites Check

First, ensure your EC2 instance has the required components:

```bash
# Check Python version
python3 --version  # Should be 3.12+

# Install uv if not present
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Check AWS CLI
aws --version
aws sts get-caller-identity  # Verify credentials

# Check for SSL certificates (required for production)
ls -la /opt/ssl/
```

### 2. Clone and Setup

```bash
# If not already cloned
git clone https://github.com/awslabs/amazon-bedrock-agentcore-samples
cd amazon-bedrock-agentcore-samples/02-use-cases/SRE-agent

# Make setup script executable
chmod +x gateway/setup_production.sh

# Run production setup with validation
./gateway/setup_production.sh --validate-only
```

### 3. Configure AWS Credentials

If you encountered the "NoCredentialsError", fix it with:

```bash
# Option 1: Configure AWS CLI
aws configure
# Enter your Access Key ID, Secret Access Key, Region, and Output format

# Option 2: Use IAM role (recommended for EC2)
# Attach an IAM role with BedrockAgentCoreFullAccess to your EC2 instance

# Option 3: Set environment variables
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1

# Verify credentials work
aws sts get-caller-identity
```

### 4. Setup Configuration Files

```bash
# Navigate to gateway directory
cd gateway

# Create configuration from template
cp config.yaml.example config.yaml
cp .env.example .env

# Edit configuration with your values
nano config.yaml
# Update: account_id, region, role_name, user_pool_id, client_id

nano .env
# Update: BACKEND_API_KEY, COGNITO_* variables
```

### 5. Run Production Setup

```bash
# Run complete production setup
./setup_production.sh

# Or run with debug output
./setup_production.sh --debug

# If setup fails, resume from last step
./setup_production.sh --resume
```

## Detailed Configuration

### AWS Configuration (config.yaml)

```yaml
# AWS Configuration
account_id: "123456789012"  # Your AWS account ID
region: "us-east-1"         # Your preferred region
role_name: "YourRoleName"   # IAM role with BedrockAgentCoreFullAccess

# Endpoints (update region in URLs)
endpoint_url: "https://bedrock-agentcore-control.us-east-1.amazonaws.com"
credential_provider_endpoint_url: "https://us-east-1.prod.agent-credential-provider.cognito.aws.dev"

# Cognito Configuration (from setup_cognito.sh output)
user_pool_id: "us-east-1_ABCDEFGHI"
client_id: "your-client-id"

# S3 Configuration
s3_bucket: ""  # Leave empty for auto-creation
s3_path_prefix: "devops-multiagent-demo"

# Gateway Configuration
gateway_name: "ProductionSREGateway"
gateway_description: "Production SRE Agent Gateway"
credential_provider_name: "sre-agent-api-key-credential-provider"
```

### Environment Variables (.env)

```bash
# Backend API Key (required)
BACKEND_API_KEY=your-secure-api-key-here

# Cognito Configuration
COGNITO_DOMAIN=https://yourdomain.auth.us-east-1.amazoncognito.com
COGNITO_CLIENT_ID=your-client-id
COGNITO_CLIENT_SECRET=your-client-secret
COGNITO_USER_POOL_ID=us-east-1_ABCDEFGHI

# Optional: Anthropic API Key (if using Anthropic models)
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

## Production Features

### 1. Robust Error Handling

The production setup script includes:

- **Comprehensive validation** of AWS credentials and permissions
- **Detailed error messages** with specific remediation steps
- **State management** for resuming failed setups
- **Logging** to `gateway/setup.log` for troubleshooting

### 2. Security Best Practices

- **HTTPS enforcement** for all endpoints
- **SSL certificate validation** for backend servers
- **Credential validation** before setup begins
- **IAM permission verification**

### 3. Monitoring and Observability

```bash
# Check setup logs
tail -f gateway/setup.log

# Monitor backend servers
ps aux | grep python | grep -E "(8011|8012|8013|8014)"

# Check gateway status
cat gateway/.gateway_uri
cat gateway/.access_token
```

## Troubleshooting Common Issues

### 1. AWS Credential Issues

**Error**: `NoCredentialsError: Unable to locate credentials`

**Solution**:
```bash
# Check current credentials
aws sts get-caller-identity

# If no credentials, configure them
aws configure

# Or use IAM role (recommended)
# Attach role to EC2 instance in AWS Console
```

### 2. Configuration Validation Errors

**Error**: Configuration validation failed

**Solution**:
```bash
# Run validation only to see specific errors
./gateway/setup_production.sh --validate-only

# Check configuration file
cat gateway/config.yaml

# Verify all placeholder values are replaced
grep -E "(YOUR_|REGION|your-)" gateway/config.yaml
```

### 3. SSL Certificate Issues

**Error**: SSL certificate not found

**Solution**:
```bash
# Check for certificates
ls -la /opt/ssl/

# If missing, install Let's Encrypt certificates
sudo apt update
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com

# Or use self-signed for testing (not recommended for production)
sudo mkdir -p /opt/ssl
sudo openssl req -x509 -newkey rsa:4096 -keyout /opt/ssl/privkey.pem -out /opt/ssl/fullchain.pem -days 365 -nodes
```

### 4. Backend Server Issues

**Error**: Backend servers not starting

**Solution**:
```bash
# Check if ports are available
netstat -tlnp | grep -E "(8011|8012|8013|8014)"

# Kill existing processes if needed
pkill -f "python.*backend"

# Start servers manually
cd backend
./scripts/start_demo_backend.sh --host 0.0.0.0
```

## Testing the Production Setup

### 1. Basic Functionality Test

```bash
# Activate virtual environment
source .venv/bin/activate

# Test basic query
uv run sre-agent --prompt "list the pods in my infrastructure"

# Test with Bedrock provider
uv run sre-agent --provider bedrock --prompt "check cluster health"
```

### 2. Interactive Mode Test

```bash
# Start interactive session
uv run sre-agent --interactive

# Try various commands
/help
/agents
list all running pods
analyze memory usage trends
```

### 3. Gateway Connectivity Test

```bash
# Check gateway URL
cat gateway/.gateway_uri

# Test MCP commands
cd gateway
./mcp_cmds.sh
```

## Production Deployment Options

### Option 1: Local EC2 Deployment (Current)

Your current setup runs the agent directly on the EC2 instance:

```bash
# Start the agent service
uv run sre-agent --interactive

# Or run specific queries
uv run sre-agent --prompt "your query here"
```

### Option 2: Container Deployment

For scalable production deployment:

```bash
# Build container for local testing
LOCAL_BUILD=true ./deployment/build_and_deploy.sh

# Test container locally
docker run -p 8080:8080 --env-file sre_agent/.env sre_agent:latest

# Deploy to AgentCore Runtime
./deployment/build_and_deploy.sh
```

### Option 3: Service Deployment

Create a systemd service for automatic startup:

```bash
# Create service file
sudo tee /etc/systemd/system/sre-agent.service << EOF
[Unit]
Description=SRE Agent Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/amazon-bedrock-agentcore-samples/02-use-cases/SRE-agent
Environment=PATH=/home/ubuntu/amazon-bedrock-agentcore-samples/02-use-cases/SRE-agent/.venv/bin
ExecStart=/home/ubuntu/amazon-bedrock-agentcore-samples/02-use-cases/SRE-agent/.venv/bin/uv run sre-agent --interactive
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl enable sre-agent
sudo systemctl start sre-agent
sudo systemctl status sre-agent
```

## Maintenance

### Daily Tasks

```bash
# Refresh gateway token (expires every 24 hours)
cd gateway
./create_gateway.sh

# Check logs
tail -f setup.log

# Monitor system resources
htop
df -h
```

### Weekly Tasks

```bash
# Update dependencies
uv pip install --upgrade -e .

# Check for security updates
sudo apt update && sudo apt upgrade

# Backup configuration
tar -czf sre-agent-backup-$(date +%Y%m%d).tar.gz gateway/config.yaml gateway/.env
```

## Support and Documentation

- **Setup Issues**: Check `gateway/setup.log`
- **Agent Issues**: Use `--debug` flag for detailed output
- **AWS Issues**: Verify credentials with `aws sts get-caller-identity`
- **Documentation**: See `docs/` directory for detailed guides

For additional help, refer to the comprehensive documentation in the `docs/` directory.