# CloudFormation Deployment Guide for SRE Agent

This guide provides step-by-step instructions for deploying the SRE Agent infrastructure using AWS CloudFormation.

## Prerequisites

Before starting the deployment, ensure you have:

- [ ] AWS CLI installed and configured with appropriate permissions
- [ ] An AWS account with administrative access
- [ ] An EC2 Key Pair created in your target region
- [ ] A registered domain name (optional, for SSL certificates)
- [ ] Basic understanding of AWS services

## Required AWS Permissions

Your AWS user/role needs the following permissions:
- CloudFormation full access
- EC2 full access
- IAM full access
- S3 full access
- Cognito full access
- Bedrock full access
- CloudWatch full access
- SSM full access

## Deployment Methods

### Method 1: AWS Console (GUI) Deployment

#### Step 1: Prepare Parameters

1. **Download the CloudFormation template**:
   - Save `cloudformation/sre-agent-infrastructure.yaml` to your local machine

2. **Gather required parameters**:
   - **ProjectName**: `sre-agent` (default)
   - **Environment**: `production` (or `development`/`staging`)
   - **InstanceType**: `t3.xlarge` (recommended for production)
   - **KeyPairName**: Your existing EC2 key pair name
   - **SSHAccessCIDR**: Your IP address in CIDR format (e.g., `203.0.113.0/32`)
   - **DomainName**: Your domain name (optional, e.g., `sre-agent.yourdomain.com`)
   - **CertificateArn**: ACM certificate ARN (optional)

#### Step 2: Deploy via AWS Console

1. **Navigate to CloudFormation Console**:
   - Go to https://console.aws.amazon.com/cloudformation/
   - Select your target region

2. **Create Stack**:
   - Click "Create stack" → "With new resources (standard)"
   - Choose "Upload a template file"
   - Upload `sre-agent-infrastructure.yaml`
   - Click "Next"

3. **Specify Stack Details**:
   - **Stack name**: `sre-agent-production`
   - Fill in all parameters with your values
   - Click "Next"

4. **Configure Stack Options**:
   - **Tags** (optional but recommended):
     - Key: `Project`, Value: `SRE-Agent`
     - Key: `Environment`, Value: `Production`
     - Key: `Owner`, Value: `Your-Name`
   - **Permissions**: Use default or specify a service role
   - **Stack failure options**: Select "Roll back all stack resources"
   - Click "Next"

5. **Review and Create**:
   - Review all settings
   - Check "I acknowledge that AWS CloudFormation might create IAM resources"
   - Click "Create stack"

6. **Monitor Deployment**:
   - Watch the "Events" tab for progress
   - Deployment typically takes 10-15 minutes
   - Wait for status to show "CREATE_COMPLETE"

#### Step 3: Retrieve Outputs

After successful deployment, go to the "Outputs" tab to get:
- **InstancePublicIP**: Public IP address of your EC2 instance
- **SSHCommand**: Command to SSH into your instance
- **S3BucketName**: Name of the created S3 bucket
- **UserPoolId**: Cognito User Pool ID
- **CognitoDomain**: Cognito authentication domain

### Method 2: AWS CLI Deployment

#### Step 1: Validate Template

```bash
aws cloudformation validate-template \
  --template-body file://cloudformation/sre-agent-infrastructure.yaml
```

#### Step 2: Deploy Stack

```bash
aws cloudformation create-stack \
  --stack-name sre-agent-production \
  --template-body file://cloudformation/sre-agent-infrastructure.yaml \
  --parameters \
    ParameterKey=ProjectName,ParameterValue=sre-agent \
    ParameterKey=Environment,ParameterValue=production \
    ParameterKey=InstanceType,ParameterValue=t3.xlarge \
    ParameterKey=KeyPairName,ParameterValue=your-key-pair-name \
    ParameterKey=SSHAccessCIDR,ParameterValue=your.ip.address/32 \
    ParameterKey=DomainName,ParameterValue=sre-agent.yourdomain.com \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags \
    Key=Project,Value=SRE-Agent \
    Key=Environment,Value=Production
```

#### Step 3: Monitor Deployment

```bash
# Check stack status
aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].StackStatus'

# Watch events
aws cloudformation describe-stack-events \
  --stack-name sre-agent-production \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table
```

#### Step 4: Get Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name sre-agent-production \
  --query 'Stacks[0].Outputs' \
  --output table
```

## Post-Deployment Steps

### Step 1: Connect to EC2 Instance

```bash
# Use the SSH command from CloudFormation outputs
ssh -i your-key-pair.pem ec2-user@<INSTANCE_PUBLIC_IP>
```

### Step 2: Run Deployment Script

```bash
# On the EC2 instance, run the deployment script
sudo chmod +x /opt/sre-agent/scripts/deploy-sre-agent.sh

# Set environment variables (optional)
export DOMAIN_NAME="sre-agent.yourdomain.com"  # If you have a domain
export GITHUB_REPO="https://github.com/awslabs/amazon-bedrock-agentcore-samples"

# Run deployment
/opt/sre-agent/scripts/deploy-sre-agent.sh
```

### Step 3: Configure DNS (if using custom domain)

If you provided a domain name:

1. **Update DNS Records**:
   - Create an A record pointing your domain to the EC2 instance public IP
   - Example: `sre-agent.yourdomain.com` → `<INSTANCE_PUBLIC_IP>`

2. **Wait for DNS Propagation**:
   - DNS changes can take up to 48 hours to propagate
   - Test with: `nslookup sre-agent.yourdomain.com`

### Step 4: Verify Deployment

1. **Check Service Status**:
   ```bash
   sudo systemctl status sre-agent
   ```

2. **View Logs**:
   ```bash
   sudo journalctl -u sre-agent -f
   ```

3. **Test API Endpoints**:
   ```bash
   # Test backend APIs
   curl -k https://<INSTANCE_IP>:8011/health
   curl -k https://<INSTANCE_IP>:8012/health
   curl -k https://<INSTANCE_IP>:8013/health
   curl -k https://<INSTANCE_IP>:8014/health
   ```

4. **Test SRE Agent**:
   ```bash
   cd /opt/sre-agent
   source .venv/bin/activate
   uv run sre-agent --prompt "Test the system"
   ```

## Troubleshooting

### Common Issues

#### 1. CloudFormation Stack Creation Failed

**Symptoms**: Stack shows "CREATE_FAILED" status

**Solutions**:
- Check the "Events" tab for specific error messages
- Verify you have sufficient permissions
- Ensure the key pair exists in the target region
- Check if resource limits are exceeded

#### 2. EC2 Instance Not Accessible

**Symptoms**: Cannot SSH to the instance

**Solutions**:
- Verify security group allows SSH from your IP
- Check if the key pair is correct
- Ensure the instance is in a public subnet
- Verify the instance has a public IP

#### 3. SSL Certificate Issues

**Symptoms**: HTTPS not working, certificate errors

**Solutions**:
- Ensure domain points to the correct IP address
- Wait for DNS propagation (up to 48 hours)
- Check Let's Encrypt rate limits
- Verify port 80 is accessible for certificate validation

#### 4. Backend Services Not Starting

**Symptoms**: API endpoints return connection errors

**Solutions**:
- Check service logs: `sudo journalctl -u sre-agent -f`
- Verify Python dependencies are installed
- Check if ports 8011-8014 are accessible
- Ensure SSL certificates are properly configured

### Debugging Commands

```bash
# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name sre-agent-production

# Check EC2 instance status
aws ec2 describe-instances --instance-ids <INSTANCE_ID>

# Check security group rules
aws ec2 describe-security-groups --group-ids <SECURITY_GROUP_ID>

# Check S3 bucket
aws s3 ls s3://<BUCKET_NAME>

# Check Cognito user pool
aws cognito-idp describe-user-pool --user-pool-id <USER_POOL_ID>
```

## Cleanup

### Delete Stack via Console

1. Go to CloudFormation Console
2. Select your stack
3. Click "Delete"
4. Confirm deletion

### Delete Stack via CLI

```bash
aws cloudformation delete-stack --stack-name sre-agent-production
```

**Note**: Some resources may need manual cleanup:
- S3 bucket contents (if versioning is enabled)
- CloudWatch log groups
- SSL certificates (if using ACM)

## Cost Optimization

### Estimated Monthly Costs

| Resource | Type | Estimated Cost |
|----------|------|----------------|
| EC2 Instance | t3.xlarge | ~$150/month |
| EBS Storage | 50GB GP3 | ~$5/month |
| S3 Storage | <1GB | <$1/month |
| CloudWatch Logs | Standard usage | ~$5/month |
| Cognito | <1000 users | Free tier |
| **Total** | | **~$160/month** |

### Cost Reduction Tips

1. **Use Spot Instances**: For development/testing environments
2. **Schedule Instances**: Stop instances during non-business hours
3. **Right-size Instances**: Monitor usage and adjust instance type
4. **Use Reserved Instances**: For long-term production workloads
5. **Enable S3 Lifecycle Policies**: Archive old logs and data

## Security Best Practices

1. **Restrict SSH Access**: Use specific IP addresses, not 0.0.0.0/0
2. **Enable VPC Flow Logs**: Monitor network traffic
3. **Use IAM Roles**: Avoid hardcoded credentials
4. **Enable CloudTrail**: Audit API calls
5. **Regular Updates**: Keep OS and packages updated
6. **Monitor Logs**: Set up CloudWatch alarms for suspicious activity

## Next Steps

After successful deployment:

1. **Configure Monitoring**: Set up CloudWatch dashboards and alarms
2. **Backup Strategy**: Implement automated backups for critical data
3. **Disaster Recovery**: Plan for multi-region deployment
4. **Performance Tuning**: Monitor and optimize based on usage patterns
5. **Security Hardening**: Implement additional security measures
6. **Documentation**: Document your specific configuration and procedures