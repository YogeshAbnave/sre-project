"""
Interface definitions for AWS gateway setup system.
"""

from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional
from .models import (
    ValidationResult, CredentialValidationResult, ConnectivityResult,
    SetupResult, VerificationReport, AWSConfig, CredentialConfig,
    GatewayConfig, SetupState
)


class ConfigurationManagerInterface(ABC):
    """Interface for configuration management operations."""
    
    @abstractmethod
    def load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from file."""
        pass
    
    @abstractmethod
    def validate_config(self, config: Dict[str, Any]) -> ValidationResult:
        """Validate configuration parameters."""
        pass
    
    @abstractmethod
    def create_template_files(self) -> None:
        """Create template configuration files."""
        pass
    
    @abstractmethod
    def update_config_parameter(self, key: str, value: str) -> None:
        """Update a single configuration parameter."""
        pass
    
    @abstractmethod
    def save_config(self, config: Dict[str, Any], config_path: str) -> None:
        """Save configuration to file."""
        pass


class ValidationEngineInterface(ABC):
    """Interface for validation operations."""
    
    @abstractmethod
    def validate_aws_credentials(self) -> CredentialValidationResult:
        """Validate AWS credentials."""
        pass
    
    @abstractmethod
    def validate_environment_variables(self, required_vars: List[str]) -> ValidationResult:
        """Validate required environment variables."""
        pass
    
    @abstractmethod
    def test_aws_connectivity(self, services: List[str]) -> List[ConnectivityResult]:
        """Test connectivity to AWS services."""
        pass
    
    @abstractmethod
    def validate_configuration_parameters(self, config: Dict[str, Any]) -> ValidationResult:
        """Validate configuration parameters."""
        pass


class AWSServiceManagerInterface(ABC):
    """Interface for AWS service operations."""
    
    @abstractmethod
    def create_credential_provider(self, config: CredentialConfig) -> SetupResult:
        """Create AWS credential provider."""
        pass
    
    @abstractmethod
    def create_s3_bucket(self, bucket_name: str, region: str) -> SetupResult:
        """Create S3 bucket."""
        pass
    
    @abstractmethod
    def setup_gateway(self, gateway_config: GatewayConfig, aws_config: AWSConfig) -> SetupResult:
        """Setup AgentCore gateway."""
        pass
    
    @abstractmethod
    def test_service_connectivity(self, service: str, region: str) -> ConnectivityResult:
        """Test connectivity to a specific AWS service."""
        pass


class ErrorHandlerInterface(ABC):
    """Interface for error handling operations."""
    
    @abstractmethod
    def handle_credential_error(self, error: Exception) -> Dict[str, str]:
        """Handle credential-related errors."""
        pass
    
    @abstractmethod
    def generate_troubleshooting_guide(self, error: Exception, context: Dict[str, Any]) -> List[str]:
        """Generate troubleshooting guidance."""
        pass
    
    @abstractmethod
    def log_detailed_error(self, error: Exception, context: Dict[str, Any]) -> None:
        """Log detailed error information."""
        pass


class StateManagerInterface(ABC):
    """Interface for setup state management."""
    
    @abstractmethod
    def save_state(self, state: SetupState) -> None:
        """Save setup state."""
        pass
    
    @abstractmethod
    def load_state(self) -> Optional[SetupState]:
        """Load setup state."""
        pass
    
    @abstractmethod
    def clear_state(self) -> None:
        """Clear setup state."""
        pass
    
    @abstractmethod
    def can_resume_setup(self) -> bool:
        """Check if setup can be resumed."""
        pass


class ReportGeneratorInterface(ABC):
    """Interface for report generation."""
    
    @abstractmethod
    def generate_verification_report(self, setup_result: SetupResult) -> VerificationReport:
        """Generate verification report."""
        pass
    
    @abstractmethod
    def generate_troubleshooting_report(self, errors: List[Exception]) -> str:
        """Generate troubleshooting report."""
        pass