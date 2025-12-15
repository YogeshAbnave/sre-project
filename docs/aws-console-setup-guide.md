# AWS Console Setup Guide for SRE Agent Production Deployment

This guide provides detailed step-by-step instructions for setting up all required AWS resources using the AWS Console (GUI). Follow these instructions in order to ensure proper configuration for your production SRE Agent deployment.

## Prerequisites Checklist

Before starting, ensure you have:
- [ ] AWS Account with administrative access
- [ ] Domain name registered (for SSL certificates)
- [ ] Basic understanding of AWS services
- [ ] Access to AWS Console (https://console.aws.amazon.com)

## Overview of Resources to Create

You will create the following AWS resources:
1. **IAM Roles and Policies** - Service permissions and trust relationships
2. **EC2 Instance** - Production server with proper sizing and security
3. **Security Groups** - Network access control for required ports
4. **S3 Bucket** - Storage for OpenAPI schemas and configurations
5. **Amazon Cognito User Pool** - Authentication and JWT token management
6. **SSL Certificate** - Secure HTTPS communication

---

## Step 1: Create IAM Roles and Policies

### 1.1 Create SRE Agent EC2 Instance Role

**Purpose**: This role allows the EC2 instance to access Bedrock, S3, and Cognito services.

1. **Navigate to IAM Console**
   - Go to https://console.aws.amazon.com/iam/
   - Click on "Roles" in the left sidebar

2. **Create New Role**
   - Click "Create role" button
   - Select "AWS service" as trusted entity type
   - Choose "EC2" from the service list
   - Click "Next"

3. **Attach Policies**
   - Search for and select the following managed policies:
     - `AmazonBedrockFullAccess`
     - `AmazonS3FullAccess` 
     - `AmazonCognitoPowerUser`
   - Click "Next"

4. **Configure Role Details**
   - Role name: `SREAgentEC2Role`
   - Description: `IAM role for SRE Agent EC2 instance with Bedrock, S3, and Cognito access`
   - Click "Create role"

5. **Note the Role ARN**
   - After creation, click on the role name
   - Copy the Role ARN (format: `arn:aws:iam::ACCOUNT-ID:role/SREAgentEC2Role`)
   - Save this ARN - you'll need it later

### 1.2 Create Bedrock AgentCore Gateway Role

**Purpose**: This role allows the AgentCore Gateway service to operate with proper permissions.

1. **Create New Role**
   - Click "Create role" button
   - Select "AWS service" as trusted entity type
   - Choose "Bedrock" from the service list (if available) or "Custom trust policy"

2. **Configure Trust Policy** (if using custom trust policy)
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Service": "bedrock-agentcore.amazonaws.com"
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   ```

3. **Attach Policies**
   - Search for and select: `BedrockAgentCoreFullAccess`
   - If not available, create a custom policy with these permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "bedrock:*",
           "s3:GetObject",
           "s3:PutObject",
           "cognito-idp:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

4. **Configure Role Details**
   - Role name: `BedrockAgentCoreGatewayRole`
   - Description: `IAM role for Bedrock AgentCore Gateway service`
   - Click "Create role"

---

## Step 2: Create EC2 Instance

### 2.1 Launch EC2 Instance

1. **Navigate to EC2 Console**
   - Go to https://console.aws.amazon.com/ec2/
   - Click "Launch instance"

2. **Configure Instance Details**
   - **Name**: `SRE-Agent-Production`
   - **Application and OS Images**: 
     - Select "Amazon Linux 2023 AMI" or "Ubuntu Server 22.04 LTS"
   - **Instance type**: `t3.xlarge` (4 vCPU, 16 GB RAM)
   - **Key pair**: Create new or select existing key pair for SSH access

3. **Network Settings**
   - **VPC**: Use default VPC or create new one
   - **Subnet**: Select public subnet for internet access
   - **Auto-assign public IP**: Enable
   - **Security group**: Create new (we'll configure this next)

4. **Configure Storage**
   - **Root volume**: 50 GB GP3 SSD
   - **Encryption**: Enable (recommended for production)

5. **Advanced Details**
   - **IAM instance profile**: Select `SREAgentEC2Role` (created in Step 1.1)
   - **User data** (optional - for automated setup):
   ```bash
   #!/bin/bash
   yum update -y
   yum install -y docker git python3 python3-pip
   systemctl start docker
   systemctl enable docker
   usermod -a -G docker ec2-user
   
   # Install UV package manager
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

6. **Launch Instance**
   - Review all settings
   - Click "Launch instance"
   - Note the Instance ID for reference

### 2.2 Create Security Group

1. **Navigate to Security Groups**
   - In EC2 Console, click "Security Groups" in left sidebar
   - Click "Create security group"

2. **Configure Security Group**
   - **Name**: `SRE-Agent-Security-Group`
   - **Description**: `Security group for SRE Agent production instance`
   - **VPC**: Select same VPC as EC2 instance

3. **Configure Inbound Rules**
   Add the following rules:
   
   | Type | Protocol | Port Range | Source | Description |
   |------|----------|------------|--------|-------------|
   | SSH | TCP | 22 | Your IP/32 | SSH access (restrict to your IP) |
   | HTTPS | TCP | 443 | 0.0.0.0/0 | HTTPS web traffic |
   | Custom TCP | TCP | 8011 | VPC CIDR | Backend API - K8s |
   | Custom TCP | TCP | 8012 | VPC CIDR | Backend API - Logs |
   | Custom TCP | TCP | 8013 | VPC CIDR | Backend API - Metrics |
   | Custom TCP | TCP | 8014 | VPC CIDR | Backend API - Runbooks |

4. **Configure Outbound Rules**
   - Keep default "All traffic" to 0.0.0.0/0 (allows all outbound)

5. **Create Security Group**
   - Click "Create security group"
   - Note the Security Group ID

6. **Attach to EC2 Instance**
   - Go back to EC2 Instances
   - Select your SRE Agent instance
   - Click "Actions" → "Security" → "Change security groups"
   - Select the new security group
   - Click "Save"

---

## Step 3: Create S3 Bucket

### 3.1 Create S3 Bucket for OpenAPI Schemas

1. **Navigate to S3 Console**
   - Go to https://console.aws.amazon.com/s3/
   - Click "Create bucket"

2. **Configure Bucket Settings**
   - **Bucket name**: `sre-agent-schemas-[YOUR-ACCOUNT-ID]` (must be globally unique)
   - **Region**: Same region as your EC2 instance (e.g., us-east-1)
   - **Object Ownership**: ACLs disabled (recommended)

3. **Configure Public Access Settings**
   - **Block all public access**: Uncheck (we need controlled public access)
   - Acknowledge the warning about public access

4. **Configure Additional Settings**
   - **Bucket Versioning**: Enable (recommended for production)
   - **Default encryption**: Enable with SSE-S3
   - **Object Lock**: Disable (not needed for this use case)

5. **Create Bucket**
   - Review settings and click "Create bucket"

### 3.2 Configure Bucket Policy

1. **Navigate to Bucket Permissions**
   - Click on your newly created bucket
   - Go to "Permissions" tab
   - Scroll to "Bucket policy" section

2. **Add Bucket Policy**
   Replace `YOUR-BUCKET-NAME` and `YOUR-ACCOUNT-ID` with actual values:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowAgentCoreAccess",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::YOUR-ACCOUNT-ID:role/BedrockAgentCoreGatewayRole"
         },
         "Action": [
           "s3:GetObject",
           "s3:PutObject"
         ],
         "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
       },
       {
         "Sid": "AllowEC2InstanceAccess",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::YOUR-ACCOUNT-ID:role/SREAgentEC2Role"
         },
         "Action": [
           "s3:GetObject",
           "s3:PutObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::YOUR-BUCKET-NAME",
           "arn:aws:s3:::YOUR-BUCKET-NAME/*"
         ]
       }
     ]
   }
   ```

3. **Save Policy**
   - Click "Save changes"

### 3.3 Configure CORS (if needed for web access)

1. **Navigate to CORS Configuration**
   - In bucket settings, go to "Permissions" tab
   - Scroll to "Cross-origin resource sharing (CORS)" section

2. **Add CORS Configuration**
   ```json
   [
     {
       "AllowedHeaders": ["*"],
       "AllowedMethods": ["GET", "PUT", "POST"],
       "AllowedOrigins": ["https://your-domain.com"],
       "ExposeHeaders": []
     }
   ]
   ```

---

## Step 4: Create Amazon Cognito User Pool

### 4.1 Create User Pool

1. **Navigate to Cognito Console**
   - Go to https://console.aws.amazon.com/cognito/
   - Click "Create user pool"

2. **Configure Sign-in Experience**
   - **Authentication providers**: Cognito user pool
   - **Cognito user pool sign-in options**: Email
   - Click "Next"

3. **Configure Security Requirements**
   - **Password policy**: Default or custom (recommend strong policy for production)
   - **Multi-factor authentication**: Optional (recommended for production)
   - **User account recovery**: Email only
   - Click "Next"

4. **Configure Sign-up Experience**
   - **Self-service sign-up**: Enable
   - **Required attributes**: Email
   - **Optional attributes**: Add as needed (name, phone_number)
   - Click "Next"

5. **Configure Message Delivery**
   - **Email provider**: Send email with Cognito (for testing) or SES (for production)
   - Configure email settings as needed
   - Click "Next"

6. **Integrate Your App**
   - **User pool name**: `SRE-Agent-UserPool`
   - **App client name**: `SRE-Agent-Client`
   - **Client secret**: Generate (required for server-side apps)
   - Click "Next"

7. **Review and Create**
   - Review all settings
   - Click "Create user pool"

### 4.2 Configure App Client Settings

1. **Navigate to App Client**
   - Click on your user pool
   - Go to "App integration" tab
   - Click on your app client

2. **Configure OAuth Settings**
   - **Allowed OAuth flows**: Authorization code grant
   - **Allowed OAuth scopes**: email, openid, profile
   - **Callback URLs**: Add your application URLs
   - **Sign out URLs**: Add your application URLs

3. **Save Changes**

### 4.3 Create Domain (Optional but Recommended)

1. **Navigate to Domain**
   - In user pool settings, go to "App integration" tab
   - Click "Actions" → "Create Cognito domain"

2. **Configure Domain**
   - **Domain prefix**: `sre-agent-auth-[random-string]`
   - Check availability
   - Click "Create domain"

3. **Note Domain URL**
   - Save the full domain URL (e.g., `https://sre-agent-auth-xyz.auth.us-east-1.amazoncognito.com`)

---

## Step 5: SSL Certificate Setup

### 5.1 Domain Registration (if not already done)

1. **Register Domain**
   - Use Route 53, GoDaddy, Namecheap, or any domain registrar
   - Choose a domain name for your SRE Agent (e.g., `sre-agent.yourdomain.com`)

2. **Configure DNS**
   - Point your domain to your EC2 instance's public IP
   - Create an A record: `sre-agent.yourdomain.com` → `EC2-PUBLIC-IP`

### 5.2 SSL Certificate with Let's Encrypt (Recommended)

**Note**: This will be done on the EC2 instance after connecting via SSH.

1. **Connect to EC2 Instance**
   ```bash
   ssh -i your-key.pem ec2-user@your-ec2-public-ip
   ```

2. **Install Certbot**
   ```bash
   # For Amazon Linux 2023
   sudo yum install -y certbot python3-certbot-nginx

   # For Ubuntu
   sudo apt update
   sudo apt install -y certbot python3-certbot-nginx
   ```

3. **Obtain Certificate**
   ```bash
   sudo certbot certonly --standalone -d your-domain.com
   ```

4. **Set Up Auto-Renewal**
   ```bash
   sudo crontab -e
   # Add this line:
   0 12 * * * /usr/bin/certbot renew --quiet
   ```

5. **Note Certificate Paths**
   - Certificate: `/etc/letsencrypt/live/your-domain.com/fullchain.pem`
   - Private Key: `/etc/letsencrypt/live/your-domain.com/privkey.pem`

---

## Step 6: Verification Checklist

After completing all steps, verify the following:

- [ ] **IAM Roles Created**
  - SREAgentEC2Role with proper policies
  - BedrockAgentCoreGatewayRole with trust policy

- [ ] **EC2 Instance Running**
  - t3.xlarge instance with proper IAM role
  - Security group with required ports
  - Public IP assigned and accessible

- [ ] **S3 Bucket Configured**
  - Bucket created with proper naming
  - Bucket policy allows required access
  - CORS configured if needed

- [ ] **Cognito User Pool Ready**
  - User pool created with app client
  - OAuth settings configured
  - Domain created (optional)

- [ ] **SSL Certificate Installed**
  - Domain pointing to EC2 instance
  - Valid SSL certificate obtained
  - Auto-renewal configured

- [ ] **Network Connectivity**
  - SSH access to EC2 instance works
  - Domain resolves to EC2 public IP
  - HTTPS access works (after SRE Agent deployment)

---

## Next Steps

Once all AWS resources are created and configured:

1. **Record Configuration Values**
   - Save all ARNs, IDs, and URLs in a secure location
   - You'll need these for the SRE Agent configuration

2. **Proceed to SRE Agent Installation**
   - SSH into your EC2 instance
   - Follow the SRE Agent installation and configuration guide

3. **Test the Complete Setup**
   - Verify all components work together
   - Run connectivity tests
   - Validate security configurations

## Troubleshooting Common Issues

### IAM Permission Issues
- Ensure roles have correct policies attached
- Verify trust relationships are properly configured
- Check that instance profile is attached to EC2

### Network Connectivity Issues
- Verify security group rules allow required traffic
- Check that EC2 instance is in public subnet
- Ensure internet gateway is attached to VPC

### SSL Certificate Issues
- Verify domain DNS is pointing to correct IP
- Check that port 80 is accessible for Let's Encrypt validation
- Ensure certificate files have correct permissions

### S3 Access Issues
- Verify bucket policy syntax is correct
- Check that IAM roles have S3 permissions
- Ensure bucket name is globally unique

For additional help, refer to AWS documentation or contact AWS support.