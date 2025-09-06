"""
TMF921 Intent Gateway package.

This package provides validation and processing capabilities for TMF921 Intent Management API v5.0.
It includes schema validation, CLI interface, and TIO compatibility mode.
"""

__version__ = "0.1.0"
__author__ = "Nephio Intent Pipeline Team"

from .validator import TMF921Validator, ValidationError, ValidationResult

__all__ = ["TMF921Validator", "ValidationError", "ValidationResult"]
