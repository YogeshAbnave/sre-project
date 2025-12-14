"""
Data models for AWS gateway setup system.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum


class ValidationStatus(Enum):
    """Status of validation operations."""
    VALID = "valid"
    INVALID = "invalid"
    WARNING = "warning"


class SetupStatus(Enum):
    """Status of setup operations."""
    SUCCESS = "success"
    FAILED = "failed"
    PARTIAL = "partial"


@dataclass
class ValidationError:
    """Represents a validation error with context."""
    field: str
    message: str
    suggestion: Optional[str] = None
    error_code: Optional[str] = None


@dataclass
class ValidationResult:
    """Result of a validation operation."""
    is_valid: bool
    status: ValidationStatus
    errors: List[ValidationError] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    
    def add_error(self, field: str, message: str, suggestion: Optional[str] = None, error_code: Optional[str] = None):
        """Add a validation error."""
        self.errors.append(ValidationError(field, message, suggestion, error_code))
        self.is_valid = False
        self.status = ValidationStatus.INVALID
    
    def add_warning(self, message: str):
        """Add a validation warning."""
        self.warnings.append(message)
        if self.status == ValidationStatus.VALID:
            self.status = ValidationStatus.WARNING


@dataclass
class AWSConfig:
    """AWS configuration parameters."""
    account_id: str
    region: str
    role_name: str
    endpoint_url: str
    credential_provider_endpoint_url: str
    
    def __post_init__(self):
        """Validate configuration after initialization."""
        # Remove any whitespace from critical identifiers
        self.account_id = self.account_id.strip()
        self.role_name = self.role_name.strip()


@dataclass
class CognitoConfig:
    """Cognito configuration parameters."""
    user_pool_id: str
    client_id: str
    domain: Optional[str] = None
    client_secret: Optional[str] = None
    
    def __post_init__(self):
        """Validate configuration after initialization."""
        self.user_pool_id = self.user_pool_id.strip()
        self.client_id = self.client_id.strip()


@dataclass
class S3Config:
    """S3 configuration parameters."""
    bucket: Optional[str] = None
    path_prefix: str = "devops-multiagent-demo"
    auto_create: bool = True
    
    def __post_init__(self):
        """Validate configuration after initialization."""
        if self.bucket:
            self.bucket = self.bucket.strip()


@dataclass
class CredentialConfig:
    """Credential provider configuration."""
    provider_name: str
    api_key: str
    region: str
    endpoint_url: str
    
    def __post_init__(self):
        """Validate configuration after initialization."""
        self.provider_name = self.provider_name.strip()
        self.region = self.region.strip()


@dataclass
class GatewayConfig:
    """Gateway configuration parameters."""
    name: str
    description: str
    provider_arn: Optional[str] = None
    
    def __post_init__(self):
        """Validate configuration after initialization."""
        self.name = self.name.strip()


@dataclass
class CredentialValidationResult:
    """Result of AWS credential validation."""
    is_valid: bool
    has_credentials: bool
    can_authenticate: bool
    services_accessible: Dict[str, bool] = field(default_factory=dict)
    errors: List[str] = field(default_factory=list)
    suggestions: List[str] = field(default_factory=list)


@dataclass
class ConnectivityResult:
    """Result of AWS service connectivity testing."""
    service: str
    is_accessible: bool
    response_time_ms: Optional[float] = None
    error_message: Optional[str] = None
    endpoint: Optional[str] = None


@dataclass
class SetupError:
    """Represents a setup error with context."""
    component: str
    error_type: str
    message: str
    suggestion: Optional[str] = None
    recoverable: bool = True


@dataclass
class SetupResult:
    """Result of a setup operation."""
    success: bool
    status: SetupStatus
    gateway_url: Optional[str] = None
    provider_arn: Optional[str] = None
    errors: List[SetupError] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    
    def add_error(self, component: str, error_type: str, message: str, 
                  suggestion: Optional[str] = None, recoverable: bool = True):
        """Add a setup error."""
        self.errors.append(SetupError(component, error_type, message, suggestion, recoverable))
        self.success = False
        if self.status == SetupStatus.SUCCESS:
            self.status = SetupStatus.FAILED if not recoverable else SetupStatus.PARTIAL


@dataclass
class VerificationReport:
    """Comprehensive verification report."""
    configured_components: List[str] = field(default_factory=list)
    gateway_status: str = "unknown"
    connectivity_tests: Dict[str, bool] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.now)
    setup_duration_seconds: Optional[float] = None
    recommendations: List[str] = field(default_factory=list)


@dataclass
class SetupState:
    """Represents the current state of the setup process."""
    step: str
    completed_steps: List[str] = field(default_factory=list)
    failed_steps: List[str] = field(default_factory=list)
    configuration: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.now)
    
    def mark_step_completed(self, step: str):
        """Mark a step as completed."""
        if step not in self.completed_steps:
            self.completed_steps.append(step)
        if step in self.failed_steps:
            self.failed_steps.remove(step)
    
    def mark_step_failed(self, step: str):
        """Mark a step as failed."""
        if step not in self.failed_steps:
            self.failed_steps.append(step)
    
    def can_resume_from(self, step: str) -> bool:
        """Check if setup can resume from a specific step."""
        return step in self.completed_steps or step == self.step