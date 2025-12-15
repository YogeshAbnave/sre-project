# Git-Based Deployment Guide for SRE Agent

This guide provides step-by-step commands for pushing your SRE Agent code to Git and deploying it on EC2 using Git pull.

## 📋 Prerequisites

- Git repository (GitHub, GitLab, or Bitbucket)
- EC2 instance running (from CloudFormation deployment)
- SSH access to EC2 instance
- Git configured on your local machine

## 🚀 Part 1: Local Git Setup and Push

### Step 1: Initialize Git Repository (if not already done)

```bash
# Navigate to your project directory
cd /path/to/your/sre-agent-project

# Initialize git repository
git init

# Add remote repository
git remote add origin https://github.com/YogeshAbnave/sre-project.git
# OR for SSH:
# git remote add origin git@github.com:YogeshAbnave/sre-project.git
```

### Step 2: Configure Git (if not already done)

```bash
# Set your Git configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify configuration
git config --list
```

### Step 3: Prepare Files for Commit

```bash
# Check current status
git status

# Add all files to staging
git add .

# Or add specific files/directories
git add cloudformation/
git add scripts/
git add docs/
git add sre_agent/
git add gateway/
git add backend/
git add pyproject.toml
git add README.md
git add .gitignore

# Check what will be committed
git status
```

### Step 4: Create .gitignore (if not exists)

```bash
# Create/update .gitignore file
cat > .gitignore << 'EOF'
# Environment files
.env
*.env
!.env.example

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
.venv/
venv/
ENV/
env/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# AWS and sensitive files
*.pem
*.key
.aws/
.credentials_provider
.gateway_uri
.access_token
.agent_arn
.memory_id
.cognito_config

# Temporary files
*.tmp
*.temp
.cache/

# Node modules (if any)
node_modules/

# Coverage reports
htmlcov/
.coverage
.pytest_cache/
EOF
```

### Step 5: Commit and Push to Git

```bash
# Commit your changes
git commit -m "Initial commit: SRE Agent production deployment with AWS CloudFormation

- Added complete CloudFormation infrastructure template
- Added production deployment scripts
- Added comprehensive validation framework
- Added complete documentation suite
- Added IAM policies and security configurations
- Ready for production deployment on AWS EC2"

# Push to remote repository (first time)
git push -u origin main

# For subsequent pushes
git push origin main
```

### Step 6: Verify Push Success

```bash
# Check remote repository status
git remote -v

# Check branch status
git branch -a

# View commit history
git log --oneline -5
```

## 🖥️ Part 2: EC2 Deployment Commands

### Step 1: Connect to EC2 Instance

```bash
# Connect to your EC2 instance (replace with your actual IP and key file)
ssh -i AgentCore-Project.pem ec2-user@YOUR_EC2_PUBLIC_IP

# Example:
# ssh -i AgentCore-Project.pem ec2-user@54.123.45.67
```

### Step 2: Install Git and Required Tools (if not already installed)

```bash
# Update system packages
sudo yum update -y

# Install Git and other required tools
sudo yum install -y git curl wget unzip jq

# Install Python 3.12 and pip
sudo yum install -y python3 python3-pip

# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Install UV package manager
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# Verify installations
git --version
python3 --version
aws --version
uv --version
docker --version
```

### Step 3: Clone Repository on EC2

```bash
# Create application directory
sudo mkdir -p /opt/sre-agent
sudo chown ec2-user:ec2-user /opt/sre-agent

# Clone your repository
cd /opt
git clone https://github.com/YogeshAbnave/sre-project.git
sre-agent

# OR if using SSH (need to set up SSH keys first)
# git clone git@github.com:yourusername/sre-agent-production.git sre-agent

# Change ownership
sudo chown -R ec2-user:ec2-user /opt/sre-agent

# Navigate to project directory
cd /opt/sre-agent

# Verify clone success
ls -la
git status
git log --oneline -3
```

### Step 4: Set Up AWS Configuration

```bash
# Configure AWS CLI (if not already configured)
aws configure

# Or use IAM role (recommended for EC2)
# The CloudFormation template should have already attached the proper IAM role

# Verify AWS access
aws sts get-caller-identity

# Test Bedrock access
aws bedrock list-foundation-models --region us-east-1

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"
echo "Public IP: $PUBLIC_IP"
```

### Step 5: Run Deployment Script

```bash
# Make deployment script executable
chmod +x /opt/sre-agent/scripts/deploy-sre-agent.sh

# Set environment variables (optional)
export PROJECT_NAME="sre-agent"
export ENVIRONMENT="production"
export DOMAIN_NAME="sre-agent.yourdomain.com"  # Optional - set if you have a domain

# Run the deployment script
/opt/sre-agent/scripts/deploy-sre-agent.sh

# The script will:
# 1. Get AWS configuration from SSM Parameter Store
# 2. Set up Python virtual environment
# 3. Install dependencies
# 4. Configure SSL certificates (if domain provided)
# 5. Generate OpenAPI specifications
# 6. Start backend services
# 7. Set up AgentCore Gateway
# 8. Initialize memory system
# 9. Create systemd service
# 10. Run validation tests
```

### Step 6: Validate Deployment

```bash
# Run validation script
chmod +x /opt/sre-agent/scripts/validate-deployment.sh
/opt/sre-agent/scripts/validate-deployment.sh

# Check service status
sudo systemctl status sre-agent

# View service logs
sudo journalctl -u sre-agent -f

# Test SRE Agent manually
cd /opt/sre-agent
source .venv/bin/activate
uv run sre-agent --prompt "Test the system health"
```

### Step 7: Verify Backend Services

```bash
# Check if backend processes are running
ps aux | grep python | grep -E "(8011|8012|8013|8014)"

# Test backend API endpoints
curl -k http://localhost:8011/health
curl -k http://localhost:8012/health
curl -k http://localhost:8013/health
curl -k http://localhost:8014/health

# If SSL is configured, test HTTPS
curl -k https://localhost:8011/health
curl -k https://localhost:8012/health
curl -k https://localhost:8013/health
curl -k https://localhost:8014/health
```

## 🔄 Part 3: Update and Redeploy Commands

### For Future Updates (Local Machine)

```bash
# Make changes to your code
# ... edit files ...

# Stage and commit changes
git add .
git commit -m "Update: Description of your changes"

# Push to remote repository
git push origin main
```

### For Future Updates (EC2 Instance)

```bash
# Connect to EC2
ssh -i AgentCore-Project.pem ec2-user@YOUR_EC2_PUBLIC_IP

# Navigate to project directory
cd /opt/sre-agent

# Stop the service (if running)
sudo systemctl stop sre-agent

# Pull latest changes
git pull origin main

# Check what changed
git log --oneline -5

# Restart deployment if needed
/opt/sre-agent/scripts/deploy-sre-agent.sh

# Or just restart the service if only minor changes
sudo systemctl start sre-agent
sudo systemctl status sre-agent
```

## 🛠️ Part 4: Troubleshooting Commands

### Check Git Status

```bash
# On EC2 instance
cd /opt/sre-agent

# Check current branch and status
git branch
git status
git remote -v

# Check recent commits
git log --oneline -10

# Check differences
git diff HEAD~1
```

### Check Service Status

```bash
# Check systemd service
sudo systemctl status sre-agent
sudo systemctl is-active sre-agent
sudo systemctl is-enabled sre-agent

# View logs
sudo journalctl -u sre-agent -n 50
sudo journalctl -u sre-agent -f

# Check process
ps aux | grep sre-agent
```

### Check Backend Services

```bash
# Check backend processes
ps aux | grep python | grep -E "(k8s_server|logs_server|metrics_server|runbooks_server)"

# Check ports
netstat -tlnp | grep -E "(8011|8012|8013|8014)"

# Check logs
ls -la /var/log/sre-agent/
tail -f /var/log/sre-agent/*.log
```

### Restart Services

```bash
# Restart SRE Agent service
sudo systemctl restart sre-agent

# Restart backend services
cd /opt/sre-agent/backend
./scripts/stop_demo_backend.sh
./scripts/start_demo_backend.sh --host $PRIVATE_IP

# Restart all services
sudo systemctl restart sre-agent
```

## 🔐 Part 5: Security Best Practices

### Secure Git Access

```bash
# Use SSH keys instead of HTTPS for better security
# Generate SSH key on EC2 (if not exists)
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add public key to your Git provider (GitHub/GitLab)
cat ~/.ssh/id_ed25519.pub

# Test SSH connection
ssh -T git@github.com

# Update remote URL to use SSH
cd /opt/sre-agent
git remote set-url origin git@github.com:yourusername/sre-agent-production.git
```

### Secure File Permissions

```bash
# Set proper permissions
sudo chown -R ec2-user:ec2-user /opt/sre-agent
chmod 755 /opt/sre-agent/scripts/*.sh
chmod 600 /opt/sre-agent/sre_agent/.env
chmod 600 /opt/sre-agent/gateway/.env
```

## 📋 Quick Reference Commands

### Essential Commands Summary

```bash
# === LOCAL MACHINE ===
# Push code to Git
git add .
git commit -m "Your commit message"
git push origin main

# === EC2 INSTANCE ===
# Connect to EC2
ssh -i AgentCore-Project.pem ec2-user@YOUR_EC2_IP

# Deploy/Update
cd /opt/sre-agent
git pull origin main
/opt/sre-agent/scripts/deploy-sre-agent.sh

# Check status
sudo systemctl status sre-agent
/opt/sre-agent/scripts/validate-deployment.sh

# View logs
sudo journalctl -u sre-agent -f

# Test functionality
cd /opt/sre-agent && source .venv/bin/activate
uv run sre-agent --prompt "Test system"
```

This guide provides all the commands you need for a complete Git-based deployment workflow. The process is designed to be repeatable and reliable for production use.