"""
Configuration management for AWS gateway setup system.
"""

import os
import yaml
import json
from pathlib import Path
from typing import Dict, Any, Optional, List
import logging
from .interfaces import ConfigurationManagerInterface
from .models import ValidationResult, ValidationStatus, AWSConfig, CredentialConfig, GatewayConfig

logger = logging.getLogger(__name__)


class ConfigurationManager(ConfigurationManagerInterface):
    """Manages configuration loading, validation, and template creation."""
    
    def __init__(self, config_dir: str = "."):
        """Initialize configuration manager.
        
        Args:
            config_dir: Directory containing configuration files
        """
        self.config_dir = Path(config_dir)
        self.config_file = self.config_dir / "config.yaml"
        self.env_file = self.config_dir / ".env"
        
    def load_config(self, config_path: Optional[str] = None) -> Dict[str, Any]:
        """Load configuration from YAML file.
        
        Args:
            config_path: Optional path to config file, defaults to config.yaml
            
        Returns:
            Dictionary containing configuration parameters
            
        Raises:
            FileNotFoundError: If config file doesn't exist
            yaml.YAMLError: If config file is invalid YAML
        """
        if config_path:
            config_file = Path(config_path)
        else:
            config_file = self.config_file
            
        if not config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_file}")
            
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
                
            # Clean up string values (remove whitespace from critical identifiers)
            if config:
                for key in ['account_id', 'role_name', 'user_pool_id', 'client_id', 
                           's3_bucket', 'credential_provider_name']:
                    if key in config and isinstance(config[key], str):
                        config[key] = config[key].strip()
                        
            logger.info(f"Loaded configuration from {config_file}")
            return config or {}
            
        except yaml.YAMLError as e:
            logger.error(f"Invalid YAML in config file {config_file}: {e}")
            raise
            
    def validate_config(self, config: Dict[str, Any]) -> ValidationResult:
        """Validate configuration parameters.
        
        Args:
            config: Configuration dictionary to validate
            
        Returns:
            ValidationResult with validation status and any errors
        """
        result = ValidationResult(is_valid=True, status=ValidationStatus.VALID)
        
        # Required AWS configuration parameters
        required_aws_params = [
            'account_id', 'region', 'role_name', 'endpoint_url',
            'credential_provider_endpoint_url'
        ]
        
        # Required Cognito parameters
        required_cognito_params = ['user_pool_id', 'client_id']
        
        # Required gateway parameters
        required_gateway_params = ['gateway_name', 'credential_provider_name']
        
        # Check required AWS parameters
        for param in required_aws_params:
            if param not in config or not config[param]:
                result.add_error(
                    param, 
                    f"Required AWS parameter '{param}' is missing or empty",
                    f"Add '{param}' to your config.yaml file"
                )
                
        # Check required Cognito parameters
        for param in required_cognito_params:
            if param not in config or not config[param]:
                result.add_error(
                    param,
                    f"Required Cognito parameter '{param}' is missing or empty",
                    f"Run deployment/setup_cognito.sh to generate Cognito configuration"
                )
                
        # Check required gateway parameters
        for param in required_gateway_params:
            if param not in config or not config[param]:
                result.add_error(
                    param,
                    f"Required gateway parameter '{param}' is missing or empty",
                    f"Add '{param}' to your config.yaml file"
                )
                
        # Validate AWS account ID format
        if 'account_id' in config and config['account_id']:
            account_id = str(config['account_id']).strip()
            if not account_id.isdigit() or len(account_id) != 12:
                result.add_error(
                    'account_id',
                    f"Invalid AWS account ID format: {account_id}",
                    "AWS account ID must be a 12-digit number"
                )
                
        # Validate region format
        if 'region' in config and config['region']:
            region = config['region'].strip()
            if not region.replace('-', '').replace('_', '').isalnum():
                result.add_error(
                    'region',
                    f"Invalid AWS region format: {region}",
                    "AWS region should be in format like 'us-east-1'"
                )
                
        # Validate endpoint URLs
        for url_param in ['endpoint_url', 'credential_provider_endpoint_url']:
            if url_param in config and config[url_param]:
                url = config[url_param].strip()
                if not url.startswith('https://'):
                    result.add_error(
                        url_param,
                        f"Invalid endpoint URL: {url}",
                        "Endpoint URLs must use HTTPS"
                    )
                    
        # Validate User Pool ID format
        if 'user_pool_id' in config and config['user_pool_id']:
            pool_id = config['user_pool_id'].strip()
            if '_' not in pool_id or not pool_id.split('_')[0].replace('-', '').isalnum():
                result.add_error(
                    'user_pool_id',
                    f"Invalid Cognito User Pool ID format: {pool_id}",
                    "User Pool ID should be in format 'region_POOLID'"
                )
                
        # Check for placeholder values
        placeholder_values = [
            'YOUR_ACCOUNT_ID', 'REGION', '', 'YOUR_USER_POOL_ID',
            'YOUR_CLIENT_ID', 'your-bucket-name'
        ]
        
        for key, value in config.items():
            if isinstance(value, str) and value in placeholder_values:
                result.add_error(
                    key,
                    f"Configuration parameter '{key}' contains placeholder value: {value}",
                    f"Replace '{value}' with your actual {key}"
                )
                
        logger.info(f"Configuration validation completed: {result.status.value}")
        return result
        
    def create_template_files(self) -> None:
        """Create template configuration files with instructions."""
        
        # Create config.yaml template
        config_template = {
            'account_id': 'YOUR_ACCOUNT_ID',
            'region': 'us-east-1',
            'role_name': 'SRE-Agent-Gateway-Role ',
            'endpoint_url': 'https://bedrock-agentcore-control.us-east-1.amazonaws.com',
            'credential_provider_endpoint_url': 'https://us-east-1.prod.agent-credential-provider.cognito.aws.dev',
            'user_pool_id': 'YOUR_USER_POOL_ID',
            'client_id': 'YOUR_CLIENT_ID',
            's3_bucket': '',
            's3_path_prefix': 'devops-multiagent-demo',
            'credential_provider_name': 'sre-agent-api-key-credential-provider',
            'provider_arn': 'arn:aws:bedrock-agentcore:REGION:ACCOUNT_ID:token-vault/default/apikeycredentialprovider/sre-agent-api-key-credential-provider',
            'gateway_name': 'MyAgentCoreGateway',
            'gateway_description': 'AgentCore Gateway for API Integration',
            'target_description': 'S3 target for OpenAPI schema'
        }
        
        config_file = self.config_dir / "config.yaml"
        if not config_file.exists():
            with open(config_file, 'w') as f:
                f.write("# AgentCore Gateway Configuration\n")
                f.write("# Replace placeholder values with your actual configuration\n\n")
                yaml.dump(config_template, f, default_flow_style=False, sort_keys=False)
            logger.info(f"Created config template: {config_file}")
            
        # Create .env template
        env_template = """# Environment Variables for SRE Agent Gateway Setup
# Copy this file to .env and fill in your actual values

# Cognito Configuration for Token Generation
COGNITO_DOMAIN=https://yourdomain.auth.us-west-2.amazoncognito.com
COGNITO_CLIENT_ID=your-client-id-here
COGNITO_CLIENT_SECRET=your-client-secret-here
COGNITO_USER_POOL_ID=your-user-pool-id-here

# Backend API Key for credential provider
BACKEND_API_KEY=your-backend-api-key-here

# Anthropic API Credentials (optional - for Anthropic models)
ANTHROPIC_API_KEY=your-anthropic-api-key-here
"""
        
        env_file = self.config_dir / ".env.example"
        if not env_file.exists():
            with open(env_file, 'w') as f:
                f.write(env_template)
            logger.info(f"Created .env template: {env_file}")
            
    def update_config_parameter(self, key: str, value: str) -> None:
        """Update a single configuration parameter.
        
        Args:
            key: Configuration parameter key
            value: New value for the parameter
        """
        try:
            config = self.load_config()
        except FileNotFoundError:
            config = {}
            
        config[key] = value
        self.save_config(config)
        logger.info(f"Updated configuration parameter: {key}")
        
    def save_config(self, config: Dict[str, Any], config_path: Optional[str] = None) -> None:
        """Save configuration to YAML file.
        
        Args:
            config: Configuration dictionary to save
            config_path: Optional path to save config, defaults to config.yaml
        """
        if config_path:
            config_file = Path(config_path)
        else:
            config_file = self.config_file
            
        # Ensure directory exists
        config_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)
            
        logger.info(f"Saved configuration to {config_file}")
        
    def load_environment_variables(self) -> Dict[str, str]:
        """Load environment variables from .env file.
        
        Returns:
            Dictionary of environment variables
        """
        env_vars = {}
        
        if self.env_file.exists():
            with open(self.env_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        env_vars[key.strip()] = value.strip()
                        
        logger.info(f"Loaded {len(env_vars)} environment variables from {self.env_file}")
        return env_vars
        
    def validate_environment_variables(self, required_vars: List[str]) -> ValidationResult:
        """Validate that required environment variables are present.
        
        Args:
            required_vars: List of required environment variable names
            
        Returns:
            ValidationResult with validation status
        """
        result = ValidationResult(is_valid=True, status=ValidationStatus.VALID)
        
        # Check environment variables from both OS and .env file
        env_vars = dict(os.environ)
        env_vars.update(self.load_environment_variables())
        
        for var in required_vars:
            if var not in env_vars or not env_vars[var]:
                result.add_error(
                    var,
                    f"Required environment variable '{var}' is not set",
                    f"Set {var} in your .env file or environment"
                )
                
        return result
        
    def get_aws_config(self) -> AWSConfig:
        """Get AWS configuration from loaded config.
        
        Returns:
            AWSConfig object
            
        Raises:
            ValueError: If required AWS configuration is missing
        """
        config = self.load_config()
        validation = self.validate_config(config)
        
        if not validation.is_valid:
            error_messages = [f"{err.field}: {err.message}" for err in validation.errors]
            raise ValueError(f"Invalid AWS configuration: {'; '.join(error_messages)}")
            
        return AWSConfig(
            account_id=config['account_id'],
            region=config['region'],
            role_name=config['role_name'],
            endpoint_url=config['endpoint_url'],
            credential_provider_endpoint_url=config['credential_provider_endpoint_url']
        )
        
    def get_credential_config(self, api_key: str) -> CredentialConfig:
        """Get credential configuration.
        
        Args:
            api_key: API key for credential provider
            
        Returns:
            CredentialConfig object
        """
        config = self.load_config()
        
        return CredentialConfig(
            provider_name=config.get('credential_provider_name', 'sre-agent-api-key-credential-provider'),
            api_key=api_key,
            region=config.get('region', 'us-east-1'),
            endpoint_url=config.get('credential_provider_endpoint_url', 
                                  'https://us-east-1.prod.agent-credential-provider.cognito.aws.dev')
        )
        
    def get_gateway_config(self) -> GatewayConfig:
        """Get gateway configuration.
        
        Returns:
            GatewayConfig object
        """
        config = self.load_config()
        
        return GatewayConfig(
            name=config.get('gateway_name', 'MyAgentCoreGateway'),
            description=config.get('gateway_description', 'AgentCore Gateway for API Integration'),
            provider_arn=config.get('provider_arn')
        )