# Git Deployment Commands Reference

This document provides all the essential commands for deploying your SRE Agent project using Git.

## 🚀 Quick Start Commands

### 1. Prepare Your Local Repository

```bash
# Navigate to your SRE Agent project directory
cd /path/to/your/sre-agent-project

# Run the preparation script
chmod +x scripts/prepare-git-repo.sh
./scripts/prepare-git-repo.sh --repo https://github.com/yourusername/sre-agent-production.git --init

# Or manually:
git init
git remote add origin https://github.com/YogeshAbnave/sre-project.git
git add .
git commit -m "Initial commit: SRE Agent production deployment"
git push -u origin main
```

### 2. Deploy Infrastructure (One-time setup)

```bash
# Deploy CloudFormation stack
aws cloudformation create-stack \
  --stack-name sre-agent-production \
  --template-body file://cloudformation/sre-agent-infrastructure.yaml \
  --parameters ParameterKey=KeyPairName,ParameterValue=your-key-pair-name \
               ParameterKey=SSHAccessCIDR,ParameterValue=your-ip/32 \
  --capabilities CAPABILITY_NAMED_IAM

# Wait for completion
aws cloudformation wait stack-create-complete --stack-name sre-agent-production

# Get EC2 instance IP
INSTANCE_IP=$(aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' \
  --output text)

echo "EC2 Instance IP: $INSTANCE_IP"
```

### 3. Deploy Application on EC2

```bash
# Connect to EC2 instance
ssh -i your-key-pair.pem ec2-user@$INSTANCE_IP

# Run Git deployment (one command)
curl -sSL https://raw.githubusercontent.com/yourusername/sre-agent-production/main/scripts/git-deploy.sh | bash -s -- --repo https://github.com/yourusername/sre-agent-production.git --domain sre-agent.yourdomain.com

# Or clone and run locally:
git clone https://github.com/yourusername/sre-agent-production.git /opt/sre-agent
cd /opt/sre-agent
chmod +x scripts/git-deploy.sh
./scripts/git-deploy.sh --domain sre-agent.yourdomain.com
```

## 📋 Detailed Command Sequences

### Local Machine Commands

#### Initial Setup
```bash
# 1. Prepare Git repository
cd /path/to/your/sre-agent-project
chmod +x scripts/prepare-git-repo.sh
./scripts/prepare-git-repo.sh --repo https://github.com/yourusername/sre-agent-production.git --init

# 2. Verify Git status
git status
git log --oneline -3
git remote -v

# 3. Push to remote
git push origin main
```

#### Making Updates
```bash
# 1. Make your changes
# ... edit files ...

# 2. Commit and push
git add .
git commit -m "Update: Description of your changes"
git push origin main

# 3. Verify push
git log --oneline -3
```

### AWS Infrastructure Commands

#### Deploy Infrastructure
```bash
# 1. Validate CloudFormation template
aws cloudformation validate-template \
  --template-body file://cloudformation/sre-agent-infrastructure.yaml

# 2. Create stack
aws cloudformation create-stack \
  --stack-name sre-agent-production \
  --template-body file://cloudformation/sre-agent-infrastructure.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=sre-agent \
    ParameterKey=Environment,ParameterValue=production \
    ParameterKey=InstanceType,ParameterValue=t3.xlarge \
    ParameterKey=KeyPairName,ParameterValue=your-key-pair-name \
    ParameterKey=SSHAccessCIDR,ParameterValue=your-ip/32 \
    ParameterKey=DomainName,ParameterValue=sre-agent.yourdomain.com \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=Project,Value=SRE-Agent Key=Environment,Value=Production

# 3. Monitor deployment
aws cloudformation describe-stack-events \
  --stack-name sre-agent-production \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table

# 4. Wait for completion
aws cloudformation wait stack-create-complete --stack-name sre-agent-production

# 5. Get outputs
aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].Outputs' \
  --output table
```

#### Get Infrastructure Information
```bash
# Get EC2 instance IP
INSTANCE_IP=$(aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' \
  --output text)

# Get SSH command
SSH_COMMAND=$(aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].Outputs[?OutputKey==`SSHCommand`].OutputValue' \
  --output text)

# Get S3 bucket name
S3_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)

echo "Instance IP: $INSTANCE_IP"
echo "SSH Command: $SSH_COMMAND"
echo "S3 Bucket: $S3_BUCKET"
```

### EC2 Instance Commands

#### Initial Deployment
```bash
# 1. Connect to EC2
ssh -i your-key-pair.pem ec2-user@$INSTANCE_IP

# 2. Run Git deployment script (automated)
curl -sSL https://raw.githubusercontent.com/yourusername/sre-agent-production/main/scripts/git-deploy.sh | bash -s -- \
  --repo https://github.com/yourusername/sre-agent-production.git \
  --domain sre-agent.yourdomain.com

# 3. Or manual deployment
sudo mkdir -p /opt/sre-agent
sudo chown ec2-user:ec2-user /opt/sre-agent
git clone https://github.com/yourusername/sre-agent-production.git /opt/sre-agent
cd /opt/sre-agent
chmod +x scripts/git-deploy.sh
./scripts/git-deploy.sh --domain sre-agent.yourdomain.com
```

#### Update Deployment
```bash
# 1. Connect to EC2
ssh -i your-key-pair.pem ec2-user@$INSTANCE_IP

# 2. Update using Git deployment script
cd /opt/sre-agent
./scripts/git-deploy.sh --update

# 3. Or manual update
git pull origin main
./scripts/deploy-sre-agent.sh
```

#### Service Management
```bash
# Check service status
sudo systemctl status sre-agent

# Start/stop/restart service
sudo systemctl start sre-agent
sudo systemctl stop sre-agent
sudo systemctl restart sre-agent

# View logs
sudo journalctl -u sre-agent -f
sudo journalctl -u sre-agent -n 100

# Check backend services
ps aux | grep python | grep -E "(8011|8012|8013|8014)"
netstat -tlnp | grep -E "(8011|8012|8013|8014)"
```

#### Testing and Validation
```bash
# Run validation script
cd /opt/sre-agent
./scripts/validate-deployment.sh

# Test SRE Agent manually
source .venv/bin/activate
uv run sre-agent --prompt "Test the system health"

# Test backend APIs
curl -k http://localhost:8011/health
curl -k http://localhost:8012/health
curl -k http://localhost:8013/health
curl -k http://localhost:8014/health

# Test with SSL (if configured)
curl -k https://localhost:8011/health
```

## 🔧 Troubleshooting Commands

### Git Issues
```bash
# Check Git status
git status
git log --oneline -10
git remote -v

# Fix merge conflicts
git stash
git pull origin main
git stash pop

# Reset to remote state
git fetch origin
git reset --hard origin/main

# Check differences
git diff HEAD~1
git show HEAD
```

### Service Issues
```bash
# Check service logs
sudo journalctl -u sre-agent -n 50 --no-pager
sudo journalctl -u sre-agent -f

# Check process status
ps aux | grep sre-agent
ps aux | grep python | grep -E "(k8s_server|logs_server|metrics_server|runbooks_server)"

# Check ports
netstat -tlnp | grep -E "(8011|8012|8013|8014|443)"
ss -tlnp | grep -E "(8011|8012|8013|8014|443)"

# Check system resources
free -h
df -h
top -p $(pgrep -d',' -f sre-agent)
```

### AWS Issues
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Bedrock access
aws bedrock list-foundation-models --region us-east-1

# Check S3 access
aws s3 ls s3://your-bucket-name

# Check Cognito
aws cognito-idp describe-user-pool --user-pool-id your-pool-id

# Check CloudFormation stack
aws cloudformation describe-stacks --stack-name sre-agent-production
aws cloudformation describe-stack-events --stack-name sre-agent-production
```

### SSL Certificate Issues
```bash
# Check certificates
sudo certbot certificates

# Check certificate files
ls -la /etc/letsencrypt/live/
ls -la /opt/ssl/

# Test SSL
openssl s_client -connect localhost:443 -servername your-domain.com

# Renew certificates
sudo certbot renew --dry-run
sudo certbot renew
```

## 🚀 One-Line Deployment Commands

### Complete Fresh Deployment
```bash
# Deploy infrastructure and application in one go
aws cloudformation create-stack --stack-name sre-agent-production --template-body file://cloudformation/sre-agent-infrastructure.yaml --parameters ParameterKey=KeyPairName,ParameterValue=your-key-pair --capabilities CAPABILITY_NAMED_IAM && \
aws cloudformation wait stack-create-complete --stack-name sre-agent-production && \
INSTANCE_IP=$(aws cloudformation describe-stacks --stack-name sre-agent-production --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' --output text) && \
ssh -i your-key-pair.pem ec2-user@$INSTANCE_IP "curl -sSL https://raw.githubusercontent.com/yourusername/sre-agent-production/main/scripts/git-deploy.sh | bash -s -- --repo https://github.com/yourusername/sre-agent-production.git"
```

### Quick Update
```bash
# Update application on EC2
ssh -i your-key-pair.pem ec2-user@$INSTANCE_IP "cd /opt/sre-agent && git pull origin main && ./scripts/git-deploy.sh --update"
```

### Health Check
```bash
# Quick health check
ssh -i your-key-pair.pem ec2-user@$INSTANCE_IP "cd /opt/sre-agent && ./scripts/validate-deployment.sh && sudo systemctl status sre-agent"
```

## 📝 Environment Variables Reference

### Local Development
```bash
export GIT_REPO="https://github.com/yourusername/sre-agent-production.git"
export GIT_BRANCH="main"
export AWS_PROFILE="your-profile"
export AWS_REGION="us-east-1"
```

### EC2 Deployment
```bash
export PROJECT_NAME="sre-agent"
export ENVIRONMENT="production"
export DOMAIN_NAME="sre-agent.yourdomain.com"
export GIT_REPO="https://github.com/yourusername/sre-agent-production.git"
export GIT_BRANCH="main"
```

## 🔐 Security Best Practices

### SSH Key Management
```bash
# Generate SSH key for Git (on EC2)
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub  # Add to GitHub/GitLab

# Use SSH for Git
git remote set-url origin git@github.com:yourusername/sre-agent-production.git
```

### File Permissions
```bash
# Set proper permissions
sudo chown -R ec2-user:ec2-user /opt/sre-agent
chmod 755 /opt/sre-agent/scripts/*.sh
chmod 600 /opt/sre-agent/sre_agent/.env
chmod 600 /opt/sre-agent/gateway/.env
```

This reference provides all the commands you need for a complete Git-based deployment workflow!