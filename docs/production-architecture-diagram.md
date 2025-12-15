# SRE Agent Production Architecture

This document provides a visual representation of the production architecture for the SRE Agent deployment on AWS.

## High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                AWS Cloud Environment                            │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              Internet Gateway                               │ │
│  └─────────────────────────┬───────────────────────────────────────────────────┘ │
│                            │                                                     │
│  ┌─────────────────────────▼───────────────────────────────────────────────────┐ │
│  │                            Public Subnet                                   │ │
│  │                                                                             │ │
│  │  ┌─────────────────────┐                    ┌─────────────────────┐        │ │
│  │  │     EC2 Instance    │                    │   Security Group    │        │ │
│  │  │   (t3.xlarge)       │◄──────────────────►│                     │        │ │
│  │  │                     │                    │ • SSH (22)          │        │ │
│  │  │ • SRE Agent         │                    │ • HTTPS (443)       │        │ │
│  │  │ • Backend APIs      │                    │ • APIs (8011-8014)  │        │ │
│  │  │ • SSL Certificates  │                    │                     │        │ │
│  │  └─────────────────────┘                    └─────────────────────┘        │ │
│  │            │                                                                │ │
│  └────────────┼────────────────────────────────────────────────────────────────┘ │
│               │                                                                  │
│               │ HTTPS/API Calls                                                 │
│               ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                        AWS Managed Services                                 │ │
│  │                                                                             │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │ │
│  │  │  Amazon Bedrock │  │   Amazon S3     │  │  Amazon Cognito │            │ │
│  │  │   AgentCore     │  │                 │  │                 │            │ │
│  │  │                 │  │ • OpenAPI       │  │ • User Pool     │            │ │
│  │  │ • Gateway       │◄─┤   Schemas       │  │ • JWT Tokens    │            │ │
│  │  │ • Runtime       │  │ • Configurations│  │ • Authentication│            │ │
│  │  │ • Memory        │  │                 │  │                 │            │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘            │ │
│  │           │                     │                     │                    │ │
│  └───────────┼─────────────────────┼─────────────────────┼────────────────────┘ │
│              │                     │                     │                      │
│              ▼                     ▼                     ▼                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              IAM Roles                                     │ │
│  │                                                                             │ │
│  │  ┌─────────────────────┐              ┌─────────────────────┐              │ │
│  │  │  SREAgentEC2Role    │              │BedrockAgentCoreRole │              │ │
│  │  │                     │              │                     │              │ │
│  │  │ • BedrockFullAccess │              │ • AgentCoreAccess   │              │ │
│  │  │ • S3FullAccess      │              │ • S3GetObject       │              │ │
│  │  │ • CognitoPowerUser  │              │ • CognitoAccess     │              │ │
│  │  └─────────────────────┘              └─────────────────────┘              │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
┌─────────────┐    1. HTTPS Request     ┌─────────────────┐
│    User     │─────────────────────────►│   EC2 Instance │
│             │                         │   (SRE Agent)   │
└─────────────┘                         └─────────────────┘
                                                 │
                                        2. Authenticate
                                                 ▼
                                        ┌─────────────────┐
                                        │ Amazon Cognito  │
                                        │   User Pool     │
                                        └─────────────────┘
                                                 │
                                        3. JWT Token
                                                 ▼
                                        ┌─────────────────┐
                                        │   AgentCore     │
                                        │    Gateway      │
                                        └─────────────────┘
                                                 │
                                        4. Fetch Schemas
                                                 ▼
                                        ┌─────────────────┐
                                        │   Amazon S3     │
                                        │ (OpenAPI Specs) │
                                        └─────────────────┘
                                                 │
                                        5. Execute Tools
                                                 ▼
                                        ┌─────────────────┐
                                        │  Backend APIs   │
                                        │ (K8s, Logs,     │
                                        │ Metrics, Books) │
                                        └─────────────────┘
```

## Network Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (Virtual Private Cloud)             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                      Public Subnet                         │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │                Security Group Rules                    │ │ │
│  │  │                                                         │ │ │
│  │  │  Inbound Rules:                                         │ │ │
│  │  │  ┌─────────────────────────────────────────────────────┐ │ │ │
│  │  │  │ Port 22  (SSH)    │ Your IP Only    │ Management  │ │ │ │
│  │  │  │ Port 443 (HTTPS)  │ 0.0.0.0/0       │ Public Web  │ │ │ │
│  │  │  │ Port 8011 (K8s)   │ VPC CIDR Only   │ Internal    │ │ │ │
│  │  │  │ Port 8012 (Logs)  │ VPC CIDR Only   │ Internal    │ │ │ │
│  │  │  │ Port 8013 (Metrics)│ VPC CIDR Only  │ Internal    │ │ │ │
│  │  │  │ Port 8014 (Books) │ VPC CIDR Only   │ Internal    │ │ │ │
│  │  │  └─────────────────────────────────────────────────────┘ │ │ │
│  │  │                                                         │ │ │
│  │  │  Outbound Rules:                                        │ │ │
│  │  │  ┌─────────────────────────────────────────────────────┐ │ │ │
│  │  │  │ All Traffic      │ 0.0.0.0/0       │ Internet       │ │ │ │
│  │  │  └─────────────────────────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  │                                                              │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │                   EC2 Instance                          │ │ │
│  │  │                                                         │ │ │
│  │  │  ┌─────────────────────────────────────────────────────┐ │ │ │
│  │  │  │              SSL/TLS Layer                          │ │ │ │
│  │  │  │                                                     │ │ │ │
│  │  │  │ • Let's Encrypt Certificate                         │ │ │ │
│  │  │  │ • Auto-renewal via Certbot                          │ │ │ │
│  │  │  │ • HTTPS Termination                                 │ │ │ │
│  │  │  └─────────────────────────────────────────────────────┘ │ │ │
│  │  │                                                          │ │ │
│  │  │  ┌─────────────────────────────────────────────────────┐ │ │ │
│  │  │  │            Application Layer                        │ │ │ │
│  │  │  │                                                     │ │ │ │
│  │  │  │ • SRE Agent (Python/FastAPI)                        │ │ │ │
│  │  │  │ • Backend APIs (Kubernetes, Logs, Metrics, Books)   │ │ │ │
│  │  │  │ • MCP Tools Integration                             │ │ │ │
│  │  │  └─────────────────────────────────────────────────────┘ │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Component Interaction Sequence

```
User Request Flow:
1. User → [HTTPS] → EC2 Instance (Port 443)
2. EC2 Instance → [API] → Cognito (Authentication)
3. Cognito → [JWT Token] → EC2 Instance
4. EC2 Instance → [Authenticated Request] → AgentCore Gateway
5. AgentCore Gateway → [Schema Fetch] → S3 Bucket
6. AgentCore Gateway → [Tool Execution] → Backend APIs
7. Backend APIs → [Results] → AgentCore Gateway
8. AgentCore Gateway → [Response] → EC2 Instance
9. EC2 Instance → [HTTPS Response] → User

Authentication Flow:
1. User credentials → Cognito User Pool
2. Cognito validates → Issues JWT token
3. JWT token → AgentCore Gateway
4. Gateway validates token → Allows API access

Data Storage Flow:
1. OpenAPI Schemas → S3 Bucket
2. Configuration files → EC2 Instance
3. Logs and metrics → CloudWatch (optional)
4. User sessions → Cognito (managed)
```

## Security Boundaries

```
┌─────────────────────────────────────────────────────────────────┐
│                        Security Perimeter                      │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Internet Boundary                       │ │
│  │  • SSL/TLS Encryption (HTTPS only)                         │ │
│  │  • Domain validation                                       │ │
│  │  • Rate limiting (optional)                                │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                │                                │
│  ┌─────────────────────────────▼───────────────────────────────┐ │
│  │                    Network Boundary                        │ │
│  │  • Security Groups (Firewall rules)                       │ │
│  │  • VPC isolation                                           │ │
│  │  • Subnet segmentation                                     │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                │                                │
│  ┌─────────────────────────────▼───────────────────────────────┐ │
│  │                 Application Boundary                       │ │
│  │  • JWT token validation                                    │ │
│  │  • API authentication                                      │ │
│  │  • Input validation                                        │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                │                                │
│  ┌─────────────────────────────▼───────────────────────────────┐ │
│  │                    Service Boundary                        │ │
│  │  • IAM role-based access                                   │ │
│  │  • Service-to-service authentication                       │ │
│  │  • Resource-level permissions                              │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Monitoring and Observability

```
┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring Architecture                      │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   CloudWatch    │  │     X-Ray       │  │   CloudTrail    │ │
│  │                 │  │                 │  │                 │ │
│  │ • Metrics       │  │ • Distributed   │  │ • API Calls     │ │
│  │ • Logs          │  │   Tracing       │  │ • Security      │ │
│  │ • Alarms        │  │ • Performance   │  │   Events        │ │
│  │ • Dashboards    │  │   Analysis      │  │ • Compliance    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│           │                     │                     │        │
│           ▼                     ▼                     ▼        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    SRE Agent Application                   │ │
│  │                                                             │ │
│  │ • OpenTelemetry instrumentation                            │ │
│  │ • Custom metrics and logging                               │ │
│  │ • Health checks and status endpoints                       │ │
│  │ • Performance monitoring                                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

This architecture provides:
- **High Availability**: Single instance with potential for auto-scaling
- **Security**: Multiple layers of security controls
- **Scalability**: Can be extended with load balancers and multiple instances
- **Monitoring**: Comprehensive observability and alerting
- **Maintainability**: Clear separation of concerns and modular design