# AWS Configuration Worksheet

Use this worksheet to record all the configuration values as you create AWS resources. You'll need these values for configuring the SRE Agent.

## AWS Account Information

- **AWS Account ID**: `_________________________`
- **AWS Region**: `_________________________` (e.g., us-east-1)
- **Your IP Address**: `_________________________` (for security group SSH access)

## IAM Roles

### SRE Agent EC2 Role
- **Role Name**: `SREAgentEC2Role`
- **Role ARN**: `arn:aws:iam::____________:role/SREAgentEC2Role`

### Bedrock AgentCore Gateway Role  
- **Role Name**: `BedrockAgentCoreGatewayRole`
- **Role ARN**: `arn:aws:iam::____________:role/BedrockAgentCoreGatewayRole`

## EC2 Instance

- **Instance ID**: `i-_________________________`
- **Instance Type**: `t3.xlarge`
- **Public IP Address**: `_________________________`
- **Private IP Address**: `_________________________`
- **Key Pair Name**: `_________________________`
- **Security Group ID**: `sg-_________________________`
- **Security Group Name**: `SRE-Agent-Security-Group`

## S3 Bucket

- **Bucket Name**: `sre-agent-schemas-____________`
- **Bucket ARN**: `arn:aws:s3:::sre-agent-schemas-____________`
- **Region**: `_________________________`

## Amazon Cognito

- **User Pool ID**: `_________________________`
- **User Pool ARN**: `arn:aws:cognito-idp:______:______:userpool/____________`
- **App Client ID**: `_________________________`
- **App Client Secret**: `_________________________` (keep secure!)
- **Cognito Domain**: `https://____________.auth.______.amazoncognito.com`

## Domain and SSL Certificate

- **Domain Name**: `_________________________` (e.g., sre-agent.yourdomain.com)
- **SSL Certificate Path**: `/etc/letsencrypt/live/____________/fullchain.pem`
- **SSL Private Key Path**: `/etc/letsencrypt/live/____________/privkey.pem`

## Network Configuration

- **VPC ID**: `vpc-_________________________`
- **Subnet ID**: `subnet-_________________________`
- **Internet Gateway ID**: `igw-_________________________`

## Configuration Files to Update

Once you have all the above information, you'll need to update these files in your SRE Agent project:

### gateway/config.yaml
```yaml
account_id: "YOUR_ACCOUNT_ID"
region: "YOUR_REGION"
role_name: "SREAgentEC2Role"
user_pool_id: "YOUR_USER_POOL_ID"
client_id: "YOUR_CLIENT_ID"
s3_bucket: "YOUR_BUCKET_NAME"
gateway_name: "SREAgentGateway"
```

### gateway/.env
```bash
COGNITO_DOMAIN=https://YOUR_DOMAIN.auth.YOUR_REGION.amazoncognito.com
COGNITO_CLIENT_ID=YOUR_CLIENT_ID
COGNITO_CLIENT_SECRET=YOUR_CLIENT_SECRET
COGNITO_USER_POOL_ID=YOUR_USER_POOL_ID
BACKEND_API_KEY=your-backend-api-key-here
```

### sre_agent/.env
```bash
GATEWAY_ACCESS_TOKEN=will-be-generated-later
LLM_PROVIDER=bedrock
DEBUG=false
# Optional: ANTHROPIC_API_KEY=sk-ant-your-key-here
```

## Verification Commands

After setup, run these commands on your EC2 instance to verify everything is working:

```bash
# Check AWS CLI access
aws sts get-caller-identity

# Check S3 bucket access
aws s3 ls s3://YOUR_BUCKET_NAME

# Check Cognito access
aws cognito-idp describe-user-pool --user-pool-id YOUR_USER_POOL_ID

# Check SSL certificate
sudo certbot certificates

# Check network connectivity
curl -I https://YOUR_DOMAIN.com
```

## Security Checklist

- [ ] SSH access restricted to your IP address only
- [ ] IAM roles follow principle of least privilege
- [ ] S3 bucket has proper access policies
- [ ] SSL certificate is valid and auto-renewing
- [ ] Security groups only allow necessary ports
- [ ] Cognito user pool has strong password policy
- [ ] All sensitive values are stored securely

## Notes Section

Use this space for any additional notes or customizations:

```
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
```