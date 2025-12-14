"""
Pytest configuration and fixtures for AWS gateway setup tests.
"""

import pytest
import os
import tempfile
from unittest.mock import Mock, patch
from typing import Dict, Any

from aws_setup.models import AWSConfig, CredentialConfig, GatewayConfig, CognitoConfig, S3Config


@pytest.fixture
def temp_config_dir():
    """Create a temporary directory for configuration files."""
    with tempfile.TemporaryDirectory() as temp_dir:
        yield temp_dir


@pytest.fixture
def sample_aws_config():
    """Sample AWS configuration for testing."""
    return AWSConfig(
        account_id="123456789012",
        region="us-east-1",
        role_name="test-role",
        endpoint_url="https://bedrock-agentcore-control.us-east-1.amazonaws.com",
        credential_provider_endpoint_url="https://us-east-1.prod.agent-credential-provider.cognito.aws.dev"
    )


@pytest.fixture
def sample_credential_config():
    """Sample credential configuration for testing."""
    return CredentialConfig(
        provider_name="test-provider",
        api_key="test-api-key-123",
        region="us-east-1",
        endpoint_url="https://us-east-1.prod.agent-credential-provider.cognito.aws.dev"
    )


@pytest.fixture
def sample_gateway_config():
    """Sample gateway configuration for testing."""
    return GatewayConfig(
        name="test-gateway",
        description="Test gateway for unit tests",
        provider_arn="arn:aws:bedrock-agentcore:us-east-1:123456789012:token-vault/default/apikeycredentialprovider/test-provider"
    )


@pytest.fixture
def sample_cognito_config():
    """Sample Cognito configuration for testing."""
    return CognitoConfig(
        user_pool_id="us-east-1_ABCDEFGHI",
        client_id="test-client-id-123",
        domain="https://test-domain.auth.us-east-1.amazoncognito.com",
        client_secret="test-client-secret"
    )


@pytest.fixture
def sample_s3_config():
    """Sample S3 configuration for testing."""
    return S3Config(
        bucket="test-bucket-123",
        path_prefix="test-prefix",
        auto_create=True
    )


@pytest.fixture
def mock_boto3_client():
    """Mock boto3 client for AWS service testing."""
    with patch('boto3.client') as mock_client:
        yield mock_client


@pytest.fixture
def mock_environment_variables():
    """Mock environment variables for testing."""
    env_vars = {
        'AWS_ACCESS_KEY_ID': 'test-access-key',
        'AWS_SECRET_ACCESS_KEY': 'test-secret-key',
        'AWS_DEFAULT_REGION': 'us-east-1',
        'BACKEND_API_KEY': 'test-backend-api-key'
    }
    
    with patch.dict(os.environ, env_vars, clear=False):
        yield env_vars


@pytest.fixture
def sample_config_dict():
    """Sample configuration dictionary for testing."""
    return {
        'account_id': '123456789012',
        'region': 'us-east-1',
        'role_name': 'test-role',
        'endpoint_url': 'https://bedrock-agentcore-control.us-east-1.amazonaws.com',
        'credential_provider_endpoint_url': 'https://us-east-1.prod.agent-credential-provider.cognito.aws.dev',
        'user_pool_id': 'us-east-1_ABCDEFGHI',
        'client_id': 'test-client-id',
        's3_bucket': 'test-bucket',
        's3_path_prefix': 'test-prefix',
        'credential_provider_name': 'test-provider',
        'gateway_name': 'test-gateway',
        'gateway_description': 'Test gateway'
    }