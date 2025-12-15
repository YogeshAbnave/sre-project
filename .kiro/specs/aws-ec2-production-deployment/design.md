# AWS EC2 Production Deployment Design

## Overview

This design document outlines the comprehensive approach for deploying the SRE Agent POC project to an Amazon EC2 instance in a production environment. The system is a sophisticated multi-agent Site Reliability Engineering assistant that leverages Amazon Bedrock AgentCore, specialized AI agents, and MCP (Model Context Protocol) tools to investigate infrastructure issues, analyze logs, monitor performance metrics, and execute operational procedures.

The deployment strategy focuses on using the AWS Console (GUI) for all resource creation and configuration, providing detailed step-by-step instructions that ensure proper security, scalability, and maintainability in a production environment.

## Architecture

### High-Level Architecture

The production deployment consists of several interconnected components:

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Cloud Environment                    │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Amazon EC2    │    │  Amazon Bedrock │    │   Amazon    │ │
│  │   Instance      │◄──►│   AgentCore     │◄──►│   Cognito   │ │
│  │                 │    │   Gateway       │    │             │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│           │                       │                     │      │
│           ▼                       ▼                     ▼      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   SSL/TLS       │    │   Amazon S3     │    │   IAM Roles │ │
│  │  Certificates   │    │   (OpenAPI      │    │ & Policies  │ │
│  │                 │    │   Schemas)      │    │             │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

1. **User Request** → **EC2 Instance** (HTTPS with SSL)
2. **EC2 Instance** → **AgentCore Gateway** (Authenticated API calls)
3. **AgentCore Gateway** → **Cognito** (JWT token validation)
4. **AgentCore Gateway** → **S3** (OpenAPI schema retrieval)
5. **EC2 Instance** → **Bedrock** (LLM inference)
6. **EC2 Instance** → **Backend APIs** (MCP tool execution)

## Components and Interfaces

### 1. EC2 Instance Configuration

**Instance Specifications:**
- **Instance Type**: t3.xlarge or larger (4 vCPU, 16 GB RAM minimum)
- **Operating System**: Amazon Linux 2023 or Ubuntu 22.04 LTS
- **Storage**: 50 GB GP3 EBS volume minimum
- **Network**: VPC with public subnet for internet access

**Security Group Configuration:**
- **Port 443**: HTTPS traffic (0.0.0.0/0)
- **Port 8011-8014**: Backend API services (internal/VPC only)
- **Port 22**: SSH access (restricted IP ranges)

**Required Software Stack:**
- Python 3.12+
- UV package manager
- Docker and Docker Compose
- AWS CLI v2
- SSL certificate management tools

### 2. Amazon Bedrock AgentCore Gateway

**Gateway Configuration:**
- **Authentication**: Cognito JWT tokens
- **API Targets**: Multiple OpenAPI endpoints (K8s, Logs, Metrics, Runbooks)
- **Credential Provider**: API key-based authentication for backend services
- **Network**: HTTPS-only communication

**MCP Tool Integration:**
- Kubernetes operations (pod status, deployments, events)
- Log analysis (search, patterns, error detection)
- Metrics monitoring (performance, availability, trends)
- Runbook execution (incident response, troubleshooting)

### 3. Authentication and Authorization

**Amazon Cognito Configuration:**
- **User Pool**: JWT token issuance and validation
- **App Client**: OAuth 2.0 client credentials
- **Domain**: Custom domain for authentication endpoints
- **Security**: MFA support, password policies

**IAM Role Structure:**
- **EC2 Instance Role**: Bedrock, S3, and Cognito access
- **Gateway Role**: AgentCore service permissions
- **Service Roles**: Least privilege access for each component

### 4. SSL/TLS Certificate Management

**Certificate Requirements:**
- **Domain Registration**: Public domain name for HTTPS endpoints
- **Certificate Authority**: Let's Encrypt or commercial CA
- **Certificate Paths**: Standard locations (/opt/ssl/ or /etc/letsencrypt/)
- **Renewal**: Automated certificate renewal process

## Data Models

### Configuration Data Models

```python
@dataclass
class AWSConfig:
    account_id: str
    region: str
    role_name: str
    endpoint_url: str
    
    def validate(self) -> ValidationResult:
        """Validate AWS configuration parameters"""
        pass

@dataclass
class CredentialConfig:
    cognito_domain: str
    client_id: str
    client_secret: str
    user_pool_id: str
    
    def validate(self) -> ValidationResult:
        """Validate Cognito credential configuration"""
        pass

@dataclass
class GatewayConfig:
    gateway_name: str
    s3_bucket: str
    s3_path_prefix: str
    provider_arn: str
    
    def validate(self) -> ValidationResult:
        """Validate gateway configuration parameters"""
        pass

@dataclass
class DeploymentConfig:
    instance_type: str
    ssl_cert_path: str
    ssl_key_path: str
    domain_name: str
    
    def validate(self) -> ValidationResult:
        """Validate deployment configuration"""
        pass
```

### Validation and Result Models

```python
@dataclass
class ValidationResult:
    is_valid: bool
    errors: List[str]
    warnings: List[str]
    suggestions: List[str]

@dataclass
class SetupResult:
    success: bool
    component: str
    message: str
    details: Dict[str, Any]
    next_steps: List[str]

@dataclass
class VerificationReport:
    timestamp: datetime
    overall_status: str
    component_results: List[SetupResult]
    connectivity_tests: Dict[str, bool]
    recommendations: List[str]
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, several properties can be consolidated:
- Properties 1.1, 1.2, 1.4 can be combined into a comprehensive deployment validation property
- Properties 2.1, 2.3 can be combined into SSL/authentication validation
- Properties 3.2, 3.3, 3.4, 3.5 can be combined into AWS resource configuration validation
- Properties 4.1, 4.2, 4.3, 4.4 can be combined into comprehensive connectivity testing
- Properties 5.1, 5.2, 5.3, 5.4 can be combined into error handling validation

### Core Properties

**Property 1: Deployment Validation**
*For any* valid deployment configuration, the SRE Agent should successfully initialize all services, pass connectivity tests, and be accessible via HTTPS endpoints
**Validates: Requirements 1.1, 1.2, 1.3, 1.4**

**Property 2: SSL and Authentication Security**
*For any* connection attempt, the system should require valid SSL certificates and properly authenticate requests through Cognito JWT tokens
**Validates: Requirements 2.1, 2.2, 2.3**

**Property 3: AWS Resource Configuration**
*For any* AWS resource creation, the deployment process should configure IAM roles, security groups, S3 buckets, and Cognito with exact specifications that allow required access and deny unauthorized access
**Validates: Requirements 3.2, 3.3, 3.4, 3.5**

**Property 4: Comprehensive Connectivity Testing**
*For any* deployed system, all configuration validation, AWS service connectivity, API endpoint accessibility, and authentication testing should pass before marking deployment as complete
**Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5**

**Property 5: Error Handling and Recovery**
*For any* error condition during setup, the system should provide specific error messages with context, suggest alternative approaches, and support resuming from the last successful step
**Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**

**Property 6: Configuration Management**
*For any* deployment update or backup operation, the system should preserve existing configurations, migrate to new formats when needed, and handle conflicts with clear resolution options
**Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5**

**Property 7: Certificate Monitoring**
*For any* SSL certificate, the system should monitor expiration dates and provide warnings with renewal guidance before certificates expire
**Validates: Requirements 2.4**

**Property 8: Security Event Logging**
*For any* unauthorized access attempt, the system should reject the request and log security events with appropriate detail
**Validates: Requirements 2.5**

## Error Handling

### Error Categories and Responses

**1. Configuration Errors**
- Invalid environment variables → Specific validation messages with examples
- Missing required files → Clear file path guidance and template generation
- Malformed YAML/JSON → Syntax error highlighting with correction suggestions

**2. AWS Service Errors**
- Authentication failures → Credential verification steps and IAM role guidance
- Service connectivity issues → Network troubleshooting and endpoint validation
- Resource creation conflicts → Alternative naming strategies and cleanup procedures

**3. SSL Certificate Errors**
- Certificate not found → Domain registration and certificate acquisition guidance
- Certificate expired → Renewal procedures and automated renewal setup
- Certificate validation failures → Certificate chain verification and troubleshooting

**4. Gateway and Authentication Errors**
- Gateway creation failures → Step-by-step recreation with alternative configurations
- Token generation issues → Cognito configuration validation and client setup
- API authentication failures → Credential provider verification and token refresh

### Error Recovery Strategies

**State Preservation:**
- Track setup progress in persistent state files
- Enable resumption from last successful step
- Provide rollback capabilities for failed operations

**Alternative Approaches:**
- Multiple configuration options for each component
- Fallback mechanisms for service failures
- Manual override capabilities for automated processes

**User Guidance:**
- Context-aware error messages with specific next steps
- Links to relevant AWS documentation and troubleshooting guides
- Interactive prompts for configuration resolution

## Testing Strategy

### Dual Testing Approach

The testing strategy employs both unit testing and property-based testing to ensure comprehensive coverage:

**Unit Testing:**
- Specific configuration validation scenarios
- AWS service integration points
- SSL certificate handling edge cases
- Error message generation and formatting

**Property-Based Testing:**
- Universal configuration validation across all input combinations
- AWS resource creation with randomized valid parameters
- SSL certificate validation with various certificate types and states
- Error handling across all possible failure scenarios

**Property-Based Testing Framework:**
- **Library**: Hypothesis for Python
- **Test Iterations**: Minimum 100 iterations per property test
- **Test Tagging**: Each property test tagged with format: `**Feature: aws-ec2-production-deployment, Property {number}: {property_text}**`

**Integration Testing:**
- End-to-end deployment scenarios with mocked AWS services
- Complete workflow validation from configuration to verification
- Multi-component interaction testing
- Failure recovery and resumption scenarios

### Test Environment Requirements

**Local Testing:**
- Docker containers for isolated testing
- Mocked AWS services using LocalStack or similar
- SSL certificate generation for testing
- Cognito simulation for authentication testing

**AWS Testing:**
- Dedicated test AWS account or isolated environment
- Automated cleanup of test resources
- Cost monitoring and resource limits
- Security scanning and compliance validation

## Implementation Architecture

### Modular Component Design

**1. Configuration Management Module**
- Environment variable validation and parsing
- Configuration file template generation
- Parameter validation with detailed error reporting
- Configuration migration and backup capabilities

**2. AWS Service Integration Module**
- Abstracted AWS service clients with error handling
- Retry logic with exponential backoff
- Service connectivity testing and validation
- Resource creation and management operations

**3. Validation Engine Module**
- Comprehensive configuration validation
- AWS service connectivity testing
- SSL certificate validation and monitoring
- Authentication flow testing and verification

**4. Error Handling and Recovery Module**
- Structured error reporting with context
- Recovery strategy suggestion engine
- Setup state tracking and resumption
- User guidance generation and formatting

**5. Deployment Orchestration Module**
- Step-by-step deployment workflow
- Progress tracking and reporting
- Rollback and cleanup capabilities
- Verification report generation

### CLI Interface Design

**Command Structure:**
```bash
# Main deployment command
sre-agent-deploy --config config.yaml --mode production

# Validation only
sre-agent-deploy --validate-only --config config.yaml

# Resume from failure
sre-agent-deploy --resume --state-file .deployment_state

# Cleanup and rollback
sre-agent-deploy --cleanup --deployment-id <id>
```

**Interactive Mode:**
- Step-by-step configuration prompts
- Real-time validation feedback
- Progress indicators and status updates
- Error resolution guidance

### Integration with Existing Components

**Gateway Scripts Enhancement:**
- Integrate new validation system into existing `create_gateway.sh`
- Enhance `create_credentials_provider.py` with comprehensive error handling
- Update `configure_gateway.sh` with production deployment support
- Maintain backward compatibility with existing configuration files

**Deployment Scripts Integration:**
- Enhance `build_and_deploy.sh` with validation and testing
- Update `deploy_agent_runtime.py` with error recovery
- Integrate SSL certificate management into deployment workflow
- Add comprehensive verification and reporting capabilities