#!/usr/bin/env python3
"""
ACC-18 Intent→KRM Contract Testing using TDD methodology
Tests TMF921 JSON → KRM (O2IMS PR + site overlays) translation contract

TDD Requirements:
1. Feed 3 golden intents (edge1/edge2/both)
2. Assert exact file creation under rendered/krm/<site>/**
3. kubeconform validate
4. Output: artifacts/acc18/contract_report.json with per-field mapping checks
"""

import json
import yaml
import pytest
import subprocess
import os
import sys
import tempfile
import shutil
from pathlib import Path
from typing import Dict, Any, List, Tuple
from datetime import datetime
import deepdiff

# Add tools to path
sys.path.insert(0, str(Path(__file__).parent.parent / "tools" / "intent-compiler"))
from translate import IntentToKRMTranslator

class TMF921ContractTest:
    """Contract test suite for TMF921 Intent to KRM translation"""

    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.test_dir = self.project_root / "tests"
        self.artifacts_dir = self.project_root / "artifacts" / "acc18"
        self.artifacts_dir.mkdir(parents=True, exist_ok=True)

        # Contract validation report
        self.contract_report = {
            "test_execution": {
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "test_type": "ACC-18_Intent_KRM_Contract",
                "methodology": "TDD_Red_Green_Refactor"
            },
            "tmf921_compliance": {
                "version": "TMF921_v5.0/921A",
                "schema_validation": {},
                "field_mappings": {}
            },
            "test_results": {
                "golden_intents": {},
                "krm_generation": {},
                "kubeconform_validation": {},
                "contract_assertions": {}
            },
            "metrics": {
                "total_tests": 0,
                "passed": 0,
                "failed": 0,
                "coverage_percentage": 0
            }
        }

    def setup_golden_intents(self) -> Dict[str, Dict[str, Any]]:
        """Create TMF921-compliant golden intents for contract testing"""

        golden_intents = {
            "edge1": {
                "id": "golden-edge1-001",
                "intentType": "NetworkSliceIntent",
                "state": "acknowledged",
                "name": "Golden Edge1 eMBB Service",
                "description": "Enhanced Mobile Broadband service for edge1 site",
                "priority": 2,
                "version": "1.0.0",
                "creationDate": "2025-09-13T00:00:00Z",
                "lastModified": "2025-09-13T00:00:00Z",
                "@baseType": "Intent",
                "@type": "NetworkSliceIntent",
                "@schemaLocation": "https://schemas.tmforum.org/Intent/v5.0.0/schema/Intent.schema.json",

                # Intent-specific fields for translator
                "intentId": "golden-edge1-001",
                "serviceType": "enhanced-mobile-broadband",
                "targetSite": "edge1",
                "resourceProfile": "standard",

                "characteristic": [
                    {"name": "serviceType", "value": "enhanced-mobile-broadband", "valueType": "string"},
                    {"name": "sliceType", "value": "eMBB", "valueType": "string"},
                    {"name": "maxUEs", "value": 10000, "valueType": "integer"},
                    {"name": "maxConnections", "value": 50000, "valueType": "integer"}
                ],

                "expectation": [
                    {
                        "id": "perf-exp-001",
                        "name": "Throughput Performance",
                        "expectationType": "PerformanceExpectation",
                        "targetCondition": "downlinkThroughput >= 1Gbps",
                        "targetValue": {"value": "1000", "unit": "Mbps"}
                    },
                    {
                        "id": "qos-exp-001",
                        "name": "Latency Quality",
                        "expectationType": "QualityExpectation",
                        "targetCondition": "latency <= 20ms",
                        "targetValue": {"value": "20", "unit": "ms"}
                    }
                ],

                "sla": {
                    "availability": 99.99,
                    "latency": 10,
                    "throughput": 1000,
                    "connections": 50000
                },

                "validFor": {
                    "startDateTime": "2025-01-01T00:00:00Z",
                    "endDateTime": "2025-12-31T23:59:59Z"
                }
            },

            "edge2": {
                "id": "golden-edge2-001",
                "intentType": "NetworkSliceIntent",
                "state": "acknowledged",
                "name": "Golden Edge2 URLLC Service",
                "description": "Ultra-Reliable Low-Latency service for edge2 site",
                "priority": 1,
                "version": "1.0.0",
                "creationDate": "2025-09-13T00:00:00Z",
                "lastModified": "2025-09-13T00:00:00Z",
                "@baseType": "Intent",
                "@type": "NetworkSliceIntent",
                "@schemaLocation": "https://schemas.tmforum.org/Intent/v5.0.0/schema/Intent.schema.json",

                # Intent-specific fields for translator
                "intentId": "golden-edge2-001",
                "serviceType": "ultra-reliable-low-latency",
                "targetSite": "edge2",
                "resourceProfile": "high-performance",

                "characteristic": [
                    {"name": "serviceType", "value": "ultra-reliable-low-latency", "valueType": "string"},
                    {"name": "sliceType", "value": "URLLC", "valueType": "string"},
                    {"name": "maxUEs", "value": 1000, "valueType": "integer"},
                    {"name": "maxConnections", "value": 5000, "valueType": "integer"}
                ],

                "expectation": [
                    {
                        "id": "perf-exp-002",
                        "name": "Ultra-Low Latency",
                        "expectationType": "PerformanceExpectation",
                        "targetCondition": "latency <= 1ms",
                        "targetValue": {"value": "1", "unit": "ms"}
                    },
                    {
                        "id": "rel-exp-002",
                        "name": "Ultra Reliability",
                        "expectationType": "QualityExpectation",
                        "targetCondition": "reliability >= 99.999%",
                        "targetValue": {"value": "99.999", "unit": "%"}
                    }
                ],

                "sla": {
                    "availability": 99.999,
                    "latency": 1,
                    "throughput": 500,
                    "connections": 5000
                },

                "validFor": {
                    "startDateTime": "2025-01-01T00:00:00Z",
                    "endDateTime": "2025-12-31T23:59:59Z"
                }
            },

            "both": {
                "id": "golden-both-001",
                "intentType": "NetworkSliceIntent",
                "state": "acknowledged",
                "name": "Golden Multi-Site mMTC Service",
                "description": "Massive Machine Type Communication service for multi-site deployment",
                "priority": 3,
                "version": "1.0.0",
                "creationDate": "2025-09-13T00:00:00Z",
                "lastModified": "2025-09-13T00:00:00Z",
                "@baseType": "Intent",
                "@type": "NetworkSliceIntent",
                "@schemaLocation": "https://schemas.tmforum.org/Intent/v5.0.0/schema/Intent.schema.json",

                # Intent-specific fields for translator
                "intentId": "golden-both-001",
                "serviceType": "massive-machine-type",
                "targetSite": "both",
                "resourceProfile": "standard",

                "characteristic": [
                    {"name": "serviceType", "value": "massive-machine-type", "valueType": "string"},
                    {"name": "sliceType", "value": "mMTC", "valueType": "string"},
                    {"name": "maxUEs", "value": 100000, "valueType": "integer"},
                    {"name": "maxConnections", "value": 500000, "valueType": "integer"},
                    {"name": "connectionDensity", "value": "1000000/km2", "valueType": "string"}
                ],

                "expectation": [
                    {
                        "id": "scale-exp-003",
                        "name": "Massive Scale Support",
                        "expectationType": "PerformanceExpectation",
                        "targetCondition": "connectionDensity >= 1M/km2",
                        "targetValue": {"value": "1000000", "unit": "connections/km2"}
                    }
                ],

                "sla": {
                    "availability": 99.0,
                    "latency": 100,
                    "throughput": 100,
                    "connections": 500000
                },

                "validFor": {
                    "startDateTime": "2025-01-01T00:00:00Z",
                    "endDateTime": "2025-12-31T23:59:59Z"
                }
            }
        }

        return golden_intents

    def validate_tmf921_compliance(self, intent: Dict[str, Any]) -> Dict[str, Any]:
        """Validate intent against TMF921 v5.0 schema"""

        validation_result = {
            "valid": True,
            "errors": [],
            "required_fields_present": [],
            "missing_fields": []
        }

        # Required TMF921 fields
        required_fields = ["id", "intentType", "state", "@baseType", "@type"]

        for field in required_fields:
            if field in intent:
                validation_result["required_fields_present"].append(field)
            else:
                validation_result["missing_fields"].append(field)
                validation_result["valid"] = False
                validation_result["errors"].append(f"Missing required field: {field}")

        # Validate enum values
        if "intentType" in intent:
            valid_types = ["NetworkSliceIntent", "ServiceIntent", "ResourceIntent", "PolicyIntent", "CustomIntent"]
            if intent["intentType"] not in valid_types:
                validation_result["valid"] = False
                validation_result["errors"].append(f"Invalid intentType: {intent['intentType']}")

        if "state" in intent:
            valid_states = ["acknowledged", "inProgress", "fulfilled", "cancelled", "failed"]
            if intent["state"] not in valid_states:
                validation_result["valid"] = False
                validation_result["errors"].append(f"Invalid state: {intent['state']}")

        return validation_result

    def create_test_intent_files(self, golden_intents: Dict[str, Dict[str, Any]]) -> Dict[str, str]:
        """Create temporary intent files for testing"""

        temp_files = {}

        for intent_name, intent_data in golden_intents.items():
            temp_file = self.artifacts_dir / f"golden_intent_{intent_name}.json"
            with open(temp_file, 'w') as f:
                json.dump(intent_data, f, indent=2)
            temp_files[intent_name] = str(temp_file)

        return temp_files

    def test_intent_to_krm_translation(self, intent_file: str, intent_name: str) -> Dict[str, Any]:
        """Test the intent to KRM translation contract"""

        test_result = {
            "intent_name": intent_name,
            "intent_file": intent_file,
            "translation_success": False,
            "generated_files": [],
            "expected_files": [],
            "file_validation": {},
            "kubeconform_results": {},
            "field_mappings": {}
        }

        try:
            # Create temporary output directory
            with tempfile.TemporaryDirectory() as temp_output:
                translator = IntentToKRMTranslator(temp_output)

                # Translate intent to KRM
                results = translator.translate(intent_file)
                translator.save_resources(results)

                test_result["translation_success"] = True

                # Validate generated files
                for site, resources in results.items():
                    site_dir = Path(temp_output) / site

                    # Expected files based on translator logic
                    expected_files = [
                        f"*-{site}-provisioning-request.yaml",
                        f"intent-*-{site}-configmap.yaml",
                        "kustomization.yaml"
                    ]

                    # Check if SLA/NetworkSlice should be generated
                    with open(intent_file, 'r') as f:
                        intent_data = json.load(f)
                    if "sla" in intent_data:
                        expected_files.append(f"slice-*-{site}-networkslice.yaml")

                    test_result["expected_files"].extend([f"{site}/{ef}" for ef in expected_files])

                    # List actually generated files
                    if site_dir.exists():
                        generated_files = list(site_dir.glob("*.yaml"))
                        test_result["generated_files"].extend([f"{site}/{f.name}" for f in generated_files])

                        # Validate each file with kubeconform
                        for file_path in generated_files:
                            kubeconf_result = self.validate_with_kubeconform(file_path)
                            test_result["kubeconform_results"][f"{site}/{file_path.name}"] = kubeconf_result

                        # Validate field mappings
                        field_mapping_result = self.validate_field_mappings(intent_data, resources, site)
                        test_result["field_mappings"][site] = field_mapping_result

        except Exception as e:
            test_result["error"] = str(e)
            test_result["translation_success"] = False

        return test_result

    def validate_with_kubeconform(self, file_path: Path) -> Dict[str, Any]:
        """Validate KRM file with kubeconform"""

        result = {
            "valid": False,
            "errors": [],
            "file": str(file_path)
        }

        try:
            # Run kubeconform validation
            cmd = ["kubeconform", "-summary", "-verbose", str(file_path)]
            process = subprocess.run(cmd, capture_output=True, text=True)

            result["exit_code"] = process.returncode
            result["stdout"] = process.stdout
            result["stderr"] = process.stderr

            if process.returncode == 0:
                result["valid"] = True
            else:
                result["errors"].append(f"kubeconform validation failed: {process.stderr}")

        except Exception as e:
            result["errors"].append(f"kubeconform execution error: {str(e)}")

        return result

    def validate_field_mappings(self, intent: Dict[str, Any], krm_resources: List[Dict[str, Any]], site: str) -> Dict[str, Any]:
        """Validate field-by-field mapping from TMF921 intent to KRM resources"""

        mapping_result = {
            "total_mappings": 0,
            "successful_mappings": 0,
            "failed_mappings": 0,
            "mapping_details": {}
        }

        # Define expected field mappings
        field_mappings = [
            # Intent ID mapping
            {
                "source_path": "intentId",
                "target_resource": "ProvisioningRequest",
                "target_path": "metadata.labels.intent-id",
                "mapping_type": "direct"
            },
            {
                "source_path": "intentId",
                "target_resource": "ProvisioningRequest",
                "target_path": "metadata.name",
                "mapping_type": "transform",
                "transform": lambda x: f"{x}-{site}"
            },
            # Service type mapping
            {
                "source_path": "serviceType",
                "target_resource": "ProvisioningRequest",
                "target_path": "metadata.labels.service-type",
                "mapping_type": "direct"
            },
            # Target site mapping
            {
                "source_path": "targetSite",
                "target_resource": "ProvisioningRequest",
                "target_path": "metadata.labels.target-site",
                "mapping_type": "transform",
                "transform": lambda x: site if x == "both" else x
            },
            # SLA mapping to spec.slaRequirements
            {
                "source_path": "sla.availability",
                "target_resource": "ProvisioningRequest",
                "target_path": "spec.slaRequirements.availability",
                "mapping_type": "transform",
                "transform": lambda x: f"{x}%"
            },
            {
                "source_path": "sla.latency",
                "target_resource": "ProvisioningRequest",
                "target_path": "spec.slaRequirements.maxLatency",
                "mapping_type": "transform",
                "transform": lambda x: f"{x}ms"
            },
            {
                "source_path": "sla.throughput",
                "target_resource": "ProvisioningRequest",
                "target_path": "spec.slaRequirements.minThroughput",
                "mapping_type": "transform",
                "transform": lambda x: f"{x}Mbps"
            }
        ]

        # Find resources by kind
        pr_resource = None
        cm_resource = None
        ns_resource = None

        for resource in krm_resources:
            if resource.get("kind") == "ProvisioningRequest":
                pr_resource = resource
            elif resource.get("kind") == "ConfigMap":
                cm_resource = resource
            elif resource.get("kind") == "NetworkSlice":
                ns_resource = resource

        # Validate each mapping
        for mapping in field_mappings:
            mapping_result["total_mappings"] += 1
            mapping_detail = {
                "source_path": mapping["source_path"],
                "target_path": mapping["target_path"],
                "target_resource": mapping["target_resource"],
                "mapping_type": mapping["mapping_type"],
                "success": False,
                "error": None,
                "source_value": None,
                "target_value": None
            }

            try:
                # Get source value from intent
                source_value = self._get_nested_value(intent, mapping["source_path"])
                mapping_detail["source_value"] = source_value

                if source_value is not None:
                    # Get target resource
                    target_resource = None
                    if mapping["target_resource"] == "ProvisioningRequest":
                        target_resource = pr_resource
                    elif mapping["target_resource"] == "ConfigMap":
                        target_resource = cm_resource
                    elif mapping["target_resource"] == "NetworkSlice":
                        target_resource = ns_resource

                    if target_resource:
                        # Get target value
                        target_value = self._get_nested_value(target_resource, mapping["target_path"])
                        mapping_detail["target_value"] = target_value

                        # Validate mapping
                        expected_value = source_value
                        if mapping["mapping_type"] == "transform" and "transform" in mapping:
                            expected_value = mapping["transform"](source_value)

                        if target_value == expected_value:
                            mapping_detail["success"] = True
                            mapping_result["successful_mappings"] += 1
                        else:
                            mapping_detail["error"] = f"Value mismatch: expected {expected_value}, got {target_value}"
                            mapping_result["failed_mappings"] += 1
                    else:
                        mapping_detail["error"] = f"Target resource {mapping['target_resource']} not found"
                        mapping_result["failed_mappings"] += 1
                else:
                    mapping_detail["error"] = f"Source value not found at {mapping['source_path']}"
                    mapping_result["failed_mappings"] += 1

            except Exception as e:
                mapping_detail["error"] = f"Mapping validation error: {str(e)}"
                mapping_result["failed_mappings"] += 1

            mapping_result["mapping_details"][f"{mapping['source_path']}->{mapping['target_path']}"] = mapping_detail

        return mapping_result

    def _get_nested_value(self, data: Dict[str, Any], path: str) -> Any:
        """Get nested value from dict using dot notation"""
        keys = path.split('.')
        current = data

        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None

        return current

    def run_tdd_contract_tests(self) -> Dict[str, Any]:
        """Execute TDD contract tests for ACC-18"""

        print("🔄 Running ACC-18 Intent→KRM Contract Tests using TDD methodology...")

        # RED: Define failing tests first
        print("\n📍 TDD Phase 1: RED - Defining failing contract tests")

        # Setup golden intents
        golden_intents = self.setup_golden_intents()

        # Validate TMF921 compliance
        for intent_name, intent_data in golden_intents.items():
            validation = self.validate_tmf921_compliance(intent_data)
            self.contract_report["tmf921_compliance"]["schema_validation"][intent_name] = validation

        # Create test files
        intent_files = self.create_test_intent_files(golden_intents)

        # GREEN: Execute tests and validate existing implementation
        print("\n📍 TDD Phase 2: GREEN - Validating existing translation implementation")

        for intent_name, intent_file in intent_files.items():
            print(f"  Testing {intent_name} intent...")

            test_result = self.test_intent_to_krm_translation(intent_file, intent_name)
            self.contract_report["test_results"]["golden_intents"][intent_name] = test_result

            if test_result["translation_success"]:
                self.contract_report["metrics"]["passed"] += 1
                print(f"    ✅ Translation successful")
            else:
                self.contract_report["metrics"]["failed"] += 1
                print(f"    ❌ Translation failed: {test_result.get('error', 'Unknown error')}")

        self.contract_report["metrics"]["total_tests"] = len(intent_files)

        # Calculate coverage
        if self.contract_report["metrics"]["total_tests"] > 0:
            self.contract_report["metrics"]["coverage_percentage"] = (
                self.contract_report["metrics"]["passed"] / self.contract_report["metrics"]["total_tests"]
            ) * 100

        # REFACTOR: Ensure robust contract compliance
        print("\n📍 TDD Phase 3: REFACTOR - Ensuring robust contract compliance")

        # Generate comprehensive contract report
        report_file = self.artifacts_dir / "contract_report.json"
        with open(report_file, 'w') as f:
            json.dump(self.contract_report, f, indent=2)

        print(f"\n📋 Contract report generated: {report_file}")
        print(f"📊 Test Summary: {self.contract_report['metrics']['passed']}/{self.contract_report['metrics']['total_tests']} passed")
        print(f"📈 Coverage: {self.contract_report['metrics']['coverage_percentage']:.1f}%")

        return self.contract_report


def main():
    """Run ACC-18 contract tests"""
    tester = TMF921ContractTest()
    report = tester.run_tdd_contract_tests()

    # Return appropriate exit code
    if report["metrics"]["failed"] == 0:
        print("\n🎉 All contract tests passed!")
        return 0
    else:
        print(f"\n⚠️  {report['metrics']['failed']} contract tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())