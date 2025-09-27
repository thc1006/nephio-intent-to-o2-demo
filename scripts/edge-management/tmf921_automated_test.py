#!/usr/bin/env python3
"""
TMF921 Adapter Automated Test Script
Demonstrates fully automated usage without passwords or manual intervention
"""

import requests
import json
import time
import sys
from typing import Dict, Any, List
from dataclasses import dataclass


@dataclass
class TestCase:
    """Test case for TMF921 adapter"""
    name: str
    input_data: Dict[str, Any]
    expected_service_type: str
    expected_target_site: str
    expected_sst: int


class TMF921AutomatedTester:
    """Automated tester for TMF921 adapter"""

    def __init__(self, base_url: str = "http://localhost:8889"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'TMF921-Automated-Tester/1.0'
        })
        self.test_results = []

    def check_health(self) -> bool:
        """Check if the TMF921 adapter is healthy"""
        try:
            response = self.session.get(f"{self.base_url}/health", timeout=5)
            if response.status_code == 200:
                health_data = response.json()
                print(f"✅ Service is healthy - Status: {health_data['status']}")
                return True
            else:
                print(f"❌ Health check failed - Status: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ Cannot reach service: {e}")
            return False

    def generate_intent(self, natural_language: str, target_site: str = None) -> Dict[str, Any]:
        """Generate TMF921 intent from natural language"""
        payload = {"natural_language": natural_language}
        if target_site:
            payload["target_site"] = target_site

        try:
            response = self.session.post(
                f"{self.base_url}/generate_intent",
                json=payload,
                timeout=30
            )

            if response.status_code == 200:
                return response.json()
            else:
                raise Exception(f"API error: {response.status_code} - {response.text}")

        except Exception as e:
            raise Exception(f"Request failed: {e}")

    def validate_tmf921_structure(self, intent: Dict[str, Any]) -> List[str]:
        """Validate TMF921 structure and return list of issues"""
        issues = []

        # Required top-level fields
        required_fields = ["intentId", "name", "description", "service", "targetSite", "qos", "slice", "priority", "lifecycle", "metadata"]
        for field in required_fields:
            if field not in intent:
                issues.append(f"Missing required field: {field}")

        # Service structure validation
        if "service" in intent:
            service = intent["service"]
            if not isinstance(service, dict):
                issues.append("Service must be an object")
            else:
                service_required = ["name", "type", "characteristics"]
                for field in service_required:
                    if field not in service:
                        issues.append(f"Missing service field: {field}")

                # Validate service type
                if "type" in service and service["type"] not in ["eMBB", "URLLC", "mMTC", "generic"]:
                    issues.append(f"Invalid service type: {service['type']}")

        # QoS structure validation
        if "qos" in intent:
            qos = intent["qos"]
            if not isinstance(qos, dict):
                issues.append("QoS must be an object")

        # Slice structure validation
        if "slice" in intent:
            slice_data = intent["slice"]
            if not isinstance(slice_data, dict):
                issues.append("Slice must be an object")
            else:
                if "sst" not in slice_data:
                    issues.append("Missing slice SST field")
                elif slice_data["sst"] not in [1, 2, 3]:
                    issues.append(f"Invalid SST value: {slice_data['sst']}")

        # Target site validation
        if "targetSite" in intent:
            target_site = intent["targetSite"]
            if target_site not in ["edge1", "edge2", "edge3", "edge4", "both"]:
                issues.append(f"Invalid targetSite: {target_site}")

        # Priority validation
        if "priority" in intent:
            priority = intent["priority"]
            if priority not in ["low", "medium", "high", "critical"]:
                issues.append(f"Invalid priority: {priority}")

        # Lifecycle validation
        if "lifecycle" in intent:
            lifecycle = intent["lifecycle"]
            if lifecycle not in ["draft", "active", "inactive", "deprecated"]:
                issues.append(f"Invalid lifecycle: {lifecycle}")

        return issues

    def run_test_case(self, test_case: TestCase) -> bool:
        """Run a single test case"""
        print(f"\n🧪 Running test: {test_case.name}")
        print(f"   Input: {test_case.input_data['natural_language']}")

        try:
            # Generate intent
            start_time = time.time()
            result = self.generate_intent(**test_case.input_data)
            execution_time = time.time() - start_time

            intent = result["intent"]

            # Validate structure
            issues = self.validate_tmf921_structure(intent)
            if issues:
                print(f"❌ Structure validation failed:")
                for issue in issues:
                    print(f"   - {issue}")
                return False

            # Validate expected values
            service_type = intent.get("service", {}).get("type")
            target_site = intent.get("targetSite")
            sst = intent.get("slice", {}).get("sst")

            success = True

            if service_type != test_case.expected_service_type:
                print(f"❌ Service type mismatch: got {service_type}, expected {test_case.expected_service_type}")
                success = False

            if target_site != test_case.expected_target_site:
                print(f"❌ Target site mismatch: got {target_site}, expected {test_case.expected_target_site}")
                success = False

            if sst != test_case.expected_sst:
                print(f"❌ SST mismatch: got {sst}, expected {test_case.expected_sst}")
                success = False

            if success:
                print(f"✅ Test passed - Execution time: {execution_time:.3f}s")
                print(f"   Intent ID: {intent['intentId']}")
                print(f"   Service: {service_type}, Target: {target_site}, SST: {sst}")

            self.test_results.append({
                "test_name": test_case.name,
                "success": success,
                "execution_time": execution_time,
                "intent_id": intent.get("intentId")
            })

            return success

        except Exception as e:
            print(f"❌ Test failed: {e}")
            self.test_results.append({
                "test_name": test_case.name,
                "success": False,
                "error": str(e)
            })
            return False

    def run_all_tests(self) -> bool:
        """Run all automated tests"""
        test_cases = [
            TestCase(
                name="eMBB Gaming Service at Edge1",
                input_data={
                    "natural_language": "Deploy 5G network slice with high bandwidth for gaming at edge1",
                    "target_site": "edge1"
                },
                expected_service_type="eMBB",
                expected_target_site="edge1",
                expected_sst=1
            ),
            TestCase(
                name="URLLC Industrial Automation at Edge2",
                input_data={
                    "natural_language": "Setup ultra-low latency service for industrial automation at edge2"
                },
                expected_service_type="URLLC",
                expected_target_site="edge2",
                expected_sst=2
            ),
            TestCase(
                name="mMTC IoT Sensors at Edge3",
                input_data={
                    "natural_language": "Configure IoT sensor monitoring network at edge3",
                    "target_site": "edge3"
                },
                expected_service_type="mMTC",
                expected_target_site="edge3",
                expected_sst=3
            ),
            TestCase(
                name="Multi-site Video Streaming",
                input_data={
                    "natural_language": "Deploy video streaming service across all edge sites"
                },
                expected_service_type="eMBB",
                expected_target_site="both",
                expected_sst=1
            ),
            TestCase(
                name="Edge4 Critical Service",
                input_data={
                    "natural_language": "Setup real-time critical service for autonomous vehicles",
                    "target_site": "edge4"
                },
                expected_service_type="URLLC",
                expected_target_site="edge4",
                expected_sst=2
            ),
            TestCase(
                name="Auto-detection Test",
                input_data={
                    "natural_language": "Deploy machine monitoring sensors at edge site 2"
                },
                expected_service_type="mMTC",
                expected_target_site="edge2",
                expected_sst=3
            )
        ]

        print("🚀 Starting TMF921 Adapter Automated Test Suite")
        print(f"   Service URL: {self.base_url}")
        print(f"   Total test cases: {len(test_cases)}")

        # Check health first
        if not self.check_health():
            print("❌ Service health check failed. Please start the adapter service.")
            return False

        # Run all tests
        passed = 0
        failed = 0

        for test_case in test_cases:
            if self.run_test_case(test_case):
                passed += 1
            else:
                failed += 1

        # Print summary
        print(f"\n📊 Test Summary:")
        print(f"   Total: {len(test_cases)}")
        print(f"   Passed: {passed}")
        print(f"   Failed: {failed}")
        print(f"   Success rate: {(passed/len(test_cases)*100):.1f}%")

        if failed == 0:
            print("\n🎉 All tests passed! TMF921 adapter is working correctly.")
            return True
        else:
            print(f"\n⚠️  {failed} test(s) failed. Check the issues above.")
            return False

    def demo_automation_workflow(self):
        """Demonstrate complete automation workflow"""
        print("\n🔄 Demonstrating Complete Automation Workflow")

        # Example workflow: Processing multiple intents in sequence
        workflows = [
            {
                "name": "Gaming Network Setup",
                "steps": [
                    {"nl": "Deploy eMBB service for gaming at edge1", "site": "edge1"},
                    {"nl": "Configure QoS for low latency gaming", "site": "edge1"},
                    {"nl": "Setup load balancing across edge sites", "site": "both"}
                ]
            },
            {
                "name": "Industrial IoT Deployment",
                "steps": [
                    {"nl": "Deploy mMTC for sensor networks at edge2", "site": "edge2"},
                    {"nl": "Configure URLLC for critical control systems", "site": "edge2"},
                    {"nl": "Setup backup connectivity to edge3", "site": "edge3"}
                ]
            }
        ]

        for workflow in workflows:
            print(f"\n📋 Workflow: {workflow['name']}")
            workflow_intents = []

            for i, step in enumerate(workflow['steps'], 1):
                print(f"   Step {i}: {step['nl']}")
                try:
                    result = self.generate_intent(step['nl'], step['site'])
                    intent_id = result['intent']['intentId']
                    workflow_intents.append(intent_id)
                    print(f"   ✅ Generated intent: {intent_id}")
                except Exception as e:
                    print(f"   ❌ Failed: {e}")

            print(f"   🎯 Workflow completed with {len(workflow_intents)} intents")

        print("\n✨ Automation workflow demonstration completed")


def main():
    """Main function"""
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        base_url = "http://localhost:8889"

    tester = TMF921AutomatedTester(base_url)

    # Run all tests
    success = tester.run_all_tests()

    # Demonstrate automation workflow
    tester.demo_automation_workflow()

    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()