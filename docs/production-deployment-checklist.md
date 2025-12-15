# Production Deployment Checklist for SRE Agent

This comprehensive checklist ensures all required AWS resources are properly configured and the SRE Agent is production-ready.

## Pre-Deployment Checklist

### AWS Account Preparation
- [ ] AWS account with administrative access
- [ ] AWS CLI installed and configured
- [ ] Appropriate IAM permissions for CloudFormation, EC2, Bedrock, S3, Cognito
- [ ] EC2 Key Pair created in target region
- [ ] Domain name registered (optional, for SSL)
- [ ] SSL certificate in ACM (optional)

### Resource Planning
- [ ] Determine target AWS region
- [ ] Choose appropriate EC2 instance type (recommended: t3.xlarge)
- [ ] Plan network architecture (VPC, subnets, security groups)
- [ ] Estimate costs and set up billing alerts
- [ ] Define backup and disaster recovery strategy

## Infrastructure Deployment

### Step 1: CloudFormation Stack Deployment
- [ ] Download CloudFormation template (`cloudformation/sre-agent-infrastructure.yaml`)
- [ ] Prepare deployment parameters:
  - [ ] ProjectName: `sre-agent`
  - [ ] Environment: `production`
  - [ ] InstanceType: `t3.xlarge`
  - [ ] KeyPairName: `your-key-pair-name`
  - [ ] SSHAccessCIDR: `your-ip/32`
  - [ ] DomainName: `sre-agent.yourdomain.com` (optional)
  - [ ] CertificateArn: ACM certificate ARN (optional)

#### Console Deployment
- [ ] Navigate to CloudFormation Console
- [ ] Create stack with template
- [ ] Fill in parameters
- [ ] Add appropriate tags
- [ ] Enable termination protection
- [ ] Deploy stack (10-15 minutes)
- [ ] Verify CREATE_COMPLETE status

#### CLI Deployment
```bash
aws cloudformation create-stack \
  --stack-name sre-agent-production \
  --template-body file://cloudformation/sre-agent-infrastructure.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=Project,Value=SRE-Agent Key=Environment,Value=Production
```

### Step 2: Verify Infrastructure Resources
- [ ] **VPC and Networking**
  - [ ] VPC created with proper CIDR (10.0.0.0/16)
  - [ ] Public subnet with internet gateway
  - [ ] Private subnet for future expansion
  - [ ] Route tables configured correctly
  - [ ] Security groups allow required ports (22, 443, 8011-8014)

- [ ] **EC2 Instance**
  - [ ] Instance running and accessible
  - [ ] Proper instance type (t3.xlarge)
  - [ ] IAM role attached (SREAgentEC2Role)
  - [ ] Security group attached
  - [ ] EBS volume encrypted (50GB GP3)
  - [ ] Public IP assigned

- [ ] **IAM Roles and Policies**
  - [ ] SREAgentEC2Role created with proper policies
  - [ ] BedrockAgentCoreRole created with trust policy
  - [ ] Instance profile attached to EC2
  - [ ] Bedrock permissions configured
  - [ ] S3 access permissions
  - [ ] Cognito access permissions
  - [ ] CloudWatch permissions

- [ ] **S3 Bucket**
  - [ ] Bucket created with unique name
  - [ ] Encryption enabled (AES256)
  - [ ] Versioning enabled
  - [ ] Bucket policy configured for AgentCore access
  - [ ] Public access blocked appropriately

- [ ] **Cognito User Pool**
  - [ ] User pool created with strong password policy
  - [ ] App client created with client secret
  - [ ] Resource server configured
  - [ ] Domain configured
  - [ ] OAuth scopes defined

- [ ] **CloudWatch Resources**
  - [ ] Log groups created
  - [ ] CloudWatch agent configuration
  - [ ] Metrics namespace configured

- [ ] **SSM Parameters**
  - [ ] Configuration parameters stored
  - [ ] Proper parameter hierarchy
  - [ ] Secure string parameters encrypted

## Application Deployment

### Step 3: Connect to EC2 Instance
```bash
# Get connection details from CloudFormation outputs
aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].Outputs'

# Connect via SSH
ssh -i your-key-pair.pem ec2-user@<INSTANCE_PUBLIC_IP>
```

### Step 4: Run Deployment Script
- [ ] Make deployment script executable
- [ ] Set environment variables (if needed)
- [ ] Run deployment script
- [ ] Monitor deployment progress
- [ ] Verify successful completion

```bash
sudo chmod +x /opt/sre-agent/scripts/deploy-sre-agent.sh
export DOMAIN_NAME="sre-agent.yourdomain.com"  # Optional
/opt/sre-agent/scripts/deploy-sre-agent.sh
```

### Step 5: SSL Certificate Configuration
- [ ] **If using custom domain:**
  - [ ] DNS A record pointing to EC2 public IP
  - [ ] Let's Encrypt certificate obtained
  - [ ] Certificate auto-renewal configured
  - [ ] Certificate files linked to /opt/ssl/

- [ ] **If using ACM certificate:**
  - [ ] Certificate validated and issued
  - [ ] Load balancer configured (if applicable)

### Step 6: Application Configuration
- [ ] **Environment Files**
  - [ ] `sre_agent/.env` configured with proper values
  - [ ] `gateway/.env` configured with Cognito settings
  - [ ] `gateway/config.yaml` configured with AWS resources

- [ ] **OpenAPI Specifications**
  - [ ] Generated with correct backend domain
  - [ ] Uploaded to S3 bucket
  - [ ] Accessible by AgentCore Gateway

- [ ] **Backend Services**
  - [ ] All 4 backend APIs running (ports 8011-8014)
  - [ ] SSL configured if certificates available
  - [ ] Health endpoints responding
  - [ ] Logs being written correctly

- [ ] **AgentCore Gateway**
  - [ ] Gateway created successfully
  - [ ] Credential provider configured
  - [ ] MCP commands executed
  - [ ] Gateway URI updated in agent config
  - [ ] Access token generated and configured

- [ ] **Memory System**
  - [ ] Memory system initialized
  - [ ] User preferences configured
  - [ ] Memory status verified (may take 10-12 minutes)

## Validation and Testing

### Step 7: Run Validation Script
```bash
sudo chmod +x /opt/sre-agent/scripts/validate-deployment.sh
/opt/sre-agent/scripts/validate-deployment.sh
```

### Step 8: Manual Testing
- [ ] **System Requirements**
  - [ ] Python 3.12+ installed
  - [ ] UV package manager working
  - [ ] Docker installed and running
  - [ ] Required system packages available

- [ ] **AWS Connectivity**
  - [ ] AWS CLI working with proper credentials
  - [ ] Bedrock access verified
  - [ ] S3 bucket accessible
  - [ ] Cognito user pool accessible

- [ ] **Application Testing**
  - [ ] SRE Agent CLI available
  - [ ] Virtual environment activated
  - [ ] Dependencies installed correctly
  - [ ] Basic functionality test passes

- [ ] **Service Testing**
  - [ ] Systemd service created and enabled
  - [ ] Service starts automatically
  - [ ] Service logs accessible
  - [ ] Service restarts on failure

- [ ] **Network Testing**
  - [ ] Internet connectivity working
  - [ ] AWS endpoints accessible
  - [ ] Backend APIs responding
  - [ ] SSL certificates valid (if configured)

### Step 9: End-to-End Testing
```bash
# Test SRE Agent functionality
cd /opt/sre-agent
source .venv/bin/activate
uv run sre-agent --prompt "Test the system health"
```

- [ ] Agent responds to queries
- [ ] Backend APIs are accessible
- [ ] Gateway authentication working
- [ ] Memory system functioning
- [ ] Logs being generated

## Production Readiness

### Step 10: Security Hardening
- [ ] **Network Security**
  - [ ] SSH access restricted to specific IPs
  - [ ] Security groups follow least privilege
  - [ ] VPC Flow Logs enabled
  - [ ] Network ACLs configured

- [ ] **System Security**
  - [ ] OS updates applied
  - [ ] Unnecessary services disabled
  - [ ] File permissions properly set
  - [ ] Audit logging enabled

- [ ] **AWS Security**
  - [ ] CloudTrail enabled
  - [ ] Config rules configured
  - [ ] GuardDuty enabled
  - [ ] Security Hub enabled

### Step 11: Monitoring and Alerting
- [ ] **CloudWatch Configuration**
  - [ ] CloudWatch agent running
  - [ ] Custom metrics configured
  - [ ] Log groups created
  - [ ] Dashboards created

- [ ] **Alerting Setup**
  - [ ] SNS topics created
  - [ ] CloudWatch alarms configured
  - [ ] Error rate monitoring
  - [ ] Resource utilization alerts

### Step 12: Backup and Recovery
- [ ] **Data Backup**
  - [ ] EBS snapshots scheduled
  - [ ] S3 bucket versioning enabled
  - [ ] Configuration files backed up
  - [ ] Database backups (if applicable)

- [ ] **Disaster Recovery**
  - [ ] Recovery procedures documented
  - [ ] Multi-region strategy planned
  - [ ] RTO/RPO defined
  - [ ] Recovery testing scheduled

### Step 13: Documentation
- [ ] **Operational Documentation**
  - [ ] Deployment procedures documented
  - [ ] Configuration parameters recorded
  - [ ] Troubleshooting guide created
  - [ ] Contact information updated

- [ ] **Security Documentation**
  - [ ] Security controls documented
  - [ ] Compliance requirements met
  - [ ] Incident response procedures
  - [ ] Access control matrix

## Post-Deployment Tasks

### Step 14: Performance Optimization
- [ ] **Resource Optimization**
  - [ ] Instance sizing validated
  - [ ] Storage performance optimized
  - [ ] Network performance tested
  - [ ] Cost optimization reviewed

- [ ] **Application Tuning**
  - [ ] Memory allocation optimized
  - [ ] Connection pooling configured
  - [ ] Caching strategies implemented
  - [ ] Load testing completed

### Step 15: Maintenance Planning
- [ ] **Regular Maintenance**
  - [ ] Update schedule defined
  - [ ] Maintenance windows planned
  - [ ] Change management process
  - [ ] Version control strategy

- [ ] **Operational Procedures**
  - [ ] Health check procedures
  - [ ] Log rotation configured
  - [ ] Certificate renewal process
  - [ ] Token refresh automation

## Final Validation Checklist

### Critical Success Criteria
- [ ] All CloudFormation resources deployed successfully
- [ ] EC2 instance accessible and properly configured
- [ ] All AWS services (Bedrock, S3, Cognito) accessible
- [ ] SRE Agent application running and responsive
- [ ] Backend APIs healthy and accessible
- [ ] SSL certificates valid and properly configured
- [ ] Monitoring and alerting functional
- [ ] Security controls implemented
- [ ] Documentation complete

### Performance Benchmarks
- [ ] Response time < 5 seconds for typical queries
- [ ] System resource utilization < 70% under normal load
- [ ] All health checks passing
- [ ] Error rate < 1%
- [ ] Uptime > 99.9%

### Security Validation
- [ ] No critical security vulnerabilities
- [ ] All access properly authenticated and authorized
- [ ] Audit logging functional
- [ ] Encryption in transit and at rest
- [ ] Compliance requirements met

## Sign-off

### Technical Sign-off
- [ ] **Infrastructure Team**: _________________ Date: _________
- [ ] **Security Team**: _________________ Date: _________
- [ ] **Operations Team**: _________________ Date: _________

### Business Sign-off
- [ ] **Project Manager**: _________________ Date: _________
- [ ] **Business Owner**: _________________ Date: _________

### Go-Live Approval
- [ ] **Production Ready**: ☐ Yes ☐ No
- [ ] **Go-Live Date**: _________________
- [ ] **Rollback Plan**: ☐ Documented ☐ Tested

---

**Notes:**
- This checklist should be completed in order
- All items must be checked before production go-live
- Any deviations must be documented and approved
- Regular reviews should be scheduled post-deployment