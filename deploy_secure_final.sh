#!/bin/bash

# =============================================================================
# Secure SRE Agent Deployment Script
# =============================================================================
# This script deploys SRE Agent using environment variables for secrets
# Usage: ANTHROPIC_API_KEY=your-key ./deploy_secure_final.sh [deployment_type]
# =============================================================================

set -e

# Check if API key is provided
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "❌ Error: ANTHROPIC_API_KEY environment variable is required"
    echo ""
    echo "Usage:"
    echo "  ANTHROPIC_API_KEY=sk-ant-your-key ./deploy_secure_final.sh [local|container|full-aws]"
    echo ""
    echo "Example:"
    echo "  ANTHROPIC_API_KEY=sk-ant-api03-xxx ./deploy_secure_final.sh local"
    exit 1
fi

# AWS configuration (non-sensitive)
export AWS_ACCOUNT_ID="238415673903"
export AWS_REGION="us-east-1"
export USER_POOL_ID="us-east-1_E1DBtfMOA"
export CLIENT_ID="4e41t3t6dv60tdd1sco2ki8mp5"
export GATEWAY_ROLE_NAME="SRE-Agent-Gateway-Role"
export LLM_PROVIDER="anthropic"
export DEBUG_MODE="true"
export DEPLOYMENT_TYPE="${1:-local}"

echo "🚀 Deploying SRE Agent securely..."
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region: ${AWS_REGION}"
echo "Provider: ${LLM_PROVIDER}"
echo "Deployment Type: ${DEPLOYMENT_TYPE}"
echo "API Key: ${ANTHROPIC_API_KEY:0:20}..." # Show only first 20 chars
echo ""

# Create secure .env file
cat > sre_agent/.env << EOF
# SRE Agent Configuration
USER_ID=${AWS_ACCOUNT_ID}
SESSION_ID=session-\$(date +%Y%m%d-%H%M%S)

# Anthropic API Key (from environment)
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
MEMORY_ENABLED=true

# AWS Account Configuration
account_id=${AWS_ACCOUNT_ID}
region=${AWS_REGION}
role_name=${GATEWAY_ROLE_NAME}
user_pool_id=${USER_POOL_ID}
client_id=${CLIENT_ID}
s3_bucket=

# Backend Configuration
BACKEND_API_KEY=your-secret-gateway-key-\$(date +%s)

# Debug and Logging
DEBUG=${DEBUG_MODE}
EOF

echo "✅ Secure .env file created with your API key"
echo ""
echo "Next steps:"
echo "1. Run: source .venv/bin/activate"
echo "2. Test: python sre_simple_fixed.py 'Hello SRE Agent'"
echo "3. Or run: sre-agent --prompt 'Hello' --provider anthropic"
echo ""