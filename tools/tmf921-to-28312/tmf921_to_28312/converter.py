"""TMF921 to 3GPP TS 28.312 conversion logic.

This module contains the core conversion logic from TMF921 Intent format
to 3GPP TS 28.312 IntentExpectation and IntentReport formats.

Reference: 3GPP TS 28.312 V17.1.0 (2022-03) - Intent driven management services for mobile networks
"""

import json
import yaml
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set
from uuid import uuid4

from .schemas import validate_28312_expectation, validate_28312_report


class ConversionError(Exception):
    """Exception raised during intent conversion."""
    
    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        """Initialize with error message and optional details."""
        super().__init__(message)
        self.details = details or {}


class ConversionResult:
    """Result of TMF921 to 28.312 conversion."""
    
    def __init__(
        self,
        success: bool,
        expectations: List[Dict[str, Any]],
        reports: List[Dict[str, Any]],
        delta_report: Dict[str, Any],
        error_message: Optional[str] = None
    ):
        """Initialize conversion result."""
        self.success = success
        self.expectations = expectations
        self.reports = reports
        self.delta_report = delta_report
        self.error_message = error_message


class TMF921To28312Converter:
    """Converter from TMF921 to 3GPP TS 28.312 format."""
    
    def __init__(self, mapping_file: Optional[Path] = None):
        """Initialize converter with mapping rules."""
        if mapping_file is None:
            mapping_file = Path(__file__).parent.parent / "mappings" / "tmf921_to_28312.yaml"
        
        self._mapping_rules = self._load_mapping_rules(mapping_file)
        self._tracked_fields: Set[str] = set()
    
    def _load_mapping_rules(self, mapping_file: Path) -> Dict[str, Any]:
        """Load mapping rules from YAML file."""
        try:
            with open(mapping_file, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            raise ConversionError(f"Mapping file not found: {mapping_file}")
        except yaml.YAMLError as e:
            raise ConversionError(f"Invalid YAML in mapping file: {e}")
    
    @property
    def mapping_rules(self) -> Dict[str, Any]:
        """Get mapping rules."""
        return self._mapping_rules
    
    def convert(self, tmf921_intent: Dict[str, Any]) -> ConversionResult:
        """Convert TMF921 intent to 28.312 format."""
        try:
            self._tracked_fields.clear()
            
            # Validate basic structure
            if not isinstance(tmf921_intent, dict):
                raise ConversionError("Invalid TMF921 intent: not a dictionary")
            
            if "id" not in tmf921_intent:
                raise ConversionError("Missing required field: id")
            
            if "intentType" not in tmf921_intent:
                raise ConversionError("Missing required field: intentType")
            
            # Check if intent type is supported
            intent_type = tmf921_intent["intentType"]
            if intent_type not in ["ServiceIntent"]:
                return ConversionResult(
                    success=False,
                    expectations=[],
                    reports=[],
                    delta_report={},
                    error_message=f"Unsupported intent type: {intent_type}"
                )
            
            # Extract expectations
            expectations = self._extract_expectations(tmf921_intent)
            
            # Generate reports
            reports = self._generate_reports(expectations)
            
            # Generate delta report
            delta_report = generate_delta_report(tmf921_intent, expectations)
            
            return ConversionResult(
                success=True,
                expectations=expectations,
                reports=reports,
                delta_report=delta_report
            )
            
        except Exception as e:
            return ConversionResult(
                success=False,
                expectations=[],
                reports=[],
                delta_report={},
                error_message=str(e)
            )
    
    def _extract_expectations(self, tmf921_intent: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Extract and convert expectations from TMF921 intent."""
        expectations = []
        
        intent_spec = tmf921_intent.get("intentSpecification", {})
        tmf921_expectations = intent_spec.get("intentExpectations", [])
        
        for index, tmf921_exp in enumerate(tmf921_expectations):
            expectation = self._convert_single_expectation(
                tmf921_intent, tmf921_exp, index
            )
            expectations.append(expectation)
        
        return expectations
    
    def _convert_single_expectation(
        self, 
        tmf921_intent: Dict[str, Any], 
        tmf921_exp: Dict[str, Any], 
        index: int
    ) -> Dict[str, Any]:
        """Convert a single TMF921 expectation to 28.312 format."""
        base_id = tmf921_intent["id"]
        
        expectation = {
            "intentExpectationId": f"{base_id}-exp-{index}",
            "intentExpectationType": self.map_expectation_type(
                tmf921_exp.get("expectationType", "deliver")
            )
        }
        
        # Map context
        context = self._map_context(tmf921_exp)
        if context:
            expectation["intentExpectationContext"] = context
        else:
            # Default context if none specified
            expectation["intentExpectationContext"] = {
                "contextAttribute": "default",
                "contextCondition": "EQUAL",
                "contextValueRange": ["all"]
            }
        
        # Map target (use first target if multiple)
        targets = tmf921_exp.get("expectationTargets", [])
        if targets:
            expectation["intentExpectationTarget"] = self._map_target(targets[0])
        
        # Map object if present
        obj = tmf921_exp.get("expectationObject")
        if obj:
            expectation["intentExpectationObject"] = self._map_object(obj)
        
        return expectation
    
    def _map_context(self, tmf921_exp: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Map TMF921 expectation context to 28.312 format."""
        contexts = tmf921_exp.get("expectationContext", [])
        if not contexts:
            return None
        
        # Use first context if multiple
        ctx = contexts[0]
        return {
            "contextAttribute": ctx.get("contextParameter", "default"),
            "contextCondition": "EQUAL",
            "contextValueRange": [ctx.get("contextValue", "all")]
        }
    
    def _map_target(self, tmf921_target: Dict[str, Any]) -> Dict[str, Any]:
        """Map TMF921 target to 28.312 format."""
        target_name = tmf921_target.get("targetName", "unknown")
        target_condition = tmf921_target.get("targetCondition", "lessThan")
        target_value = tmf921_target.get("targetValue", "0")
        target_unit = tmf921_target.get("targetUnit", "")
        
        # Combine value and unit
        if target_unit:
            combined_value = f"{target_value}{target_unit}"
        else:
            combined_value = target_value
        
        return {
            "targetAttribute": target_name,
            "targetCondition": self.map_target_condition(target_condition),
            "targetValue": combined_value
        }
    
    def _map_object(self, tmf921_obj: Dict[str, Any]) -> Dict[str, Any]:
        """Map TMF921 object to 28.312 format."""
        return {
            "objectType": self.map_object_type(tmf921_obj.get("objectType", "service")),
            "objectInstance": tmf921_obj.get("objectInstance", "unknown")
        }
    
    def _generate_reports(self, expectations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Generate report skeletons for expectations."""
        reports = []
        current_time = datetime.utcnow().isoformat() + "Z"
        
        for expectation in expectations:
            report = {
                "intentReportId": f"report-{uuid4().hex[:8]}",
                "intentExpectationId": expectation["intentExpectationId"],
                "intentReportStatus": "NOT_FULFILLED",
                "timestamp": current_time,
                "notFulfilledReason": "PENDING_MEASUREMENT"
            }
            reports.append(report)
        
        return reports
    
    def map_target_condition(self, condition: str) -> str:
        """Map TMF921 target condition to 28.312 format."""
        mapping = self._mapping_rules.get("target_conditions", {})
        return mapping.get(condition, "EQUAL")
    
    def map_expectation_type(self, expectation_type: str) -> str:
        """Map TMF921 expectation type to 28.312 format."""
        mapping = self._mapping_rules.get("expectation_types", {})
        return mapping.get(expectation_type, "ServicePerformance")
    
    def map_object_type(self, object_type: str) -> str:
        """Map TMF921 object type to 28.312 format."""
        mapping = self._mapping_rules.get("object_types", {})
        return mapping.get(object_type, "Service")


def load_tmf921_intent(file_path: Path) -> Dict[str, Any]:
    """Load TMF921 intent from file."""
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            
        try:
            intent = json.loads(content)
        except json.JSONDecodeError as e:
            raise ConversionError(f"Invalid JSON in {file_path}: {e}")
        
        return intent
        
    except FileNotFoundError:
        raise FileNotFoundError(f"TMF921 intent file not found: {file_path}")
    except Exception as e:
        raise ConversionError(f"Error loading TMF921 intent: {e}")


def generate_delta_report(
    tmf921_intent: Dict[str, Any],
    converted_expectations: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """Generate delta report for unmapped fields."""
    unmapped_fields = []
    
    # Get unmapped field patterns from mapping rules
    mapping_file = Path(__file__).parent.parent / "mappings" / "tmf921_to_28312.yaml"
    try:
        with open(mapping_file, 'r') as f:
            mapping_rules = yaml.safe_load(f)
    except:
        mapping_rules = {}
    
    unmapped_patterns = mapping_rules.get("unmapped_fields", [])
    
    # Scan for unmapped fields
    def scan_object(obj: Any, path: str = "") -> None:
        if isinstance(obj, dict):
            for key, value in obj.items():
                current_path = f"{path}.{key}" if path else key
                
                # Check if this field matches unmapped patterns
                for pattern in unmapped_patterns:
                    if _matches_pattern(current_path, pattern):
                        unmapped_fields.append({
                            "path": current_path,
                            "value": value,
                            "type": type(value).__name__,
                            "reason": "Field marked as unmapped in mapping rules"
                        })
                        break
                
                # Recursively scan nested objects
                if isinstance(value, (dict, list)):
                    scan_object(value, current_path)
        
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                current_path = f"{path}[{i}]"
                scan_object(item, current_path)
    
    scan_object(tmf921_intent)
    
    # Calculate summary statistics
    total_fields = _count_fields(tmf921_intent)
    mapped_fields = total_fields - len(unmapped_fields)
    
    return {
        "unmapped_fields": unmapped_fields,
        "conversion_summary": {
            "total_fields_processed": total_fields,
            "successfully_mapped": mapped_fields,
            "unmapped_count": len(unmapped_fields),
            "mapping_coverage": mapped_fields / total_fields if total_fields > 0 else 1.0
        },
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }


def _matches_pattern(path: str, pattern: str) -> bool:
    """Check if a field path matches an unmapped pattern."""
    import re
    
    # Convert pattern to regex pattern
    # Replace * with .* and handle array indices [n] as literal matches
    regex_pattern = pattern.replace("*", ".*")
    
    # Handle array indices by replacing [n] patterns with actual array index patterns
    regex_pattern = re.sub(r'\\\[.*?\\\]', r'\\[\\d+\\]', regex_pattern)
    
    # Make it a full match
    regex_pattern = f"^{regex_pattern}$"
    
    try:
        return bool(re.match(regex_pattern, path))
    except re.error:
        # Fallback to simple string matching
        if "*" in pattern:
            parts = pattern.split("*")
            if len(parts) == 2:
                prefix, suffix = parts
                return path.startswith(prefix) and path.endswith(suffix)
        return path == pattern


def _count_fields(obj: Any, count: int = 0) -> int:
    """Count total number of fields in nested object."""
    if isinstance(obj, dict):
        count += len(obj)
        for value in obj.values():
            count = _count_fields(value, count)
    elif isinstance(obj, list):
        for item in obj:
            count = _count_fields(item, count)
    
    return count