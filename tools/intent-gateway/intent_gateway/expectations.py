"""
TMF921 Intent Expectations Parser.

Provides parsing and validation for intent expectations and outcomes.
"""

from dataclasses import dataclass
from typing import Any, Dict, List


@dataclass
class Expectation:
    """Represents a parsed intent expectation."""
    
    expectation_id: str
    expectation_type: str
    kpi_name: str | None = None
    kpi_value: str | None = None
    kpi_unit: str | None = None
    operator: str | None = None
    
    def is_measurable(self) -> bool:
        """Check if this expectation is measurable (has KPI data)."""
        return all([
            self.kpi_name is not None,
            self.kpi_value is not None,
            self.operator is not None
        ])


class ExpectationParser:
    """Parser for TMF921 intent expectations."""
    
    def parse(self, intent_data: Dict[str, Any]) -> List[Expectation]:
        """
        Parse expectations from intent data.
        
        Args:
            intent_data: Intent data containing expectations
            
        Returns:
            List of parsed Expectation objects
        """
        expectations = []
        
        # Check for both "expectations" (old format) and "expectation" (TMF921 format)
        expectation_data = intent_data.get("expectation", intent_data.get("expectations", []))
        
        for exp_data in expectation_data:
            expectation = Expectation(
                expectation_id=exp_data.get("id", exp_data.get("expectationId", "")),
                expectation_type=exp_data.get("expectationType", ""),
            )
            
            # Parse expected value (old format)
            expected_value = exp_data.get("expectedValue", {})
            if expected_value:
                expectation.kpi_name = expected_value.get("kpiName")
                expectation.kpi_value = expected_value.get("kpiValue")
                expectation.kpi_unit = expected_value.get("kpiUnit")
                expectation.operator = expected_value.get("operator")
            
            # Parse TMF921 format
            target_condition = exp_data.get("targetCondition", "")
            target_value = exp_data.get("targetValue", {})
            
            if target_condition and target_value:
                # Extract KPI name from target condition (e.g., "latency <= 1 ms" -> "latency")
                import re
                kpi_match = re.match(r'^(\w+)\s*[<>=]+\s*', target_condition)
                if kpi_match:
                    expectation.kpi_name = kpi_match.group(1)
                
                expectation.kpi_value = str(target_value.get("value", ""))
                expectation.kpi_unit = target_value.get("unit")
                
                # Extract operator from target condition
                if "<=" in target_condition:
                    expectation.operator = "lessThanOrEqual"
                elif ">=" in target_condition:
                    expectation.operator = "greaterThanOrEqual"
                elif "<" in target_condition:
                    expectation.operator = "lessThan"
                elif ">" in target_condition:
                    expectation.operator = "greaterThan"
                elif "=" in target_condition:
                    expectation.operator = "equal"
            
            expectations.append(expectation)
            
        return expectations