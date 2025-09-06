"""
TMF921 TIO Compliance Checker.

Provides TM Forum Intent NRM CTK compliance checking with fake mode support.
"""

from dataclasses import dataclass
from typing import Any, Dict


@dataclass
class ComplianceResult:
    """Result of TIO compliance check."""
    
    compliant: bool
    api_version: str
    errors: list[str] = None
    warnings: list[str] = None
    
    def __post_init__(self):
        if self.errors is None:
            self.errors = []
        if self.warnings is None:
            self.warnings = []


class TIOComplianceChecker:
    """TM Forum Intent NRM CTK compliance checker."""
    
    def __init__(self, mode: str = "strict"):
        """
        Initialize compliance checker.
        
        Args:
            mode: Compliance mode ('fake' bypasses checks, 'strict' for full compliance)
        """
        self.mode = mode
    
    def check_compliance(self, intent_data: Dict[str, Any]) -> ComplianceResult:
        """
        Check intent compliance with TM Forum CTK requirements.
        
        Args:
            intent_data: Intent data to check
            
        Returns:
            ComplianceResult with compliance status
        """
        if self.mode == "fake":
            # In fake mode, always return compliant
            return ComplianceResult(
                compliant=True,
                api_version="TMF921-v4.0.0",
                warnings=["TIO_MODE_FAKE: Compliance checking bypassed in fake mode"]
            )
        
        # In strict mode, perform actual compliance checks
        errors = []
        warnings = []
        
        # Check required fields for TMF921 compliance
        required_fields = ["id", "@type"]
        for field in required_fields:
            if field not in intent_data:
                errors.append(f"Missing required field: {field}")
        
        # Check lifecycle status if present
        if "lifecycleStatus" in intent_data:
            valid_statuses = [
                "acknowledged", "rejected", "inProgress", "pending",
                "held", "cancelled", "completed", "failed", "feasibilityChecked"
            ]
            status = intent_data["lifecycleStatus"]
            if status not in valid_statuses:
                errors.append(f"Invalid lifecycle status: {status}")
        
        # Check @type field
        if intent_data.get("@type") != "Intent":
            warnings.append("@type should be 'Intent' for TMF921 compliance")
        
        is_compliant = len(errors) == 0
        
        return ComplianceResult(
            compliant=is_compliant,
            api_version="TMF921-v4.0.0",
            errors=errors,
            warnings=warnings
        )