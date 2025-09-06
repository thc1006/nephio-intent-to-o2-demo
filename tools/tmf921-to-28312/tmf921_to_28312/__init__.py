"""
TMF921 to 3GPP TS 28.312 Intent Converter.

This package provides tools for converting TMF921 Intent specifications
to 3GPP TS 28.312 IntentExpectation and IntentReport formats.

Following TDD approach - this is the initial package structure.
Implementation will be added to make tests pass.
"""

__version__ = "0.1.0"
__author__ = "Nephio Intent Pipeline Team"
__email__ = "noreply@nephio.org"

# Package exports - these will be implemented to make tests pass
__all__ = [
    "TMF921To28312Converter",
    "ConversionResult", 
    "ConversionError",
    "load_tmf921_intent",
    "generate_delta_report"
]