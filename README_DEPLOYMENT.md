# 🚀 SRE Agent - Secure Deployment Guide

## 🔒 Security First Approach

This SRE Agent deployment uses **environment variables** for API keys to ensure no secrets are stored in version control.

## ⚡ Quick Start

### 1. Prerequisites
- Ubuntu EC2 instance
- Anthropic API key with credits
- AWS CLI configured (optional)

### 2. Get Your API Key
1. Go to https://console.anthropic.com/
2. Create account and get API key
3. Add $5-10 credits for testing

### 3. Deploy Securely
```bash
# Clone repository
git clone https://github.com/YogeshAbnave/sre-project.git
cd sre-project

# Make executable
chmod +x deploy_secure_final.sh

# Deploy with your API key
ANTHROPIC_API_KEY=sk-ant-your-actual-key-here ./deploy_secure_final.sh
```

## 🎯 What You Get

- ✅ **Multi-Agent SRE System** - Kubernetes, logs, metrics, runbooks agents
- ✅ **CLI Interface** - `sre-agent --prompt "your query"`
- ✅ **Interactive Mode** - `sre-agent --interactive`
- ✅ **Simple Agent** - `python sre_simple_fixed.py "query"`
- ✅ **Production Ready** - Container and AWS deployment options

## 🔧 Configuration (Pre-configured)

Your AWS settings are already configured:
- **Account**: 238415673903
- **Region**: us-east-1
- **Cognito Pool**: us-east-1_E1DBtfMOA
- **Client ID**: 4e41t3t6dv60tdd1sco2ki8mp5

## 🧪 Test Commands

```bash
# After deployment
source .venv/bin/activate

# Test simple agent
python sre_simple_fixed.py "Check system health"

# Test full CLI
sre-agent --prompt "Analyze infrastructure issues" --provider anthropic

# Interactive mode
sre-agent --interactive
```

## 🛡️ Security Features

- ✅ No API keys in code
- ✅ Environment variable based secrets
- ✅ .env files in .gitignore
- ✅ Secure deployment scripts
- ✅ No secrets in version control

## 📞 Support

For issues:
1. Ensure API key has credits
2. Check AWS CLI configuration
3. Verify all prerequisites are met

---

**Your SRE Agent is ready for secure deployment!** 🎉