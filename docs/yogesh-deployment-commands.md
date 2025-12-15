# Deployment Commands for YogeshAbnave/sre-project

This document provides the exact commands to deploy your SRE Agent project from your GitHub repository.

## 🚀 **Complete Deployment Commands for Your Repository**

### **Step 1: Install Prerequisites on EC2**

```bash
# Update system and install Git and prerequisites
sudo yum update -y
sudo yum install -y git curl wget unzip jq python3 python3-pip docker

# Start Docker
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

### **Step 2: Clone Your Repository**

```bash
# Create directory and set permissions
sudo mkdir -p /opt/sre-agent
sudo chown ec2-user:ec2-user /opt/sre-agent

# Clone your repository
cd /opt
git clone https://github.com/YogeshAbnave/sre-project.git sre-agent

# Set ownership
sudo chown -R ec2-user:ec2-user /opt/sre-agent

# Navigate to project
cd /opt/sre-agent

# Verify clone
ls -la
git status
```

### **Step 3: Run Automated Deployment**

```bash
# Navigate to project directory
cd /opt/sre-agent

# Make deployment script executable
chmod +x scripts/git-deploy.sh

# Run deployment with your domain (optional)
./scripts/git-deploy.sh --domain sre-agent.yourdomain.com

# Or run without domain (HTTP only)
./scripts/git-deploy.sh
```

## 🔄 **One-Command Complete Installation**

Run this single command to do everything at once:

```bash
sudo yum update -y && \
sudo yum install -y git curl wget unzip jq python3 python3-pip docker && \
sudo systemctl start docker && \
sudo systemctl enable docker && \
sudo usermod -a -G docker ec2-user && \
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
unzip awscliv2.zip && \
sudo ./aws/install && \
rm -rf aws awscliv2.zip && \
curl -LsSf https://astral.sh/uv/install.sh | sh && \
source ~/.bashrc && \
sudo mkdir -p /opt/sre-agent && \
sudo chown ec2-user:ec2-user /opt/sre-agent && \
cd /opt && \
git clone https://github.com/YogeshAbnave/sre-project.git sre-agent && \
sudo chown -R ec2-user:ec2-user /opt/sre-agent && \
cd /opt/sre-agent && \
chmod +x scripts/git-deploy.sh && \
./scripts/git-deploy.sh
```

## 🔄 **For Future Updates**

### **Update Your Code (Local Machine)**
```bash
# Make changes to your code
# ... edit files ...

# Commit and push
git add .
git commit -m "Update: Description of changes"
git push origin main
```

### **Deploy Updates (EC2)**
```bash
# Connect to EC2
ssh -i your-key-pair.pem ec2-user@YOUR_EC2_IP

# Update deployment
cd /opt/sre-agent
git pull origin main
./scripts/git-deploy.sh --update
```

## ✅ **Validation Commands**

```bash
# Run validation script
cd /opt/sre-agent
chmod +x scripts/validate-deployment.sh
./scripts/validate-deployment.sh

# Check service status
sudo systemctl status sre-agent

# View logs
sudo journalctl -u sre-agent -f

# Test SRE Agent
source .venv/bin/activate
uv run sre-agent --prompt "Test the system"

# Test backend APIs
curl -k http://localhost:8011/health
curl -k http://localhost:8012/health
curl -k http://localhost:8013/health
curl -k http://localhost:8014/health
```

## 🛠️ **Troubleshooting Commands**

```bash
# Check Git status
cd /opt/sre-agent
git status
git log --oneline -5

# Check processes
ps aux | grep sre-agent
ps aux | grep python | grep -E "(8011|8012|8013|8014)"

# Check ports
netstat -tlnp | grep -E "(8011|8012|8013|8014)"

# Restart services
sudo systemctl restart sre-agent

# Check logs
sudo journalctl -u sre-agent -n 50
tail -f /var/log/sre-agent/*.log
```

## 🎯 **Quick Reference**

### **Repository Information**
- **Repository URL**: https://github.com/YogeshAbnave/sre-project.git
- **SSH URL**: git@github.com:YogeshAbnave/sre-project.git
- **Installation Directory**: /opt/sre-agent

### **Key Commands**
```bash
# Clone repository
git clone https://github.com/YogeshAbnave/sre-project.git sre-agent

# Deploy
cd /opt/sre-agent && ./scripts/git-deploy.sh

# Update
cd /opt/sre-agent && git pull origin main && ./scripts/git-deploy.sh --update

# Validate
cd /opt/sre-agent && ./scripts/validate-deployment.sh

# Check status
sudo systemctl status sre-agent
```

## 🔐 **SSH Setup (Optional)**

If you want to use SSH instead of HTTPS:

```bash
# Generate SSH key on EC2
ssh-keygen -t ed25519 -C "your.email@example.com"

# Display public key (add this to your GitHub account)
cat ~/.ssh/id_ed25519.pub

# Test SSH connection
ssh -T git@github.com

# Update remote URL to use SSH
cd /opt/sre-agent
git remote set-url origin git@github.com:YogeshAbnave/sre-project.git
```

## 📋 **Environment Variables**

Set these if needed:

```bash
export GIT_REPO="https://github.com/YogeshAbnave/sre-project.git"
export GIT_BRANCH="main"
export PROJECT_NAME="sre-agent"
export ENVIRONMENT="production"
export DOMAIN_NAME="sre-agent.yourdomain.com"  # Optional
```

This guide is specifically tailored for your repository at https://github.com/YogeshAbnave/sre-project.git