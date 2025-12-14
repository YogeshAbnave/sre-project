#!/bin/bash

# =============================================================================
# Secure Production Setup Script
# =============================================================================
# This script sets up the SRE Agent using environment variables for credentials
# No hardcoded secrets - all sensitive data loaded from environment
# =============================================================================

set -e

echo "🔐 Secure SRE Agent Production Setup"
echo "====================================="

# Check required environment variables
check_env_var() {
    local var_name=$1
    local var_value=${!var_name}
    
    if [ -z "$var_value" ]; then
        echo "❌ Error: $var_name environment variable not set"
        return 1
    else
        echo "✅ $var_name is configured"
        return 0
    fi
}

echo "🔍 Checking required environment variables..."

# Check for required credentials
if ! check_env_var "ANTHROPIC_API_KEY"; then
    echo ""
    echo "Please set your Anthropic API key:"
    echo "export ANTHROPIC_API_KEY=\"your-anthropic-api-key-here\""
    exit 1
fi

# Set defaults for optional variables
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-238415673903}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export USER_POOL_ID="${USER_POOL_ID:-us-east-1_E1DBtfMOA}"
export CLIENT_ID="${CLIENT_ID:-4e41t3t6dv60tdd1sco2ki8mp5}"
export GATEWAY_ROLE_NAME="${GATEWAY_ROLE_NAME:-SRE-Agent-Gateway-Role}"
export LLM_PROVIDER="${LLM_PROVIDER:-anthropic}"
export DEBUG_MODE="${DEBUG_MODE:-true}"

echo ""
echo "🚀 Setting up SRE Agent with secure configuration..."
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "Provider: ${LLM_PROVIDER}"
echo ""

# Step 1: Create working .env file
echo "📝 Creating production .env file..."
cat > sre_agent/.env << EOF
# SRE Agent Production Configuration
USER_ID=${AWS_ACCOUNT_ID}
SESSION_ID=session-$(date +%Y%m%d-%H%M%S)

# Anthropic API Key (for Claude models)
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

# Gateway Access Token (will be filled after gateway setup)
GATEWAY_ACCESS_TOKEN=waiting_for_gateway_token

# LLM Provider Configuration
LLM_PROVIDER=${LLM_PROVIDER}

# AWS Region
AWS_REGION=${AWS_REGION}

# Bedrock Model Configuration
BEDROCK_MODEL_ID=anthropic.claude-3-haiku-20240307-v1:0

# Memory System Configuration
MEMORY_TABLE_NAME=sre-agent-memories
MEMORY_ENABLED=false

# AWS Account Configuration
account_id=${AWS_ACCOUNT_ID}
region=${AWS_REGION}
role_name=${GATEWAY_ROLE_NAME}
user_pool_id=${USER_POOL_ID}
client_id=${CLIENT_ID}
s3_bucket=

# Backend Configuration
BACKEND_API_KEY=your-secret-gateway-key-$(date +%s)

# Cognito Configuration
COGNITO_DOMAIN=https://yourdomain.auth.${AWS_REGION}.amazoncognito.com
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_CLIENT_SECRET=
COGNITO_USER_POOL_ID=${USER_POOL_ID}

# Debug and Logging
DEBUG=${DEBUG_MODE}
EOF

# Step 2: Create gateway configuration
echo "🔧 Creating gateway configuration..."
cat > gateway/config.yaml << EOF
account_id: "${AWS_ACCOUNT_ID}"
region: "${AWS_REGION}"
role_name: "${GATEWAY_ROLE_NAME}"
user_pool_id: "${USER_POOL_ID}"
client_id: "${CLIENT_ID}"
s3_bucket: ""
gateway_name: "sre-agent-gateway"
endpoint_url: "https://bedrock-agentcore-control.${AWS_REGION}.amazonaws.com"
credential_provider_endpoint_url: "https://${AWS_REGION}.prod.agent-credential-provider.cognito.aws.dev"
credential_provider_name: "sre-agent-api-key-credential-provider"
s3_path_prefix: "devops-multiagent-demo"
EOF

# Step 3: Create agent configuration
echo "⚙️ Creating agent configuration..."
mkdir -p sre_agent/config
cat > sre_agent/config/agent_config.yaml << 'EOF'
agents:
  supervisor:
    model_provider: anthropic
    model_name: claude-3-haiku-20240307
    temperature: 0.1
    max_tokens: 4000
    
  kubernetes_agent:
    model_provider: anthropic
    model_name: claude-3-haiku-20240307
    temperature: 0.1
    max_tokens: 4000
    
  logs_agent:
    model_provider: anthropic
    model_name: claude-3-haiku-20240307
    temperature: 0.1
    max_tokens: 4000
    
  metrics_agent:
    model_provider: anthropic
    model_name: claude-3-haiku-20240307
    temperature: 0.1
    max_tokens: 4000
    
  runbooks_agent:
    model_provider: anthropic
    model_name: claude-3-haiku-20240307
    temperature: 0.1
    max_tokens: 4000

gateway:
  uri: ""
  timeout: 30

memory:
  enabled: false
  table_name: sre-agent-memories
EOF

echo "✅ Configuration files created securely!"
echo ""
echo "🧪 Testing your setup..."

# Step 4: Test API key
echo "Testing Anthropic API key..."
python test_api_simple.py

# Step 5: Test simple agent
echo ""
echo "Testing SRE Agent..."
python sre_simple_fixed.py "Test production setup with secure credentials"

echo ""
echo "🎉 Secure production setup completed!"
echo ""
echo "Your SRE Agent is ready with:"
echo "✅ Secure credential management"
echo "✅ Environment variable configuration"
echo "✅ Production-ready setup"
echo ""
echo "Next steps:"
echo "1. Add credits to your Anthropic account if needed"
echo "2. Test: python sre_simple_fixed.py 'Check system health'"
echo "3. Full CLI: sre-agent --prompt 'Hello' --provider anthropic"
echo ""
echo "🔐 Security Note: No secrets are stored in this script!"